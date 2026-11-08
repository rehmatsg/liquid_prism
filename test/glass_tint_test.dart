import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/glass.dart'
    show
        batchLensStride,
        batchLensUniforms,
        batchMaxLenses,
        glassUniformCount,
        resolveSurfaceFrost;
import 'package:liquid_prism/src/chrome_material.dart';
import 'package:liquid_prism/src/recipe.dart';
import 'package:liquid_prism/src/system_chrome.dart' show SystemChromeListener;

import 'support/rendering.dart';

GlassRecipe _recipe(
  Glass glass, {
  bool dark = false,
  GlassRole role = GlassRole.surface,
  bool customOptics = false,
}) => GlassRecipe.resolve(
  glass,
  dark ? Brightness.dark : Brightness.light,
  role,
  customOptics: customOptics,
);

List<FrostPass> _frost(
  Glass glass,
  double tint, {
  bool dark = false,
  bool followsTint = true,
  double? frost,
}) {
  final recipe = _recipe(glass, dark: dark);
  return resolveSurfaceFrost(
    recipe,
    frost ?? recipe.optics(24).frost,
    tint: tint,
    followsTint: followsTint,
  );
}

void main() {
  group('measured tint tables', () {
    test('sample the captured inputs and interpolate between them', () {
      expect(GlassTint.sample(GlassTint.regularLighten, 0), 0.6749999523162842);
      expect(GlassTint.sample(GlassTint.regularNormal, .25), .25);
      expect(GlassTint.sample(GlassTint.regularFaceFill, 1), .5);
      expect(GlassTint.sample(GlassTint.clearBlurRadius, .75), .75);
      // Halfway between the 0.5 and 1 captures.
      expect(
        GlassTint.sample(GlassTint.regularFaceFill, .75),
        closeTo(.35, 1e-12),
      );
      expect(GlassTint.sample(GlassTint.clearFillNormal, .75), .5);
      // Out of range clamps to the slider's ends.
      expect(GlassTint.sample(GlassTint.regularNormal, -1), 0);
      expect(GlassTint.sample(GlassTint.regularNormal, 2), 1);
    });

    test('an explicit amount wins, then the device, then iOS default', () {
      expect(GlassTint.resolve(.2, .9), .2);
      expect(GlassTint.resolve(0, .9), 0, reason: 'explicit zero is kept');
      expect(GlassTint.resolve(null, .25), .25);
      expect(GlassTint.resolve(null, null), .5);
      expect(GlassTint.resolve(null, 1.4), 1);
    });
  });

  group('frost passes', () {
    test('regular frost follows the fitted light and dark setting sweep', () {
      const light = [5.2, 6.76, 8.32, 10.11, 12.0];
      const dark = [2.98, 5.07, 7.12, 9.62, 12.0];
      for (var i = 0; i < GlassTint.amounts.length; i++) {
        for (final isDark in [false, true]) {
          final pass = _frost(
            Glass.regular,
            GlassTint.amounts[i],
            dark: isDark,
          ).single;
          expect(pass.sigma, closeTo((isDark ? dark : light)[i], 1e-12));
          expect(pass.covers, isTrue);
          expect(pass.blendMode, BlendMode.srcOver);
        }
      }
      expect(_frost(Glass.regular, .375).single.sigma, closeTo(7.54, 1e-12));
    });

    test('clear glass scales its blur and fades in a blur fill to tint 1', () {
      expect(_frost(Glass.clear, 0), isEmpty);
      expect(_frost(Glass.clear, .25), [const FrostPass(.9)]);
      expect(_frost(Glass.clear, .5), [const FrostPass(1.8)]);
      expect(_frost(Glass.clear, .75), [
        const FrostPass(1.8),
        const FrostPass(GlassRecipe.blurFillFrost, .5),
      ]);
      expect(_frost(Glass.clear, 1), [
        const FrostPass(GlassRecipe.blurFillFrost),
      ]);
    });

    test('explicit blur, custom optics and lenses keep a plain frost', () {
      for (final tint in [0.0, .25, 1.0]) {
        expect(_frost(Glass.regular, tint, followsTint: false, frost: 8), [
          const FrostPass(8),
        ]);
        for (final role in [GlassRole.surface, GlassRole.tabLens]) {
          final recipe = _recipe(
            Glass.regular,
            role: role,
            customOptics: role == GlassRole.surface,
          );
          expect(recipe.kind, role == GlassRole.surface ? 0 : 3);
          expect(
            resolveSurfaceFrost(recipe, 5, tint: tint, followsTint: true),
            [const FrostPass(5)],
          );
        }
      }
      expect(_frost(Glass.regular, .25, followsTint: false, frost: 0), isEmpty);
    });

    test('the optical pass assumes only a blur that covers the face', () {
      expect(FrostPass.effectiveSigma(_frost(Glass.regular, .5)), 8.32);
      expect(FrostPass.effectiveSigma(_frost(Glass.regular, .25)), 6.76);
      expect(FrostPass.effectiveSigma(_frost(Glass.clear, .75)), 1.8);
      expect(FrostPass.effectiveSigma(const []), 0);
    });
  });

  group('face packet', () {
    test('the white fill follows the tint; the ring keeps its strength', () {
      final button = _recipe(Glass.regular, role: GlassRole.button);
      expect(button.faceUniforms, [.2, NativeGlassShadow.ringOpacity, .94, 1]);
      expect(button.withTint(0).faceUniforms.first, 0);
      expect(button.withTint(.25).faceUniforms.first, closeTo(.1, 1e-12));
      expect(button.withTint(1).faceUniforms.first, .5);
      expect(
        _recipe(Glass.regular).faceUniforms[1],
        NativeGlassShadow.ringOpacity,
      );
      expect(_recipe(Glass.regular, customOptics: true).faceUniforms[1], 0);
      expect(
        _recipe(Glass.regular, role: GlassRole.tabLens).faceUniforms[1],
        0,
      );
    });

    test('dark face settings preserve captured size limits and gray fills', () {
      final recipe = _recipe(Glass.regular, dark: true);
      for (final tint in [0.0, .25, .5, .75, 1.0]) {
        final resolved = recipe
            .withTint(tint)
            .withPresence(.5)
            .withChromaticFringe(3.5, 4.8);
        final small = resolved.faceUniformsFor(48);
        final large = resolved.faceUniformsFor(96);
        expect(small[2], closeTo(.6, 1e-12));
        expect(large[2], closeTo(tint < .5 ? .48 - .16 * tint : .4, 1e-12));
        expect(small[0], tint <= .5 ? 0 : tint - .5);
        expect(small[3], closeTo((tint - .5).abs() * .25, 1e-12));
        expect(resolved.withLensRim(1).faceUniformsFor(96), large);
      }
    });

    test('Dart packets agree with the shaders', () {
      int floats(String source) {
        var count = 0;
        final declaration = RegExp(
          r'^uniform (float|vec2|vec4) (\w+)(?:\[(\d+)\])?;',
          multiLine: true,
        );
        for (final match in declaration.allMatches(source)) {
          final size = {'float': 1, 'vec2': 2, 'vec4': 4}[match[1]]!;
          count += size * int.parse(match[3] ?? '1');
        }
        return count;
      }

      final scalar = File('shaders/glass.frag').readAsStringSync();
      expect(floats(scalar), glassUniformCount);
      expect(
        RegExp(r'uniform vec4 u_face;\s*uniform sampler2D').hasMatch(scalar),
        isTrue,
        reason: 'the face block closes the packet',
      );

      final batch = File('shaders/glass_batch.frag').readAsStringSync();
      final lenses = int.parse(
        RegExp(r'u_lenses\[(\d+)\]').firstMatch(batch)![1]!,
      );
      final stride = int.parse(
        RegExp(r'slot = i \* (\d+);').firstMatch(batch)![1]!,
      );
      final most = int.parse(
        RegExp(r'i < (\d+); i\+\+').firstMatch(batch)![1]!,
      );
      expect(stride * 4, batchLensStride);
      expect(most, batchMaxLenses);
      expect(most * stride, lessThanOrEqualTo(lenses));
      expect(batch, contains('u_face = u_lenses[slot + 16];'));

      // Each lens: device bounds, the scalar blocks, derived, then face.
      final packet = [for (var i = 0; i < glassUniformCount; i++) i * 1.0];
      final lens = batchLensUniforms(
        const Rect.fromLTRB(1, 2, 3, 4),
        2,
        packet,
      );
      expect(lens.length, batchLensStride);
      expect(lens.take(4), [2, 4, 6, 8]);
      expect(lens.sublist(4, 48), packet.sublist(2, 46));
      expect(
        lens.sublist(48, 64),
        packet.sublist(glassUniformCount - 20, glassUniformCount - 4),
      );
      expect(lens.sublist(64), packet.sublist(glassUniformCount - 4));
    });
  });

  testWidgets('bar capsules mark only their own optics as the material', (
    tester,
  ) async {
    Future<LiquidPrism> bar({
      double? blur,
      LiquidPrismStyle? optics,
      LiquidPrismThemeData theme = const LiquidPrismThemeData(),
    }) async {
      await tester.pumpWidget(
        glassHarness(
          imageKey: GlobalKey(),
          child: LiquidPrismTheme(
            data: theme,
            child: ChromeMaterial(
              height: 48,
              role: GlassRole.toolbar,
              blur: blur,
              optics: optics,
              child: const SizedBox(width: 96, height: 48),
            ),
          ),
        ),
      );
      return tester.widget<LiquidPrism>(find.byType(LiquidPrism));
    }

    // The bar's native frost follows the tint like the recipe's.
    final native = await bar();
    expect(native.materialOptics, isTrue);
    expect(native.blur, isNull);
    expect(native.optics!.frost, GlassRecipe.regularFrost);
    // An app's blur or optics replace it with a plain frost.
    expect((await bar(blur: 2)).blur, 2);
    expect(
      (await bar(theme: const LiquidPrismThemeData(blur: 0))).blur,
      0,
      reason: 'explicit zero blur is kept',
    );
    final custom = await bar(optics: const LiquidPrismStyle(frost: 7));
    expect(custom.materialOptics, isFalse);
    expect(custom.blur, 7);
  });

  group('theme glassTint', () {
    double resolvedTint(WidgetTester tester) =>
        tester
                .state(find.byType(LiquidPrism))
                .toDiagnosticsNode()
                .getProperties()
                .firstWhere((p) => p.name == 'glassTint')
                .value
            as double;

    Widget app(double? glassTint) => glassHarness(
      imageKey: GlobalKey(),
      child: LiquidPrismTheme(
        data: LiquidPrismThemeData(glassTint: glassTint),
        child: const SizedBox(
          width: 120,
          height: 44,
          child: LiquidPrism(glass: Glass.regular),
        ),
      ),
    );

    test('merges per field and keeps an explicit zero', () {
      const base = LiquidPrismThemeData(glassTint: .8, blur: 2);
      expect(base.merge(const LiquidPrismThemeData(blur: 4)).glassTint, .8);
      expect(base.merge(const LiquidPrismThemeData(glassTint: 0)).glassTint, 0);
      expect(base.copyWith(glassTint: .1).glassTint, .1);
      expect(base.copyWith(refraction: 3).glassTint, .8);
    });

    testWidgets('without a device setting null renders at iOS default', (
      tester,
    ) async {
      await tester.pumpWidget(app(null));
      expect(resolvedTint(tester), .5);
      await tester.pumpWidget(app(.25));
      expect(resolvedTint(tester), .25);
    });

    testWidgets('null follows the device setting live; explicit wins', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      late MockStreamHandlerEventSink events;
      messenger
        ..setMockMethodCallHandler(
          const MethodChannel('liquid_prism/menus'),
          (call) async => 'iOS 27.2',
        )
        ..setMockStreamHandler(
          SystemChromeListener.channel,
          MockStreamHandler.inline(
            onListen: (_, sink) {
              events = sink;
              sink.success({'supported': false, 'glassTintAmount': .25});
            },
          ),
        );
      addTearDown(() {
        unawaited(SystemChromeListener.instance.reset());
        messenger.setMockMethodCallHandler(
          const MethodChannel('liquid_prism/menus'),
          null,
        );
      });
      unawaited(SystemChromeListener.instance.reset());

      await tester.pumpWidget(app(null));
      await tester.pump();
      expect(LiquidPrismSystemChrome.deviceGlassTintAmount.value, .25);
      expect(resolvedTint(tester), .25);

      // The slider moves in Settings: the glass follows without a rebuild
      // from above.
      events.success({'supported': false, 'glassTintAmount': 1.0});
      await tester.pump();
      await tester.pump();
      expect(LiquidPrismSystemChrome.deviceGlassTintAmount.value, 1);
      expect(resolvedTint(tester), 1);

      await tester.pumpWidget(app(0));
      expect(resolvedTint(tester), 0, reason: 'the theme overrides the device');
      events.success({'supported': false, 'glassTintAmount': .5});
      await tester.pump();
      await tester.pump();
      expect(LiquidPrismSystemChrome.deviceGlassTintAmount.value, .5);
      expect(resolvedTint(tester), 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
