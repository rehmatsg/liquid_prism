import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/control_lens.dart';
import 'package:liquid_prism/src/glass.dart' show writeChromaticFringeUniforms;
import 'package:liquid_prism/src/recipe.dart';
import 'package:liquid_prism/src/tab_content_lens.dart';

import 'support/rendering.dart';

void main() {
  test(
    'partial chromatic styles inherit per field and retain explicit zero',
    () {
      const shared = GlassLensStyle(chromaticAberration: 2, chromaticBand: 6);
      final local = shared.merge(const GlassLensStyle(chromaticAberration: 0));
      expect(local.chromaticAberration, 0);
      expect(local.chromaticBand, 6);
      expect(local.copyWith(chromaticBand: 0).chromaticBand, 0);
      expect(local.copyWith(shadow: false).chromaticAberration, 0);
      final theme = const LiquidPrismThemeData(lens: shared).merge(
        const LiquidPrismThemeData(lens: GlassLensStyle(chromaticBand: 0)),
      );
      expect(theme.lens!.chromaticAberration, 2);
      expect(theme.lens!.chromaticBand, 0);
    },
  );

  testWidgets('lens defaults and packet split follow lift, not lens height', (
    tester,
  ) async {
    for (final role in [
      GlassRole.segmentLens,
      GlassRole.tabLens,
      GlassRole.controlThumb,
      GlassRole.sliderLens,
    ]) {
      final expected =
          role == GlassRole.segmentLens || role == GlassRole.tabLens
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
          final glass = tester.widget<LiquidPrism>(find.byType(LiquidPrism));
          expect(glass.chromaticSplit, closeTo(expected * lift, 1e-9));
          expect(glass.chromaticBand, 4.8);
          // Existing generic dispersion remains authoritative for small lenses.
          expect(glass.optics!.dispersion, closeTo(.3 * lift, 1e-9));
          final recipe = GlassRecipe.resolve(
            Glass.clear,
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
    for (final role in [GlassRole.segmentLens, GlassRole.surface]) {
      final recipe = GlassRecipe.resolve(
        Glass.regular,
        Brightness.light,
        role,
        customOptics: false,
      ).withChromaticFringe(3.5, 4.8).withPresence(.5).withLensRim(.7);
      final packet = List<double>.filled(338, 0);
      writeChromaticFringeUniforms(packet, recipe, 2);
      expect(packet[329], role == GlassRole.segmentLens ? 3.5 : 0);
      expect(packet[60], role == GlassRole.segmentLens ? 4.8 : 0);
      expect(
        recipe.uniforms[19],
        .7,
      ); // Glint survives new fields and presence.
      expect(recipe.uniforms[18], .5);
    }
  });

  testWidgets(
    'segment resolves shared, component and local lens for both passes',
    (tester) async {
      Future<void> check({GlassSegmentedStyle? style, double split = 2}) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: GlobalKey(),
            child: LiquidPrismTheme(
              data: const LiquidPrismThemeData(
                lens: GlassLensStyle(chromaticAberration: 5, chromaticBand: 6),
                segmentedControl: GlassSegmentedStyle(
                  lens: GlassLensStyle(chromaticAberration: 2),
                ),
              ),
              child: LiquidPrismSegmentedControl<int>(
                children: const {0: Text('A'), 1: Text('B')},
                selectedValue: 0,
                onValueChanged: (_) {},
                style: style,
              ),
            ),
          ),
        );
        expect(
          tester.widget<LiquidPrism>(find.byType(LiquidPrism)).chromaticSplit,
          0,
        );
        final finger = await tester.startGesture(
          tester.getCenter(find.text('A')),
        );
        await tester.pumpAndSettle();
        final glass = tester.widget<LiquidPrism>(find.byType(LiquidPrism));
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
          tester.widget<LiquidPrism>(find.byType(LiquidPrism)).chromaticSplit,
          0,
        );
      }

      await check();
      await check(
        style: const GlassSegmentedStyle(
          lens: GlassLensStyle(chromaticAberration: 0, minifyUnderlay: false),
        ),
        split: 0,
      );
    },
  );

  testWidgets('tab multiplier scales both fringes and glint; zero disables', (
    tester,
  ) async {
    Future<void> check(GlassTabBarStyle style, double split, double rim) async {
      await tester.pumpWidget(
        glassHarness(
          imageKey: GlobalKey(),
          child: LiquidPrismTheme(
            data: const LiquidPrismThemeData(
              lens: GlassLensStyle(chromaticBand: 6),
              tabBar: GlassTabBarStyle(rimRefraction: 2),
            ),
            child: LiquidPrismTabBar(
              tabs: const [
                LiquidPrismTab(
                  label: 'A',
                  icon: SizedBox(width: 22, height: 22),
                ),
                LiquidPrismTab(
                  label: 'B',
                  icon: SizedBox(width: 22, height: 22),
                ),
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
      final glass = tester.widget<LiquidPrism>(
        find.byWidgetPredicate(
          (w) => w is LiquidPrism && w.role == GlassRole.tabLens,
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

    await check(const GlassTabBarStyle(rimRefraction: 1), 3.5, 1);
    await check(const GlassTabBarStyle(rimRefraction: .5), 1.75, .5);
    await check(const GlassTabBarStyle(rimRefraction: 0), 0, 0);
    await check(
      const GlassTabBarStyle(lens: GlassLensStyle(chromaticAberration: 0)),
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
      expect(values[0], 0); // Fringe can operate independently of displacement.
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
            64, 64, // Source raster size.
            8, 8, 48, 44, // Lens origin and extent.
            1, 1, 0, 0, // DPR, lift, square contour for flat-band sampling.
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
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
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

            // Red right of green/blue on top; order reverses at the bottom.
            expect(centroid(9, 0), greaterThan(centroid(9, 1) + 1));
            expect(centroid(9, 1), greaterThan(centroid(9, 2) + 1));
            expect(centroid(50, 0), lessThan(centroid(50, 2) - 2));
            // Beyond the band all channels stay together.
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
