import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/menu/menu_engine.dart';
import 'package:liquid_prism/src/menu/menu_platform_interface.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_platform.dart';

void main() {
  late FakePrismMenuPlatform platform;
  late BuildContext context;

  Future<Object?> show(PrismMenu menu, {PrismMenuAnchor? anchor}) {
    return PrismMenuEngine.instance.show(
      context: context,
      menu: menu,
      anchor: anchor ?? const PrismMenuPointAnchor(Offset(100, 200)),
    );
  }

  setUp(() {
    platform = FakePrismMenuPlatform();
    PrismMenuPlatform.instance = platform;
    PrismMenuEngine.instance.resetForTests();
    PrismMenuEngine.debugTargetPlatformOverride = .iOS;
  });

  tearDown(() {
    PrismMenuEngine.debugTargetPlatformOverride = null;
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  group('wire serialization', () {
    testWidgets('action serializes static fields and a minted id', (t) async {
      await mount(t);
      const menu = PrismMenu(
        children: [
          PrismMenuAction<Object?>(
            title: 'Delete',
            icon: PrismMenuSfSymbol('trash'),
            destructive: true,
            enabled: false,
            hidden: true,
            keepsMenuPresented: true,
            discoverabilityTitle: 'Del',
            state: .mixed,
          ),
        ],
      );
      unawaited(show(menu));
      await t.pump();
      final items = (platform.shows.single.menu['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items.single, {
        'type': 'action',
        'id': startsWith('lm_'),
        'title': 'Delete',
        'icon': {'kind': 'sfSymbol', 'name': 'trash'},
        'state': 'mixed',
        'destructive': true,
        'disabled': true,
        'hidden': true,
        'keepsMenuPresented': true,
        'discoverabilityTitle': 'Del',
      });
    });

    testWidgets('explicit action id is preserved on the wire', (t) async {
      await mount(t);
      unawaited(
        show(
          const PrismMenu(
            children: [PrismMenuAction<Object?>(id: 'save', title: 'Save')],
          ),
        ),
      );
      await t.pump();
      final items = (platform.shows.single.menu['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items.single['id'], 'save');
    });

    testWidgets('divider, section and submenu shapes', (t) async {
      await mount(t);
      const menu = PrismMenu(
        children: [
          PrismMenuAction<Object?>(title: 'A'),
          PrismMenuDivider(),
          PrismMenuSection(
            title: 'Group',
            singleSelection: true,
            children: [PrismMenuAction<Object?>(title: 'B', state: .on)],
          ),
          PrismSubmenu(
            title: 'More',
            icon: PrismMenuSfSymbol('ellipsis'),
            children: [PrismMenuAction<Object?>(title: 'C')],
          ),
        ],
      );
      unawaited(show(menu));
      await t.pump();
      final items = (platform.shows.single.menu['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items[1], {'type': 'divider'});
      expect(items[2]['type'], 'section');
      final section = items[2]['menu']! as Map<String, Object?>;
      final sectionItems = section['items']! as List<Object?>;
      expect(section['options'], {'singleSelection': true});
      expect((sectionItems.single! as Map<String, Object?>)['state'], 'on');
      expect(items[3]['type'], 'submenu');
      final submenu = items[3]['menu']! as Map<String, Object?>;
      expect(submenu['title'], 'More');
      expect(submenu['image'], {'kind': 'sfSymbol', 'name': 'ellipsis'});
      final submenuItems = submenu['items']! as List<Object?>;
      expect((submenuItems.single! as Map<String, Object?>)['title'], 'C');
    });

    testWidgets('nested actions inside sections join the registry', (t) async {
      await mount(t);
      var fired = false;
      final menu = PrismMenu(
        children: [
          PrismMenuSection(
            children: [
              PrismMenuAction<Object?>(
                title: 'Nested',
                onSelected: () => fired = true,
              ),
            ],
          ),
        ],
      );
      final future = show(menu);
      await t.pump();
      final menuId = platform.shows.single.menuId;
      final items = (platform.shows.single.menu['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final section = items.single['menu']! as Map<String, Object?>;
      final sectionItems = section['items']! as List<Object?>;
      final nestedId =
          (sectionItems.single! as Map<String, Object?>)['id']! as String;
      expect(nestedId, startsWith('lm_'));
      platform.emit(PrismMenuActionEvent(menuId: menuId, actionId: nestedId));
      await t.pump();
      expect(fired, isTrue);
      platform.emit(PrismMenuDismissed(menuId: menuId));
      await future;
    });

    testWidgets('deferred mints an id and registers its loader', (t) async {
      await mount(t);
      unawaited(
        show(
          PrismMenu(
            children: [
              PrismMenuDeferred(
                loader: () async => [
                  const PrismMenuAction<Object?>(title: 'Late'),
                ],
              ),
            ],
          ),
        ),
      );
      await t.pump();
      final items = (platform.shows.single.menu['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items.single['type'], 'deferred');
      expect(items.single['id'], startsWith('lm_'));

      final resolved = await platform.deferredResolver!(
        platform.shows.single.menuId,
        items.single['id']! as String,
      );
      expect(resolved!.single, isA<Map<Object?, Object?>>());
      expect((resolved.single! as Map<String, Object?>)['title'], 'Late');
    });

    testWidgets('anchor maps', (t) async {
      await mount(t);
      unawaited(show(const PrismMenu(), anchor: const .point(Offset(10, 20))));
      await t.pump();
      expect(platform.shows.single.anchor, {
        'type': 'point',
        'x': 10.0,
        'y': 20.0,
      });

      unawaited(
        show(
          const PrismMenu(),
          anchor: const .rect(Rect.fromLTWH(1, 2, 30, 40)),
        ),
      );
      await t.pump();
      expect(platform.shows.last.anchor, {
        'type': 'rect',
        'x': 1.0,
        'y': 2.0,
        'width': 30.0,
        'height': 40.0,
      });
    });

    testWidgets(
      'sf symbol icon serializes weight/scale/renderingMode/palette',
      (t) async {
        await mount(t);
        unawaited(
          show(
            const PrismMenu(
              children: [
                PrismMenuAction<Object?>(
                  title: 'A',
                  icon: PrismMenuSfSymbol(
                    'star.fill',
                    weight: .bold,
                    scale: .large,
                    renderingMode: .palette,
                    palette: [Color(0xFFFF0000), Color(0xFF00FF00)],
                  ),
                ),
              ],
            ),
          ),
        );
        await t.pump();
        final items = (platform.shows.single.menu['items']! as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(items.single['icon'], {
          'kind': 'sfSymbol',
          'name': 'star.fill',
          'weight': 'bold',
          'scale': 'large',
          'renderingMode': 'palette',
          'palette': [0xFFFF0000, 0xFF00FF00],
        });
      },
    );
  });

  group('session lifecycle', () {
    testWidgets('show completes with the selected action value on dismiss', (
      t,
    ) async {
      await mount(t);
      const menu = PrismMenu(
        children: [
          PrismMenuAction<Object?>(title: 'One', value: 'one'),
          PrismMenuAction<Object?>(title: 'Two', value: 'two'),
        ],
      );
      final result = show(menu);
      await t.pump();
      final menuId = platform.shows.single.menuId;
      final items = (platform.shows.single.menu['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final secondId = items.last['id']! as String;

      platform
        ..emit(PrismMenuActionEvent(menuId: menuId, actionId: secondId))
        ..emit(PrismMenuDismissed(menuId: menuId));
      expect(await result, 'two');
    });

    testWidgets('bare dismissal completes null', (t) async {
      await mount(t);
      final result = show(const PrismMenu());
      await t.pump();
      platform.emit(PrismMenuDismissed(menuId: platform.shows.single.menuId));
      expect(await result, isNull);
    });

    testWidgets('events for a stale menuId are ignored', (t) async {
      await mount(t);
      final result = show(const PrismMenu());
      await t.pump();
      platform.emit(const PrismMenuDismissed(menuId: 'lm_stale-0000'));
      var completed = false;
      unawaited(result.then((_) => completed = true));
      await t.pump();
      expect(completed, isFalse);
      platform.emit(PrismMenuDismissed(menuId: platform.shows.single.menuId));
      expect(await result, isNull);
    });

    testWidgets('a second show supersedes the first session', (t) async {
      await mount(t);
      final first = show(const PrismMenu());
      await t.pump();
      final second = show(const PrismMenu());
      await t.pump();
      expect(await first, isNull);
      platform.emit(PrismMenuDismissed(menuId: platform.shows.last.menuId));
      expect(await second, isNull);
      expect(platform.shows, hasLength(2));
    });

    testWidgets('keepsMenuPresented actions fire onSelected repeatedly', (
      t,
    ) async {
      await mount(t);
      var taps = 0;
      final menu = PrismMenu(
        children: [
          PrismMenuAction<Object?>(
            title: 'Pin',
            keepsMenuPresented: true,
            onSelected: () => taps++,
          ),
        ],
      );
      final result = show(menu);
      await t.pump();
      final menuId = platform.shows.single.menuId;
      final actionId =
          ((platform.shows.single.menu['items']! as List<Object?>).single!
                  as Map<String, Object?>)['id']!
              as String;
      platform
        ..emit(PrismMenuActionEvent(menuId: menuId, actionId: actionId))
        ..emit(PrismMenuActionEvent(menuId: menuId, actionId: actionId));
      await t.pump();
      expect(taps, 2);
      platform.emit(PrismMenuDismissed(menuId: menuId));
      expect(await result, isNull);
    });

    testWidgets('rejected show falls through to the Flutter fallback', (
      t,
    ) async {
      await mount(t);
      platform.acceptShow = false;
      final result = show(const PrismMenu());
      await t.pumpAndSettle();

      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(await result, isNull);
    });
  });
}
