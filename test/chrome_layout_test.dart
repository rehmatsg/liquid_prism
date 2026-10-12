import 'dart:async';
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/system_chrome.dart' show SystemChromeListener;

/// Window sizes and safe areas measured on iOS 27.1 simulators.
const duo = (
  size: Size(466, 678),
  padding: FakeViewPadding(right: 84, bottom: 34),
);
const duoUnfolded = (
  size: Size(951, 669),
  padding: FakeViewPadding(right: 84, bottom: 34),
);
const phone = (
  size: Size(402, 874),
  padding: FakeViewPadding(top: 62, bottom: 34),
);

void main() {
  group('GlassChromePlacement.resolve', () {
    test('moves chrome into the deep side of an asymmetric safe area', () {
      expect(
        GlassChromePlacement.resolve(const EdgeInsets.only(right: 84)),
        GlassChromePlacement.rightRail,
      );
      expect(
        GlassChromePlacement.resolve(const EdgeInsets.only(left: 84)),
        GlassChromePlacement.leftRail,
      );
    });

    test(
      'keeps the bottom bar for portrait and symmetric landscape insets',
      () {
        expect(
          GlassChromePlacement.resolve(
            const EdgeInsets.only(top: 62, bottom: 34),
          ),
          GlassChromePlacement.bottom,
        );
        expect(
          GlassChromePlacement.resolve(
            const EdgeInsets.only(left: 62, right: 62, bottom: 21),
          ),
          GlassChromePlacement.bottom,
        );
        expect(
          GlassChromePlacement.resolve(const EdgeInsets.only(right: 20)),
          GlassChromePlacement.bottom,
        );
      },
    );
  });

  testWidgets('iPhone Duo: actions and icon-only tabs stack in the rail', (
    tester,
  ) async {
    window(tester, duo);
    await tester.pumpWidget(const _App());

    final bar = tester.getRect(find.byType(LiquidPrismTabBar));
    // Native: a 48 pt column 24 pt from the edges; 50 pt per tab plus 12.
    expect(bar, const Rect.fromLTWH(394, 678 - 24 - 162, 48, 162));
    expect(find.text('Home'), findsNothing, reason: 'the rail is icon-only');
    expect(find.bySemanticsLabel('Home'), findsOneWidget);

    final actions = tester.getRect(find.byType(LiquidPrismToolbarGroup));
    expect(actions, const Rect.fromLTWH(394, 170, 48, 100));

    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.right, 84);
    expect(padding.top, 24, reason: 'the status bar moves to the rail');
    expect(
      LiquidPrismScaffold.placementOf(tester.element(find.byKey(_body))),
      GlassChromePlacement.rightRail,
    );
  });

  testWidgets('unfolded iPhone Duo keeps the rail, actions sit higher', (
    tester,
  ) async {
    window(tester, duoUnfolded);
    await tester.pumpWidget(const _App());
    // Native: tab capsule at x 879, ending 24 pt above the bottom; the
    // trailing group at y 120 under the landscape status bar.
    expect(
      tester.getRect(find.byType(LiquidPrismTabBar)),
      const Rect.fromLTWH(879, 669 - 24 - 162, 48, 162),
    );
    expect(
      tester.getRect(find.byType(LiquidPrismToolbarGroup)),
      const Rect.fromLTWH(879, 120, 48, 100),
    );
    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.right, 84);
  });

  testWidgets('iPhone: top-trailing actions and a floating bottom tab bar', (
    tester,
  ) async {
    window(tester, phone);
    await tester.pumpWidget(const _App());

    final bar = tester.getRect(find.byType(LiquidPrismTabBar));
    expect(bar.bottom, 874 - 21);
    expect(bar.center.dx, 201);
    expect(find.text('Home'), findsOneWidget);

    final actions = tester.getRect(find.byType(LiquidPrismToolbarGroup));
    expect(actions.right, 402 - 16);
    expect(actions.top, 62);
    expect(actions.height, 44);

    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.top, 62 + 44);
    expect(padding.bottom, 874 - bar.top + 3);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('folding moves chrome and keeps the parent-owned selection', (
    tester,
  ) async {
    window(tester, phone);
    var selected = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _App(
          selected: selected,
          onSelected: (index) => setState(() => selected = index),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    expect(selected, 2);

    window(tester, duo);
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(LiquidPrismTabBar));
    expect(bar.width, 48);
    final tab = tester.widget<LiquidPrismTabBar>(
      find.byType(LiquidPrismTabBar),
    );
    expect(tab.selectedIndex, 2);

    // The middle tab of the rail selects by vertical position.
    await tester.tapAt(Offset(bar.center.dx, bar.top + 6 + 75));
    await tester.pumpAndSettle();
    expect(selected, 1);

    window(tester, phone);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(LiquidPrismTabBar)).bottom, 874 - 21);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a vertical tab bar drags, uses up/down keys and ignores RTL', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: StatefulBuilder(
            builder: (context, setState) => LiquidPrismTabBar(
              axis: Axis.vertical,
              selectedIndex: selected,
              onSelected: (index) => setState(() => selected = index),
              tabs: [
                for (final tab in _tabs)
                  LiquidPrismTab(
                    label: tab.label,
                    icon: KeyedSubtree(
                      key: ValueKey(tab.label),
                      child: tab.icon,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(LiquidPrismTabBar));
    expect(bar.size, const Size(48, 162));

    // Top to bottom in either direction: the first slot stays on top.
    await tester.tapAt(Offset(bar.center.dx, bar.top + 6 + 25));
    await tester.pumpAndSettle();
    expect(selected, 0);

    await tester.dragFrom(
      Offset(bar.center.dx, bar.top + 6 + 25),
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();
    expect(selected, 2);

    Focus.of(tester.element(find.byKey(const ValueKey('Search'))))
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit axes win over the scaffold placement', (tester) async {
    window(tester, duo);
    await tester.pumpWidget(
      _App(
        tabBar: LiquidPrismTabBar(
          axis: Axis.horizontal,
          selectedIndex: 0,
          onSelected: (_) {},
          tabs: _tabs,
        ),
      ),
    );
    final bar = tester.getRect(find.byType(LiquidPrismTabBar));
    expect(bar.height, lessThan(bar.width));
  });

  testWidgets('a vertical toolbar group transposes the measured capsule', (
    tester,
  ) async {
    Widget group(Axis axis) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: LiquidPrismToolbarGroup(
          axis: axis,
          items: [
            for (final label in ['Share', 'More'])
              GlassToolbarItem(
                icon: const Icon(CupertinoIcons.star),
                label: label,
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(group(Axis.horizontal));
    final row = tester.getSize(find.byType(LiquidPrismToolbarGroup));
    await tester.pumpWidget(group(Axis.vertical));
    final column = tester.getSize(find.byType(LiquidPrismToolbarGroup));
    expect(column, row.flipped);
    expect(column, const Size(48, 100));
  });

  testWidgets('keyboard hides only the bottom tab bar', (tester) async {
    window(tester, phone);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const _App());
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(find.byType(LiquidPrismTabBar), findsNothing);
    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.bottom, 300);

    window(tester, duo);
    await tester.pump();
    expect(find.byType(LiquidPrismTabBar), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('iOS 27.1 system chrome', () {
    Future<void> report(
      WidgetTester tester,
      Map<String, Object?> chrome,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('liquid_prism/menus'),
        (call) async => 'iOS 27.1',
      );
      messenger.setMockStreamHandler(
        SystemChromeListener.channel,
        MockStreamHandler.inline(
          onListen: (_, sink) => sink.success({'supported': true, ...chrome}),
        ),
      );
      addTearDown(() {
        // The stream mock stays installed so the asynchronous cancel that
        // reset() starts still reaches a handler.
        unawaited(SystemChromeListener.instance.reset());
        messenger.setMockMethodCallHandler(
          const MethodChannel('liquid_prism/menus'),
          null,
        );
      });
      unawaited(SystemChromeListener.instance.reset());
    }

    testWidgets('the vertical bar edge wins over safe-area insets', (
      tester,
    ) async {
      // Split View, app on the left: the bar moves to the left edge.
      window(tester, (
        size: const Size(475, 669),
        padding: const FakeViewPadding(left: 84, bottom: 34),
      ));
      await report(tester, {'verticalBarEdge': 'left'});
      await tester.pumpWidget(const _App());
      await tester.pump();
      expect(tester.getRect(find.byType(LiquidPrismTabBar)).left, 84 - 12 - 48);

      // The system chose horizontal bars despite a one-sided inset.
      await report(tester, {'verticalBarEdge': null});
      window(tester, duo);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const _App());
      await tester.pump();
      final bar = tester.getRect(find.byType(LiquidPrismTabBar));
      expect(bar.width, greaterThan(bar.height));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Split View on the left reserves its own rail strip', (
      tester,
    ) async {
      // Measured: the left app gets edge left but no left safe area, and no
      // status bar, which belongs to the app on the right.
      window(tester, (
        size: const Size(455.5, 669),
        padding: const FakeViewPadding(bottom: 34),
      ));
      await report(tester, {
        'verticalBarEdge': 'left',
        'divisions': [
          [455.5, 0.0, 13.5, 669.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ],
      });
      await tester.pumpWidget(const _App());
      await tester.pump();
      expect(tester.getRect(find.byType(LiquidPrismTabBar)).left, 24);
      expect(
        tester.getRect(find.byType(LiquidPrismToolbarGroup)).topLeft,
        const Offset(24, 24),
      );
      final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
      expect(padding.left, 84);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('closed landscape stops the rail above the status bar', (
      tester,
    ) async {
      // Native: the status bar and camera sit at the bottom of the rail and
      // the tab bar ends at y 384, where they begin.
      window(tester, (
        size: const Size(678, 466),
        padding: const FakeViewPadding(right: 84, bottom: 34),
      ));
      await report(tester, {
        'verticalBarEdge': 'right',
        'occlusions': [
          [611.6, 399.6, 37.0, 37.0],
          [594.0, 384.0, 84.0, 82.0],
        ],
      });
      await tester.pumpWidget(const _App());
      await tester.pump();
      expect(tester.getRect(find.byType(LiquidPrismTabBar)).bottom, 384);
      expect(tester.getRect(find.byType(LiquidPrismToolbarGroup)).top, 24);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a corner status bar shares the top bar row', (tester) async {
      // Native, unfolded in portrait: actions at y 24, 48 pt tall, ending
      // where the status bar's region begins at x 535.
      window(tester, (
        size: const Size(669, 951),
        padding: const FakeViewPadding(top: 82, bottom: 34),
      ));
      await report(tester, {
        'verticalBarEdge': null,
        'occlusions': [
          [535.0, 0.0, 134.0, 82.0],
        ],
      });
      await tester.pumpWidget(const _App());
      await tester.pump();
      final actions = tester.getRect(find.byType(LiquidPrismToolbarGroup));
      expect(actions.right, 535);
      expect(actions.top, 24);
      expect(actions.height, 48);
      expect(tester.getRect(find.byType(LiquidPrismTabBar)).bottom, 951 - 21);
      final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
      expect(padding.top, 82);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('rail actions start below the reported status bar region', (
      tester,
    ) async {
      window(tester, duoUnfolded);
      await report(tester, {
        'verticalBarEdge': 'right',
        'occlusions': [
          [867.0, 0.0, 84.0, 131.0],
          // A camera region outside the rail does not move the actions.
          [677.0, 21.0, 58.0, 37.0],
        ],
      });
      await tester.pumpWidget(const _App());
      await tester.pump();
      expect(tester.getRect(find.byType(LiquidPrismToolbarGroup)).top, 131);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a partial fold reaches the body as a display feature', (
      tester,
    ) async {
      window(tester, duoUnfolded);
      await report(tester, {
        'verticalBarEdge': 'right',
        'divisions': [
          [455.5, 0.0, 40.0, 669.0, 20.0, 0.0, 20.0, 0.0],
        ],
      });
      await tester.pumpWidget(const _App());
      await tester.pump();
      final features = MediaQuery.of(tester.element(find.byKey(_body)))
          .displayFeatures;
      expect(features.single.bounds, const Rect.fromLTWH(455.5, 0, 40, 669));
      expect(features.single.type, DisplayFeatureType.fold);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('a short rail collapses actions into one overflow menu', (
    tester,
  ) async {
    // The folded Duo in landscape: 466 pt tall with the bar on the side.
    window(tester, (
      size: const Size(678, 380),
      padding: const FakeViewPadding(right: 84, bottom: 21),
    ));
    await tester.pumpWidget(const _App());
    final group = tester.widget<LiquidPrismToolbarGroup>(
      find.byType(LiquidPrismToolbarGroup),
    );
    expect(group.items.single.label, 'More');
    expect(group.items.single.menu!.children, hasLength(2));
    expect(find.byType(LiquidPrismTabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('sidebar placement', () {
    Widget app({required ValueChanged<int> onSelected, int selected = 0}) =>
        CupertinoApp(
          home: LiquidPrismScaffold(
            tabBarPlacement: GlassTabBarPlacement.sidebar,
            tabBar: LiquidPrismTabBar(
              selectedIndex: selected,
              onSelected: onSelected,
              tabs: _tabs,
            ),
            body: const SizedBox.expand(key: _body),
          ),
        );

    testWidgets('lists the tabs beside content at regular width', (
      tester,
    ) async {
      window(tester, duoUnfolded);
      var selected = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => app(
            selected: selected,
            onSelected: (index) => setState(() => selected = index),
          ),
        ),
      );
      // Native: a 280 pt sidebar; rows 240 x 44 at x 20 under the toggle.
      expect(find.byType(LiquidPrismTabBar), findsNothing);
      expect(tester.getRect(find.text('Saved')).left, 20 + 54);
      final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
      expect(padding.left, 280);
      expect(padding.right, 84);

      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(selected, 2);

      // Hidden, the tabs go back to the rail and a toggle brings it back.
      await tester.tap(find.bySemanticsLabel('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(tester.getRect(find.byType(LiquidPrismTabBar)).width, 48);
      await tester.tap(find.bySemanticsLabel('Show sidebar'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('keeps the tab bar at compact width', (tester) async {
      window(tester, duo);
      await tester.pumpWidget(app(onSelected: (_) {}));
      expect(find.byType(LiquidPrismTabBar), findsOneWidget);
      expect(find.bySemanticsLabel('Hide sidebar'), findsNothing);
    });
  });
}

const _body = ValueKey('body');
const _tabs = [
  LiquidPrismTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
  LiquidPrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
  LiquidPrismTab(label: 'Search', icon: Icon(CupertinoIcons.search)),
];

void window(
  WidgetTester tester,
  ({Size size, FakeViewPadding padding}) device,
) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = device.size
    ..padding = device.padding
    ..viewPadding = device.padding;
  addTearDown(tester.view.reset);
}

class _App extends StatelessWidget {
  const _App({this.selected = 0, this.onSelected, this.tabBar});
  final int selected;
  final ValueChanged<int>? onSelected;
  final Widget? tabBar;

  @override
  Widget build(BuildContext context) => CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: LiquidPrismScaffold(
      actions: [
        for (final label in ['Share', 'More'])
          GlassToolbarItem(
            icon: const Icon(CupertinoIcons.star),
            label: label,
            onPressed: () {},
          ),
      ],
      tabBar:
          tabBar ??
          LiquidPrismTabBar(
            selectedIndex: selected,
            onSelected: onSelected ?? (_) {},
            tabs: _tabs,
          ),
      body: const SizedBox.expand(key: _body),
    ),
  );
}
