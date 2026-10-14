import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/badge.dart';
import 'package:liquid_prism/src/chrome_material.dart';
import 'package:liquid_prism/src/pressable.dart';
import 'package:liquid_prism/src/tab_content_lens.dart';

void main() {
  testWidgets(
    'badges show overflow but announce full count, dots announce activity',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidPrismTabBar(
                  tabs: const [
                    LiquidPrismTab(
                      label: 'Inbox',
                      icon: Icon(Icons.mail),
                      badge: GlassBadge.count(125, overflow: 99),
                    ),
                    LiquidPrismTab(label: 'Home', icon: Icon(Icons.home)),
                  ],
                  selectedIndex: 1,
                  onSelected: (_) {},
                ),
                LiquidPrismToolbarGroup(
                  items: [
                    GlassToolbarItem(
                      icon: const Icon(Icons.mail),
                      label: 'Messages',
                      badge: const GlassBadge.dot(),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
      // Native counts are never shortened; thousands are grouped.
      expect(const GlassBadge.count(1000).text, '1,000');
      expect(const GlassBadge.count(1234567).text, '1,234,567');
      expect(const GlassBadge.count(7).text, '7');
      expect(const GlassBadge.text('1.000').text, '1.000');
      expect(const GlassBadge.dot().text, isNull);
      expect(tester.getSemantics(find.bySemanticsLabel('Inbox')).value, '125');
      expect(find.bySemanticsLabel('Messages, New activity'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('badges paint outside the capsule clip and the tab window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidPrismTabBar(
                tabs: const [
                  LiquidPrismTab(
                    label: 'Inbox',
                    icon: Icon(Icons.mail),
                    badge: GlassBadge.count(7),
                  ),
                  LiquidPrismTab(label: 'Home', icon: Icon(Icons.home)),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              LiquidPrismToolbarGroup(
                items: [
                  GlassToolbarItem(
                    icon: const Icon(Icons.mail),
                    label: 'Messages',
                    badge: const GlassBadge.dot(),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final views = find.byType(GlassBadgeView);
    expect(views, findsNWidgets(2));
    for (final type in [ClipPath, ClipRect, ContentLensWindow]) {
      expect(
        find.ancestor(of: views, matching: find.byType(type)),
        findsNothing,
        reason: 'a $type would clip or recolour the badge',
      );
    }
    // The toolbar badge overhangs its item, as measured natively.
    final item = tester.getRect(find.byIcon(Icons.mail).last);
    final badge = tester.getRect(views.last);
    expect(badge.top, lessThan(item.top - 8));
  });

  testWidgets('a toolbar badge follows its capsule while pressed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LiquidPrismToolbarGroup(
            items: [
              GlassToolbarItem(
                icon: const Icon(Icons.mail),
                label: 'Messages',
                badge: const GlassBadge.count(7),
                onPressed: () {},
              ),
              GlassToolbarItem(
                icon: const Icon(Icons.share),
                label: 'Share',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final view = find.byType(GlassBadgeView);
    final rest = tester.getRect(view);
    final group = tester.getRect(find.byType(LiquidPrismToolbarGroup));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mail)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final scales = tester
        .widgetList<LiquidPrismPressFeedback>(
          find.ancestor(
            of: find.byType(ChromeMaterial),
            matching: find.byType(LiquidPrismPressFeedback),
          ),
        )
        .map((scope) => scope.scale)
        .toList();
    // The nearest scope is the one the capsule's glass scales by.
    final scale = scales.first;
    expect(scale, greaterThan(1.01), reason: 'the capsule grows while held');
    final held = tester.getRect(view);
    // Scaled about the capsule's centre, exactly as the glass is.
    final centre = group.center;
    expect(held.width, closeTo(rest.width * scale, .01));
    expect(
      held.center.dx,
      closeTo(centre.dx + (rest.center.dx - centre.dx) * scale, .01),
    );
    expect(
      held.center.dy,
      closeTo(centre.dy + (rest.center.dy - centre.dy) * scale, .01),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(view), rest);
  });
}
