import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Where iOS 27.1+ places bar chrome around the Flutter view: the vertical
/// bar edge (`UITraitCollection.verticalBarEdge`) and the active reserved
/// regions (`UIView.reservedRegions(kind:)`), in logical coordinates.
@immutable
class SystemChrome {
  const SystemChrome({
    this.verticalBarEdge,
    this.occlusions = const [],
    this.divisions = const [],
  });

  /// Parses the `liquid_prism/system_chrome` payload. Null before iOS 27.1.
  static SystemChrome? fromMap(Map<Object?, Object?> map) {
    if (map['supported'] != true) return null;
    Rect rect(List<Object?> values) => Rect.fromLTWH(
      (values[0]! as num).toDouble(),
      (values[1]! as num).toDouble(),
      (values[2]! as num).toDouble(),
      (values[3]! as num).toDouble(),
    );
    List<List<Object?>> lists(Object? value) =>
        (value as List<Object?>? ?? const []).cast<List<Object?>>();
    return SystemChrome(
      verticalBarEdge: switch (map['verticalBarEdge']) {
        'left' => AxisDirection.left,
        'right' => AxisDirection.right,
        _ => null,
      },
      occlusions: [for (final values in lists(map['occlusions'])) rect(values)],
      divisions: [
        for (final values in lists(map['divisions']))
          (
            frame: rect(values),
            margins: EdgeInsets.fromLTRB(
              (values[4]! as num).toDouble(),
              (values[5]! as num).toDouble(),
              (values[6]! as num).toDouble(),
              (values[7]! as num).toDouble(),
            ),
          ),
      ],
    );
  }

  /// [AxisDirection.left] or [AxisDirection.right]; null when the system
  /// uses horizontal bars here.
  final AxisDirection? verticalBarEdge;

  /// Regions covered by system UI, such as the status bar in the rail.
  final List<Rect> occlusions;

  /// Regions content should divide around, such as a partial fold. [frame]
  /// includes [margins] for interactive content.
  final List<({Rect frame, EdgeInsets margins})> divisions;

  /// Divisions as Flutter display features, so `DisplayFeatureSubScreen`
  /// and dialogs keep interactive content out of the fold.
  List<DisplayFeature> get displayFeatures => [
    for (final division in divisions)
      DisplayFeature(
        bounds: division.frame,
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
  ];

  @override
  bool operator ==(Object other) =>
      other is SystemChrome &&
      other.verticalBarEdge == verticalBarEdge &&
      listEquals(other.occlusions, occlusions) &&
      listEquals(other.divisions, divisions);

  @override
  int get hashCode => Object.hash(
    verticalBarEdge,
    Object.hashAll(occlusions),
    Object.hashAll(divisions),
  );
}

/// The latest [SystemChrome] from the plugin, subscribed on first use.
/// Stays null on other platforms, before iOS 27.1 and without the plugin.
class SystemChromeListener {
  SystemChromeListener._();
  static final instance = SystemChromeListener._();

  static const channel = EventChannel('liquid_prism/system_chrome');

  final _value = ValueNotifier<SystemChrome?>(null);
  StreamSubscription<Object?>? _subscription;

  ValueListenable<SystemChrome?> get value {
    if (!_started && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _started = true;
      unawaited(_listen());
    }
    return _value;
  }

  bool _started = false;

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
      if (event is Map) _value.value = SystemChrome.fromMap(event);
    }, onError: (Object _) {});
  }

  /// Forgets the subscription and value, for tests that mock the channel.
  @visibleForTesting
  void reset() {
    _started = false;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _value.value = null;
  }
}
