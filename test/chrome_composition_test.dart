import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone;

const _body = ValueKey('body');
const _tabs = [
  LiquidPrismTab(icon: Icon(CupertinoIcons.house), label: 'Home'),
  LiquidPrismTab(icon: Icon(CupertinoIcons.search), label: 'Search'),
];

Widget _app(Widget child, {bool rtl = false}) => CupertinoApp(
  home: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: child,
  ),
);

void main() {
  testWidgets('text actions measure their labels and activate once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Center(
          child: LiquidPrismToolbar(
            content: [
              GlassToolbarItem(label: 'Save changes', onPressed: () => taps++),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(LiquidPrismToolbarGroup)).width,
      greaterThan(tester.getSize(find.text('Save changes')).width),
    );
    expect(find.bySemanticsLabel('Save changes'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom items retain input ownership, state and keyed order', (
    tester,
  ) async {
    var taps = 0;
    const inputKey = ValueKey('input');
    final input = GlassToolbarItem.custom(
      key: inputKey,
      child: LiquidPrismButton(label: 'Custom', onPressed: () => taps++),
    );
    final action = GlassToolbarItem(label: 'Save', onPressed: () {});
    Widget page(bool reverse) => _app(
      Center(
        child: LiquidPrismToolbar(
          content: reverse ? [action, input] : [input, action],
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    final state = tester.state(
      find.descendant(
        of: find.byKey(inputKey).first,
        matching: find.byType(LiquidPrismPressable),
      ),
    );
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(
      tester.state(
        find.descendant(
          of: find.byKey(inputKey).first,
          matching: find.byType(LiquidPrismPressable),
        ),
      ),
      same(state),
    );
    expect(find.byType(LiquidPrismToolbarGroup), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final rtl in [false, true]) {
    testWidgets('flexible spacers fill bounded space, RTL $rtl', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 350,
              child: LiquidPrismToolbar(
                content: [
                  GlassToolbarItem(label: 'Undo', onPressed: () {}),
                  const GlassToolbarSpacer.flexible(),
                  GlassToolbarItem(label: 'Done', onPressed: () {}),
                ],
              ),
            ),
          ),
          rtl: rtl,
        ),
      );
      await tester.pumpAndSettle();
      final groups = find.byType(LiquidPrismToolbarGroup);
      final first = tester.getRect(groups.first),
          last = tester.getRect(groups.last);
      expect((first.center.dx - last.center.dx).abs(), greaterThan(200));
      expect(first.center.dx > last.center.dx, rtl);
      expect(tester.getSize(find.byType(LiquidPrismToolbar)).width, 350);
    });

    for (final sliver in [false, true]) {
      testWidgets(
        'typed placements preserve principal input, sliver $sliver RTL $rtl',
        (tester) async {
          phone(tester);
          var taps = 0;
          final content = <GlassToolbarContent>[
            GlassToolbarItem(
              label: 'Leading',
              placement: GlassToolbarPlacement.topLeading,
              onPressed: () {},
            ),
            GlassToolbarItem.custom(
              placement: GlassToolbarPlacement.principal,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => taps++,
                child: const Text('Principal'),
              ),
            ),
            GlassToolbarItem(label: 'Trailing', onPressed: () {}),
            GlassToolbarItem(
              label: 'Undo',
              placement: GlassToolbarPlacement.bottomLeading,
              onPressed: () {},
            ),
            GlassToolbarItem(
              label: 'Done',
              placement: GlassToolbarPlacement.bottomTrailing,
              onPressed: () {},
            ),
          ];
          final bar = sliver
              ? CustomScrollView(
                  slivers: [
                    LiquidPrismSliverAppBar(toolbar: content),
                    const SliverFillRemaining(child: SizedBox()),
                  ],
                )
              : LiquidPrismScaffold(
                  toolbar: content,
                  body: const SizedBox.expand(),
                );
          await tester.pumpWidget(_app(bar, rtl: rtl));
          await tester.pumpAndSettle();
          final leading = tester.getCenter(find.text('Leading'));
          final trailing = tester.getCenter(find.text('Trailing'));
          expect(leading.dx > trailing.dx, rtl);
          expect(
            tester.getCenter(find.text('Principal')).dx,
            closeTo(201, .01),
          );
          expect(
            tester.getCenter(find.text('Undo')).dx >
                tester.getCenter(find.text('Done')).dx,
            rtl,
          );
          await tester.tap(find.text('Principal'));
          await tester.pumpAndSettle();
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'title alignment and directional padding, sliver $sliver RTL $rtl',
        (tester) async {
          phone(tester);
          Future<void> render(GlassTitleAlignment alignment) =>
              tester.pumpWidget(
                _app(
                  sliver
                      ? CustomScrollView(
                          slivers: [
                            LiquidPrismSliverAppBar(
                              title: const Text('Title'),
                              navigationBarStyle: GlassNavigationBarStyle(
                                titleAlignment: alignment,
                                contentPadding:
                                    const EdgeInsetsDirectional.only(start: 20),
                              ),
                            ),
                            const SliverFillRemaining(child: SizedBox()),
                          ],
                        )
                      : LiquidPrismScaffold(
                          title: const Text('Title'),
                          navigationBarStyle: GlassNavigationBarStyle(
                            titleAlignment: alignment,
                            contentPadding: const EdgeInsetsDirectional.only(
                              start: 20,
                            ),
                          ),
                          body: const SizedBox.expand(),
                        ),
                  rtl: rtl,
                ),
              );
          await render(GlassTitleAlignment.leading);
          await tester.pumpAndSettle();
          final leading = tester.getRect(find.text('Title'));
          expect(rtl ? 402 - leading.right : leading.left, closeTo(36, .01));
          await render(GlassTitleAlignment.trailing);
          await tester.pumpAndSettle();
          final trailing = tester.getRect(find.text('Title'));
          expect(rtl ? trailing.left : 402 - trailing.right, closeTo(16, .01));
          await render(GlassTitleAlignment.center);
          await tester.pumpAndSettle();
          expect(
            tester.getCenter(find.text('Title')).dx,
            closeTo(rtl ? 191 : 211, .01),
          );
        },
      );
    }

    for (final dock in [
      GlassTabBarPlacement.top,
      GlassTabBarPlacement.bottom,
      GlassTabBarPlacement.leading,
      GlassTabBarPlacement.trailing,
    ]) {
      testWidgets('tab dock clears content and keyboard, $dock RTL $rtl', (
        tester,
      ) async {
        phone(tester, keyboard: 300);
        await tester.pumpWidget(
          _app(
            LiquidPrismScaffold(
              title: const Text('Title'),
              tabBarPlacement: dock,
              style: const GlassScaffoldStyle(tabBarMargin: EdgeInsets.all(10)),
              tabBar: LiquidPrismTabBar(
                selectedIndex: 0,
                onSelected: (_) {},
                tabs: _tabs,
              ),
              body: const SizedBox.expand(key: _body),
            ),
            rtl: rtl,
          ),
        );
        await tester.pumpAndSettle();
        final bodyInsets = MediaQuery.paddingOf(
          tester.element(find.byKey(_body)),
        );
        if (dock == GlassTabBarPlacement.bottom) {
          expect(find.byType(LiquidPrismTabBar), findsNothing);
        } else {
          final bar = tester.getRect(find.byType(LiquidPrismTabBar));
          expect(bar.bottom, lessThanOrEqualTo(874 - 300));
          if (dock == GlassTabBarPlacement.top) {
            expect(bodyInsets.top, greaterThanOrEqualTo(bar.bottom));
          } else {
            final left = (dock == GlassTabBarPlacement.leading) != rtl;
            expect(
              left ? bodyInsets.left : bodyInsets.right,
              closeTo(bar.width + 20, .01),
            );
          }
        }
        expect(bodyInsets.bottom, greaterThanOrEqualTo(300));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('local dock overrides merge with themed maximum width', (
    tester,
  ) async {
    phone(tester);
    Widget page(EdgeInsets margin) => _app(
      LiquidPrismTheme(
        data: const LiquidPrismThemeData(
          scaffold: GlassScaffoldStyle(
            tabBarMaxWidth: 200,
            tabBarMargin: EdgeInsets.all(30),
            tabBarAlignment: AlignmentDirectional.centerStart,
          ),
        ),
        child: LiquidPrismScaffold(
          style: GlassScaffoldStyle(tabBarMargin: margin),
          tabBar: LiquidPrismTabBar(
            selectedIndex: 0,
            onSelected: (_) {},
            tabs: _tabs,
          ),
          body: const SizedBox.expand(key: _body),
        ),
      ),
    );
    await tester.pumpWidget(page(EdgeInsets.zero));
    await tester.pumpAndSettle();
    var bar = tester.getRect(find.byType(LiquidPrismTabBar));
    expect(bar.left, 0);
    expect(bar.width, lessThanOrEqualTo(200));
    expect(bar.bottom, 874);
    await tester.pumpWidget(page(const EdgeInsets.all(12)));
    await tester.pumpAndSettle();
    bar = tester.getRect(find.byType(LiquidPrismTabBar));
    expect(bar.left, 12);
    expect(bar.bottom, 862);
  });

  testWidgets('scaffold presets yield to themed and group sizes', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      _app(
        LiquidPrismTheme(
          data: const LiquidPrismThemeData(
            toolbar: GlassToolbarStyle(size: GlassToolbarSize.bottom),
          ),
          child: LiquidPrismScaffold(
            toolbar: [
              GlassToolbarGroup(
                items: [
                  GlassToolbarItem(
                    icon: const Icon(CupertinoIcons.star),
                    label: 'Theme',
                    onPressed: () {},
                  ),
                ],
              ),
              GlassToolbarGroup(
                style: const GlassToolbarStyle(
                  size: GlassToolbarSize.navigation,
                ),
                items: [
                  GlassToolbarItem(
                    icon: const Icon(CupertinoIcons.star),
                    label: 'Local',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final groups = find.byType(LiquidPrismToolbarGroup);
    expect(tester.getSize(groups.first).height, 48);
    expect(tester.getSize(groups.last).height, 44);
  });

  testWidgets(
    'rail overflow retains custom input and folds actions into native More',
    (tester) async {
      phone(tester);
      var taps = 0;
      await tester.pumpWidget(
        _app(
          LiquidPrismScaffold(
            placement: GlassChromePlacement.rightRail,
            toolbar: [
              GlassToolbarItem.custom(
                width: 60,
                child: CupertinoButton(
                  onPressed: () => taps++,
                  child: const Text('Own'),
                ),
              ),
              for (var i = 0; i < 20; i++)
                GlassToolbarItem(
                  icon: const Icon(CupertinoIcons.star),
                  label: 'Action $i',
                  onPressed: () {},
                ),
            ],
            tabBar: LiquidPrismTabBar(
              selectedIndex: 0,
              onSelected: (_) {},
              tabs: _tabs,
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('More'), findsOneWidget);
      expect(find.bySemanticsLabel('Action 0'), findsNothing);
      await tester.tap(find.text('Own'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vertical tabs honor labels and bounded fill sizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Center(
          child: SizedBox(
            height: 350,
            child: LiquidPrismTabBar(
              axis: Axis.vertical,
              selectedIndex: 0,
              onSelected: (_) {},
              tabs: _tabs,
              style: const GlassTabBarStyle(
                sizing: GlassTabBarSizing.fill,
                labelBehavior: GlassTabLabelBehavior.always,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LiquidPrismTabBar)).height, 350);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
