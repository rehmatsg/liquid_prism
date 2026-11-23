import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/controls/control_lens.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart' show RawPrismSurface;
import 'package:liquid_prism/src/rendering/surface_render.dart'
    show writeChromaticFringeUniforms, writeLensUnderlayUniform;
import 'package:liquid_prism/src/rendering/tab_content_lens.dart';

import '../support/rendering.dart';

void main() {
  test(
    'partial chromatic styles inherit per field and retain explicit zero',
    () {
      const shared = PrismLensStyle(chromaticAberration: 2, chromaticBand: 6);
      final local = shared.merge(const PrismLensStyle(chromaticAberration: 0));
      expect(local.chromaticAberration, 0);
      expect(local.chromaticBand, 6);
      expect(local.copyWith(chromaticBand: 0).chromaticBand, 0);
      expect(local.copyWith(shadow: false).chromaticAberration, 0);
      final theme = const PrismThemeData(lens: shared)
          .merge(const PrismThemeData(lens: PrismLensStyle(chromaticBand: 0)));
      expect(theme.lens!.chromaticAberration, 2);
      expect(theme.lens!.chromaticBand, 0);
    },
  );

  testWidgets('lens defaults and packet split follow lift, not lens height', (
    tester,
  ) async {
    for (final role in [
      PrismRole.segmentLens,
      PrismRole.tabLens,
      PrismRole.controlThumb,
      PrismRole.sliderLens,
    ]) {
      final expected =
          role == PrismRole.segmentLens || role == PrismRole.tabLens
          ? 3.5
          : 0.0;
      for (final lift in [0.0, .4, 1.0]) {
        for (final height in [44.0, 70.0]) {
          await tester.pumpWidget(
            glassHarness(
              imageKey: GlobalKey(),
              child: SizedBox(
                width: 110,
                height: height,
                child: ControlLens(lift: lift, role: role, rim: 1),
              ),
            ),
          );
          final glass = tester.widget<RawPrismSurface>(
            find.byType(RawPrismSurface),
          );
          expect(glass.chromaticSplit, closeTo(expected * lift, 1e-9));
          expect(glass.chromaticBand, 4.8);

          expect(glass.optics!.dispersion, closeTo(.3 * lift, 1e-9));
          final recipe = PrismRecipe.resolve(
            PrismGlass.clear,
            Brightness.dark,
            glass.role,
            customOptics: true,
          ).withChromaticFringe(glass.chromaticSplit, glass.chromaticBand);
          final packet = List<double>.filled(338, 0);
          writeChromaticFringeUniforms(packet, recipe, 3);
          expect(packet[329], closeTo(expected * lift * 3, 1e-9));
          expect(packet[60], 4.8);
        }
      }
    }
  });

  test('packet respects presence and non-lens/batch recipes stay zero', () {
    for (final role in [PrismRole.segmentLens, PrismRole.surface]) {
      final recipe = PrismRecipe.resolve(
        PrismGlass.regular,
        Brightness.light,
        role,
        customOptics: false,
      ).withChromaticFringe(3.5, 4.8).withPresence(.5).withLensRim(.7);
      final packet = List<double>.filled(338, 0);
      writeChromaticFringeUniforms(packet, recipe, 2);
      expect(packet[329], role == PrismRole.segmentLens ? 3.5 : 0);
      expect(packet[60], role == PrismRole.segmentLens ? 4.8 : 0);
      expect(recipe.uniforms[19], .7);
      expect(recipe.uniforms[18], .5);
    }
  });

  test('underlay has its own slot, limited like the rim, lens only', () {
    for (final role in [PrismRole.tabLens, PrismRole.surface]) {
      final recipe = PrismRecipe.resolve(
        PrismGlass.clear,
        Brightness.light,
        role,
        customOptics: false,
      ).withChromaticFringe(3.5, 4.8).withUnderlay(9).withPresence(.5);

      expect(recipe.withLensRim(.7).underlay, 9);
      final packet = List<double>.filled(338, 0);
      writeLensUnderlayUniform(
        packet,
        recipe,
        const Rect.fromLTWH(0, 0, 110, 70),
      );
      expect(packet[61], role == PrismRole.tabLens ? 9 : 0);
      writeLensUnderlayUniform(
        packet,
        recipe,
        const Rect.fromLTWH(0, 0, 40, 12),
      );
      expect(packet[61], role == PrismRole.tabLens ? closeTo(6.6, 1e-9) : 0);
    }
  });

  testWidgets(
    'segment resolves shared, component and local lens for both passes',
    (tester) async {
      Future<void> check({PrismSegmentedStyle? style, double split = 2}) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: GlobalKey(),
            child: PrismTheme(
              data: const PrismThemeData(
                lens: PrismLensStyle(chromaticAberration: 5, chromaticBand: 6),
                segmentedControl: PrismSegmentedStyle(
                  lens: PrismLensStyle(chromaticAberration: 2),
                ),
              ),
              child: PrismSegmentedControl<int>(
                children: const {0: Text('A'), 1: Text('B')},
                selectedValue: 0,
                onValueChanged: (_) {},
                style: style,
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<RawPrismSurface>(find.byType(RawPrismSurface))
              .chromaticSplit,
          0,
        );
        final finger = await tester.startGesture(
          tester.getCenter(find.text('A')),
        );
        await tester.pumpAndSettle();
        final glass = tester.widget<RawPrismSurface>(
          find.byType(RawPrismSurface),
        );
        final content = tester.widget<ContentLensWindow>(
          find.byType(ContentLensWindow),
        );
        expect(glass.chromaticSplit, split);
        expect(glass.chromaticBand, 6);
        expect(content.chromaticAberration, split);
        expect(content.chromaticBand, 6);
        await finger.up();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RawPrismSurface>(find.byType(RawPrismSurface))
              .chromaticSplit,
          0,
        );
      }

      await check();
      await check(
        style: const PrismSegmentedStyle(
          lens: PrismLensStyle(chromaticAberration: 0, minifyUnderlay: false),
        ),
        split: 0,
      );
    },
  );

  testWidgets('tab multiplier scales both fringes and glint; zero disables', (
    tester,
  ) async {
    Future<void> check(PrismTabBarStyle style, double split, double rim) async {
      await tester.pumpWidget(
        glassHarness(
          imageKey: GlobalKey(),
          child: PrismTheme(
            data: const PrismThemeData(
              lens: PrismLensStyle(chromaticBand: 6),
              tabBar: PrismTabBarStyle(rimRefraction: 2),
            ),
            child: PrismTabBar(
              tabs: const [
                PrismTab(label: 'A', icon: SizedBox(width: 22, height: 22)),
                PrismTab(label: 'B', icon: SizedBox(width: 22, height: 22)),
              ],
              style: style,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('A')),
      );
      await tester.pumpAndSettle();
      final glass = tester.widget<RawPrismSurface>(
        find.byWidgetPredicate(
          (w) => w is RawPrismSurface && w.role == PrismRole.tabLens,
        ),
      );
      final content = tester.widget<ContentLensWindow>(
        find.byType(ContentLensWindow),
      );
      expect(glass.chromaticSplit, split);
      expect(content.chromaticAberration, split);
      expect(glass.chromaticBand, 6);
      expect(content.chromaticBand, 6);
      expect(glass.lensRim, rim);
      await finger.up();
      await tester.pumpAndSettle();
    }

    await check(const PrismTabBarStyle(rimRefraction: 1), 3.5, 1);
    await check(const PrismTabBarStyle(rimRefraction: .5), 1.75, .5);
    await check(const PrismTabBarStyle(rimRefraction: 0), 0, 0);
    await check(
      const PrismTabBarStyle(lens: PrismLensStyle(chromaticAberration: 0)),
      0,
      2,
    );
  });

  test('foreground effect converts to composited pixels and clamps lift', () {
    for (final lift in [-1.0, 0.0, .5, 1.0, 2.0]) {
      final values = contentLensEffectUniforms(
        refraction: 0,
        depth: 11.2,
        chromaticAberration: 3.5,
        chromaticBand: 4.8,
        lift: lift,
        scale: 1.1,
        deviceScale: 3,
      );
      expect(values, hasLength(4));
      expect(values[0], 0);
      expect(values[1], closeTo(12.32, 1e-9));
      expect(values[2], closeTo(3.5 * lift.clamp(0, 1) * 1.1 * 3, 1e-9));
      expect(values[3], closeTo(5.28, 1e-9));
    }
  });
  testWidgets(
    'foreground shader separates rim channels with valid glyph alpha',
    (tester) async {
      await tester.runAsync(() async {
        final program = await ui.FragmentProgram.fromAsset(
          'shaders/tab_content.frag',
        );
        final sourceRecorder = ui.PictureRecorder();
        Canvas(sourceRecorder).drawRect(
          const Rect.fromLTWH(31, 8, 2, 44),
          Paint()..color = const Color(0xFFFFFFFF),
        );
        final sourcePicture = sourceRecorder.endRecording();
        final source = await sourcePicture.toImage(64, 64);
        sourcePicture.dispose();
        final shader = program.fragmentShader();
        try {
          final uniforms = <double>[
            64,
            64,
            8,
            8,
            48,
            44,
            1,
            1,
            0,
            0,
            ...List<double>.filled(276, 0),
            ...contentLensEffectUniforms(
              refraction: 0,
              depth: 11.2,
              chromaticAberration: 3.5,
              chromaticBand: 4.8,
              lift: 1,
              scale: 1,
              deviceScale: 1,
            ),
            0,
            0,
          ];
          for (var i = 0; i < uniforms.length; i++) {
            shader.setFloat(i, uniforms[i]);
          }
          shader.setImageSampler(0, source, filterQuality: FilterQuality.low);
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawRect(
            const Rect.fromLTWH(0, 0, 64, 64),
            Paint()..shader = shader,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(64, 64);
          picture.dispose();
          try {
            final data = (await image.toByteData())!;
            final bytes = data.buffer.asUint8List();
            double centroid(int y, int channel) {
              var weighted = 0.0, sum = 0.0;
              for (var x = 0; x < 64; x++) {
                final value = bytes[(y * 64 + x) * 4 + channel];
                weighted += x * value;
                sum += value;
              }
              expect(sum, greaterThan(0));
              return weighted / sum;
            }

            expect(centroid(9, 0), greaterThan(centroid(9, 1) + .2));
            expect(centroid(9, 1), greaterThan(centroid(9, 2) + .2));
            expect(centroid(50, 0), lessThan(centroid(50, 2) - .4));

            expect(centroid(30, 0), centroid(30, 1));
            expect(centroid(30, 1), centroid(30, 2));
            var coloredEdge = false;
            for (var i = 0; i < bytes.length; i += 4) {
              for (var c = 0; c < 3; c++) {
                expect(bytes[i + c], lessThanOrEqualTo(bytes[i + 3]));
              }
              coloredEdge |= bytes[i] != bytes[i + 2] && bytes[i + 3] > 0;
            }
            expect(coloredEdge, isTrue);
          } finally {
            image.dispose();
          }
        } finally {
          shader.dispose();
          source.dispose();
        }
      });
    },
  );
}
