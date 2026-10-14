import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void phone(WidgetTester tester, {double keyboard = 0}) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(402, 874)
    ..padding = const FakeViewPadding(top: 62, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 62, bottom: 34)
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

List<Widget> rows([int count = 60]) => [
  SliverList.builder(
    itemCount: count,
    itemBuilder: (context, i) =>
        SizedBox(height: 50, child: Text('Row $i', key: ValueKey('row$i'))),
  ),
];

Rect rectOf(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey(key)));

void main() {
  testWidgets('slivers start below the bar and its large title', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Inline'),
          largeTitle: const Text('Large'),
          actions: [
            GlassToolbarItem(
              icon: const Icon(CupertinoIcons.star),
              label: 'Star',
              onPressed: () {},
            ),
          ],
          scrollController: controller,
          slivers: rows(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final top = rectOf(tester, 'row0').top;
    expect(
      top,
      closeTo(
        62 + 44 + (34 * 1.2 + 11.33) + LiquidPrismScaffold.topBarClearance,
        .01,
      ),
    );
    // Content moves one for one while the large title collapses, and the
    // titles swap once its row has scrolled away.
    controller.jumpTo(40);
    await tester.pumpAndSettle();
    expect(rectOf(tester, 'row0').top, closeTo(top - 40, .01));
    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.text('Inline'),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      greaterThan(.9),
      reason: 'the inline title has faded in',
    );
  });

  testWidgets('the last sliver clears the tab bar', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          tabBar: LiquidPrismTabBar(
            selectedIndex: 0,
            onSelected: (_) {},
            tabs: const [
              LiquidPrismTab(label: 'A', icon: Icon(CupertinoIcons.house)),
              LiquidPrismTab(label: 'B', icon: Icon(CupertinoIcons.star)),
            ],
          ),
          scrollController: controller,
          slivers: rows(30),
        ),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(LiquidPrismTabBar));
    expect(rectOf(tester, 'row29').bottom, lessThanOrEqualTo(bar.top));
  });

  testWidgets('pull to refresh', (tester) async {
    phone(tester);
    var refreshed = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          onRefresh: () async => refreshed++,
          slivers: rows(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });

  testWidgets('a bottom bar sits above the home indicator and the keyboard', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget app() => CupertinoApp(
      home: LiquidPrismScaffold(
        title: const Text('Edit'),
        scrollController: controller,
        bottomBar: const SizedBox(
          key: ValueKey('bar'),
          height: 60,
          width: double.infinity,
        ),
        slivers: rows(30),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(rectOf(tester, 'bar').bottom, 874 - 34);
    expect(find.byType(LiquidPrismScrollEdge), findsNWidgets(2));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      rectOf(tester, 'row29').bottom,
      lessThanOrEqualTo(rectOf(tester, 'bar').top),
    );

    phone(tester, keyboard: 300);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(rectOf(tester, 'bar').bottom, 874 - 300);
  });

  testWidgets('scrollDepth 1 follows the lists inside a tab view', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Tracker'),
          largeTitle: const Text('Tracker'),
          scrollDepth: 1,
          body: PageView(
            children: [
              for (var t = 0; t < 2; t++)
                ListView(
                  children: [
                    for (var i = 0; i < 40; i++)
                      SizedBox(height: 50, child: Text('T$t $i')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final large = tester.getTopLeft(find.text('Tracker').last).dy;
    await tester.drag(find.text('T0 3'), const Offset(0, -30));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Tracker').last).dy, lessThan(large));
  });

  test('a scaffold takes either a body or slivers', () {
    expect(() => LiquidPrismScaffold(), throwsAssertionError);
    expect(
      () => LiquidPrismScaffold(body: const SizedBox(), slivers: const []),
      throwsAssertionError,
    );
  });

  testWidgets('a list body moves one for one under a collapsing title', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Inline'),
          largeTitle: const Text('Large'),
          body: ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 50, child: Text('r$i', key: ValueKey('r$i'))),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final top = rectOf(tester, 'r5').top;
    for (final offset in [10.0, 30.0, 52.0, 100.0]) {
      controller.jumpTo(offset);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'r5').top, closeTo(top - offset, .01));
    }
  });

  testWidgets('a header scrolls away, then the title swaps in', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Inline'),
          scrollController: controller,
          header: const SizedBox(
            key: ValueKey('header'),
            height: 120,
            child: Text('Heading'),
          ),
          slivers: rows(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    double inline() => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.text('Inline'),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    final header = rectOf(tester, 'header');
    expect(header.top, 62 + 44 + LiquidPrismScaffold.topBarClearance);
    expect(rectOf(tester, 'row0').top, header.bottom);
    expect(inline(), 0);
    controller.jumpTo(60);
    await tester.pumpAndSettle();
    expect(inline(), 0, reason: 'the header still shows');
    controller.jumpTo(121);
    await tester.pumpAndSettle();
    expect(inline(), 1);
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(inline(), 0);
  });

  testWidgets('reselecting the tab scrolls the visible page to the top', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          tabBar: LiquidPrismTabBar(
            selectedIndex: 0,
            onSelected: (_) {},
            tabs: const [
              LiquidPrismTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
              LiquidPrismTab(label: 'Saved', icon: Icon(CupertinoIcons.star)),
            ],
          ),
          // A page's own scaffold inside the shell's body.
          body: LiquidPrismScaffold(
            title: const Text('Home'),
            scrollController: controller,
            slivers: rows(),
          ),
        ),
      ),
    );
    controller.jumpTo(800);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Home').last);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  testWidgets('a status bar tap scrolls to the top on iOS', (tester) async {
    phone(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          scrollController: controller,
          slivers: rows(),
        ),
      ),
    );
    controller.jumpTo(800);
    await tester.pumpAndSettle();
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a subtitle: inline 15 over 12, centred; large 11 below', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          leading: const SizedBox(
            key: ValueKey('leading'),
            width: 44,
            height: 44,
          ),
          title: const Text('Inline'),
          largeTitle: const Text('Large'),
          subtitle: const Text('Amazon'),
          scrollController: controller,
          slivers: rows(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final subtitles = find.text('Amazon');
    expect(subtitles, findsNWidgets(2));
    final large = tester.getRect(find.text('Large'));
    final largeSub = tester.getRect(subtitles.at(1));
    expect(largeSub.left, large.left);
    expect(largeSub.top - large.top, closeTo(38.33, .5));
    expect(
      DefaultTextStyle.of(tester.element(subtitles.at(1))).style.fontSize,
      11,
    );
    // The row grows for the subtitle; content starts below it.
    expect(
      rectOf(tester, 'row0').top,
      closeTo(62 + 44 + 71.33 + LiquidPrismScaffold.topBarClearance, .6),
    );
    controller.jumpTo(200);
    await tester.pumpAndSettle();
    final inline = tester.getRect(find.text('Inline'));
    final inlineSub = tester.getRect(subtitles.at(0));
    expect(
      DefaultTextStyle.of(tester.element(find.text('Inline'))).style.fontSize,
      15,
    );
    expect(
      DefaultTextStyle.of(tester.element(subtitles.at(0))).style.fontSize,
      12,
    );
    expect(inlineSub.top, greaterThanOrEqualTo(inline.bottom - 1));
    // The two-line block centres on the 44-point control row.
    final leading = rectOf(tester, 'leading');
    expect(
      (inline.top + inlineSub.bottom) / 2,
      closeTo(leading.center.dy, 1.5),
    );
  });

  testWidgets('in a sheet the bar sits 16 points below the top', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          sheet: true,
          leading: const SizedBox(
            key: ValueKey('leading'),
            width: 44,
            height: 44,
          ),
          title: const Text('Sheet'),
          slivers: rows(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(rectOf(tester, 'leading').top, 16);
    expect(
      rectOf(tester, 'row0').top,
      16 + 44 + LiquidPrismScaffold.topBarClearance,
    );
  });

  testWidgets('a hard edge ends at the bar frame, 10 points below', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Hard'),
          scrollController: controller,
          scrollEdgeStyle: const GlassScrollEdgeStyle(
            variant: GlassScrollEdgeVariant.hard,
          ),
          slivers: rows(),
        ),
      ),
    );
    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(LiquidPrismScrollEdge)).bottom,
      62 + 44 + 10,
    );
  });
}
