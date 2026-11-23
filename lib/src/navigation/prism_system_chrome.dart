import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// App preference for whether iOS may place bars in a vertical rail.
enum PrismVerticalBarBehavior {
  /// Allows automatic vertical bar placement.
  automatic,

  /// Keeps bars horizontal.
  disabled,
}

/// UIKit horizontal or vertical size class.
enum PrismSizeClass {
  /// Uses a compact layout size class.
  compact,

  /// Uses a regular layout size class.
  regular,
}

/// Region of the Flutter view reserved by system UI in logical coordinates.
@immutable
class PrismReservedRegion {
  /// Creates a reserved region with [frame], [margins], and [active] state.
  const new({
    required this.frame,
    this.margins = EdgeInsets.zero,
    this.active = true,
  });

  /// Outer frame including clearance [margins].
  final Rect frame;

  /// Clearance margins surrounding the system UI element.
  final EdgeInsets margins;

  /// Whether this region is currently active.
  final bool active;

  /// Inner area directly occupied by system UI without [margins].
  Rect get reserved => margins.deflateRect(frame);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismReservedRegion &&
          other.frame == frame &&
          other.margins == margins &&
          other.active == active;

  @override
  int get hashCode => Object.hash(frame, margins, active);

  @override
  String toString() =>
      'PrismReservedRegion($frame, margins: $margins, active: $active)';
}

/// Snapshot of system bar placement, size classes, and reserved regions.
@immutable
class PrismSystemChromeData {
  /// Creates a system chrome snapshot.
  const new({
    this.verticalBarEdge,
    this.verticalBarBehavior = PrismVerticalBarBehavior.automatic,
    this.horizontalSizeClass,
    this.verticalSizeClass,
    this.occlusions = const [],
    this.divisions = const [],
  });

  /// Decodes a system chrome event, or returns null when unsupported.
  static PrismSystemChromeData? fromMap(Map<Object?, Object?> map) {
    if (map['supported'] != true) return null;
    double at(List<Object?> values, int index) =>
        index < values.length ? (values[index]! as num).toDouble() : 0;
    PrismReservedRegion region(List<Object?> values) => PrismReservedRegion(
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
    List<PrismReservedRegion> regions(Object? value) => [
      for (final values
          in (value as List<Object?>? ?? const <Object?>[])
              .cast<List<Object?>>())
        region(values),
    ];
    PrismSizeClass? sizeClass(Object? value) => switch (value) {
      'compact' => PrismSizeClass.compact,
      'regular' => PrismSizeClass.regular,
      _ => null,
    };
    return PrismSystemChromeData(
      verticalBarEdge: switch (map['verticalBarEdge']) {
        'left' => AxisDirection.left,
        'right' => AxisDirection.right,
        _ => null,
      },
      verticalBarBehavior: map['verticalBarBehavior'] == 'disabled'
          ? PrismVerticalBarBehavior.disabled
          : PrismVerticalBarBehavior.automatic,
      horizontalSizeClass: sizeClass(map['horizontalSizeClass']),
      verticalSizeClass: sizeClass(map['verticalSizeClass']),
      occlusions: regions(map['occlusions']),
      divisions: regions(map['divisions']),
    );
  }

  /// Physical edge preferred for a vertical bar, or null for horizontal bars.
  final AxisDirection? verticalBarEdge;

  /// Active vertical bar opt-out policy.
  final PrismVerticalBarBehavior verticalBarBehavior;

  /// Current horizontal size class.
  final PrismSizeClass? horizontalSizeClass;

  /// Current vertical size class.
  final PrismSizeClass? verticalSizeClass;

  /// Whether bars currently sit in a vertical rail.
  bool get hasVerticalBar =>
      verticalBarEdge != null &&
      verticalBarBehavior != PrismVerticalBarBehavior.disabled;

  /// Regions occluded by system UI such as the status bar or camera.
  final List<PrismReservedRegion> occlusions;

  /// Regions dividing the display such as an active fold.
  final List<PrismReservedRegion> divisions;

  /// Active [divisions] represented as Flutter [DisplayFeature] entries.
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
      identical(this, other) ||
      other is PrismSystemChromeData &&
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
      'PrismSystemChromeData(edge: $verticalBarEdge, occlusions: $occlusions, '
      'divisions: $divisions)';
}

/// Publishes system chrome metrics and active fold display features.
class PrismSystemChrome extends StatelessWidget {
  /// Creates a system chrome scope around [child].
  const new({super.key, required this.child});

  /// Subtree receiving system chrome metrics and fold display features.
  final Widget child;

  /// Live listenable of the latest system chrome snapshot.
  static ValueListenable<PrismSystemChromeData?> get listenable =>
      SystemChromeListener.instance.value;

  /// Live listenable of the device's Liquid Glass tint amount setting.
  static ValueListenable<double?> get deviceGlassTintAmount =>
      SystemChromeListener.instance.glassTintAmount;

  /// Live listenable of accessibility Reduce Transparency state.
  static ValueListenable<bool> get reduceTransparency =>
      SystemChromeListener.instance.reduceTransparency;

  /// Returns the nearest scoped [PrismSystemChromeData], or the latest report.
  static PrismSystemChromeData? of(BuildContext context) =>
      scopeOf(context)?.chrome ?? listenable.value;

  /// Returns the nearest scope containing system chrome metrics.
  @internal
  static SystemChromeScope? scopeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SystemChromeScope>();

  /// Live centered Dynamic Island frame in logical coordinates.
  static ValueListenable<Rect?> get dynamicIsland =>
      SystemChromeListener.instance.island;

  /// Requests horizontal or automatic vertical bar placement on iOS.
  static Future<bool> setVerticalBarBehavior(
    PrismVerticalBarBehavior behavior,
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
      ValueListenableBuilder<PrismSystemChromeData?>(
        valueListenable: listenable,
        builder: (context, chrome, _) {
          final features = chrome?.displayFeatures ?? const <DisplayFeature>[];
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
  const new({super.key, required this.chrome, required super.child});

  final PrismSystemChromeData? chrome;

  @override
  bool updateShouldNotify(SystemChromeScope oldWidget) =>
      chrome != oldWidget.chrome;
}

@internal
class SystemChromeListener {
  new _();

  static final SystemChromeListener instance = SystemChromeListener._();

  static const EventChannel channel = EventChannel(
    'liquid_prism/system_chrome',
  );

  final ValueNotifier<PrismSystemChromeData?> _value =
      ValueNotifier<PrismSystemChromeData?>(null);
  final ValueNotifier<double?> _glassTintAmount = ValueNotifier<double?>(null);
  final ValueNotifier<bool> _reduceTransparency = ValueNotifier<bool>(false);
  final ValueNotifier<Rect?> _island = ValueNotifier<Rect?>(null);
  final ValueNotifier<Rect?> _notch = ValueNotifier<Rect?>(null);
  StreamSubscription<Object?>? _subscription;
  bool _started = false;

  ValueListenable<PrismSystemChromeData?> get value {
    if (!_started && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _started = true;
      unawaited(_listen());
    }
    return _value;
  }

  ValueListenable<double?> get glassTintAmount {
    value;
    return _glassTintAmount;
  }

  ValueListenable<bool> get reduceTransparency {
    value;
    return _reduceTransparency;
  }

  ValueListenable<Rect?> get island {
    value;
    return _island;
  }

  ValueListenable<Rect?> get notch {
    value;
    return _notch;
  }

  static Rect? _rect(Object? value) => switch (value) {
    [final num x, final num y, final num w, final num h] => Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      w.toDouble(),
      h.toDouble(),
    ),
    _ => null,
  };

  Future<void> _listen() async {
    try {
      await const MethodChannel('liquid_prism/menus')
          .invokeMethod<Object?>('getPlatformVersion');
    } on MissingPluginException {
      return;
    }
    if (!_started) return;
    _subscription = channel.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
      _value.value = PrismSystemChromeData.fromMap(event);
      _glassTintAmount.value = (event['glassTintAmount'] as num?)?.toDouble();
      _reduceTransparency.value = event['reduceTransparency'] == true;
      _island.value = _rect(event['island']);
      _notch.value = _rect(event['notch']);
    }, onError: (Object _) {});
  }

  @visibleForTesting
  Future<void> reset() async {
    _started = false;
    final cancellation = _subscription?.cancel();
    _subscription = null;
    _value.value = null;
    _glassTintAmount.value = null;
    _reduceTransparency.value = false;
    _island.value = null;
    _notch.value = null;
    await cancellation;
  }
}
