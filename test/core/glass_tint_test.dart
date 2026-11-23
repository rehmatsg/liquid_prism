import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/navigation/prism_system_chrome.dart'
    show SystemChromeListener;
import 'package:liquid_prism/src/rendering/chrome_material.dart';
import 'package:liquid_prism/src/rendering/glass_group.dart'
    show batchLensStride, batchLensUniforms, batchMaxLenses;
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart' show RawPrismSurface;
import 'package:liquid_prism/src/rendering/surface_render.dart'
    show glassUniformCount, resolveSurfaceFrost;

import '../support/rendering.dart';

PrismRecipe _recipe(
  PrismGlass glass, {
  bool dark = false,
  PrismRole role = PrismRole.surface,
  bool customOptics = false,
}) => PrismRecipe.resolve(
  glass,
  dark ? Brightness.dark : Brightness.light,
  role,
  customOptics: customOptics,
);

List<FrostPass> _frost(
  PrismGlass glass,
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

      expect(
        GlassTint.sample(GlassTint.regularFaceFill, .75),
        closeTo(.35, 1e-12),
      );
      expect(GlassTint.sample(GlassTint.clearFillNormal, .75), .5);

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
    test('regular blends a blur fill over a sharp, depth-faded base', () {
      final measured =
          (jsonDecode(
                File('research/specs/native_defaults_spec.json')
                    .readAsStringSync(),
              ) as Map<String, Object?>)['measured']!
              as Map<String, Object?>;
      for (final dark in [false, true]) {
        for (final entry
            in measured[dark ? 'dark' : 'light']! as List<Object?>) {
          final row = entry! as Map<String, Object?>;
          final tint = (row['tint']! as num).toDouble();
          final materials = row['materials']! as List<Object?>;
          final material = materials[0]! as Map<String, Object?>;
          final inputs = material['inputs']! as Map<String, Object?>;
          final passes = _frost(PrismGlass.regular, tint, dark: dark);

          const scale = 2 * FrostPass.engineSigmaScale;
          final base = scale * (inputs['inputBlurRadius']! as num);
          final fill = scale * (inputs['inputBlurFillBlurRadius']! as num);
          final normal = (inputs['inputBlurFillNormalOpacity']! as num)
              .toDouble();
          final directional =
              inputs[dark
                      ? 'inputBlurFillDarkenOpacity'
                      : 'inputBlurFillLightenOpacity']!
                  as num;
          if (tint == 1) {
            expect(passes, [FrostPass.fill(fill)]);
            continue;
          }
          expect(passes, [
            FrostPass(base, depthFade: true),
            FrostPass.fill(
              fill,
              directional.toDouble(),
              dark ? BlendMode.darken : BlendMode.lighten,
            ),
            if (normal > 0) FrostPass.fill(fill, normal),
          ]);
          expect(passes.first.scaled(.5).depthFade, isTrue);
          expect(passes.first.scaled(.5).sigma, base / 2);

          expect(
            passes[1].scaled(.5),
            FrostPass.fill(
              fill,
              directional / 2,
              dark ? BlendMode.darken : BlendMode.lighten,
            ),
          );
        }
      }
      final between = _frost(PrismGlass.regular, .125);
      expect(between[1].opacity, closeTo(.73125, 1e-6));
      expect(between[2].opacity, .125);
      expect(_frost(PrismGlass.regular, -1), _frost(PrismGlass.regular, 0));
      expect(_frost(PrismGlass.regular, 2), _frost(PrismGlass.regular, 1));
    });

    test('depth terms start past 64 points and stop growing at 150', () {
      expect(NativeGlassDepth.amount(48), 0);
      expect(NativeGlassDepth.amount(64), 0);

      expect(NativeGlassDepth.amount(80), closeTo(.1333, 1e-4));
      expect(NativeGlassDepth.amount(104), closeTo(.3333, 1e-4));
      expect(NativeGlassDepth.amount(130), closeTo(.55, 1e-4));
      expect(NativeGlassDepth.amount(170), closeTo(.7167, 1e-4));

      expect(NativeGlassDepth.lens(8), 0);
      expect(NativeGlassDepth.lens(10), 0);
      expect(NativeGlassDepth.lens(13), .5);
      expect(NativeGlassDepth.lens(16), 1);
      expect(NativeGlassDepth.lens(44), 1);
      expect(NativeGlassDepth.lens(170), 1);

      expect(
        NativeGlassDepth.bleedSigma(80) /
            NativeGlassDepth.bleedSigmaPerRadius /
            FrostPass.engineSigmaScale,
        closeTo(28, 1e-9),
      );
      expect(
        NativeGlassDepth.bleedSigma(170) /
            NativeGlassDepth.bleedSigmaPerRadius /
            FrostPass.engineSigmaScale,
        closeTo(52.5, 1e-9),
      );

      final bleed = NativeGlassDepth.bleedSigma(170);
      expect(NativeGlassDepth.bleedRadius(170, bleed), 0);
      expect(NativeGlassDepth.bleedRadius(170, 2 * bleed), 0);
      final radius = NativeGlassDepth.bleedRadius(
        170,
        FrostPass.regularFillSigma,
      );
      expect(
        radius * radius / 2 +
            FrostPass.regularFillSigma * FrostPass.regularFillSigma,
        closeTo(bleed * bleed, 1e-9),
      );
    });

    test('clear glass scales its blur and fades in a blur fill to tint 1', () {
      expect(_frost(PrismGlass.clear, 0), isEmpty);
      expect(_frost(PrismGlass.clear, .25), [const FrostPass(.9)]);
      expect(_frost(PrismGlass.clear, .5), [const FrostPass(1.8)]);
      expect(_frost(PrismGlass.clear, .75), [
        const FrostPass(1.8),
        const FrostPass.fill(PrismRecipe.blurFillFrost, .5),
      ]);
      expect(_frost(PrismGlass.clear, 1), [
        const FrostPass.fill(PrismRecipe.blurFillFrost),
      ]);
    });

    test('explicit blur, custom optics and lenses keep a plain frost', () {
      for (final tint in [0.0, .25, 1.0]) {
        expect(_frost(PrismGlass.regular, tint, followsTint: false, frost: 8), [
          const FrostPass(8),
        ]);
        for (final role in [PrismRole.surface, PrismRole.tabLens]) {
          final recipe = _recipe(
            PrismGlass.regular,
            role: role,
            customOptics: role == PrismRole.surface,
          );
          expect(recipe.kind, role == PrismRole.surface ? 0 : 3);
          expect(
            resolveSurfaceFrost(recipe, 5, tint: tint, followsTint: true),
            [const FrostPass(5)],
          );
        }
      }
      expect(
        _frost(PrismGlass.regular, .25, followsTint: false, frost: 0),
        isEmpty,
      );
    });

    test('the optical pass assumes only a blur that covers the face', () {
      expect(FrostPass.effectiveSigma(_frost(PrismGlass.regular, .5)), 0);
      expect(FrostPass.effectiveSigma(_frost(PrismGlass.regular, 0)), 0);
      expect(
        FrostPass.effectiveSigma(_frost(PrismGlass.regular, 1)),
        FrostPass.regularFillSigma,
      );
      expect(FrostPass.effectiveSigma(_frost(PrismGlass.clear, .75)), 1.8);
      expect(FrostPass.effectiveSigma(const []), 0);
    });
  });

  group('face packet', () {
    test('the white fill follows the tint; the ring keeps its strength', () {
      final button = _recipe(PrismGlass.regular, role: PrismRole.button);
      expect(button.faceUniforms, [.2, NativeGlassShadow.ringOpacity, 1, 1]);

      expect(
        button.faceUniformsFor(170)[2],
        closeTo(1 + NativeGlassDepth.lightGain * .7167, 1e-4),
      );
      expect(button.withTint(0).faceUniforms.first, 0);
      expect(button.withTint(.25).faceUniforms.first, closeTo(.1, 1e-12));
      expect(button.withTint(1).faceUniforms.first, .5);
      expect(
        _recipe(PrismGlass.regular).faceUniforms[1],
        NativeGlassShadow.ringOpacity,
      );
      expect(
        _recipe(PrismGlass.regular, customOptics: true).faceUniforms[1],
        0,
      );
      expect(
        _recipe(PrismGlass.regular, role: PrismRole.tabLens).faceUniforms[1],
        0,
      );
    });

    test('dark face settings preserve captured size limits and gray fills', () {
      final recipe = _recipe(PrismGlass.regular, dark: true);
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
        RegExp(
          r'uniform vec4 u_face;\s*(//.*\s*)*uniform vec4 u_frost;\s*'
          r'(//.*\s*)*uniform float u_headroom;\s*uniform sampler2D',
        ).hasMatch(scalar),
        isTrue,
        reason: 'face, frost and headroom close the scalar packet',
      );

      final batch = File('shaders/glass_batch.frag').readAsStringSync();
      final lenses = int.parse(
        RegExp(r'u_lenses\[(\d+)\]').firstMatch(batch)![1]!,
      );
      final stride = int.parse(
        RegExp(r'u_lenses\[i \* (\d+)\]').firstMatch(batch)![1]!,
      );
      final most = int.parse(
        RegExp(r'i < (\d+); i\+\+').firstMatch(batch)![1]!,
      );
      expect(stride * 4, batchLensStride);
      expect(most, batchMaxLenses);
      expect(most * stride, lessThanOrEqualTo(lenses));
      expect(batch, contains('u_face = u_lenses[i * 17 + 16];'));

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
        packet.sublist(glassUniformCount - 25, glassUniformCount - 9),
      );
      expect(
        lens.sublist(64),
        packet.sublist(glassUniformCount - 9, glassUniformCount - 5),
      );
      expect(batch, contains('const vec4 u_frost = vec4(0.,0.,0.,-1.);'));
    });
  });

  testWidgets('bar capsules mark only their own optics as the material', (
    tester,
  ) async {
    Future<RawPrismSurface> bar({
      double? blur,
      PrismOptics? optics,
      PrismThemeData theme = const PrismThemeData(),
    }) async {
      await tester.pumpWidget(
        glassHarness(
          imageKey: GlobalKey(),
          child: PrismTheme(
            data: theme,
            child: ChromeMaterial(
              height: 48,
              role: PrismRole.toolbar,
              blur: blur,
              optics: optics,
              child: const SizedBox(width: 96, height: 48),
            ),
          ),
        ),
      );
      return tester.widget<RawPrismSurface>(find.byType(RawPrismSurface));
    }

    final native = await bar();
    expect(native.materialOptics, isTrue);
    expect(native.blur, isNull);
    expect(native.optics!.frost, PrismRecipe.regularFrost);

    expect((await bar(blur: 2)).blur, 2);
    expect(
      (await bar(theme: const PrismThemeData(blur: 0))).blur,
      0,
      reason: 'explicit zero blur is kept',
    );
    final custom = await bar(optics: const PrismOptics(frost: 7));
    expect(custom.materialOptics, isFalse);
    expect(custom.blur, 7);
  });

  group('theme glassTint', () {
    double resolvedTint(WidgetTester tester) =>
        tester
                .state(find.byType(RawPrismSurface))
                .toDiagnosticsNode()
                .getProperties()
                .firstWhere((p) => p.name == 'glassTint')
                .value!
            as double;

    Widget app(double? glassTint) => glassHarness(
      imageKey: GlobalKey(),
      child: PrismTheme(
        data: PrismThemeData(glassTint: glassTint),
        child: const SizedBox(
          width: 120,
          height: 44,
          child: PrismSurface(glass: PrismGlass.regular),
        ),
      ),
    );

    test('merges per field and keeps an explicit zero', () {
      const base = PrismThemeData(glassTint: .8, blur: 2);
      expect(base.merge(const PrismThemeData(blur: 4)).glassTint, .8);
      expect(base.merge(const PrismThemeData(glassTint: 0)).glassTint, 0);
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
      expect(PrismSystemChrome.deviceGlassTintAmount.value, .25);
      expect(resolvedTint(tester), .25);

      events.success({'supported': false, 'glassTintAmount': 1.0});
      await tester.pump();
      await tester.pump();
      expect(PrismSystemChrome.deviceGlassTintAmount.value, 1);
      expect(resolvedTint(tester), 1);

      events.success({'supported': false, 'glassTintAmount': 0.0});
      await tester.pump();
      await tester.pump();
      expect(PrismSystemChrome.deviceGlassTintAmount.value, 0);
      expect(resolvedTint(tester), 0);

      await tester.pumpWidget(app(0));
      expect(resolvedTint(tester), 0, reason: 'the theme overrides the device');
      events.success({'supported': false, 'glassTintAmount': .5});
      await tester.pump();
      await tester.pump();
      expect(PrismSystemChrome.deviceGlassTintAmount.value, .5);
      expect(resolvedTint(tester), 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
  testWidgets(
    'the selected tab pill is blurred until the bar frost covers its face',
    (tester) async {
      Future<double> pillBlur(PrismThemeData theme, {double? blur}) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(400, 200)),
              child: PrismTheme(
                data: theme,
                child: Center(
                  child: PrismTabBar(
                    selectedIndex: 0,
                    onSelected: (_) {},
                    tabs: const [
                      PrismTab(label: 'A', icon: SizedBox.shrink()),
                      PrismTab(label: 'B', icon: SizedBox.shrink()),
                    ],
                    style: PrismTabBarStyle(blur: blur),
                  ),
                ),
              ),
            ),
          ),
        );
        return tester
            .widget<PrismSelection>(
              find.descendant(
                of: find.byKey(const ValueKey('tab-selection')),
                matching: find.byType(PrismSelection),
              ),
            )
            .blur;
      }

      const native = 2 * FrostPass.engineSigmaScale;

      expect(
        await pillBlur(const PrismThemeData(glassTint: .5)),
        closeTo(native, 1e-9),
      );
      expect(
        await pillBlur(const PrismThemeData(glassTint: 0)),
        closeTo(native, 1e-9),
      );

      expect(await pillBlur(const PrismThemeData(glassTint: 1)), 0);

      expect(await pillBlur(const PrismThemeData(glassTint: .5), blur: 6), 0);
      expect(
        await pillBlur(const PrismThemeData(glassTint: .5), blur: 0),
        closeTo(native, 1e-9),
      );
    },
  );
}
