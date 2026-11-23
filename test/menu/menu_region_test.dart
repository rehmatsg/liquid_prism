import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/menu/menu_engine.dart';
import 'package:liquid_prism/src/menu/menu_platform_interface.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_platform.dart';

void main() {
  late FakePrismMenuPlatform platform;

  setUp(() {
    platform = FakePrismMenuPlatform();
    PrismMenuPlatform.instance = platform;
    PrismMenuEngine.instance.resetForTests();
    PrismMenuEngine.debugTargetPlatformOverride = .iOS;
  });

  tearDown(() {
    PrismMenuEngine.debugTargetPlatformOverride = null;
  });

  testWidgets('tapPoint anchor mode presents at the tap point', (t) async {
    const menu = PrismMenu(children: [PrismMenuAction<Object?>(title: 'A')]);
    await t.pumpWidget(
      const Directionality(
        textDirection: .ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 60,
            child: PrismMenuRegion(
              menu: menu,
              anchor: .tapPoint,
              child: Text('trigger'),
            ),
          ),
        ),
      ),
    );

    await t.tapAt(t.getCenter(find.text('trigger')) + const Offset(20, 5));
    await t.pump();

    expect(platform.shows, hasLength(1));
    final anchor = platform.shows.single.anchor;
    expect(anchor['type'], 'point');
    final center = t.getCenter(find.text('trigger'));
    expect(anchor['x'], closeTo(center.dx + 20, 1));
    expect(anchor['y'], closeTo(center.dy + 5, 1));
  });

  testWidgets('default (triggerRect) anchor sends the region bounds', (
    t,
  ) async {
    const menu = PrismMenu(children: [PrismMenuAction<Object?>(title: 'A')]);
    await t.pumpWidget(
      const Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: PrismMenuRegion(
            menu: menu,
            child: SizedBox(width: 100, height: 40, child: Text('trigger')),
          ),
        ),
      ),
    );

    await t.tap(find.text('trigger'));
    await t.pump();

    final anchor = platform.shows.single.anchor;
    expect(anchor['type'], 'rect');
    expect(anchor['width'], 100.0);
    expect(anchor['height'], 40.0);
  });

  testWidgets('builder mode: the child drives show; pointer still anchors', (
    t,
  ) async {
    const menu = PrismMenu(children: [PrismMenuAction<Object?>(title: 'A')]);
    await t.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: PrismMenuRegion.builder(
            menu: menu,
            builder: (context, show) => GestureDetector(
              onTap: show,
              child: const SizedBox(width: 80, height: 30, child: Text('btn')),
            ),
          ),
        ),
      ),
    );

    await t.tap(find.text('btn'));
    await t.pump();
    expect(platform.shows, hasLength(1));
    expect(platform.shows.single.anchor['type'], 'point');
  });

  testWidgets('onSelected is called after dismissal with the value', (t) async {
    Object? reported;
    const menu = PrismMenu(
      children: [PrismMenuAction<Object?>(title: 'A', value: 'alpha')],
    );
    await t.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: PrismMenuRegion(
          menu: menu,
          onSelected: (v) => reported = v,
          child: const SizedBox(width: 100, height: 40, child: Text('trigger')),
        ),
      ),
    );

    await t.tap(find.text('trigger'));
    await t.pump();
    final menuId = platform.shows.single.menuId;
    final actionId =
        ((platform.shows.single.menu['items']! as List).single as Map)['id']
            as String;
    platform
      ..emit(PrismMenuActionEvent(menuId: menuId, actionId: actionId))
      ..emit(PrismMenuDismissed(menuId: menuId));
    await t.pump();
    expect(reported, 'alpha');
  });

  testWidgets('long-press trigger opens on long press, not tap', (t) async {
    const menu = PrismMenu(children: [PrismMenuAction<Object?>(title: 'A')]);
    await t.pumpWidget(
      const Directionality(
        textDirection: .ltr,
        child: PrismMenuRegion(
          menu: menu,
          trigger: .longPress,
          child: SizedBox(width: 100, height: 40, child: Text('trigger')),
        ),
      ),
    );

    await t.tap(find.text('trigger'));
    await t.pump();
    expect(platform.shows, isEmpty);

    await t.longPress(find.text('trigger'));
    await t.pump();
    expect(platform.shows, hasLength(1));
  });
}
