import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@internal
abstract final class PrismDisplay {
  static final ValueNotifier<double> headroom = ValueNotifier<double>(1);
  static const EventChannel _channel = EventChannel('liquid_prism/display');
  static StreamSubscription<Object?>? _subscription;
  static bool? _enabled;
  static bool? _listening;
  static Future<void> _configuration = Future<void>.value();

  static Future<void> configure(bool? enabled) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return Future<void>.value();
    }
    final requested = enabled ?? _enabled ?? true;
    _enabled = requested;
    return _configuration = _configuration.then((_) => _listen(requested));
  }

  static Future<void> _listen(bool requested) async {
    if (_listening == requested && _subscription != null) return;
    final old = _subscription;
    _subscription = null;
    await old?.cancel();
    headroom.value = 1;
    _listening = requested;
    _subscription = _channel
        .receiveBroadcastStream({'enabled': requested})
        .listen(
          (value) {
            if (_enabled != requested) return;
            if (value is! num || !value.isFinite) {
              headroom.value = 1;
              return;
            }
            headroom.value = requested ? value.toDouble().clamp(1, 1.3) : 1;
          },
          onError: (Object _) {
            headroom.value = 1;
          },
        );
  }

  @visibleForTesting
  static Future<void> reset() async {
    await _configuration;
    await _subscription?.cancel();
    _subscription = null;
    _enabled = null;
    _listening = null;
    headroom.value = 1;
  }
}
