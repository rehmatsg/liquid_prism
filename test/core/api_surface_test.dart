import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public barrels export only Prism-prefixed symbols', () {
    final showPattern = RegExp(r'show\s+([^;]+);', multiLine: true);
    for (final path in const ['lib/liquid_prism.dart', 'lib/primitives.dart']) {
      final content = File(path).readAsStringSync();
      final symbols = <String>[];
      for (final match in showPattern.allMatches(content)) {
        symbols.addAll(
          match
              .group(1)!
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty),
        );
      }
      expect(symbols, isNotEmpty, reason: '$path should export symbols');
      for (final symbol in symbols) {
        expect(
          symbol.startsWith('Prism') || symbol == 'prismMenus',
          isTrue,
          reason: '$path exported non-Prism symbol: $symbol',
        );
      }
    }
  });

  test('PrismSurface public constructor exposes no internal parameters', () {
    final source = File('lib/src/rendering/surface.dart').readAsStringSync();
    final constructor = RegExp(r'const PrismSurface\(\{([\s\S]*?)\}\);')
        .firstMatch(source);
    expect(constructor, isNotNull);
    final parameters = constructor!.group(1)!;
    for (final forbidden in const [
      'role',
      'lensRim',
      'chromaticSplit',
      'chromaticBand',
      'underlay',
      'resting',
      'materialOptics',
      'disabledProminent',
    ]) {
      expect(
        RegExp(r'\b' + forbidden + r'\b').hasMatch(parameters),
        isFalse,
        reason: 'PrismSurface leaked internal field $forbidden',
      );
    }
  });
}
