import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

GlassToolbarItem _item(String label) => GlassToolbarItem(
  icon: const Icon(CupertinoIcons.star),
  label: label,
  onPressed: () {},
);

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(402, 874)
      ..padding = const FakeViewPadding(top: 62, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
  }

  Widget page({
    ScrollController? controller,
    TextDirection direction = TextDirection.ltr,
    List<Object> actions = const [],
    bool large = true,
    PreferredSizeWidget? accessory,
  }) => CupertinoApp(
    home: Builder(
      builder: (context) => Directionality(
        textDirection: direction,
        child: CustomScrollView(
          controller: controller,
          slivers: [
            LiquidPrismSliverAppBar(
              leading: const SizedBox(
                key: ValueKey('leading'),
                width: 44,
                height: 44,
              ),
              title: const Text('Inline'),
              largeTitle: large ? const Text('Large') : null,
              actions: actions,
              accessory: accessory,
            ),
            SliverList.builder(
              itemCount: 100,
              itemBuilder: (context, i) => SizedBox(
                height: 60,
                child: Text('Row $i', key: ValueKey('row$i')),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  double opacityOf(WidgetTester tester, String text) => tester
      .widget<Opacity>(
        find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
      )
      .opacity;

  testWidgets('lays out like the scaffold bar; content starts below it', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(page(actions: [_item('Share')]));
    await tester.pumpAndSettle();
    final leading = tester.getRect(find.byKey(const ValueKey('leading')));
    expect(leading, const Rect.fromLTWH(16, 62, 44, 44));
    final actions = tester.getRect(find.byType(LiquidPrismToolbarGroup));
    expect(actions.right, 402 - 16);
    expect(actions.top, 62);
    final large = tester.getTopLeft(find.text('Large'));
    expect(large.dx, 16);
    // Measured: the bar frame ends at 116 and the large title's 52-point
    // row follows it, its line 3.67 points in; content starts at its end.
    expect(large.dy, closeTo(116 + 3.67, .01));
    final firstRow = tester.getTopLeft(find.byKey(const ValueKey('row0'))).dy;
    expect(firstRow, closeTo(116 + 34 * 1.2 + 11.33, .01));
    expect(opacityOf(tester, 'Large'), 1);
    expect(opacityOf(tester, 'Inline'), 0);
  });

  testWidgets('the large title rides the scroll, then swaps on a timer', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(page(controller: controller));
    await tester.pumpAndSettle();
    final rest = tester.getTopLeft(find.text('Large')).dy;
    controller.jumpTo(30);
    await tester.pump();
    expect(tester.getTopLeft(find.text('Large')).dy, closeTo(rest - 30, .01));
    expect(opacityOf(tester, 'Large'), 1);

    controller.jumpTo(60);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacityOf(tester, 'Large'), inExclusiveRange(0, 1));
    expect(opacityOf(tester, 'Inline'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, 'Large'), 0);
    expect(opacityOf(tester, 'Inline'), 1);
    // The bar stays pinned at its collapsed height.
    expect(tester.getRect(find.byKey(const ValueKey('leading'))).top, 62);

    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(opacityOf(tester, 'Large'), 1);
    expect(opacityOf(tester, 'Inline'), 0);
  });

  testWidgets('the glass and the edge effect share one group', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      page(
        controller: controller,
        actions: [
          [_item('Filter')],
          [_item('Share'), _item('More')],
        ],
      ),
    );
    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(find.byType(LiquidPrismToolbarGroup), findsNWidgets(2));
    final edge = find.byType(LiquidPrismScrollEdge);
    expect(edge, findsOneWidget);
    final group = find.ancestor(
      of: edge,
      matching: find.byType(LiquidPrismGroup),
    );
    expect(group, findsOneWidget);
    expect(
      find.descendant(
        of: group,
        matching: find.byType(LiquidPrismToolbarGroup),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('mirrors in right-to-left layouts', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      page(direction: TextDirection.rtl, actions: [_item('Share')]),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('leading'))).right,
      402 - 16,
    );
    expect(tester.getRect(find.byType(LiquidPrismToolbarGroup)).left, 16);
    expect(tester.getTopRight(find.text('Large')).dx, closeTo(402 - 16, .01));
  });

  testWidgets('implies a back button on a pushed route only', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CustomScrollView(
            slivers: [
              const LiquidPrismSliverAppBar(title: Text('Root')),
              SliverToBoxAdapter(
                child: CupertinoButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const CustomScrollView(
                        slivers: [
                          LiquidPrismSliverAppBar(title: Text('Detail')),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(LiquidPrismBackButton), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidPrismBackButton), findsOneWidget);
  });

  testWidgets('a sheet bar starts 16 points below the top', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      const CupertinoApp(
        home: CustomScrollView(
          slivers: [
            LiquidPrismSliverAppBar(
              sheet: true,
              leading: SizedBox(
                key: ValueKey('leading'),
                width: 44,
                height: 44,
              ),
              title: Text('Sheet'),
              subtitle: Text('Details'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('leading'))).top, 16);
    expect(find.text('Details'), findsOneWidget);
  });
}
