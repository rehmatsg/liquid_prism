import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/rendering/recipe.dart' show PrismRole;
import 'package:liquid_prism/src/rendering/surface.dart' show RawPrismSurface;
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    PrismSegmentedStyle? style,
    PrismThemeData data = const PrismThemeData(),
  }) => tester.pumpWidget(
    MaterialApp(
      home: PrismTheme(
        data: data,
        child: Center(
          child: PrismSegmentedControl<int>(
            style: style,
            children: const {
              0: Text('Media'),
              1: Text('Links'),
              2: Text('Docs'),
            },
            selectedValue: 0,
            onValueChanged: (_) {},
          ),
        ),
      ),
    ),
  );

  TextStyle labelStyle(WidgetTester tester, String label) => tester
      .widget<RichText>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      )
      .text
      .style!;

  testWidgets('the glass variant uses a glass capsule and native metrics', (
    tester,
  ) async {
    await mount(
      tester,
      style: const PrismSegmentedStyle(variant: PrismSegmentedVariant.glass),
    );
    expect(
      tester.getSize(find.byType(PrismSegmentedControl<int>)),
      const Size(300, 44),
    );
    final track = tester.widget<RawPrismSurface>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RawPrismSurface && widget.role == PrismRole.toolbar,
      ),
    );
    expect(track.shape, PrismShape.capsule);
    expect(tester.getSize(find.byWidget(track)), const Size(300, 44));
    expect(
      tester.getRect(find.byType(PrismSelection)),
      const Rect.fromLTWH(254, 282, 92, 36),
    );
    for (final label in ['Media', 'Links', 'Docs']) {
      final style = labelStyle(tester, label);
      expect(style.fontSize, 15, reason: label);
      expect(style.fontWeight, FontWeight.w400, reason: label);
      expect(style.letterSpacing, -.23, reason: label);
      expect(style.color, PrismColors.light.label, reason: label);
    }
  });

  testWidgets('the plain variant keeps its track, size and typography', (
    tester,
  ) async {
    await mount(tester);
    expect(
      tester.getSize(find.byType(PrismSegmentedControl<int>)),
      const Size(300, 44),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RawPrismSurface && widget.role == PrismRole.toolbar,
      ),
      findsNothing,
    );
    expect(find.byType(PrismSelection), findsNothing);
    expect(labelStyle(tester, 'Media').fontSize, 13);
    expect(labelStyle(tester, 'Media').fontWeight, FontWeight.w500);
    expect(labelStyle(tester, 'Links').fontWeight, FontWeight.w400);
    expect(labelStyle(tester, 'Links').letterSpacing, isNull);
  });

  testWidgets('the theme selects the variant and local metrics still win', (
    tester,
  ) async {
    await mount(
      tester,
      data: const PrismThemeData(
        segmentedControl: PrismSegmentedStyle(
          variant: PrismSegmentedVariant.glass,
          glass: PrismGlass.clear,
        ),
      ),
      style: const PrismSegmentedStyle(trackHeight: 56, selectionInset: 6),
    );
    expect(
      tester.getSize(find.byType(PrismSegmentedControl<int>)),
      const Size(300, 56),
    );
    final track = tester.widget<RawPrismSurface>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RawPrismSurface && widget.role == PrismRole.toolbar,
      ),
    );
    expect(track.glass, PrismGlass.clear);
    expect(tester.getSize(find.byType(PrismSelection)).width, 88);
  });

  test('variant and glass take part in copy, merge and equality', () {
    const glass = PrismSegmentedStyle(variant: PrismSegmentedVariant.glass);
    expect(const PrismSegmentedStyle().merge(glass), glass);
    expect(
      glass.merge(const PrismSegmentedStyle(width: 200)).variant,
      PrismSegmentedVariant.glass,
    );
    expect(glass, isNot(const PrismSegmentedStyle()));
    expect(glass.copyWith(glass: PrismGlass.clear).glass, PrismGlass.clear);
    expect(
      glass.copyWith(glass: PrismGlass.clear).hashCode,
      isNot(glass.hashCode),
    );
  });
}
