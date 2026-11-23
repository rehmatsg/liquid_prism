import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/rendering/surface.dart' show RawPrismSurface;
import 'package:material_ui/material_ui.dart';

const _labels = [
  'Title',
  'Large',
  'Subtitle',
  'Tool',
  'Tab',
  'Button',
  'Segment',
  'Find',
];

Widget _page() => PrismScaffold(
  title: const Text('Title'),
  largeTitle: const Text('Large'),
  subtitle: const Text('Subtitle'),
  trailing: PrismToolbar.group(
    items: [PrismToolbarItem(label: 'Tool', onPressed: () {})],
  ),
  tabBar: PrismTabBar(
    tabs: const [
      PrismTab(label: 'Tab', icon: Icon(Icons.home)),
      PrismTab(label: 'Other', icon: Icon(Icons.star)),
    ],
    selectedIndex: 0,
    onSelected: (_) {},
  ),
  body: ListView(
    children: [
      PrismButton(label: 'Button', onPressed: () {}),
      PrismSegmentedControl<int>(
        children: const {0: Text('Segment'), 1: Text('Second')},
        selectedValue: 0,
        onValueChanged: (_) {},
      ),
      const PrismSearchField(placeholder: 'Find'),
    ],
  ),
);

Map<String, TextStyle> _styles(WidgetTester tester) {
  final styles = <String, TextStyle>{};
  for (final element in find.byType(RichText).evaluate()) {
    final text = (element.widget as RichText).text;
    final label = text.toPlainText();
    if (_labels.contains(label)) styles.putIfAbsent(label, () => text.style!);
  }
  return styles;
}

Future<Map<String, TextStyle>> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  PrismThemeData data = const PrismThemeData(),
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: PrismTheme(data: data, child: _page()),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  final styles = _styles(tester);
  expect(styles.keys, containsAll(_labels));
  return styles;
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('labels never pick up the missing-Material fallback style', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final styles = await _pump(tester);
    for (final MapEntry(key: label, value: style) in styles.entries) {
      expect(style.fontFamily, isNot('monospace'), reason: label);
      expect(style.decoration, isNot(TextDecoration.underline), reason: label);
    }
    expect(styles['Title']!.fontFamily, 'CupertinoSystemText');
    expect(styles['Large']!.fontFamily, 'CupertinoSystemDisplay');
    expect(styles['Button']!.fontSize, 17);
    expect(styles['Button']!.fontWeight, FontWeight.w400);
    expect(styles['Tool']!.fontWeight, FontWeight.w600);
    expect(styles['Segment']!.fontSize, 13);
    expect(styles['Tab']!.fontSize, 10);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('every label follows the app font and keeps native metrics', (
    tester,
  ) async {
    final styles = await _pump(tester, theme: ThemeData(fontFamily: 'Brand'));
    for (final MapEntry(key: label, value: style) in styles.entries) {
      expect(style.fontFamily, 'Brand', reason: label);
    }
    expect(styles['Large']!.fontSize, 34);
    expect(styles['Button']!.fontSize, 17);
    expect(styles['Button']!.letterSpacing, isNull);
  });

  testWidgets('theme text style, then component style, override the app', (
    tester,
  ) async {
    final styles = await _pump(
      tester,
      theme: ThemeData(fontFamily: 'Brand'),
      data: const PrismThemeData(
        textStyle: TextStyle(fontFamily: 'Prism', letterSpacing: 1),
        button: PrismButtonStyle(
          textStyle: TextStyle(
            fontFamily: 'Buttons',
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    for (final MapEntry(key: label, value: style) in styles.entries) {
      expect(
        style.fontFamily,
        label == 'Button' ? 'Buttons' : 'Prism',
        reason: label,
      );
      expect(style.letterSpacing, 1, reason: label);
    }
    expect(styles['Button']!.fontSize, 22);
    expect(styles['Button']!.fontWeight, FontWeight.w700);
    expect(styles['Tool']!.fontSize, 17);
  });

  test('theme text styles merge per field and compare by value', () {
    const base = PrismThemeData(textStyle: TextStyle(fontFamily: 'A'));
    final merged = base.merge(
      const PrismThemeData(textStyle: TextStyle(fontSize: 20)),
    );
    expect(merged.textStyle!.fontFamily, 'A');
    expect(merged.textStyle!.fontSize, 20);
    expect(base.merge(const PrismThemeData()), base);
    expect(base, isNot(const PrismThemeData()));
    expect(base.copyWith().textStyle, base.textStyle);
  });

  testWidgets('destructive outranks a themed tint but not a local one', (
    tester,
  ) async {
    const themed = Color(0xFF00AA00);
    const local = Color(0xFF0000AA);
    await tester.pumpWidget(
      MaterialApp(
        home: PrismTheme(
          data: const PrismThemeData(
            button: PrismButtonStyle(tintColor: themed),
          ),
          child: Column(
            children: [
              PrismButton(
                key: const ValueKey('plain'),
                label: 'Plain',
                variant: PrismButtonVariant.prominent,
                onPressed: () {},
              ),
              PrismButton(
                key: const ValueKey('destructive'),
                label: 'Delete',
                variant: PrismButtonVariant.prominent,
                destructive: true,
                onPressed: () {},
              ),
              PrismButton(
                key: const ValueKey('local'),
                label: 'Local',
                variant: PrismButtonVariant.prominent,
                destructive: true,
                style: const PrismButtonStyle(tintColor: local),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    Color? tint(String key) => tester
        .widget<RawPrismSurface>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(RawPrismSurface),
          ),
        )
        .glass!
        .tintColor;
    final red = PrismColors.of(tester.element(find.byType(Column))).red;
    expect(tint('plain'), themed);
    expect(tint('destructive'), red);
    expect(tint('local'), local);
  });
}
