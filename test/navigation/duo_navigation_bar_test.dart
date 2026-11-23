import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

const _anchor = Key('content top');
const _rows = [
  SliverToBoxAdapter(
    child: SizedBox(
      height: 2400,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(key: _anchor, height: 1),
      ),
    ),
  ),
];

Widget _page(
  ScrollController controller, {
  required bool sliver,
  required Widget title,
  Widget? largeTitle,
  Widget? subtitle,
  PrismNavigationBarStyle? style,
}) => CupertinoApp(
  home: sliver
      ? CustomScrollView(
          controller: controller,
          slivers: [
            PrismSliverAppBar(
              title: title,
              largeTitle: largeTitle,
              subtitle: subtitle,
              navigationBarStyle: style,
              scrollEdge: false,
            ),
            ..._rows,
          ],
        )
      : PrismScaffold(
          scrollController: controller,
          title: title,
          largeTitle: largeTitle,
          subtitle: subtitle,
          navigationBarStyle: style,
          scrollEdge: false,
          slivers: _rows,
        ),
);

void _duo(WidgetTester tester, {bool rail = true}) {
  final padding = FakeViewPadding(
    right: rail ? 84 : 0,
    top: rail ? 0 : 82,
    bottom: 34,
  );
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(466, 678)
    ..viewPadding = padding
    ..padding = padding;
  addTearDown(tester.view.reset);
}

TextStyle _style(WidgetTester tester, String title) =>
    DefaultTextStyle.of(tester.element(find.text(title))).style;

void main() {
  testWidgets('Duo accessory keeps its body gap beside rail tabs', (
    tester,
  ) async {
    _duo(tester);
    const accessory = Key('page tabs');
    for (final spacing in <double?>[null, 0]) {
      await tester.pumpWidget(
        CupertinoApp(
          home: PrismScaffold(
            title: const Text('Applications'),
            navigationBarStyle: PrismNavigationBarStyle(
              contentSpacing: spacing,
            ),
            accessory: const PreferredSize(
              preferredSize: Size.fromHeight(38),
              child: SizedBox(key: accessory),
            ),
            tabBar: PrismTabBar(
              tabs: const [
                PrismTab(label: 'Home', icon: Icon(CupertinoIcons.home)),
                PrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
              ],
              selectedIndex: 1,
              onSelected: (_) {},
            ),
            slivers: _rows,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(_anchor)).dy -
            tester.getBottomLeft(find.byKey(accessory)).dy,
        spacing ?? 16,
      );
    }
  });

  testWidgets('a caller-owned body scrolls once in both directions', (
    tester,
  ) async {
    _duo(tester);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: PrismScaffold(
          title: const Text('Library'),
          scrollEdge: false,
          body: ListView(
            controller: scroll,
            children: const [
              SizedBox(key: _anchor, height: 100),
              SizedBox(height: 1500),
            ],
          ),
        ),
      ),
    );

    final anchor = find.byKey(_anchor);
    final initialY = tester.getTopLeft(anchor).dy;
    final gesture = await tester.startGesture(const Offset(170, 520));
    await gesture.moveBy(const Offset(0, -21));
    await tester.pump();
    final initialOffset = scroll.offset;
    for (final delta in [-12.0, -15.0, -19.0, 6.0, 11.0, 16.0]) {
      await gesture.moveBy(Offset(0, delta));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getTopLeft(anchor).dy + scroll.offset,
        closeTo(initialY, .01),
      );
    }
    expect(scroll.offset, greaterThan(initialOffset));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  for (final sliver in [false, true]) {
    final kind = sliver ? 'sliver' : 'scaffold';

    testWidgets('Duo $kind title modes reveal the same title', (tester) async {
      _duo(tester);
      final semantics = tester.ensureSemantics();
      try {
        for (final mode in PrismTitleDisplayMode.values) {
          await tester.pumpWidget(const SizedBox.shrink());
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          final title = mode == PrismTitleDisplayMode.large
              ? 'Expanded'
              : 'Library';
          final compact = mode == PrismTitleDisplayMode.inline;
          await tester.pumpWidget(
            _page(
              scroll,
              sliver: sliver,
              title: const Text('Library'),
              largeTitle: mode == PrismTitleDisplayMode.large
                  ? const Text('Expanded')
                  : null,
              subtitle: const Text('Details'),
              style: PrismNavigationBarStyle(titleDisplayMode: mode),
            ),
          );
          await tester.pumpAndSettle();
          expect(_style(tester, title).fontSize, compact ? 15 : 22);
          expect(
            _style(tester, title).fontWeight,
            compact ? FontWeight.w600 : FontWeight.w700,
          );
          expect(_style(tester, 'Details').fontSize, compact ? 12 : 11);
          expect(tester.getTopLeft(find.byKey(_anchor)).dy, 82);
          scroll.jumpTo(400);
          await tester.pumpAndSettle();
          expect(find.semantics.byLabel(RegExp(title)), findsNothing);
          expect(tester.getTopLeft(find.byKey(_anchor)).dy + scroll.offset, 82);
          final header = tester.renderObject<RenderSliver>(
            find.byType(SliverPersistentHeader).first,
          );
          expect(header.geometry!.maxScrollObstructionExtent, 24);
          scroll.jumpTo(220);
          await tester.pumpAndSettle();
          expect(find.semantics.byLabel(RegExp(title)), findsOneWidget);
          expect(_style(tester, title).fontSize, compact ? 15 : 22);
          expect(tester.getTopLeft(find.byKey(_anchor)).dy + scroll.offset, 82);
          expect(header.geometry!.maxScrollObstructionExtent, 82);
        }
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Duo $kind retains explicit typography and insets', (
      tester,
    ) async {
      _duo(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        PrismTheme(
          data: const PrismThemeData(
            navigationBar: PrismNavigationBarStyle(
              titleDisplayMode: PrismTitleDisplayMode.large,
              titleStyle: TextStyle(fontSize: 19),
              minimizationSafeArea: PrismMinimizationSafeArea.enabled,
            ),
          ),
          child: _page(
            scroll,
            sliver: sliver,
            title: const Text('Library'),
            style: const PrismNavigationBarStyle(
              titleDisplayMode: PrismTitleDisplayMode.inline,
              titleStyle: TextStyle(fontWeight: FontWeight.w500),
              controlRowHeight: 64,
              contentSpacing: 3,
              minimizationSafeArea: PrismMinimizationSafeArea.disabled,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_style(tester, 'Library').fontSize, 19);
      expect(_style(tester, 'Library').fontWeight, FontWeight.w500);
      expect(tester.getTopLeft(find.byKey(_anchor)).dy, 91);
      scroll.jumpTo(400);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_anchor)).dy + scroll.offset, 91);
    });

    testWidgets('pinned Duo $kind uses compact type after scrolling', (
      tester,
    ) async {
      _duo(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _page(
          scroll,
          sliver: sliver,
          title: const Text('Library'),
          style: const PrismNavigationBarStyle(
            minimizationBehavior: PrismMinimizationBehavior.never,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_style(tester, 'Library').fontSize, 28);
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(_style(tester, 'Library').fontSize, 17);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_style(tester, 'Library').fontSize, 28);
    });

    testWidgets('horizontal $kind large title retains its keyed element', (
      tester,
    ) async {
      _duo(tester, rail: false);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final titleKey = GlobalKey();
      await tester.pumpWidget(
        _page(
          scroll,
          sliver: sliver,
          title: Text('Library', key: titleKey),
          style: const PrismNavigationBarStyle(
            titleDisplayMode: PrismTitleDisplayMode.large,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final titleElement = tester.element(find.byKey(titleKey));
      expect(_style(tester, 'Library').fontSize, 34);
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(_style(tester, 'Library').fontSize, 17);
      expect(tester.element(find.byKey(titleKey)), same(titleElement));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_style(tester, 'Library').fontSize, 34);
      expect(tester.element(find.byKey(titleKey)), same(titleElement));
    });
  }
}
