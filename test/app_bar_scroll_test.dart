import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rows;

Widget page({
  required bool sliver,
  required ScrollController scroll,
  required GlassNavigationBarStyle style,
  bool large = false,
  bool rtl = false,
  bool reduceMotion = false,
  bool scrollEdge = true,
  FocusNode? focus,
  PreferredSizeWidget? accessory,
  Widget? title,
  Widget? header,
}) => CupertinoApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: sliver
            ? CustomScrollView(
                controller: scroll,
                slivers: [
                  LiquidPrismSliverAppBar(
                    navigationBarStyle: style,
                    scrollEdge: scrollEdge,
                    accessory: accessory,
                    title: title ?? const Text('Inline'),
                    largeTitle: large ? const Text('Large') : null,
                    leading: LiquidPrismButton(
                      label: 'Back',
                      focusNode: focus,
                      onPressed: () {},
                    ),
                  ),
                  ...rows(),
                ],
              )
            : LiquidPrismScaffold(
                navigationBarStyle: style,
                scrollEdge: scrollEdge,
                accessory: accessory,
                title: title ?? const Text('Inline'),
                header: header,
                largeTitle: large ? const Text('Large') : null,
                leading: LiquidPrismButton(
                  label: 'Back',
                  focusNode: focus,
                  onPressed: () {},
                ),
                scrollController: scroll,
                slivers: rows(),
              ),
      ),
    ),
  ),
);

void main() {
  testWidgets('rail controls stay fixed while the header minimizes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final left in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final padding = FakeViewPadding(
          left: left ? 84 : 0,
          right: left ? 0 : 84,
          bottom: 34,
        );
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(466, 678)
          ..padding = padding
          ..viewPadding = padding;
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var backTaps = 0, actionTaps = 0;
        const backKey = Key('rail back');
        await tester.pumpWidget(
          CupertinoApp(
            home: LiquidPrismScaffold(
              title: const Text('Rail page'),
              navigationBarStyle: const GlassNavigationBarStyle(
                minimizationBehavior:
                    GlassToolbarMinimizationBehavior.onScrollDown,
              ),
              leading: LiquidPrismButton(
                key: backKey,
                label: 'Rail Back',
                onPressed: () => backTaps++,
                child: const Icon(CupertinoIcons.chevron_back),
              ),
              toolbar: [
                GlassToolbarItem(
                  icon: const Icon(CupertinoIcons.ellipsis),
                  label: 'Rail action',
                  onPressed: () => actionTaps++,
                ),
              ],
              scrollController: scroll,
              slivers: rows(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final back = tester.getRect(find.byKey(backKey));
        final actions = tester.getRect(find.byType(LiquidPrismToolbarGroup));
        expect(back.top, greaterThan(82));
        var expectedTaps = 0;
        for (final offset in [0.0, 20.0, 80.0, 300.0, 295.0, 240.0, 0.0]) {
          scroll.jumpTo(offset);
          await tester.pumpAndSettle();
          expect(find.semantics.byLabel('Rail Back'), findsOneWidget);
          expect(find.semantics.byLabel('Rail action'), findsOneWidget);
          expect(
            tester.getRect(find.byKey(backKey)),
            back,
            reason: 'left $left offset $offset',
          );
          expect(
            tester.getRect(find.byType(LiquidPrismToolbarGroup)),
            actions,
            reason: 'left $left offset $offset',
          );
          if (offset == 300) {
            expect(find.semantics.byLabel('Rail page'), findsNothing);
          } else if (offset == 240 || offset == 0) {
            expect(find.semantics.byLabel('Rail page'), findsOneWidget);
          }
          await tester.tapAt(back.center);
          await tester.pumpAndSettle();
          await tester.tapAt(actions.center);
          await tester.pumpAndSettle();
          expectedTaps++;
          expect(backTaps, expectedTaps);
          expect(actionTaps, expectedTaps);
        }
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });

  for (final dock in [GlassTabBarPlacement.top, GlassTabBarPlacement.bottom]) {
    testWidgets('only integrated top tabs minimize with the bar, $dock', (
      tester,
    ) async {
      phone(tester);
      final semantics = tester.ensureSemantics();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: LiquidPrismScaffold(
            title: const Text('Title'),
            scrollController: scroll,
            slivers: rows(),
            navigationBarStyle: const GlassNavigationBarStyle(
              minimizationBehavior:
                  GlassToolbarMinimizationBehavior.onScrollDown,
            ),
            tabBarPlacement: dock,
            tabBar: LiquidPrismTabBar(
              tabs: const [
                LiquidPrismTab(icon: Icon(CupertinoIcons.house), label: 'Home'),
                LiquidPrismTab(
                  icon: Icon(CupertinoIcons.search),
                  label: 'Search',
                ),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Home'), findsOneWidget);
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Title'), findsNothing);
      expect(
        find.semantics.byLabel('Home'),
        dock == GlassTabBarPlacement.top ? findsNothing : findsOneWidget,
      );
      tester.view.physicalSize = const Size(874, 402);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  for (final sliver in [false, true]) {
    testWidgets(
      'compact title lifecycle follows scroll-away and reveal modes, sliver $sliver',
      (tester) async {
        phone(tester);
        final semantics = tester.ensureSemantics();
        try {
          for (final header in sliver ? [false] : [false, true]) {
            for (final away in [true, false]) {
              await tester.pumpWidget(const SizedBox.shrink());
              final scroll = ScrollController();
              final focus = FocusNode();
              addTearDown(scroll.dispose);
              addTearDown(focus.dispose);
              var builds = 0, taps = 0;
              const compactKey = Key('deferred compact title');
              Widget subject({bool sticky = false}) => page(
                sliver: sliver,
                scroll: scroll,
                large: !header,
                header: header
                    ? const SizedBox(height: 60, child: Text('Page heading'))
                    : null,
                title: Builder(
                  builder: (_) {
                    builds++;
                    return LiquidPrismButton(
                      key: compactKey,
                      label: 'Deferred compact',
                      focusNode: focus,
                      onPressed: () => taps++,
                    );
                  },
                ),
                style: GlassNavigationBarStyle(
                  minimizationBehavior: sticky
                      ? GlassToolbarMinimizationBehavior.never
                      : GlassToolbarMinimizationBehavior.onScrollDown,
                  minimizationRestoration: away
                      ? GlassToolbarMinimizationRestoration.atScrollEdge
                      : GlassToolbarMinimizationRestoration.automatic,
                ),
              );
              Future<void> hidden() async {
                if (away) {
                  expect(builds, 0);
                  expect(find.byKey(compactKey), findsNothing);
                } else {
                  expect(find.byKey(compactKey), findsOneWidget);
                  final opacity = tester
                      .widgetList<Opacity>(
                        find.ancestor(
                          of: find.byKey(compactKey),
                          matching: find.byType(Opacity),
                        ),
                      )
                      .fold(1.0, (value, widget) => value * widget.opacity);
                  expect(opacity, 0);
                  expect(
                    find.semantics.byLabel('Deferred compact'),
                    findsNothing,
                  );
                  expect(focus.canRequestFocus, isFalse);
                  final before = taps;
                  await tester.tapAt(tester.getCenter(find.byKey(compactKey)));
                  await tester.pumpAndSettle();
                  expect(taps, before);
                }
              }

              await tester.pumpWidget(subject());
              await tester.pumpAndSettle();
              await hidden();
              final retained = away
                  ? null
                  : tester.element(find.byKey(compactKey));
              for (final offset in [8.0, 30.0, 80.0, 160.0]) {
                scroll.jumpTo(offset);
                await tester.pumpAndSettle();
                await hidden();
              }
              scroll.jumpTo(155);
              await tester.pumpAndSettle();
              if (away) {
                await hidden();
              } else {
                expect(tester.element(find.byKey(compactKey)), same(retained));
                expect(
                  find.semantics.byLabel('Deferred compact'),
                  findsOneWidget,
                );
                expect(focus.canRequestFocus, isTrue);
                focus.requestFocus();
                await tester.pump();
                await tester.sendKeyEvent(LogicalKeyboardKey.enter);
                await tester.pumpAndSettle();
                expect(taps, 1);
                scroll.jumpTo(80);
                await tester.pumpAndSettle();
                await tester.tap(find.byKey(compactKey));
                await tester.pumpAndSettle();
                expect(taps, 2);
                scroll.jumpTo(220);
                await tester.pumpAndSettle();
                await hidden();
                expect(tester.element(find.byKey(compactKey)), same(retained));
              }
              scroll.jumpTo(0);
              await tester.pumpAndSettle();
              await hidden();
              scroll.jumpTo(300);
              await tester.pumpAndSettle();
              await tester.pumpWidget(subject(sticky: true));
              await tester.pumpAndSettle();
              expect(builds, greaterThan(0));
              expect(find.byKey(compactKey), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'default minimization keeps content motion continuous, sliver $sliver',
      (tester) async {
        phone(tester);
        for (final accessory in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          await tester.pumpWidget(
            page(
              sliver: sliver,
              scroll: scroll,
              style: const GlassNavigationBarStyle(
                minimizationBehavior:
                    GlassToolbarMinimizationBehavior.onScrollDown,
              ),
              accessory: accessory
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(44),
                      child: Text('Motion accessory'),
                    )
                  : null,
            ),
          );
          await tester.pumpAndSettle();
          final anchor = find.byKey(const ValueKey('row8'));
          final headerTop = tester.getTopLeft(find.text('Back')).dy;
          var y = tester.getTopLeft(anchor).dy;
          var previous = 0.0;
          for (final offset in [
            20.0,
            40.0,
            80.0,
            120.0,
            115.0,
            100.0,
            60.0,
            20.0,
            0.0,
          ]) {
            scroll.jumpTo(offset);
            await tester.pumpAndSettle();
            expect(scroll.offset, offset);
            if (offset == 80 || offset == 120) {
              expect(
                tester.getTopLeft(find.text('Back')).dy,
                lessThan(headerTop),
              );
            } else if (offset == 0) {
              expect(
                tester.getTopLeft(find.text('Back')).dy,
                closeTo(headerTop, .01),
              );
            }
            final nextY = tester.getTopLeft(anchor).dy;
            expect(
              nextY - y,
              closeTo(previous - offset, .01),
              reason: 'accessory $accessory: $previous to $offset',
            );
            y = nextY;
            previous = offset;
          }
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'accessories remain usable while navigation scrolls, sliver $sliver',
      (tester) async {
        phone(tester);
        final semantics = tester.ensureSemantics();
        try {
          const modes = {
            'sticky': GlassNavigationBarStyle(
              minimizationBehavior: GlassToolbarMinimizationBehavior.never,
              minimizationSafeAreaAdjustment:
                  GlassToolbarMinimizationSafeAreaAdjustment.enabled,
            ),
            'scroll-away': GlassNavigationBarStyle(
              minimizationBehavior:
                  GlassToolbarMinimizationBehavior.onScrollDown,
              minimizationRestoration:
                  GlassToolbarMinimizationRestoration.atScrollEdge,
              minimizationSafeAreaAdjustment:
                  GlassToolbarMinimizationSafeAreaAdjustment.enabled,
            ),
            'reveal-on-scroll-up': GlassNavigationBarStyle(
              minimizationBehavior:
                  GlassToolbarMinimizationBehavior.onScrollDown,
              minimizationSafeAreaAdjustment:
                  GlassToolbarMinimizationSafeAreaAdjustment.enabled,
            ),
          };
          for (final mode in modes.entries) {
            await tester.pumpWidget(const SizedBox.shrink());
            final scroll = ScrollController();
            addTearDown(scroll.dispose);
            var taps = 0;
            const accessoryKey = Key('persistent accessory');
            await tester.pumpWidget(
              page(
                sliver: sliver,
                scroll: scroll,
                style: mode.value,
                accessory: PreferredSize(
                  preferredSize: const Size.fromHeight(44),
                  child: CupertinoButton(
                    key: accessoryKey,
                    padding: EdgeInsets.zero,
                    onPressed: () => taps++,
                    child: const Text('Accessory action'),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            double bodyInset() =>
                tester.getTopLeft(find.byKey(const ValueKey('row8'))).dy +
                scroll.offset -
                8 * 50;
            final initialInset = bodyInset();
            final clearance =
                initialInset -
                tester.getBottomLeft(find.byKey(accessoryKey)).dy;
            var expectedTaps = 0;
            Future<void> check({required bool headerVisible}) async {
              expect(
                find.semantics.byLabel('Back'),
                headerVisible ? findsOneWidget : findsNothing,
                reason: mode.key,
              );
              expect(
                find.semantics.byLabel('Accessory action'),
                findsOneWidget,
                reason: mode.key,
              );
              final accessory = tester.getRect(find.byKey(accessoryKey));
              expect(
                accessory.top,
                headerVisible ? greaterThanOrEqualTo(62) : closeTo(62, .01),
                reason: mode.key,
              );
              expect(
                bodyInset(),
                closeTo(accessory.bottom + clearance, .01),
                reason: mode.key,
              );
              await tester.tapAt(accessory.center);
              await tester.pumpAndSettle();
              expect(taps, ++expectedTaps, reason: mode.key);
            }

            await check(headerVisible: true);
            scroll.jumpTo(300);
            await tester.pumpAndSettle();
            await check(headerVisible: mode.key == 'sticky');
            if (mode.key != 'sticky') {
              expect(bodyInset(), lessThan(initialInset));
            }
            scroll.jumpTo(240);
            await tester.pumpAndSettle();
            await check(headerVisible: mode.key != 'scroll-away');
            scroll.jumpTo(0);
            await tester.pumpAndSettle();
            await check(headerVisible: true);
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('large-title collapse precedes minimization, sliver $sliver', (
      tester,
    ) async {
      phone(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        page(
          sliver: sliver,
          scroll: scroll,
          large: true,
          style: const GlassNavigationBarStyle(
            minimizationBehavior: GlassToolbarMinimizationBehavior.onScrollDown,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester.getTopLeft(find.byKey(const ValueKey('row5'))).dy;
      scroll.jumpTo(60);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Back')).dy, greaterThan(62));
      scroll.jumpTo(200);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('row5'))).dy,
        closeTo(initial - 200, .01),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'local never overrides inherited minimization, sliver $sliver',
      (tester) async {
        phone(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          LiquidPrismTheme(
            data: const LiquidPrismThemeData(
              navigationBar: GlassNavigationBarStyle(
                minimizationBehavior:
                    GlassToolbarMinimizationBehavior.onScrollDown,
                minimizationThreshold: 40,
              ),
            ),
            child: page(
              sliver: sliver,
              scroll: scroll,
              style: const GlassNavigationBarStyle(
                minimizationBehavior: GlassToolbarMinimizationBehavior.never,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final top = tester.getTopLeft(find.text('Back')).dy;
        scroll.jumpTo(200);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Back')).dy, top);
      },
    );

    testWidgets(
      'explicit zero overrides inherited scroll threshold and spacing, sliver $sliver',
      (tester) async {
        phone(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          LiquidPrismTheme(
            data: const LiquidPrismThemeData(
              navigationBar: GlassNavigationBarStyle(
                minimizationBehavior:
                    GlassToolbarMinimizationBehavior.onScrollDown,
                minimizationThreshold: 40,
                contentSpacing: 20,
              ),
            ),
            child: page(
              sliver: sliver,
              scroll: scroll,
              scrollEdge: false,
              style: const GlassNavigationBarStyle(
                minimizationThreshold: 0,
                contentSpacing: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final top = tester.getTopLeft(find.text('Back')).dy;
        expect(tester.getTopLeft(find.byKey(const ValueKey('row0'))).dy, 106);
        scroll.jumpTo(5);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Back')).dy, closeTo(top - 5, .01));
      },
    );

    testWidgets(
      'minimizes the whole bar and restores on reversal, sliver $sliver',
      (tester) async {
        phone(tester);
        final semantics = tester.ensureSemantics();
        final scroll = ScrollController(), focus = FocusNode();
        addTearDown(scroll.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          page(
            sliver: sliver,
            scroll: scroll,
            focus: focus,
            style: const GlassNavigationBarStyle(
              minimizationBehavior:
                  GlassToolbarMinimizationBehavior.onScrollDown,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final top = tester.getTopLeft(find.text('Back')).dy;
        focus.requestFocus();
        await tester.pump();
        scroll.jumpTo(40);
        await tester.pumpAndSettle();
        final delta = top - tester.getTopLeft(find.text('Back')).dy;
        expect(delta, closeTo(40 - 40 / 3, .01));
        final opacity = tester
            .widget<Opacity>(
              find.ancestor(
                of: find.text('Inline'),
                matching: find.byType(Opacity),
              ),
            )
            .opacity;
        expect(opacity, closeTo(1 - delta / 54, .001));
        scroll.jumpTo(300);
        await tester.pumpAndSettle();
        expect(find.semantics.byLabel('Back'), findsNothing);
        expect(find.semantics.byLabel('Inline'), findsNothing);
        expect(focus.canRequestFocus, isFalse);
        expect(focus.hasFocus, isFalse);
        scroll.jumpTo(240);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Back')).dy, closeTo(top, .01));
        expect(find.semantics.byLabel('Back'), findsOneWidget);
        expect(focus.canRequestFocus, isTrue);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'edge restoration ignores reversal until the top, sliver $sliver',
      (tester) async {
        phone(tester);
        final semantics = tester.ensureSemantics();
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          page(
            sliver: sliver,
            scroll: scroll,
            style: const GlassNavigationBarStyle(
              minimizationBehavior:
                  GlassToolbarMinimizationBehavior.onScrollDown,
              minimizationRestoration:
                  GlassToolbarMinimizationRestoration.atScrollEdge,
            ),
          ),
        );
        await tester.pumpAndSettle();
        scroll.jumpTo(400);
        await tester.pumpAndSettle();
        scroll.jumpTo(100);
        await tester.pumpAndSettle();
        expect(find.semantics.byLabel('Inline'), findsNothing);
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.semantics.byLabel('Inline'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets('on-scroll-up minimizes on reversal, sliver $sliver', (
      tester,
    ) async {
      phone(tester);
      final semantics = tester.ensureSemantics();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        page(
          sliver: sliver,
          scroll: scroll,
          style: const GlassNavigationBarStyle(
            minimizationBehavior: GlassToolbarMinimizationBehavior.onScrollUp,
          ),
        ),
      );
      await tester.pumpAndSettle();
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Inline'), findsOneWidget);
      scroll.jumpTo(240);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Inline'), findsNothing);
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Inline'), findsOneWidget);
      semantics.dispose();
    });

    for (final fixedInsets in [false, true]) {
      testWidgets('minimization safe area fixed $fixedInsets, sliver $sliver', (
        tester,
      ) async {
        phone(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          page(
            sliver: sliver,
            scroll: scroll,
            style: GlassNavigationBarStyle(
              minimizationBehavior:
                  GlassToolbarMinimizationBehavior.onScrollDown,
              minimizationSafeAreaAdjustment: fixedInsets
                  ? GlassToolbarMinimizationSafeAreaAdjustment.disabled
                  : GlassToolbarMinimizationSafeAreaAdjustment.enabled,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final initial = tester
            .getTopLeft(find.byKey(const ValueKey('row0')))
            .dy;
        expect(initial, closeTo(116, .01));
        scroll.jumpTo(100);
        await tester.pumpAndSettle();
        // The first row has moved out of view; row 2 retains the same 100pt gap.
        final y = tester.getTopLeft(find.byKey(const ValueKey('row2'))).dy;
        expect(y, closeTo(fixedInsets ? 116 : 62, .01));
        expect(tester.takeException(), isNull);
      });
    }

    for (final rtl in [false, true]) {
      testWidgets('title alignments are independent, sliver $sliver RTL $rtl', (
        tester,
      ) async {
        phone(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          page(
            sliver: sliver,
            scroll: scroll,
            large: true,
            rtl: rtl,
            style: const GlassNavigationBarStyle(
              titleAlignment: GlassTitleAlignment.leading,
              largeTitleAlignment: GlassTitleAlignment.center,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.text('Large')).dx, closeTo(201, .01));
        scroll.jumpTo(200);
        await tester.pumpAndSettle();
        final title = tester.getRect(find.text('Inline'));
        final back = tester.getRect(find.byType(LiquidPrismButton));
        expect(
          rtl ? title.right : title.left,
          closeTo(rtl ? back.left - 12 : back.right + 12, .01),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
