import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/rendering/surface.dart' show RawPrismSurface;

import 'scaffold_slivers_test.dart' show phone;

const _body = ValueKey('body');
const _tabs = [
  PrismTab(icon: Icon(CupertinoIcons.house), label: 'Home'),
  PrismTab(icon: Icon(CupertinoIcons.search), label: 'Search'),
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
          child: PrismToolbar(
            content: [
              PrismToolbarItem(label: 'Save changes', onPressed: () => taps++),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(PrismToolbar)).width,
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
    final input = PrismToolbarItem.custom(
      key: inputKey,
      child: PrismButton(label: 'Custom', onPressed: () => taps++),
    );
    final action = PrismToolbarItem(label: 'Save', onPressed: () {});
    Widget page(bool reverse) => _app(
      Center(
        child: PrismToolbar(
          content: reverse ? [action, input] : [input, action],
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    final state = tester.state(
      find.descendant(
        of: find.byKey(inputKey).first,
        matching: find.byType(PrismPressable),
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
          matching: find.byType(PrismPressable),
        ),
      ),
      same(state),
    );
    expect(find.byType(PrismToolbar), findsOneWidget);
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
              child: PrismToolbar(
                content: [
                  PrismToolbarItem(label: 'Undo', onPressed: () {}),
                  const PrismToolbarSpacer.flexible(),
                  PrismToolbarItem(label: 'Done', onPressed: () {}),
                ],
              ),
            ),
          ),
          rtl: rtl,
        ),
      );
      await tester.pumpAndSettle();
      final groups = find.descendant(
        of: find.byType(PrismToolbar),
        matching: find.byType(RawPrismSurface),
      );
      final first = tester.getRect(groups.first),
          last = tester.getRect(groups.last);
      expect((first.center.dx - last.center.dx).abs(), greaterThan(200));
      expect(first.center.dx > last.center.dx, rtl);
      expect(tester.getSize(find.byType(PrismToolbar)).width, 350);
    });

    for (final sliver in [false, true]) {
      testWidgets(
        'typed placements preserve principal input, sliver $sliver RTL $rtl',
        (tester) async {
          phone(tester);
          var taps = 0;
          final content = <PrismToolbarContent>[
            PrismToolbarItem(
              label: 'Leading',
              placement: PrismToolbarPlacement.topLeading,
              onPressed: () {},
            ),
            PrismToolbarItem.custom(
              placement: PrismToolbarPlacement.principal,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => taps++,
                child: const Text('Principal'),
              ),
            ),
            PrismToolbarItem(label: 'Trailing', onPressed: () {}),
            PrismToolbarItem(
              label: 'Undo',
              placement: PrismToolbarPlacement.bottomLeading,
              onPressed: () {},
            ),
            PrismToolbarItem(
              label: 'Done',
              placement: PrismToolbarPlacement.bottomTrailing,
              onPressed: () {},
            ),
          ];
          final bar = sliver
              ? CustomScrollView(
                  slivers: [
                    PrismSliverAppBar(toolbar: content),
                    const SliverFillRemaining(child: SizedBox()),
                  ],
                )
              : PrismScaffold(toolbar: content, body: const SizedBox.expand());
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
          Future<void> render(PrismTitleAlignment alignment) =>
              tester.pumpWidget(
                _app(
                  sliver
                      ? CustomScrollView(
                          slivers: [
                            PrismSliverAppBar(
                              title: const Text('Title'),
                              navigationBarStyle: PrismNavigationBarStyle(
                                titleAlignment: alignment,
                                contentPadding:
                                    const EdgeInsetsDirectional.only(start: 20),
                              ),
                            ),
                            const SliverFillRemaining(child: SizedBox()),
                          ],
                        )
                      : PrismScaffold(
                          title: const Text('Title'),
                          navigationBarStyle: PrismNavigationBarStyle(
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
          await render(PrismTitleAlignment.leading);
          await tester.pumpAndSettle();
          final leading = tester.getRect(find.text('Title'));
          expect(rtl ? 402 - leading.right : leading.left, closeTo(36, .01));
          await render(PrismTitleAlignment.trailing);
          await tester.pumpAndSettle();
          final trailing = tester.getRect(find.text('Title'));
          expect(rtl ? trailing.left : 402 - trailing.right, closeTo(16, .01));
          await render(PrismTitleAlignment.center);
          await tester.pumpAndSettle();
          expect(
            tester.getCenter(find.text('Title')).dx,
            closeTo(rtl ? 191 : 211, .01),
          );
        },
      );
    }

    for (final dock in [
      PrismTabBarPlacement.top,
      PrismTabBarPlacement.bottom,
      PrismTabBarPlacement.leading,
      PrismTabBarPlacement.trailing,
    ]) {
      testWidgets('tab dock clears content and keyboard, $dock RTL $rtl', (
        tester,
      ) async {
        phone(tester, keyboard: 300);
        await tester.pumpWidget(
          _app(
            PrismScaffold(
              title: const Text('Title'),
              tabBarPlacement: dock,
              style: const PrismScaffoldStyle(tabBarMargin: EdgeInsets.all(10)),
              tabBar: PrismTabBar(
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
        if (dock == PrismTabBarPlacement.bottom) {
          expect(find.byType(PrismTabBar), findsNothing);
        } else {
          final bar = tester.getRect(find.byType(PrismTabBar));
          expect(bar.bottom, lessThanOrEqualTo(874 - 300));
          if (dock == PrismTabBarPlacement.top) {
            expect(bodyInsets.top, greaterThanOrEqualTo(bar.bottom));
          } else {
            final left = (dock == PrismTabBarPlacement.leading) != rtl;
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
      PrismTheme(
        data: const PrismThemeData(
          scaffold: PrismScaffoldStyle(
            tabBarMaxWidth: 200,
            tabBarMargin: EdgeInsets.all(30),
            tabBarAlignment: AlignmentDirectional.centerStart,
          ),
        ),
        child: PrismScaffold(
          style: PrismScaffoldStyle(tabBarMargin: margin),
          tabBar: PrismTabBar(
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
    var bar = tester.getRect(find.byType(PrismTabBar));
    expect(bar.left, 0);
    expect(bar.width, lessThanOrEqualTo(200));
    expect(bar.bottom, 874);
    await tester.pumpWidget(page(const EdgeInsets.all(12)));
    await tester.pumpAndSettle();
    bar = tester.getRect(find.byType(PrismTabBar));
    expect(bar.left, 12);
    expect(bar.bottom, 862);
  });

  testWidgets('scaffold presets yield to themed and group sizes', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      _app(
        PrismTheme(
          data: const PrismThemeData(
            toolbar: PrismToolbarStyle(size: PrismToolbarSize.bottom),
          ),
          child: PrismScaffold(
            toolbar: [
              PrismToolbarGroup(
                items: [
                  PrismToolbarItem(
                    icon: const Icon(CupertinoIcons.star),
                    label: 'Theme',
                    onPressed: () {},
                  ),
                ],
              ),
              PrismToolbarGroup(
                style: const PrismToolbarStyle(
                  size: PrismToolbarSize.navigation,
                ),
                items: [
                  PrismToolbarItem(
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
    final groups = find.descendant(
      of: find.byType(PrismToolbar),
      matching: find.byType(RawPrismSurface),
    );
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
          PrismScaffold(
            placement: PrismChromePlacement.rightRail,
            toolbar: [
              PrismToolbarItem.custom(
                width: 60,
                child: CupertinoButton(
                  onPressed: () => taps++,
                  child: const Text('Own'),
                ),
              ),
              for (var i = 0; i < 20; i++)
                PrismToolbarItem(
                  icon: const Icon(CupertinoIcons.star),
                  label: 'Action $i',
                  onPressed: () {},
                ),
            ],
            tabBar: PrismTabBar(
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
            child: PrismTabBar(
              axis: Axis.vertical,
              selectedIndex: 0,
              onSelected: (_) {},
              tabs: _tabs,
              style: const PrismTabBarStyle(
                sizing: PrismTabBarSizing.fill,
                labelBehavior: PrismTabLabelBehavior.always,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PrismTabBar)).height, 350);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
