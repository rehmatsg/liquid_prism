import 'package:flutter/cupertino.dart';
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
                    title: const Text('Inline'),
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
                title: const Text('Inline'),
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
        closeTo(initial - 200 - 54, .01),
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
