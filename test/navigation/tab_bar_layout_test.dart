import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';

Finder housing() => find.byWidgetPredicate(
  (w) => w is RawPrismSurface && w.role == PrismRole.tabBar,
);
List<PrismTab> tabs(int count, {String? long}) => [
  for (var i = 0; i < count; i++)
    PrismTab(
      label: long ?? String.fromCharCode(65 + i),
      icon: const SizedBox(width: 25, height: 25),
    ),
];
Widget host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Center(child: child),
  ),
);

void main() {
  final native = jsonDecode(
    File('research/specs/native_tab_layout_spec.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final count in [2, 3, 4]) {
    testWidgets(
      '$count tabs keep the native compact width in a wide tight parent',
      (tester) async {
        final sample = (native['samples']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .firstWhere(
              (sample) =>
                  (sample['labels']! as List<Object?>).length == count &&
                  sample['hidden'] == false,
            );
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 600,
              child: PrismTabBar(
                tabs: tabs(count),
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        );
        expect(
          tester.getSize(housing()).width,
          closeTo(
            ((sample['housing']! as List<Object?>)[2]! as num).toDouble(),
            .001,
          ),
        );
        expect(tester.getCenter(housing()).dx, closeTo(400, .001));
      },
    );
  }
  testWidgets(
    'long labels grow the compact bar and selection does not resize it',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 700,
            child: StatefulBuilder(
              builder: (context, update) => PrismTabBar(
                tabs: tabs(3, long: 'A longer destination label'),
                selectedIndex: selected,
                onSelected: (i) => update(() => selected = i),
              ),
            ),
          ),
        ),
      );
      final before = tester.getSize(housing());
      expect(before.width, greaterThan(274));
      expect(before.width, lessThanOrEqualTo(700));
      await tester.tapAt(
        tester.getCenter(housing()) + Offset(before.width / 3, 0),
      );
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(tester.getSize(housing()), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'hidden labels remain compact; expanded style fills the available width',
    (tester) async {
      Future<void> render(bool expanded) => tester.pumpWidget(
        host(
          SizedBox(
            width: 600,
            child: PrismTabBar(
              tabs: tabs(3, long: 'Hidden long title'),
              selectedIndex: 0,
              onSelected: (_) {},
              style: PrismTabBarStyle(
                labelBehavior: PrismTabLabelBehavior.never,
                sizing: expanded
                    ? PrismTabBarSizing.fill
                    : PrismTabBarSizing.compact,
              ),
            ),
          ),
        ),
      );
      await render(false);
      expect(tester.getSize(housing()).width, 274);
      await render(true);
      expect(tester.getSize(housing()).width, 600);
    },
  );
  testWidgets(
    'compact bar fits narrow constraints and unbounded horizontal rows',
    (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 220,
            child: PrismTabBar(
              tabs: tabs(3),
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      expect(tester.getSize(housing()).width, 220);
      await tester.pumpWidget(
        host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrismTabBar(tabs: tabs(2), selectedIndex: 0, onSelected: (_) {}),
            ],
          ),
        ),
      );
      expect(tester.getSize(housing()).width, 188);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('explicit compact style overrides an expanded theme', (
    tester,
  ) async {
    Future<void> render(bool? expanded) => tester.pumpWidget(
      host(
        SizedBox(
          width: 600,
          child: PrismTheme(
            data: const PrismThemeData(
              tabBar: PrismTabBarStyle(sizing: PrismTabBarSizing.fill),
            ),
            child: PrismTabBar(
              tabs: tabs(3),
              selectedIndex: 0,
              onSelected: (_) {},
              style: PrismTabBarStyle(
                sizing: expanded == null
                    ? null
                    : expanded
                    ? PrismTabBarSizing.fill
                    : PrismTabBarSizing.compact,
              ),
            ),
          ),
        ),
      ),
    );
    await render(null);
    expect(tester.getSize(housing()).width, 600);
    await render(false);
    expect(tester.getSize(housing()).width, 274);
  });
  testWidgets('empty margins around a compact bar do not select a tab', (
    tester,
  ) async {
    var selections = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 600,
          child: PrismTabBar(
            tabs: tabs(3),
            selectedIndex: 0,
            onSelected: (_) => selections++,
          ),
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(PrismTabBar)) + const Offset(5, 31),
    );
    await tester.pumpAndSettle();
    expect(selections, 0);
  });
}
