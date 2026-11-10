import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/badge.dart';
import 'package:liquid_prism/src/chrome_material.dart';
import 'package:liquid_prism/src/pressable.dart';
import 'package:liquid_prism/src/tab_content_lens.dart';

void main() {
  testWidgets('toolbar badges materialize with their whole group', (
    tester,
  ) async {
    for (final managed in [false, true]) {
      Widget app(bool visible) {
        final items = visible
            ? [
                GlassToolbarItem(
                  label: 'Inbox',
                  icon: const Icon(Icons.mail),
                  badge: const GlassBadge.dot(),
                  onPressed: () {},
                ),
              ]
            : <GlassToolbarItem>[];
        return MaterialApp(
          home: Center(
            child: managed
                ? LiquidPrismToolbar(content: [GlassToolbarGroup(items: items)])
                : LiquidPrismToolbarGroup(items: items),
          ),
        );
      }

      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(true));
      await tester.pump(const Duration(milliseconds: 80));
      final glass = find.byType(LiquidPrism);
      final progress = LiquidPrismPresence.of(tester.element(glass));
      expect(progress, inExclusiveRange(0, 1));
      final badge = find.byType(GlassBadgeView);
      final opacity = tester
          .widget<Opacity>(
            find.ancestor(of: badge, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(
        opacity,
        closeTo(progress, .001),
        reason: 'a badge outside the glass child must follow the same materialization progress',
      );
      await tester.pumpAndSettle();
    }
  });
  testWidgets('toolbar counts grow inward at the trailing safe edge', (
    tester,
  ) async {
    for (final axis in Axis.values) {
      for (final direction in TextDirection.values) {
        double? edge;
        for (final (count, scale) in [
          (7, 1.0),
          (1234567, 1.0),
          (1234567, 2.0),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: Center(
                    child: LiquidPrismToolbarGroup(
                      axis: axis,
                      items: [
                        GlassToolbarItem(
                          icon: const Icon(Icons.mail),
                          label: 'Mail',
                          badge: GlassBadge.count(count),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final badge = tester.getRect(find.byType(GlassBadgeView));
          final trailing = direction == TextDirection.ltr
              ? badge.right
              : badge.left;
          edge ??= trailing;
          expect(
            trailing,
            closeTo(edge, .01),
            reason: 'long counts must expand inward rather than beyond the rail safe edge',
          );
        }
      }
    }
  });
  testWidgets(
    'tab and sidebar badge centers do not drift for dots or text scaling',
    (tester) async {
      for (final direction in TextDirection.values) {
        Offset? anchor;
        for (final (badge, scale) in [
          (const GlassBadge.count(7), 1.0),
          (const GlassBadge.dot(), 1.0),
          (const GlassBadge.count(7), 2.0),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: Center(
                    child: GlassBadgedIcon(
                      badge: badge,
                      child: const Icon(Icons.mail),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final center = tester.getCenter(find.byType(GlassBadgeView));
          anchor ??= center;
          expect((center - anchor).distance, lessThan(.01));
        }
      }
    },
  );
  testWidgets('activity dots retain their corner across toolbar axes', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      Offset? horizontalAnchor;
      for (final axis in Axis.values) {
        double? countWidth;
        for (final badge in [
          const GlassBadge.count(7),
          const GlassBadge.dot(),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: direction,
                child: Center(
                  child: LiquidPrismToolbarGroup(
                    axis: axis,
                    items: [
                      GlassToolbarItem(
                        icon: const Icon(Icons.mail),
                        label: 'Mail',
                        badge: badge,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final rect = tester.getRect(find.byType(GlassBadgeView));
          final group = tester.getRect(find.byType(LiquidPrismToolbarGroup));
          if (badge.count != null) {
            countWidth = rect.width;
          } else {
            expect(rect.width, lessThan(countWidth!));
            final anchor = Offset(
              direction == TextDirection.ltr
                  ? group.right - rect.center.dx
                  : rect.center.dx - group.left,
              rect.center.dy - group.top,
            );
            horizontalAnchor ??= anchor;
            expect((anchor - horizontalAnchor).distance, lessThan(.01));
          }
        }
      }
    }
  });

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
