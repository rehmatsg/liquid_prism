import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether iOS may move bars into a vertical bar beside the content.
enum GlassVerticalBarBehavior {
  /// The system decides, as on iPhone Duo.
  automatic,

  /// Bars stay horizontal and the status bar returns to the horizontal axis.
  /// Apple reserves this for UIs better served by horizontal bars, such as a
  /// full-screen video player or a non-scrolling calculator.
  disabled,
}

/// A UIKit size class. On iPhone Duo an iPhone app can have any combination:
/// compact width outside, regular width and height inside.
enum GlassSizeClass { compact, regular }

/// A region of the Flutter view reserved by the system
/// (`UIView.ReservedRegion`), in logical coordinates.
@immutable
class GlassReservedRegion {
  const GlassReservedRegion({
    required this.frame,
    this.margins = EdgeInsets.zero,
    this.active = true,
  });

  /// The region, including [margins] that interactive content should keep
  /// clear of.
  final Rect frame;
  final EdgeInsets margins;

  /// Whether the region currently applies, such as a fold that is bent.
  final bool active;

  /// [frame] without its margins: the area the system itself occupies.
  Rect get reserved => margins.deflateRect(frame);

  @override
  bool operator ==(Object other) =>
      other is GlassReservedRegion &&
      other.frame == frame &&
      other.margins == margins &&
      other.active == active;

  @override
  int get hashCode => Object.hash(frame, margins, active);

  @override
  String toString() =>
      'GlassReservedRegion($frame, margins: $margins, active: $active)';
}

/// Where iOS places its bars and system UI around the Flutter view.
///
/// Reported on iOS 27.1 and later from `UITraitCollection.verticalBarEdge`
/// and `UIView.reservedRegions(kind:)`. Use it to keep your own sheets,
/// dialogs and custom bars clear of the status bar, camera and fold, and to
/// put controls on the same edge as the system's vertical bar.
@immutable
class GlassSystemChrome {
  const GlassSystemChrome({
    this.verticalBarEdge,
    this.verticalBarBehavior = GlassVerticalBarBehavior.automatic,
    this.horizontalSizeClass,
    this.verticalSizeClass,
    this.occlusions = const [],
    this.divisions = const [],
  });

  /// Parses the `liquid_prism/system_chrome` payload. Null before iOS 27.1.
  static GlassSystemChrome? fromMap(Map<Object?, Object?> map) {
    if (map['supported'] != true) return null;
    double at(List<Object?> values, int index) =>
        index < values.length ? (values[index]! as num).toDouble() : 0;
    GlassReservedRegion region(List<Object?> values) => GlassReservedRegion(
      frame: Rect.fromLTWH(
        at(values, 0),
        at(values, 1),
        at(values, 2),
        at(values, 3),
      ),
      margins: EdgeInsets.fromLTRB(
        at(values, 4),
        at(values, 5),
        at(values, 6),
        at(values, 7),
      ),
      active: values.length < 9 || at(values, 8) != 0,
    );
    List<GlassReservedRegion> regions(Object? value) => [
      for (final values
          in (value as List<Object?>? ?? const []).cast<List<Object?>>())
        region(values),
    ];
    GlassSizeClass? sizeClass(Object? value) => switch (value) {
      'compact' => GlassSizeClass.compact,
      'regular' => GlassSizeClass.regular,
      _ => null,
    };
    return GlassSystemChrome(
      verticalBarEdge: switch (map['verticalBarEdge']) {
        'left' => AxisDirection.left,
        'right' => AxisDirection.right,
        _ => null,
      },
      verticalBarBehavior: map['verticalBarBehavior'] == 'disabled'
          ? GlassVerticalBarBehavior.disabled
          : GlassVerticalBarBehavior.automatic,
      horizontalSizeClass: sizeClass(map['horizontalSizeClass']),
      verticalSizeClass: sizeClass(map['verticalSizeClass']),
      occlusions: regions(map['occlusions']),
      divisions: regions(map['divisions']),
    );
  }

  /// [AxisDirection.left] or [AxisDirection.right] when the system prefers a
  /// vertical bar on that physical edge; null for horizontal bars. UIKit keeps
  /// reporting the edge after an app disables the vertical bar, so check
  /// [hasVerticalBar] for whether one is in use.
  final AxisDirection? verticalBarEdge;

  /// The app's preference, set with
  /// [LiquidPrismSystemChrome.setVerticalBarBehavior].
  final GlassVerticalBarBehavior verticalBarBehavior;

  /// The Flutter view's size classes. Choose layouts by these, not by device.
  final GlassSizeClass? horizontalSizeClass, verticalSizeClass;

  /// Whether bars sit in a vertical bar on [verticalBarEdge] right now.
  bool get hasVerticalBar =>
      verticalBarEdge != null &&
      verticalBarBehavior != GlassVerticalBarBehavior.disabled;

  /// Regions covered by system UI: the status bar in the vertical bar, the
  /// camera. Includes inactive regions.
  final List<GlassReservedRegion> occlusions;

  /// Regions content should divide around, such as the fold. Includes
  /// inactive regions; a fold is active while the device is bent.
  final List<GlassReservedRegion> divisions;

  /// Active [divisions] as Flutter display features. Dialogs, popup menus and
  /// `DisplayFeatureSubScreen` keep content on one side of these.
  List<DisplayFeature> get displayFeatures => [
    for (final division in divisions)
      if (division.active)
        DisplayFeature(
          bounds: division.frame,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
  ];

  @override
  bool operator ==(Object other) =>
      other is GlassSystemChrome &&
      other.verticalBarEdge == verticalBarEdge &&
      other.verticalBarBehavior == verticalBarBehavior &&
      other.horizontalSizeClass == horizontalSizeClass &&
      other.verticalSizeClass == verticalSizeClass &&
      listEquals(other.occlusions, occlusions) &&
      listEquals(other.divisions, divisions);

  @override
  int get hashCode => Object.hash(
    verticalBarEdge,
    verticalBarBehavior,
    horizontalSizeClass,
    verticalSizeClass,
    Object.hashAll(occlusions),
    Object.hashAll(divisions),
  );

  @override
  String toString() =>
      'GlassSystemChrome(edge: $verticalBarEdge, occlusions: $occlusions, '
      'divisions: $divisions)';
}

/// Publishes [GlassSystemChrome] below it and adds an active fold to
/// [MediaQueryData.displayFeatures], so standard dialogs, popup menus and
/// sheets avoid it.
///
/// Place it in your app's builder so routes see it too:
///
/// ```dart
/// CupertinoApp(
///   builder: (context, child) => LiquidPrismSystemChrome(child: child!),
/// )
/// ```
class LiquidPrismSystemChrome extends StatelessWidget {
  const LiquidPrismSystemChrome({super.key, required this.child});
  final Widget child;

  /// The latest report, for code outside the widget tree. Null on other
  /// platforms, before iOS 27.1 and without the plugin.
  static ValueListenable<GlassSystemChrome?> get listenable =>
      SystemChromeListener.instance.value;

  /// The report from the nearest [LiquidPrismSystemChrome]. Without one, the
  /// latest report, without rebuilding when it changes.
  static GlassSystemChrome? of(BuildContext context) =>
      scopeOf(context)?.chrome ?? listenable.value;

  /// The nearest scope, used by `LiquidPrismScaffold` to avoid adding the
  /// same display features twice.
  @internal
  static SystemChromeScope? scopeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SystemChromeScope>();

  /// Asks iOS to keep bars horizontal, or to decide again. Returns whether it
  /// applied: it needs iOS 27.1 and `LiquidPrismViewController` as the
  /// Flutter view controller. Apple asks that this stay a stable choice, not
  /// one that changes as people navigate.
  static Future<bool> setVerticalBarBehavior(
    GlassVerticalBarBehavior behavior,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await const MethodChannel('liquid_prism/system')
              .invokeMethod<bool>('setVerticalBarBehavior', {
                'behavior': behavior.name,
              }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<GlassSystemChrome?>(
        valueListenable: listenable,
        builder: (context, chrome, _) {
          final features = chrome?.displayFeatures ?? const [];
          final media = MediaQuery.maybeOf(context);
          return SystemChromeScope(
            chrome: chrome,
            child: media == null || features.isEmpty
                ? child
                : MediaQuery(
                    data: media.copyWith(
                      displayFeatures: [...media.displayFeatures, ...features],
                    ),
                    child: child,
                  ),
          );
        },
      );
}

@internal
class SystemChromeScope extends InheritedWidget {
  const SystemChromeScope({
    super.key,
    required this.chrome,
    required super.child,
  });
  final GlassSystemChrome? chrome;

  @override
  bool updateShouldNotify(SystemChromeScope oldWidget) =>
      chrome != oldWidget.chrome;
}

/// The latest [GlassSystemChrome] from the plugin, subscribed on first use.
/// Stays null on other platforms, before iOS 27.1 and without the plugin.
class SystemChromeListener {
  SystemChromeListener._();
  static final instance = SystemChromeListener._();

  static const channel = EventChannel('liquid_prism/system_chrome');

  final _value = ValueNotifier<GlassSystemChrome?>(null);
  StreamSubscription<Object?>? _subscription;
  bool _started = false;

  ValueListenable<GlassSystemChrome?> get value {
    if (!_started && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _started = true;
      unawaited(_listen());
    }
    return _value;
  }

  Future<void> _listen() async {
    // An unregistered event channel reports its failure as a Flutter error, so
    // confirm the plugin is present with a call whose failure can be caught.
    try {
      await const MethodChannel('liquid_prism/menus')
          .invokeMethod<Object?>('getPlatformVersion');
    } on MissingPluginException {
      return;
    }
    if (!_started) return;
    _subscription = channel.receiveBroadcastStream().listen((event) {
      if (event is Map) _value.value = GlassSystemChrome.fromMap(event);
    }, onError: (Object _) {});
  }

  /// Forgets the subscription and value, for tests that mock the channel.
  @visibleForTesting
  Future<void> reset() async {
    _started = false;
    final subscription = _subscription;
    _subscription = null;
    _value.value = null;
    await subscription?.cancel();
  }
}
