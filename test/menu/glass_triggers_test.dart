import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/menu/menu_engine.dart';
import 'package:liquid_prism/src/menu/menu_platform_interface.dart';

import 'fake_platform.dart';

void main() {
  late FakePrismMenuPlatform platform;
  setUp(() {
    platform = FakePrismMenuPlatform();
    PrismMenuPlatform.instance = platform;
    PrismMenuEngine.instance.resetForTests();
    PrismMenuEngine.debugTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() {
    PrismMenuEngine.debugTargetPlatformOverride = null;
  });
  const menu = PrismMenu(
    children: [
      PrismMenuAction<String>(
        id: 'chosen',
        title: 'Choose me',
        value: 'chosen-value',
      ),
    ],
  );
  Widget app(Widget child) => CupertinoApp(
    home: PrismTheme(
      brightness: Brightness.dark,
      child: Center(child: child),
    ),
  );
  void select() {
    final id = platform.shows.last.menuId;
    platform.emit(PrismMenuActionEvent(menuId: id, actionId: 'chosen'));
    platform.emit(PrismMenuDismissed(menuId: id));
  }

  testWidgets(
    'glass button opens one native session and reports the value on dismissal',
    (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(
        app(
          PrismButton.menu(
            menu: menu,
            label: 'Options',
            onSelected: results.add,
            child: const Text('Options'),
          ),
        ),
      );
      await tester.tap(find.byType(PrismButton));
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
          PrismToolbar.group(
            items: [
              PrismToolbarItem.menu(
                key: const ValueKey('active-menu'),
                icon: const Icon(CupertinoIcons.ellipsis),
                label: 'Active menu',
                menu: menu,
                onSelected: (v) => result = v,
              ),
              const PrismToolbarItem.menu(
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
        lessThan(tester.getSize(find.byType(PrismToolbar)).width),
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
          const PrismButton.menu(
            enabled: false,
            menu: menu,
            label: 'Disabled',
            child: Text('Disabled'),
          ),
        ),
      );
      await tester.tap(find.byType(PrismButton));
      await tester.pumpAndSettle();
      expect(platform.shows, isEmpty);
      await tester.pumpWidget(
        app(
          PrismButton.menu(
            menu: menu,
            label: 'Options',
            onSelected: (_) => callbacks++,
            child: const Text('Options'),
          ),
        ),
      );
      await tester.tap(find.byType(PrismButton));
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
    final pending = prismMenus.show<Object?>(context: trigger, menu: menu);
    await tester.pump();
    expect(platform.shows.single.anchor['width'], 120);
    expect(platform.shows.single.anchor['height'], 60);
    select();
    await pending;
  });
}
