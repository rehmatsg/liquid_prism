import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/liquid_menu_platform_interface.dart';
import 'package:liquid_prism/src/menu/menu_engine.dart';

import 'fake_platform.dart';

void main() {
  late FakeLiquidMenuPlatform platform;
  setUp(() {
    platform = FakeLiquidMenuPlatform();
    LiquidMenuPlatform.instance = platform;
    LiquidMenuEngine.instance.resetForTests();
    LiquidMenuEngine.debugTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() {
    LiquidMenuEngine.debugTargetPlatformOverride = null;
  });
  const menu = LiquidMenu(
    children: [
      LiquidMenuAction<String>(
        id: 'chosen',
        title: 'Choose me',
        value: 'chosen-value',
      ),
    ],
  );
  Widget app(Widget child) => CupertinoApp(
    home: LiquidPrismTheme(
      brightness: Brightness.dark,
      child: Center(child: child),
    ),
  );
  void select() {
    final id = platform.shows.last.menuId;
    platform.emit(LiquidMenuActionEvent(menuId: id, actionId: 'chosen'));
    platform.emit(LiquidMenuDismissed(menuId: id));
  }

  testWidgets(
    'glass button opens one native session and reports the value on dismissal',
    (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(
        app(
          LiquidPrismButton.menu(
            menu: menu,
            label: 'Options',
            onSelected: results.add,
            child: const Text('Options'),
          ),
        ),
      );
      await tester.tap(find.byType(LiquidPrismButton));
      await tester.pump();
      expect(platform.shows, hasLength(1));
      expect(platform.shows.single.anchor['type'], 'rect');
      expect(platform.shows.single.menu['appearance'], 'dark');
      select();
      await tester.pumpAndSettle();
      expect(results, ['chosen-value']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'toolbar anchors to its action rather than the entire group; disabled menu does nothing',
    (tester) async {
      Object? result;
      await tester.pumpWidget(
        app(
          LiquidPrismToolbarGroup(
            items: [
              GlassToolbarItem.menu(
                key: const ValueKey('active-menu'),
                icon: const Icon(CupertinoIcons.ellipsis),
                label: 'Active menu',
                menu: menu,
                onSelected: (v) => result = v,
              ),
              const GlassToolbarItem.menu(
                key: ValueKey('disabled-menu'),
                icon: Icon(CupertinoIcons.star),
                label: 'Disabled menu',
                menu: menu,
                enabled: false,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('active-menu')));
      await tester.pump();
      final action = tester.getRect(find.byKey(const ValueKey('active-menu')));
      final anchor = platform.shows.single.anchor;
      expect(anchor['width'], closeTo(action.width, .01));
      expect(anchor['height'], closeTo(action.height, .01));
      expect(anchor['x'], closeTo(action.left, .01));
      expect(
        anchor['width'] as double,
        lessThan(tester.getSize(find.byType(LiquidPrismToolbarGroup)).width),
      );
      select();
      await tester.pumpAndSettle();
      expect(result, 'chosen-value');
      await tester.tap(find.byKey(const ValueKey('disabled-menu')));
      await tester.pumpAndSettle();
      expect(platform.shows, hasLength(1));
    },
  );

  testWidgets(
    'disabled glass menu and disposal during a native menu are safe',
    (tester) async {
      var callbacks = 0;
      await tester.pumpWidget(
        app(
          const LiquidPrismButton.menu(
            enabled: false,
            menu: menu,
            label: 'Disabled',
            child: Text('Disabled'),
          ),
        ),
      );
      await tester.tap(find.byType(LiquidPrismButton));
      await tester.pumpAndSettle();
      expect(platform.shows, isEmpty);
      await tester.pumpWidget(
        app(
          LiquidPrismButton.menu(
            menu: menu,
            label: 'Options',
            onSelected: (_) => callbacks++,
            child: const Text('Options'),
          ),
        ),
      );
      await tester.tap(find.byType(LiquidPrismButton));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      select();
      await tester.pump();
      expect(callbacks, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native anchor includes the scale applied to a trigger', (
    tester,
  ) async {
    late BuildContext trigger;
    await tester.pumpWidget(
      app(
        Transform.scale(
          scale: 1.5,
          child: Builder(
            builder: (context) {
              trigger = context;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      ),
    );
    final pending = liquidMenus.show(context: trigger, menu: menu);
    await tester.pump();
    expect(platform.shows.single.anchor['width'], 120);
    expect(platform.shows.single.anchor['height'], 60);
    select();
    await pending;
  });
}
