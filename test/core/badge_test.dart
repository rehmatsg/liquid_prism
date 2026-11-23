import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/controls/prism_pressable.dart'
    show PrismPressFeedback;
import 'package:liquid_prism/src/core/prism_badge.dart'
    show PrismBadgeView, PrismBadgedIcon;
import 'package:liquid_prism/src/rendering/chrome_material.dart';
import 'package:liquid_prism/src/rendering/surface.dart' show RawPrismSurface;
import 'package:liquid_prism/src/rendering/tab_content_lens.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('toolbar badges materialize with their whole group', (
    tester,
  ) async {
    for (final managed in [false, true]) {
      Widget app(bool visible) {
        final items = visible
            ? [
                PrismToolbarItem(
                  label: 'Inbox',
                  icon: const Icon(Icons.mail),
                  badge: const PrismBadge.dot(),
                  onPressed: () {},
                ),
              ]
            : <PrismToolbarItem>[];
        return MaterialApp(
          home: Center(
            child: managed
                ? PrismToolbar(content: [PrismToolbarGroup(items: items)])
                : PrismToolbar.group(items: items),
          ),
        );
      }

      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(true));
      await tester.pump(const Duration(milliseconds: 80));
      final glass = find.byType(RawPrismSurface);
      final progress = PrismPresence.of(tester.element(glass));
      expect(progress, inExclusiveRange(0, 1));
      final badge = find.byType(PrismBadgeView);
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
                    child: PrismToolbar.group(
                      axis: axis,
                      items: [
                        PrismToolbarItem(
                          icon: const Icon(Icons.mail),
                          label: 'Mail',
                          badge: PrismBadge.count(count),
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
          final badge = tester.getRect(find.byType(PrismBadgeView));
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
          (const PrismBadge.count(7), 1.0),
          (const PrismBadge.dot(), 1.0),
          (const PrismBadge.count(7), 2.0),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: Center(
                    child: PrismBadgedIcon(
                      badge: badge,
                      child: const Icon(Icons.mail),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final center = tester.getCenter(find.byType(PrismBadgeView));
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
        double? countHeight;
        for (final badge in [
          const PrismBadge.count(7),
          const PrismBadge.dot(),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: direction,
                child: Center(
                  child: PrismToolbar.group(
                    axis: axis,
                    items: [
                      PrismToolbarItem(
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
          final rect = tester.getRect(find.byType(PrismBadgeView));
          final group = tester.getRect(find.byType(PrismToolbar));
          if (badge.count != null) {
            countHeight = rect.height;
          } else {
            expect(rect.height, countHeight!);
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
                PrismTabBar(
                  tabs: const [
                    PrismTab(
                      label: 'Inbox',
                      icon: Icon(Icons.mail),
                      badge: PrismBadge.count(125, overflow: 99),
                    ),
                    PrismTab(label: 'Home', icon: Icon(Icons.home)),
                  ],
                  selectedIndex: 1,
                  onSelected: (_) {},
                ),
                PrismToolbar.group(
                  items: [
                    PrismToolbarItem(
                      icon: const Icon(Icons.mail),
                      label: 'Messages',
                      badge: const PrismBadge.dot(),
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

      expect(const PrismBadge.count(1000).text, '1,000');
      expect(const PrismBadge.count(1234567).text, '1,234,567');
      expect(const PrismBadge.count(7).text, '7');
      expect(const PrismBadge.text('1.000').text, '1.000');
      expect(const PrismBadge.dot().text, isNull);
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
              PrismTabBar(
                tabs: const [
                  PrismTab(
                    label: 'Inbox',
                    icon: Icon(Icons.mail),
                    badge: PrismBadge.count(7),
                  ),
                  PrismTab(label: 'Home', icon: Icon(Icons.home)),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              PrismToolbar.group(
                items: [
                  PrismToolbarItem(
                    icon: const Icon(Icons.mail),
                    label: 'Messages',
                    badge: const PrismBadge.dot(),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final views = find.byType(PrismBadgeView);
    expect(views, findsNWidgets(2));
    for (final type in [ClipPath, ClipRect, ContentLensWindow]) {
      expect(
        find.ancestor(of: views, matching: find.byType(type)),
        findsNothing,
        reason: 'a $type would clip or recolour the badge',
      );
    }

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
          child: PrismToolbar.group(
            items: [
              PrismToolbarItem(
                icon: const Icon(Icons.mail),
                label: 'Messages',
                badge: const PrismBadge.count(7),
                onPressed: () {},
              ),
              PrismToolbarItem(
                icon: const Icon(Icons.share),
                label: 'Share',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final view = find.byType(PrismBadgeView);
    final rest = tester.getRect(view);
    final group = tester.getRect(find.byType(PrismToolbar));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mail)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final scales = tester
        .widgetList<PrismPressFeedback>(
          find.ancestor(
            of: find.byType(ChromeMaterial),
            matching: find.byType(PrismPressFeedback),
          ),
        )
        .map((scope) => scope.scale)
        .toList();

    final scale = scales.first;
    expect(scale, greaterThan(1.01), reason: 'the capsule grows while held');
    final held = tester.getRect(view);

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
