import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/navigation/prism_system_chrome.dart'
    show SystemChromeListener;

const _body = Key('body');

typedef _Chrome = ({
  Widget? title,
  Widget? leading,
  Widget? trailing,
  List<PrismToolbarContent> toolbar,
  PreferredSizeWidget? accessory,
});

_Chrome _chrome({
  Widget? title,
  Widget? leading,
  Widget? trailing,
  List<PrismToolbarContent> toolbar = const [],
  PreferredSizeWidget? accessory,
}) => (
  title: title,
  leading: leading,
  trailing: trailing,
  toolbar: toolbar,
  accessory: accessory,
);

void main() {
  accessoryTests();
  void phone(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(402, 874)
      ..padding = const FakeViewPadding(top: 62, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
  }

  Widget app({
    required ScrollController controller,
    bool scrollEdge = true,
    bool withTitle = true,
    Widget? leading,
    List<PrismToolbarItem> toolbar = const [],
    Color? background = const Color(0xFF101010),
  }) => CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: PrismScaffold(
      title: withTitle ? const Text('Page') : null,
      scrollEdge: scrollEdge,
      backgroundColor: background,
      leading: leading,
      toolbar: toolbar,
      body: ListView.builder(
        key: _body,
        controller: controller,
        itemCount: 60,
        itemBuilder: (context, index) =>
            SizedBox(height: 44, child: Text('Row $index')),
      ),
    ),
  );

  testWidgets(
    'text and glass titles and accessories take the full top edge, other top '
    'chrome the compact soft one over the status bar',
    (tester) async {
      phone(tester);
      const accessoryKey = Key('accessory');
      const accessory = PreferredSize(
        preferredSize: Size.fromHeight(36),
        child: SizedBox(key: accessoryKey, height: 36),
      );
      final action = [
        PrismToolbarItem(
          label: 'More',
          icon: const Icon(CupertinoIcons.ellipsis),
          onPressed: () {},
        ),
      ];
      const glassTitle = PrismTitle(child: Text('Company'));

      for (final (name, full, page) in <(String, bool, _Chrome)>[
        (
          'a text title',
          true,
          _chrome(title: const Text('Page'), toolbar: action),
        ),
        ('actions only', false, _chrome(toolbar: action)),
        ('a glass title', true, _chrome(title: glassTitle, toolbar: action)),
        (
          'a leading control only',
          false,
          _chrome(leading: const SizedBox(width: 44, height: 44)),
        ),
        (
          'a trailing widget only',
          false,
          _chrome(trailing: const SizedBox(width: 44, height: 44)),
        ),
        ('an accessory without a top bar', true, _chrome(accessory: accessory)),
        (
          'a glass title over an accessory',
          true,
          _chrome(title: glassTitle, toolbar: action, accessory: accessory),
        ),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          CupertinoApp(
            home: PrismScaffold(
              title: page.title,
              leading: page.leading,
              trailing: page.trailing,
              toolbar: page.toolbar,
              accessory: page.accessory,
              scrollEdgeStyle: const PrismScrollEdgeStyle(
                variant: PrismScrollEdgeVariant.hard,
              ),
              scrollController: controller,
              slivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        );
        controller.jumpTo(100);
        await tester.pumpAndSettle();
        final blur = find.byType(PrismEdgeBlur);
        expect(blur, findsOneWidget, reason: name);
        final spec = tester.widget<PrismEdgeBlur>(blur).edges.single;
        final effect = tester.getRect(blur);
        expect(effect.top, 0, reason: name);
        if (full) {
          expect(spec.fadeFloor, 1, reason: '$name: the hard style');
          expect(
            effect.bottom,
            page.accessory == null
                ? 62 + 44 + 10
                : tester.getRect(find.byKey(accessoryKey)).bottom,
            reason: name,
          );
        } else {
          expect(spec.fadeFloor, isNull, reason: '$name: always soft');
          expect(effect.bottom, 62, reason: name);
          expect(spec.extent, 62, reason: '$name: dissolve counted inside');
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'a glass title in a bar that stays on the iPhone Duo, with no status bar '
    'above it, keeps its capsule inside the edge',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(466, 678)
        ..padding = const FakeViewPadding(right: 84, bottom: 34)
        ..viewPadding = const FakeViewPadding(right: 84, bottom: 34);
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: PrismScaffold(
            navigationBarStyle: const PrismNavigationBarStyle(
              minimizationBehavior: PrismMinimizationBehavior.never,
            ),
            title: const PrismTitle(child: Text('Company')),
            toolbar: [
              PrismToolbarItem(
                label: 'More',
                icon: const Icon(CupertinoIcons.ellipsis),
                onPressed: () {},
              ),
            ],
            scrollController: controller,
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
          ),
        ),
      );
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      final blur = find.byType(PrismEdgeBlur);
      expect(blur, findsOneWidget);
      expect(
        tester.getRect(blur).bottom,
        greaterThanOrEqualTo(tester.getRect(find.byType(PrismTitle)).bottom),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  for (final sliver in [false, true]) {
    for (final restoration in PrismMinimizationRestoration.values) {
      testWidgets(
        'Duo soft edge follows visible chrome, sliver $sliver, $restoration',
        (tester) async {
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = const Size(466, 678)
            ..padding = const FakeViewPadding(right: 84, bottom: 34)
            ..viewPadding = const FakeViewPadding(right: 84, bottom: 34);
          addTearDown(tester.view.reset);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final style = PrismNavigationBarStyle(
            minimizationBehavior: PrismMinimizationBehavior.onScrollDown,
            minimizationRestoration: restoration,
          );
          const rows = [SliverToBoxAdapter(child: SizedBox(height: 2000))];
          await tester.pumpWidget(
            CupertinoApp(
              home: sliver
                  ? CustomScrollView(
                      controller: controller,
                      slivers: [
                        PrismSliverAppBar(
                          title: const Text('Profile'),
                          navigationBarStyle: style,
                        ),
                        ...rows,
                      ],
                    )
                  : PrismScaffold(
                      title: const Text('Profile'),
                      scrollController: controller,
                      navigationBarStyle: style,
                      slivers: rows,
                    ),
            ),
          );
          final blur = find.byType(PrismEdgeBlur);
          Future<void> scroll(double offset) async {
            controller.jumpTo(offset);
            await tester.pumpAndSettle();
          }

          await scroll(16);
          expect(blur, findsNothing, reason: 'title travels with the rows');
          await scroll(400);
          expect(blur, findsNothing, reason: 'fully hidden');
          await scroll(398);
          if (restoration == PrismMinimizationRestoration.atScrollEdge) {
            expect(blur, findsNothing, reason: 'reversal away from the edge');
            await scroll(30);
            expect(blur, findsNothing, reason: 'title returns with the rows');
          } else {
            expect(blur, findsOneWidget);
            final partial = tester.widget<PrismEdgeBlur>(blur).edges.single;
            expect(partial.fadeFloor, isNull);
            expect(partial.extent, lessThan(4));
            expect(partial.sigma, lessThan(.1));
            await scroll(290);
            final restored = tester.widget<PrismEdgeBlur>(blur).edges.single;
            expect(restored.fadeFloor, isNull);
            expect(restored.sigma, PrismScrollEdgeStyle.defaultSigma);
            expect(restored.extent, 82 + PrismScrollEdgeStyle.defaultExtension);
            await scroll(420);
            expect(blur, findsNothing, reason: 'hidden again');
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
  testWidgets(
    "a glass title's soft edge fades out at the glass; a text title's fades "
    'past the bar',
    (tester) async {
      phone(tester);
      for (final (name, title) in <(String, Widget)>[
        ('glass', const PrismTitle(child: Text('Company'))),
        ('text', const Text('Company')),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          CupertinoApp(
            home: PrismScaffold(
              title: title,
              scrollController: controller,
              slivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        );
        controller.jumpTo(100);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(PrismEdgeBlur)).bottom,
          name == 'glass'
              ? tester.getRect(find.byType(PrismTitle)).bottom
              : 62 + 44 + PrismScrollEdgeStyle.defaultExtension,
          reason: name,
        );
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'the compact edge fits a short status bar and is absent without one',
    (tester) async {
      for (final top in [20.0, 0.0]) {
        for (final titled in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = const Size(402, 874)
            ..padding = FakeViewPadding(top: top, bottom: 34)
            ..viewPadding = FakeViewPadding(top: top, bottom: 34);
          addTearDown(tester.view.reset);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            CupertinoApp(
              home: PrismScaffold(
                title: titled ? const Text('Page') : null,
                toolbar: [
                  PrismToolbarItem(
                    label: 'More',
                    icon: const Icon(CupertinoIcons.ellipsis),
                    onPressed: () {},
                  ),
                ],
                scrollController: controller,
                slivers: const [
                  SliverToBoxAdapter(child: SizedBox(height: 2000)),
                ],
              ),
            ),
          );
          controller.jumpTo(100);
          await tester.pumpAndSettle();
          final blur = find.byType(PrismEdgeBlur);
          final reason = 'status bar $top, titled $titled';
          if (titled) {
            expect(blur, findsOneWidget, reason: reason);
            expect(
              tester.getRect(blur).bottom,
              greaterThan(44),
              reason: reason,
            );
          } else if (top == 0) {
            expect(blur, findsNothing, reason: reason);
          } else {
            expect(tester.getRect(blur), const Rect.fromLTRB(0, 0, 402, 20));
          }
        }
      }
    },
  );
  testWidgets(
    'the compact edge ends as far below the island as the island sits below '
    'the top, and follows it',
    (tester) async {
      phone(tester);
      final messenger = tester.binding.defaultBinaryMessenger;
      late MockStreamHandlerEventSink events;
      messenger
        ..setMockMethodCallHandler(
          const MethodChannel('liquid_prism/menus'),
          (call) async => 'iOS 27.2',
        )
        ..setMockStreamHandler(
          SystemChromeListener.channel,
          MockStreamHandler.inline(
            onListen: (_, sink) {
              events = sink;
              sink.success({
                'supported': false,
                'island': [138.5, 14.0, 125.0, 36.5],
              });
            },
          ),
        );
      addTearDown(() {
        unawaited(SystemChromeListener.instance.reset());
        messenger.setMockMethodCallHandler(
          const MethodChannel('liquid_prism/menus'),
          null,
        );
      });
      unawaited(SystemChromeListener.instance.reset());
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: PrismScaffold(
            toolbar: [
              PrismToolbarItem(
                label: 'More',
                icon: const Icon(CupertinoIcons.ellipsis),
                onPressed: () {},
              ),
            ],
            scrollController: controller,
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
          ),
        ),
      );
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      final blur = find.byType(PrismEdgeBlur);
      expect(tester.getRect(blur).bottom, 50.5 + 14);

      Future<void> report(Map<String, Object?> chrome) async {
        events.success({'supported': false, ...chrome});
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      await report({
        'island': [138.0, 11.0, 126.0, 37.0],
      });
      expect(tester.getRect(blur).bottom, 48 + 11);
      await report({});
      expect(
        tester.getRect(blur).bottom,
        62,
        reason: 'without an island the status bar ends it',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await report({
        'island': [138.5, 14.0, 125.0, 36.5],
      });
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets('sheets keep only the full edge', (tester) async {
    phone(tester);
    for (final titled in [true, false]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: PrismScaffold(
            sheet: true,
            title: titled ? const Text('Sheet') : null,
            toolbar: [
              PrismToolbarItem(
                label: 'Done',
                icon: const Icon(CupertinoIcons.check_mark),
                onPressed: () {},
              ),
            ],
            scrollController: controller,
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
          ),
        ),
      );
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      expect(
        find.byType(PrismEdgeBlur),
        titled ? findsOneWidget : findsNothing,
        reason: 'titled $titled',
      );
    }
  });
  testWidgets(
    'a tab shell without top chrome leaves the top edge to its pages',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1024, 768)
        ..padding = const FakeViewPadding(top: 24, bottom: 20)
        ..viewPadding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.reset);
      const page = Key('page');
      for (final (name, placement, shellAction) in [
        ('bottom tabs', PrismTabBarPlacement.automatic, false),
        ('a sidebar', PrismTabBarPlacement.sidebar, false),

        (
          'bottom tabs with a shell action',
          PrismTabBarPlacement.automatic,
          true,
        ),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          CupertinoApp(
            home: PrismScaffold(
              tabBarPlacement: placement,
              toolbar: [
                if (shellAction)
                  PrismToolbarItem(
                    label: 'Compose',
                    icon: const Icon(CupertinoIcons.pencil),
                    onPressed: () {},
                  ),
              ],
              tabBar: PrismTabBar(
                tabs: const [
                  PrismTab(icon: Icon(CupertinoIcons.house), label: 'Home'),
                  PrismTab(icon: Icon(CupertinoIcons.search), label: 'Search'),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              body: PrismScaffold(
                key: page,
                title: const Text('Home'),
                scrollController: controller,
                slivers: const [
                  SliverToBoxAdapter(child: SizedBox(height: 3000)),
                ],
              ),
            ),
          ),
        );
        controller.jumpTo(100);
        await tester.pumpAndSettle();
        Finder topEdges(Finder within) => find.descendant(
          of: within,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is PrismScrollEdge &&
                widget.edge == PrismEdge.top &&
                widget.progress > 0,
          ),
        );
        expect(
          topEdges(find.byKey(page)),
          findsOneWidget,
          reason: '$name: the page draws its own',
        );
        expect(
          topEdges(find.byType(CupertinoApp)),
          shellAction ? findsNWidgets(2) : findsOneWidget,
          reason: name,
        );
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  for (final hard in [false, true]) {
    testWidgets(
      'a bar hidden on scroll down keeps the compact edge until a reveal grows '
      'it back${hard ? ', hard style' : ''}',
      (tester) async {
        phone(tester);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          CupertinoApp(
            home: PrismScaffold(
              title: const Text('Page'),
              scrollController: controller,
              scrollEdgeStyle: hard
                  ? const PrismScrollEdgeStyle(
                      variant: PrismScrollEdgeVariant.hard,
                    )
                  : null,
              navigationBarStyle: const PrismNavigationBarStyle(
                minimizationBehavior: PrismMinimizationBehavior.onScrollDown,
              ),
              slivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 3000)),
              ],
            ),
          ),
        );
        final blur = find.byType(PrismEdgeBlur);
        PrismEdgeBlurStrip spec() =>
            tester.widget<PrismEdgeBlur>(blur).edges.single;
        void compact(String when) {
          expect(tester.getRect(blur).bottom, 62, reason: when);
          expect(spec().fadeFloor, isNull, reason: '$when: soft');
        }

        controller.jumpTo(400);
        await tester.pumpAndSettle();
        compact('hidden');

        controller.jumpTo(399);
        await tester.pump();
        if (!hard) {
          expect(
            tester.getRect(blur).bottom,
            inInclusiveRange(62, 64),
            reason: 'a reveal starts from the compact edge',
          );
        }

        controller.jumpTo(200);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(blur).bottom,
          hard ? 62 + 44 + 10 : 62 + 44 + PrismScrollEdgeStyle.defaultExtension,
          reason: 'revealed: the full edge',
        );
        expect(spec().fadeFloor, hard ? 1 : isNull, reason: 'revealed style');

        controller.jumpTo(800);
        await tester.pumpAndSettle();
        compact('hidden again');
      },
    );
  }
  testWidgets('a plain large-title-only page retains its top edge', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      const CupertinoApp(
        home: PrismScaffold(
          largeTitle: Text('Applications'),
          slivers: [SliverToBoxAdapter(child: SizedBox(height: 2000))],
        ),
      ),
    );
    expect(find.byType(PrismScrollEdge), findsOneWidget);
  });
  testWidgets(
    'the scaffold draws the effect under its top bar while scrolled',
    (tester) async {
      phone(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          controller: controller,
          toolbar: [
            PrismToolbarItem(
              icon: const Icon(CupertinoIcons.star),
              label: 'Star',
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(find.byType(PrismScrollEdge), findsOneWidget);
      expect(
        find.byType(PrismEdgeBlur),
        findsNothing,
        reason: 'nothing paints at rest',
      );
      final effect = tester.getRect(find.byType(PrismScrollEdge));
      expect(effect.top, 0);
      expect(effect.height, 62 + PrismScaffold.topBarHeight);
      expect(effect.width, 402);

      controller.jumpTo(8);
      await tester.pump();
      final blur = find.byType(PrismEdgeBlur);
      expect(blur, findsOneWidget);
      final spec = tester.widget<PrismEdgeBlur>(blur).edges.single;
      expect(spec.sigma, PrismScrollEdgeStyle.defaultSigma / 2);
      expect(spec.fadeColor, const Color(0xFF101010));
      expect(spec.extent, 62 + 44 + PrismScrollEdgeStyle.defaultExtension);

      controller.jumpTo(100);
      await tester.pump();
      expect(
        tester.widget<PrismEdgeBlur>(blur).edges.single.sigma,
        PrismScrollEdgeStyle.defaultSigma,
      );

      final order = [
        find.byKey(_body),
        find.byType(PrismScrollEdge),
        find.byType(PrismToolbar),
      ].map((finder) => tester.getRect(finder)).toList();
      expect(order, hasLength(3));
      final scaffold = tester.element(find.byType(PrismScaffold));
      final painted = <Type>[];
      scaffold.visitChildren((child) {
        void visit(Element element) {
          final widget = element.widget;
          if (widget is PrismScrollEdge) {
            painted.add(PrismScrollEdge);
          }
          if (widget is PrismToolbar) {
            painted.add(PrismToolbar);
          }
          if (widget.key == _body) painted.add(ListView);
          element.visitChildren(visit);
        }

        visit(child);
      });
      expect(painted, [ListView, PrismScrollEdge, PrismToolbar]);

      controller.jumpTo(0);
      await tester.pump();
      expect(blur, findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('no top bar or an opt-out leaves the body alone', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller: controller, withTitle: false));
    expect(find.byType(PrismScrollEdge), findsNothing);

    await tester.pumpWidget(
      app(
        controller: controller,
        scrollEdge: false,
        leading: PrismToolbar.group(
          size: PrismToolbarSize.navigation,
          items: [
            PrismToolbarItem(
              icon: const Icon(CupertinoIcons.back),
              label: 'Back',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    controller.jumpTo(100);
    await tester.pump();
    expect(find.byType(PrismScrollEdge), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('without a background the effect blurs only', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        controller: controller,
        background: null,
        leading: const SizedBox(width: 44, height: 44),
      ),
    );
    controller.jumpTo(100);
    await tester.pump();
    final spec = tester
        .widget<PrismEdgeBlur>(find.byType(PrismEdgeBlur))
        .edges
        .single;
    expect(spec.fadeColor, isNull);
    expect(spec.sigma, PrismScrollEdgeStyle.defaultSigma);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

void accessoryTests() {
  testWidgets('an accessory sits under the bar inside the effect', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(402, 874)
      ..padding = const FakeViewPadding(top: 62, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: PrismScaffold(
          title: const Text('Page'),
          backgroundColor: const Color(0xFF101010),
          scrollEdgeStyle: const PrismScrollEdgeStyle(
            variant: PrismScrollEdgeVariant.hard,
          ),
          leading: const SizedBox(width: 44, height: 44),
          accessory: const PreferredSize(
            preferredSize: Size.fromHeight(36),
            child: SizedBox(key: Key('tabs'), height: 36),
          ),
          body: ListView.builder(
            key: _body,
            controller: controller,
            itemCount: 60,
            itemBuilder: (context, index) =>
                SizedBox(height: 44, child: Text('Row $index')),
          ),
        ),
      ),
    );
    final tabs = tester.getRect(find.byKey(const Key('tabs')));
    expect(tabs.top, 62 + 44);
    expect(tabs.height, 36);
    expect(tabs.width, 402);
    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.top, 62 + 44 + 36 + PrismScaffold.topBarClearance);

    controller.jumpTo(100);
    await tester.pump();
    final blur = find.byType(PrismEdgeBlur);
    expect(tester.getSize(blur), const Size(402, 62 + 44 + 36));
    final spec = tester.widget<PrismEdgeBlur>(blur).edges.single;
    expect(spec.extent, 62 + 44 + 36, reason: 'hard: no reach past the bar');
    expect(spec.floor, PrismScrollEdgeStyle.defaultHardFloor);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('the fade gradient keeps its floor at the far end', () {
    final gradient = PrismEdgeFade.gradient(
      color: const Color(0xFFFFFFFF),
      floor: .4,
      opacity: .5,
    );
    expect(gradient.colors.first.a, closeTo(.5, 1e-6));
    expect(gradient.colors.last.a, closeTo(.2, 1e-6));
  });
}
