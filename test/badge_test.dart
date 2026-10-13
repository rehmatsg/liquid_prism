import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/badge.dart';
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
}
