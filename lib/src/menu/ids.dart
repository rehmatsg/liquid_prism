import 'dart:math';

final Random _rng = Random.secure();

/// Mints session-scoped menu identifiers for the native bridge.
final class MenuIds {
  MenuIds._();

  /// The random identifier prefix for this isolate.
  static final String session = List.generate(
    6,
    (_) => _rng.nextInt(36).toRadixString(36),
  ).join();
  static int _counter = 0;

  /// Returns a fresh wire identifier.
  static String mint() =>
      'lm_$session-${(_counter++).toString().padLeft(4, '0')}';
}
