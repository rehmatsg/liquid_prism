import 'dart:async';
import 'dart:ui' show DisplayFeatureType, SemanticsAction, SemanticsActionEvent;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/navigation/prism_sidebar.dart';
import 'package:liquid_prism/src/navigation/prism_system_chrome.dart'
    show SystemChromeListener;
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';

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
  group('PrismChromePlacement.resolve', () {
    test('moves chrome into the deep side of an asymmetric safe area', () {
      expect(
        PrismChromePlacement.resolve(const EdgeInsets.only(right: 84)),
        PrismChromePlacement.rightRail,
      );
      expect(
        PrismChromePlacement.resolve(const EdgeInsets.only(left: 84)),
        PrismChromePlacement.leftRail,
      );
    });

    test(
      'keeps the bottom bar for portrait and symmetric landscape insets',
      () {
        expect(
          PrismChromePlacement.resolve(
            const EdgeInsets.only(top: 62, bottom: 34),
          ),
          PrismChromePlacement.bottom,
        );
        expect(
          PrismChromePlacement.resolve(
            const EdgeInsets.only(left: 62, right: 62, bottom: 21),
          ),
          PrismChromePlacement.bottom,
        );
        expect(
          PrismChromePlacement.resolve(const EdgeInsets.only(right: 20)),
          PrismChromePlacement.bottom,
        );
      },
    );
  });

  testWidgets('iPhone Duo: toolbar and icon-only tabs stack in the rail', (
    tester,
  ) async {
    window(tester, duo);
    await tester.pumpWidget(const _App());

    final bar = tester.getRect(find.byType(PrismTabBar));

    expect(bar, const Rect.fromLTWH(394, 678 - 24 - 162, 48, 162));
    expect(find.text('Home'), findsNothing, reason: 'the rail is icon-only');
    expect(find.bySemanticsLabel('Home'), findsOneWidget);

    final toolbar = tester.getRect(find.byType(PrismToolbar));
    expect(toolbar, const Rect.fromLTWH(394, 170, 48, 100));

    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.right, 84);
    expect(padding.top, 24, reason: 'the status bar moves to the rail');
    expect(
      PrismScaffold.placementOf(tester.element(find.byKey(_body))),
      PrismChromePlacement.rightRail,
    );
  });

  group('toolbar items on a rail split by axis, as native bars do', () {
    const icon = Icon(CupertinoIcons.star);
    Widget app(List<PrismToolbarContent> toolbar, {Set<PrismEdge>? hidden}) =>
        CupertinoApp(
          home: PrismScaffold(
            title: const Text('Library'),
            toolbar: toolbar,
            hiddenScrollEdges: hidden ?? const {},
            body: const SizedBox.expand(key: _body),
          ),
        );
    bool inRail(Rect rect) => rect.left >= 394 && rect.right <= 442;

    testWidgets('text items stay in the top bar; icons take the rail', (
      tester,
    ) async {
      window(tester, duo);
      await tester.pumpWidget(
        app([
          PrismToolbarItem(
            label: 'Select All',
            onPressed: () {},
            placement: PrismToolbarPlacement.topLeading,
          ),
          PrismToolbarItem(label: 'Done', onPressed: () {}),
          PrismToolbarItem(icon: icon, label: 'Share', onPressed: () {}),
        ]),
      );

      final selectAll = tester.getRect(find.text('Select All'));
      final done = tester.getRect(find.text('Done'));
      expect(inRail(selectAll), isFalse);
      expect(inRail(done), isFalse);
      expect(selectAll.center.dx, lessThan(done.center.dx));
      expect(selectAll.top, lessThan(100), reason: 'in the top bar row');
      expect(done.top, lessThan(100), reason: 'in the top bar row');
      expect(
        inRail(tester.getRect(find.bySemanticsLabel('Share'))),
        isTrue,
        reason: 'an icon item moves into the rail',
      );
    });

    testWidgets('bottom icons sit at the rail bottom; text stays below the '
        'content, and iPhone keeps both in the bottom bar', (tester) async {
      const count = Key('count');
      final toolbar = [
        const PrismToolbarItem.custom(
          placement: PrismToolbarPlacement.bottom,
          child: Text('2 Selected', key: count),
        ),
        PrismToolbarItem(
          icon: icon,
          label: 'Delete',
          onPressed: () {},
          placement: PrismToolbarPlacement.bottomTrailing,
        ),
      ];

      window(tester, duo);
      await tester.pumpWidget(app(toolbar));
      final delete = tester.getRect(find.bySemanticsLabel('Delete'));
      expect(inRail(delete), isTrue);
      expect(delete.bottom, greaterThan(678 / 2), reason: "the rail's bottom");
      final label = tester.getRect(find.byKey(count));
      expect(inRail(label), isFalse);
      expect(label.top, greaterThan(678 / 2), reason: 'along the bottom');

      window(tester, phone);
      await tester.pumpWidget(app(toolbar));

      await tester.pump(const Duration(seconds: 1));
      final phoneDelete = tester.getRect(find.bySemanticsLabel('Delete'));
      expect(phoneDelete.top, greaterThan(874 - 120));
      expect(phoneDelete.right, greaterThan(402 - 80), reason: 'trailing');
    });

    testWidgets('iPhone: a bottom center item sits on the window center, and '
        'edge items keep clear of the corners', (tester) async {
      const count = Key('count');
      window(tester, phone);
      await tester.pumpWidget(
        app([
          const PrismToolbarItem.custom(
            placement: PrismToolbarPlacement.bottom,
            child: Text('2 Selected', key: count),
          ),
          PrismToolbarItem(
            icon: icon,
            label: 'Delete',
            onPressed: () {},
            placement: PrismToolbarPlacement.bottomTrailing,
          ),
          PrismToolbarItem(
            icon: icon,
            label: 'Share',
            onPressed: () {},
            placement: PrismToolbarPlacement.bottomLeading,
          ),
        ]),
      );

      expect(tester.getCenter(find.byKey(count)).dx, closeTo(402 / 2, 0.5));
      final delete = tester.getRect(find.bySemanticsLabel('Delete'));
      final share = tester.getRect(find.bySemanticsLabel('Share'));
      expect(402 - delete.right, greaterThanOrEqualTo(24));
      expect(share.left, greaterThanOrEqualTo(24));
    });

    testWidgets('an axis behavior overrides the inference', (tester) async {
      window(tester, duo);
      await tester.pumpWidget(
        app([
          PrismToolbarItem(
            icon: icon,
            label: 'Edit',
            onPressed: () {},
            axisBehavior: PrismToolbarAxisBehavior.horizontalOnly,
          ),
          const PrismToolbarItem.custom(
            axisBehavior: PrismToolbarAxisBehavior.verticalPreferred,
            child: SizedBox(key: Key('custom'), width: 30, height: 30),
          ),
        ]),
      );

      expect(inRail(tester.getRect(find.bySemanticsLabel('Edit'))), isFalse);
      expect(inRail(tester.getRect(find.byKey(const Key('custom')))), isTrue);
    });

    testWidgets('a hidden edge drops only that scroll edge', (tester) async {
      window(tester, phone);
      final toolbar = [
        PrismToolbarItem(
          icon: icon,
          label: 'Delete',
          onPressed: () {},
          placement: PrismToolbarPlacement.bottomTrailing,
        ),
      ];
      await tester.pumpWidget(app(toolbar));
      final both = find.byType(PrismScrollEdge).evaluate().length;

      await tester.pumpWidget(app(toolbar, hidden: const {PrismEdge.bottom}));
      expect(find.byType(PrismScrollEdge), findsNWidgets(both - 1));

      await tester.pumpWidget(
        app(toolbar, hidden: const {PrismEdge.top, PrismEdge.bottom}),
      );
      expect(find.byType(PrismScrollEdge), findsNWidgets(both - 2));
    });
  });

  testWidgets('iPhone Duo: a back button heads the rail, above the toolbar', (
    tester,
  ) async {
    window(tester, duo);
    const back = Key('back');
    Widget app({required bool leading}) => CupertinoApp(
      home: PrismScaffold(
        leading: leading
            ? const SizedBox(key: back, width: 48, height: 48)
            : null,
        toolbar: [
          for (final label in ['Share', 'More'])
            PrismToolbarItem(
              icon: const Icon(CupertinoIcons.star),
              label: label,
              onPressed: () {},
            ),
        ],
        body: const SizedBox.expand(key: _body),
      ),
    );
    await tester.pumpWidget(app(leading: true));

    expect(
      tester.getRect(find.byKey(back)),
      const Rect.fromLTWH(394, 170, 48, 48),
    );
    expect(
      tester.getRect(find.byType(PrismToolbar)),
      const Rect.fromLTWH(394, 230, 48, 100),
    );

    expect(MediaQuery.paddingOf(tester.element(find.byKey(_body))).top, 24);

    window(tester, phone);
    await tester.pumpWidget(app(leading: true));
    final rect = tester.getRect(find.byKey(back));
    expect(rect.left, 16);
    expect(rect.top, lessThan(120));
  });

  group('PrismTitle', () {
    test('local style wins per field over the theme, keeping zero', () {
      const theme = PrismTitleStyle(avatarSize: 40, avatarOverlap: 4);
      final style = theme.merge(const PrismTitleStyle(avatarOverlap: 0));
      expect(style.resolvedAvatarSize, 40);
      expect(style.resolvedAvatarOverlap, 0);
      expect(style.resolvedMinHeight, 38);
      const title = PrismTitle(avatar: SizedBox(), child: Text('A'));

      expect(PrismTitle.extentOf(title, style, 20.4), closeTo(78.4, 1e-9));
      expect(
        const PrismNavigationBarStyle(titleCapsule: theme)
            .merge(
              const PrismNavigationBarStyle(
                titleCapsule: PrismTitleStyle(avatarSize: 50),
              ),
            )
            .titleCapsule,
        const PrismTitleStyle(avatarSize: 50, avatarOverlap: 4),
      );
    });

    const avatar = Key('avatar'),
        inline = Key('inline'),
        invite = Key('invite');
    var taps = 0;
    Widget app({required bool withAvatar, Widget? trailing, Widget? leading}) =>
        CupertinoApp(
          home: PrismScaffold(
            leading: leading,
            title: PrismTitle(
              avatar: withAvatar
                  ? const ColoredBox(key: avatar, color: Color(0xFFEE8866))
                  : null,
              leading: withAvatar
                  ? null
                  : const ColoredBox(key: inline, color: Color(0xFFEE8866)),
              onPressed: () => taps++,
              child: const Text('Friday'),
            ),
            trailing: trailing,
            toolbar: [
              PrismToolbarItem(
                icon: const Icon(CupertinoIcons.phone),
                label: 'Call',
                onPressed: () {},
              ),
            ],
            body: const SizedBox.expand(key: _body),
          ),
        );

    testWidgets(
      'an avatar heads the bar on iPhone Duo; the capsule tucks under',
      (tester) async {
        window(tester, duo);
        await tester.pumpWidget(app(withAvatar: true));

        final face = tester.getRect(find.byKey(avatar));
        expect(face, const Rect.fromLTWH(191 - 32, 24, 64, 64));
        final title = tester.getRect(find.byType(PrismTitle));
        expect(title.top, 24);
        expect(title.bottom, closeTo(120.4, .01));
        expect(title.center.dx, closeTo(191, .01));

        expect(
          MediaQuery.paddingOf(tester.element(find.byKey(_body))).top,
          closeTo(120.4 + 16, .01),
        );
        await tester.tap(find.text('Friday'));
        expect(taps, 1);
        expect(find.bySemanticsLabel('Friday'), findsOneWidget);
      },
    );

    testWidgets('an inline leading and a text button share the top row', (
      tester,
    ) async {
      window(tester, duo);
      await tester.pumpWidget(
        app(
          withAvatar: false,
          trailing: PrismButton(
            key: invite,
            label: 'Invite',
            onPressed: () {},
            child: const Text('Invite'),
          ),
        ),
      );
      final faceBox = tester.renderObject<RenderBox>(find.byKey(inline));
      final face = Rect.fromPoints(
        faceBox.localToGlobal(Offset.zero),
        faceBox.localToGlobal(faceBox.size.bottomRight(Offset.zero)),
      );
      expect(face.size, const Size(22, 22));
      final capsule = tester.getRect(find.byType(PrismTitle));
      expect(
        capsule.height,
        tester.getSize(find.byType(PrismToolbar)).width,
        reason: 'the inline title matches the rail icon buttons',
      );
      expect(face.center.dy, closeTo(capsule.center.dy, .01));
      expect(
        face.left - capsule.left,
        closeTo(face.top - capsule.top, .01),
        reason: 'a circle sits as far from the start as from the top',
      );

      expect(capsule.center.dx, closeTo(191, .01));

      final button = tester.getRect(find.byKey(invite));
      expect(button.right, 382);
      expect(button.center.dy, closeTo(capsule.center.dy, .01));
      expect(tester.getRect(find.byType(PrismToolbar)).left, 394);
    });

    testWidgets('a leading corner radius sets its start unless padding is '
        'explicit', (tester) async {
      window(tester, duo);
      Future<({double start, double height})> leading(
        PrismTitleStyle style,
      ) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: PrismScaffold(
              title: PrismTitle(
                style: style,
                leading: const ColoredBox(
                  key: inline,
                  color: Color(0xFFEE8866),
                ),
                child: const Text('Acme'),
              ),
              body: const SizedBox.expand(),
            ),
          ),
        );
        final capsule = tester.getRect(find.byType(PrismTitle));
        return (
          start: tester.getRect(find.byKey(inline)).left - capsule.left,
          height: capsule.height,
        );
      }

      final square = await leading(
        const PrismTitleStyle(leadingSize: 32, leadingCornerRadius: 7),
      );
      expect(square.start, closeTo(square.height / 2 - 7, .01));
      final explicit = await leading(
        const PrismTitleStyle(
          leadingSize: 32,
          leadingCornerRadius: 7,
          leadingPadding: EdgeInsetsDirectional.fromSTEB(15, 6, 10, 6),
        ),
      );
      expect(explicit.start, 15);
    });

    testWidgets('a capsule title centres its subtitle beside controls', (
      tester,
    ) async {
      window(tester, phone);
      await tester.pumpWidget(
        CupertinoApp(
          home: PrismScaffold(
            title: const PrismTitle(child: Text('Book Club')),
            subtitle: const Text('5 members'),
            toolbar: [
              PrismToolbarItem(
                icon: const Icon(CupertinoIcons.ellipsis),
                label: 'More',
                onPressed: () {},
              ),
            ],
            body: const SizedBox.expand(key: _body),
          ),
        ),
      );
      final capsule = tester.getRect(find.byType(PrismTitle));
      final subtitle = tester.getRect(find.text('5 members'));
      expect(subtitle.center.dx, closeTo(capsule.center.dx, .01));
    });

    testWidgets('on iPhone the controls keep their row above a tall title', (
      tester,
    ) async {
      window(tester, phone);
      const back = Key('back');
      await tester.pumpWidget(
        app(
          withAvatar: true,
          leading: const SizedBox(key: back, width: 44, height: 44),
        ),
      );
      final title = tester.getRect(find.byType(PrismTitle));
      final control = tester.getRect(find.byKey(back));
      expect(title.height, closeTo(96, .5));
      expect(control.top, lessThan(title.top + 20));
      expect(
        tester.getRect(find.byType(PrismToolbar)).center.dy,
        closeTo(control.center.dy, .01),
      );
    });
  });

  testWidgets(
    'on iOS a bottom bar sits on the tab bar line, not above the inset',
    (tester) async {
      window(tester, phone);
      const bar = Key('bar');
      await tester.pumpWidget(
        const CupertinoApp(
          home: PrismScaffold(
            bottomBar: SizedBox(key: bar, width: 200, height: 48),
            body: SizedBox.expand(key: _body),
          ),
        ),
      );

      expect(tester.getRect(find.byKey(bar)).bottom, 874 - 21);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('unfolded iPhone Duo keeps the rail, toolbar sit higher', (
    tester,
  ) async {
    window(tester, duoUnfolded);
    await tester.pumpWidget(const _App());

    expect(
      tester.getRect(find.byType(PrismTabBar)),
      const Rect.fromLTWH(879, 669 - 24 - 162, 48, 162),
    );
    expect(
      tester.getRect(find.byType(PrismToolbar)),
      const Rect.fromLTWH(879, 120, 48, 100),
    );
    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.right, 84);
  });

  testWidgets('iPhone: top-trailing toolbar and a floating bottom tab bar', (
    tester,
  ) async {
    window(tester, phone);
    await tester.pumpWidget(const _App());

    final bar = tester.getRect(find.byType(PrismTabBar));
    expect(bar.bottom, 874 - 21);
    expect(bar.center.dx, 201);
    expect(find.text('Home'), findsOneWidget);

    final toolbar = tester.getRect(find.byType(PrismToolbar));
    expect(toolbar.right, 402 - 16);
    expect(toolbar.top, 62);
    expect(toolbar.height, 44);

    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.top, 62 + 44 + PrismScaffold.topBarClearance);
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
    final bar = tester.getRect(find.byType(PrismTabBar));
    expect(bar.width, 48);
    final tab = tester.widget<PrismTabBar>(find.byType(PrismTabBar));
    expect(tab.selectedIndex, 2);

    await tester.tapAt(Offset(bar.center.dx, bar.top + 6 + 75));
    await tester.pumpAndSettle();
    expect(selected, 1);

    window(tester, phone);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(PrismTabBar)).bottom, 874 - 21);
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
            builder: (context, setState) => PrismTabBar(
              axis: Axis.vertical,
              selectedIndex: selected,
              onSelected: (index) => setState(() => selected = index),
              tabs: [
                for (final tab in _tabs)
                  PrismTab(
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
    final bar = tester.getRect(find.byType(PrismTabBar));
    expect(bar.size, const Size(48, 162));

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
        tabBar: PrismTabBar(
          axis: Axis.horizontal,
          selectedIndex: 0,
          onSelected: (_) {},
          tabs: _tabs,
        ),
      ),
    );
    final bar = tester.getRect(find.byType(PrismTabBar));
    expect(bar.height, lessThan(bar.width));
  });

  testWidgets('a vertical toolbar group transposes the measured capsule', (
    tester,
  ) async {
    Widget group(Axis axis) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: PrismToolbar.group(
          axis: axis,
          items: [
            for (final label in ['Share', 'More'])
              PrismToolbarItem(
                icon: const Icon(CupertinoIcons.star),
                label: label,
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(group(Axis.horizontal));
    final row = tester.getSize(find.byType(PrismToolbar));
    await tester.pumpWidget(group(Axis.vertical));
    final column = tester.getSize(find.byType(PrismToolbar));
    expect(column, row.flipped);
    expect(column, const Size(48, 100));
  });

  testWidgets('keyboard hides only the bottom tab bar', (tester) async {
    window(tester, phone);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const _App());
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(find.byType(PrismTabBar), findsNothing);
    final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
    expect(padding.bottom, 300);

    window(tester, duo);
    await tester.pump();
    expect(find.byType(PrismTabBar), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('iOS 27.1 system chrome', () {
    Future<void> report(
      WidgetTester tester,
      Map<String, Object?> chrome, {
      void Function(void Function(Object?))? captureEvents,
    }) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('liquid_prism/menus'),
        (call) async => 'iOS 27.1',
      );
      messenger.setMockStreamHandler(
        SystemChromeListener.channel,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            captureEvents?.call(sink.success);
            sink.success({'supported': true, ...chrome});
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
    }

    testWidgets('external overlays follow native rail and viewport changes', (
      tester,
    ) async {
      window(tester, (
        size: const Size(455.5, 669),
        padding: const FakeViewPadding(bottom: 34),
      ));
      late void Function(Object?) emit;
      await report(tester, {
        'verticalBarEdge': 'left',
      }, captureEvents: (send) => emit = send);
      await tester.pumpWidget(const _ContentAlignmentApp());
      await tester.pump();
      void aligned() {
        final content = tester.getRect(find.byKey(_contentArea));
        final overlay = tester.getRect(find.byKey(_overlayArea));
        expect(overlay.left, closeTo(content.left, .01));
        expect(overlay.right, closeTo(content.right, .01));
        expect(
          tester.getCenter(find.byKey(_overlayHandle)).dx,
          closeTo(content.center.dx, .01),
        );
      }

      aligned();
      final leftRailCenter = tester.getCenter(find.byKey(_overlayHandle)).dx;
      emit({'supported': true, 'verticalBarEdge': 'right'});
      await tester.pumpAndSettle();
      aligned();
      expect(
        tester.getCenter(find.byKey(_overlayHandle)).dx,
        lessThan(leftRailCenter),
      );

      tester.view
        ..physicalSize = const Size(600, 669)
        ..padding = const FakeViewPadding(left: 120, bottom: 34)
        ..viewPadding = const FakeViewPadding(left: 120, bottom: 34);
      emit({'supported': true, 'verticalBarEdge': 'left'});
      await tester.pumpAndSettle();
      aligned();
      expect(tester.getRect(find.byKey(_overlayArea)).left, 120);
      expect(tester.getRect(find.byKey(_overlayArea)).right, 600);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'overlay placement overrides inherited chrome and native traits',
      (tester) async {
        window(tester, (
          size: const Size(455.5, 669),
          padding: const FakeViewPadding(bottom: 34),
        ));
        await report(tester, {'verticalBarEdge': 'right'});
        for (final row in [
          (
            name: 'nearest scaffold wins over native right rail',
            placement: PrismChromePlacement.leftRail,
            scope: null,
            explicit: null,
          ),
          (
            name: 'explicit right wins over inherited left rail',
            placement: PrismChromePlacement.rightRail,
            scope: PrismChromePlacement.leftRail,
            explicit: PrismChromePlacement.rightRail,
          ),
          (
            name: 'explicit bottom wins over both rail sources',
            placement: PrismChromePlacement.bottom,
            scope: PrismChromePlacement.leftRail,
            explicit: PrismChromePlacement.bottom,
          ),
        ]) {
          await tester.pumpWidget(
            _ContentAlignmentApp(
              placement: row.placement,
              overlayScope: row.scope,
              overlayPlacement: row.explicit,
              overlayInBody: true,
            ),
          );
          await tester.pump();
          final content = tester.getRect(find.byKey(_contentArea));
          final overlay = tester.getRect(find.byKey(_overlayArea));
          expect(overlay.left, closeTo(content.left, .01), reason: row.name);
          expect(overlay.right, closeTo(content.right, .01), reason: row.name);
          expect(
            tester.getCenter(find.byKey(_overlayHandle)).dx,
            closeTo(content.center.dx, .01),
            reason: row.name,
          );
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'overlay insets use physical padding rather than body coverage',
      (tester) async {
        await report(tester, {'supported': false});
        for (final device in [
          (
            size: duo.size,
            padding: const FakeViewPadding(right: 60, bottom: 34),
          ),
          phone,
        ]) {
          window(tester, device);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpWidget(
            const _ContentAlignmentApp(overlayInBody: true),
          );
          await tester.pump();
          final overlay = tester.getRect(find.byKey(_overlayArea));
          final content = tester.getRect(find.byKey(_contentArea));
          final physical = MediaQuery.viewPaddingOf(
            tester.element(find.byKey(_overlayHandle)),
          );
          expect(overlay.top, physical.top);
          expect(overlay.bottom, device.size.height - physical.bottom);
          expect(overlay.left, content.left);
          expect(overlay.right, content.right);
          expect(content.top, greaterThan(overlay.top));
          expect(content.bottom, lessThan(overlay.bottom));
          expect(
            tester.getCenter(find.byKey(_overlayHandle)).dx,
            closeTo(content.center.dx, .01),
          );
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('device glass settings arrive even without the rail APIs', (
      tester,
    ) async {
      await report(tester, {
        'supported': false,
        'glassTintAmount': .4,
        'reduceTransparency': true,
      });
      await tester.pumpWidget(const _App());
      await tester.pump();
      expect(PrismSystemChrome.deviceGlassTintAmount.value, .4);
      expect(PrismSystemChrome.reduceTransparency.value, isTrue);
      expect(PrismSystemChrome.listenable.value, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the vertical bar edge wins over safe-area insets', (
      tester,
    ) async {
      window(tester, (
        size: const Size(475, 669),
        padding: const FakeViewPadding(left: 84, bottom: 34),
      ));
      await report(tester, {'verticalBarEdge': 'left'});
      await tester.pumpWidget(const _App());
      await tester.pump();
      expect(tester.getRect(find.byType(PrismTabBar)).left, 84 - 12 - 48);

      await report(tester, {'verticalBarEdge': null});
      window(tester, duo);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const _App());
      await tester.pump();
      final bar = tester.getRect(find.byType(PrismTabBar));
      expect(bar.width, greaterThan(bar.height));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Split View on the left reserves its own rail strip', (
      tester,
    ) async {
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
      expect(tester.getRect(find.byType(PrismTabBar)).left, 24);
      expect(
        tester.getRect(find.byType(PrismToolbar)).topLeft,
        const Offset(24, 24),
      );
      final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
      expect(padding.left, 84);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('closed landscape stops the rail above the status bar', (
      tester,
    ) async {
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
      expect(tester.getRect(find.byType(PrismTabBar)).bottom, 384);
      expect(tester.getRect(find.byType(PrismToolbar)).top, 24);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a sheet title ignores the window status bar above its route', (
      tester,
    ) async {
      for (final rtl in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        window(tester, (
          size: const Size(669, 951),
          padding: const FakeViewPadding(top: 82, bottom: 34),
        ));
        await report(tester, {
          'verticalBarEdge': null,
          'occlusions': [
            [rtl ? 0.0 : 535.0, 0.0, 134.0, 82.0],
          ],
        });
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          CupertinoApp(
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: PrismScaffold(
                  sheet: true,
                  title: const Text('Preferences'),
                  largeTitle: const Text('Preferences'),
                  scrollController: scroll,
                  toolbar: [
                    PrismToolbarItem(
                      icon: const Icon(CupertinoIcons.ellipsis),
                      label: 'More',
                      onPressed: () {},
                    ),
                  ],
                  slivers: const [
                    SliverToBoxAdapter(child: SizedBox(height: 2000)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        scroll.jumpTo(300);
        await tester.pumpAndSettle();
        final inline = tester.getRect(find.text('Preferences').first);
        expect(inline.center.dx, closeTo(669 / 2, .01));
        expect(inline.center.dy, closeTo(100 + 16 + 44 / 2, .01));
        final toolbar = tester.getRect(find.byType(PrismToolbar));
        expect(toolbar.top, greaterThan(82));
        expect(
          rtl ? toolbar.right : toolbar.left,
          rtl ? lessThan(134) : greaterThan(535),
          reason: 'the window status bar is above the sheet, not beside it',
        );
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'a short inline title stays centered beside a corner status bar',
      (tester) async {
        for (final rtl in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          window(tester, (
            size: const Size(669, 951),
            padding: const FakeViewPadding(
              top: 82,
              left: 24,
              right: 8,
              bottom: 34,
            ),
          ));
          await report(tester, {
            'verticalBarEdge': null,
            'occlusions': [
              [rtl ? 0.0 : 535.0, 0.0, 134.0, 82.0],
            ],
          });
          await tester.pumpWidget(
            CupertinoApp(
              home: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: const PrismScaffold(
                  navigationBarStyle: PrismNavigationBarStyle(
                    titleDisplayMode: PrismTitleDisplayMode.inline,
                    contentPadding: EdgeInsetsDirectional.only(start: 20),
                  ),
                  title: Text('Library'),
                  body: SizedBox.expand(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final contentCenter = (24 + 669 - 8 + (rtl ? -20 : 20)) / 2;
          expect(
            tester.getCenter(find.text('Library')).dx,
            closeTo(contentCenter, .01),
          );
          expect(tester.takeException(), isNull);
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    for (final rtl in [false, true]) {
      testWidgets('a wide centered title stays usable between controls '
          'with a ${rtl ? 'left' : 'right'} corner status bar', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          for (final cornerWidth in [134.0, 120.0]) {
            await tester.pumpWidget(const SizedBox.shrink());
            window(tester, (
              size: const Size(466, 678),
              padding: const FakeViewPadding(top: 82, bottom: 34),
            ));
            await report(tester, {
              'verticalBarEdge': null,
              'occlusions': [
                [rtl ? 0.0 : 466 - cornerWidth, 0.0, cornerWidth, 82.0],
              ],
            });
            const titleKey = Key('wide title');
            const backKey = Key('back control');
            var taps = 0;
            final focus = FocusNode();
            addTearDown(focus.dispose);
            await tester.pumpWidget(
              CupertinoApp(
                home: Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: PrismScaffold(
                    leading: const SizedBox(
                      key: backKey,
                      width: 44,
                      height: 44,
                    ),
                    title: CupertinoButton(
                      padding: EdgeInsets.zero,
                      focusNode: focus,
                      onPressed: () => taps++,
                      child: const SizedBox(
                        key: titleKey,
                        width: 300,
                        height: 44,
                        child: Icon(
                          CupertinoIcons.briefcase,
                          size: 28,
                          semanticLabel: 'Job details',
                        ),
                      ),
                    ),
                    toolbar: [
                      for (final label in ['Save', 'More'])
                        PrismToolbarItem(
                          icon: const Icon(CupertinoIcons.star),
                          label: label,
                          onPressed: () {},
                        ),
                    ],
                    body: const SizedBox.expand(),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final title = tester.getRect(find.byKey(titleKey));
            final back = tester.getRect(find.byKey(backKey));
            final toolbar = tester.getRect(find.byType(PrismToolbar));
            final gap = rtl
                ? back.left - toolbar.right
                : toolbar.left - back.right;
            expect(gap, greaterThan(44));
            expect(
              title.width,
              greaterThan(44),
              reason: 'corner width $cornerWidth',
            );
            expect(title.overlaps(back), isFalse);
            expect(title.overlaps(toolbar), isFalse);
            expect(title.left, greaterThanOrEqualTo(rtl ? cornerWidth : 0));
            expect(
              title.right,
              lessThanOrEqualTo(rtl ? 466 : 466 - cornerWidth),
            );
            await tester.tapAt(title.center);
            await tester.pumpAndSettle();
            expect(taps, 1);
            focus.requestFocus();
            await tester.pump();
            expect(focus.hasFocus, isTrue);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(taps, 2);
            final action = find.bySemanticsLabel('Job details');
            expect(action, findsOneWidget);
            tester.binding.performSemanticsAction(
              SemanticsActionEvent(
                type: SemanticsAction.tap,
                viewId: tester.view.viewId,
                nodeId: tester.getSemantics(action).id,
              ),
            );
            await tester.pumpAndSettle();
            expect(taps, 3);
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }

    testWidgets('a corner status bar shares the top bar row', (tester) async {
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
      final toolbar = tester.getRect(find.byType(PrismToolbar));
      expect(toolbar.right, 535);
      expect(toolbar.top, 24);
      expect(toolbar.height, 48);
      expect(tester.getRect(find.byType(PrismTabBar)).bottom, 951 - 21);
      final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
      expect(padding.top, 24 + 44 + 16);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('rail toolbar start below the reported status bar region', (
      tester,
    ) async {
      window(tester, duoUnfolded);
      await report(tester, {
        'verticalBarEdge': 'right',
        'occlusions': [
          [867.0, 0.0, 84.0, 131.0],

          [677.0, 21.0, 58.0, 37.0],
        ],
      });
      await tester.pumpWidget(const _App());
      await tester.pump();
      expect(tester.getRect(find.byType(PrismToolbar)).top, 131);
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

  testWidgets('a short rail collapses toolbar into one overflow menu', (
    tester,
  ) async {
    window(tester, (
      size: const Size(678, 380),
      padding: const FakeViewPadding(right: 84, bottom: 21),
    ));
    await tester.pumpWidget(const _App());
    final toolbar = tester.widget<PrismToolbar>(find.byType(PrismToolbar));
    final item =
        toolbar.items?.single ?? toolbar.content.single as PrismToolbarItem;
    expect(item.label, 'More');
    expect(item.menu!.children, hasLength(2));
    expect(find.byType(PrismTabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('sidebar placement', () {
    Widget app({
      required ValueChanged<int> onSelected,
      int selected = 0,
      bool reduceMotion = false,
    }) => CupertinoApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: PrismScaffold(
        tabBarPlacement: PrismTabBarPlacement.sidebar,
        tabBar: PrismTabBar(
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

      expect(find.byType(PrismTabBar), findsNothing);
      expect(tester.getRect(find.text('Saved')).left, 20 + 54);
      final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
      expect(padding.left, 280);
      expect(padding.right, 84);

      expect(padding.top, 24 + 48 + 16);

      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(selected, 2);

      await tester.tap(find.bySemanticsLabel('Hide sidebar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final panel = tester.getRect(find.byType(PrismSidebar));
      expect(panel.width, 280);
      expect(panel.left, inExclusiveRange(-280, 0));
      final reflowing = MediaQuery.paddingOf(tester.element(find.byKey(_body)))
          .left;
      expect(reflowing, closeTo(280 + panel.left, .5));

      final entering = find.ancestor(
        of: find.bySemanticsLabel('Show sidebar'),
        matching: find.byType(Transform),
      );
      expect(
        tester.widget<Transform>(entering.first).transform.getMaxScaleOnAxis(),
        greaterThan(1),
      );
      expect(find.text('Saved'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsNothing);
      expect(find.byType(PrismTabBar), findsNothing);
      expect(MediaQuery.paddingOf(tester.element(find.byKey(_body))).left, 0);
      expect(
        tester.getTopLeft(find.bySemanticsLabel('Show sidebar')),
        const Offset(20, 24),
      );
      expect(
        MediaQuery.paddingOf(tester.element(find.byKey(_body))).top,
        24 + 48 + 16,
      );

      await tester.tap(find.bySemanticsLabel('Show sidebar'));
      await tester.pump();

      expect(find.bySemanticsLabel('Show sidebar'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(tester.getRect(find.byType(PrismSidebar)).left, 0);
      expect(MediaQuery.paddingOf(tester.element(find.byKey(_body))).left, 280);
    });

    testWidgets('reduce motion toggles the sidebar without sliding', (
      tester,
    ) async {
      window(tester, duoUnfolded);
      await tester.pumpWidget(app(onSelected: (_) {}, reduceMotion: true));
      await tester.tap(find.bySemanticsLabel('Hide sidebar'));
      await tester.pump();

      expect(find.byType(PrismSidebar), findsNothing);
      expect(MediaQuery.paddingOf(tester.element(find.byKey(_body))).left, 0);
      expect(find.bySemanticsLabel('Show sidebar'), findsOneWidget);
    });

    testWidgets('keeps the tab bar at compact width', (tester) async {
      window(tester, duo);
      await tester.pumpWidget(app(onSelected: (_) {}));
      expect(find.byType(PrismTabBar), findsOneWidget);
      expect(find.bySemanticsLabel('Hide sidebar'), findsNothing);
    });
  });
  group('toolbar in several capsules', () {
    PrismToolbarItem item(String label) => PrismToolbarItem(
      icon: const Icon(CupertinoIcons.star),
      label: label,
      onPressed: () {},
    );
    Widget app(List<PrismToolbarContent> toolbar) => CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: PrismScaffold(
        toolbar: toolbar,
        tabBar: PrismTabBar(selectedIndex: 0, onSelected: (_) {}, tabs: _tabs),
        body: const SizedBox.expand(key: _body),
      ),
    );

    testWidgets('iPhone: separate capsules, trailing, in order', (
      tester,
    ) async {
      window(tester, phone);
      await tester.pumpWidget(
        app([
          PrismToolbarGroup(items: [item('Filter')]),
          PrismToolbarGroup(items: [item('Share'), item('More')]),
        ]),
      );
      await tester.pumpAndSettle();
      final capsules = find.byWidgetPredicate(
        (widget) =>
            widget is RawPrismSurface && widget.role == PrismRole.toolbar,
      );
      expect(capsules, findsNWidgets(2));
      final first = tester.getRect(capsules.first);
      final last = tester.getRect(capsules.last);
      expect(last.right, 402 - 16);
      expect(first.right, lessThan(last.left));
      expect(first.top, 62);
      expect(last.height, 44);
      expect(find.bySemanticsLabel('Filter'), findsOneWidget);
    });

    testWidgets('an empty group keeps the bar and draws nothing', (
      tester,
    ) async {
      window(tester, phone);
      await tester.pumpWidget(
        app([
          const PrismToolbarGroup(items: []),
          PrismToolbarGroup(items: [item('Share')]),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Share'), findsOneWidget);
      final padding = MediaQuery.paddingOf(tester.element(find.byKey(_body)));
      expect(padding.top, 62 + 44 + PrismScaffold.topBarClearance);
    });

    testWidgets('iPhone Duo rail folds groups that do not fit into More', (
      tester,
    ) async {
      window(tester, duo);
      await tester.pumpWidget(
        app([
          PrismToolbarGroup(
            items: [item('Filter'), item('Sort'), item('Group')],
          ),
          PrismToolbarGroup(
            items: [item('Share'), item('Save'), item('More toolbar')],
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('More'), findsOneWidget);
      expect(find.bySemanticsLabel('Filter'), findsNothing);
    });

    testWidgets('a flat list is one capsule; loose items join a capsule', (
      tester,
    ) async {
      window(tester, phone);
      await tester.pumpWidget(app([item('Share'), item('More')]));
      await tester.pumpAndSettle();
      final capsules = find.byWidgetPredicate(
        (widget) =>
            widget is RawPrismSurface && widget.role == PrismRole.toolbar,
      );
      expect(capsules, findsOneWidget);

      await tester.pumpWidget(
        app([
          item('Filter'),
          item('Sort'),
          PrismToolbarGroup(items: [item('Share'), item('More')]),
        ]),
      );
      await tester.pumpAndSettle();
      expect(capsules, findsNWidgets(2));
      final first = tester.getRect(capsules.first);
      final filter = tester.getCenter(find.bySemanticsLabel('Filter'));
      final sort = tester.getCenter(find.bySemanticsLabel('Sort'));
      expect(first.contains(filter) && first.contains(sort), isTrue);
    });
  });
}

const _body = ValueKey('body');
const _tabs = [
  PrismTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
  PrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
  PrismTab(label: 'Search', icon: Icon(CupertinoIcons.search)),
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
    home: PrismScaffold(
      toolbar: [
        for (final label in ['Share', 'More'])
          PrismToolbarItem(
            icon: const Icon(CupertinoIcons.star),
            label: label,
            onPressed: () {},
          ),
      ],
      tabBar:
          tabBar ??
          PrismTabBar(
            selectedIndex: selected,
            onSelected: onSelected ?? (_) {},
            tabs: _tabs,
          ),
      body: const SizedBox.expand(key: _body),
    ),
  );
}

const _contentArea = Key('content area');
const _overlayArea = Key('overlay area');
const _overlayHandle = Key('overlay handle');

class _ContentAlignmentApp extends StatelessWidget {
  const _ContentAlignmentApp({
    this.placement,
    this.overlayScope,
    this.overlayPlacement,
    this.overlayInBody = false,
  });

  final PrismChromePlacement? placement;
  final PrismChromePlacement? overlayScope;
  final PrismChromePlacement? overlayPlacement;
  final bool overlayInBody;

  Widget _overlay() {
    final overlay = Builder(
      builder: (context) => Padding(
        padding: PrismScaffold.contentInsetsOf(
          context,
          placement: overlayPlacement,
        ),
        child: const SizedBox.expand(
          key: _overlayArea,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(key: _overlayHandle, width: 36, height: 5),
          ),
        ),
      ),
    );
    return Positioned.fill(child: overlay);
  }

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: PrismSystemChrome(
      child: Stack(
        children: [
          PrismScaffold(
            placement: placement,
            title: const Text('Content'),
            body: Builder(
              builder: (context) => Stack(
                children: [
                  Padding(
                    padding: MediaQuery.paddingOf(context),
                    child: const SizedBox.expand(key: _contentArea),
                  ),
                  if (overlayInBody && overlayScope == null) _overlay(),
                ],
              ),
            ),
          ),
          if (overlayScope != null)
            Positioned.fill(
              child: PrismScaffold(
                placement: overlayScope,
                body: Stack(children: [_overlay()]),
              ),
            )
          else if (!overlayInBody)
            _overlay(),
        ],
      ),
    ),
  );
}
