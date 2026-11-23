import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/rendering/surface.dart';

Widget harness(Widget child, {bool reduceMotion = false}) => CupertinoApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: PrismTheme(
      brightness: Brightness.dark,
      child: Center(child: child),
    ),
  ),
);

PrismToolbarItem item(String label, {VoidCallback? onPressed}) =>
    PrismToolbarItem(
      icon: const Icon(CupertinoIcons.star),
      label: label,
      onPressed: onPressed ?? () {},
    );

void main() {
  testWidgets(
    'group-local materialization overrides toolbar transition defaults',
    (tester) async {
      for (final identity in [true, false]) {
        Widget toolbar(bool visible) => harness(
          PrismToolbar(
            style: PrismToolbarStyle(
              itemTransition: identity
                  ? PrismTransition.materialize
                  : PrismTransition.identity,
            ),
            content: [
              PrismToolbarGroup(
                style: PrismToolbarStyle(
                  itemTransition: identity
                      ? PrismTransition.identity
                      : PrismTransition.materialize,
                  itemTransitionStyle: const PrismTransitionStyle(
                    enterSpring: PrismSpring(
                      response: Duration(milliseconds: 600),
                    ),
                    contentBlur: 0,
                  ),
                ),
                items: visible ? [item('Inbox')] : [],
              ),
            ],
          ),
        );
        await tester.pumpWidget(toolbar(false));
        await tester.pumpAndSettle();
        await tester.pumpWidget(toolbar(true));
        await tester.pump(const Duration(milliseconds: 80));
        final glass = find.byType(RawPrismSurface);
        final progress = PrismPresence.of(tester.element(glass));
        expect(progress, identity ? 1 : inExclusiveRange(0, .5));
        final contentFilters = tester.widgetList<ImageFiltered>(
          find.descendant(of: glass, matching: find.byType(ImageFiltered)),
        );
        expect(
          contentFilters.where((filter) => filter.enabled),
          isEmpty,
          reason:
              'explicit zero blur must survive the '
              'parent-owned materialization',
        );
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets('a managed exiting group stops input and semantics immediately', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    Widget toolbar(bool visible) => harness(
      PrismToolbar(
        content: [
          PrismToolbarGroup(
            items: visible ? [item('Inbox', onPressed: () => taps++)] : [],
          ),
        ],
      ),
    );
    await tester.pumpWidget(toolbar(true));
    final point = tester.getCenter(find.bySemanticsLabel('Inbox'));
    await tester.tapAt(point);
    expect(taps, 1);
    await tester.pumpWidget(toolbar(false));
    expect(find.bySemanticsLabel('Inbox'), findsNothing);
    await tester.tapAt(point);
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(RawPrismSurface), findsOneWidget);
    expect(find.bySemanticsLabel('Inbox'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(RawPrismSurface), findsNothing);
    semantics.dispose();
  });
  testWidgets(
    'an inserted group materializes once without clipping its housing',
    (tester) async {
      for (final axis in Axis.values) {
        Widget toolbar(bool visible) => harness(
          PrismToolbar(
            axis: axis,
            size: PrismToolbarSize.navigation,
            content: [
              PrismToolbarGroup(items: visible ? [item('Inbox')] : []),
              PrismToolbarGroup(items: [item('Sort')]),
            ],
          ),
        );
        await tester.pumpWidget(toolbar(false));
        await tester.pumpAndSettle();
        await tester.pumpWidget(toolbar(true));
        await tester.pump(const Duration(milliseconds: 80));
        final glass = find.byType(RawPrismSurface).first;
        final presences = find.ancestor(
          of: glass,
          matching: find.byType(PrismPresence),
        );
        expect(
          presences,
          findsOneWidget,
          reason:
              'the group must not multiply two independent '
              'materialization fades',
        );
        expect(
          PrismPresence.of(tester.element(glass)),
          inExclusiveRange(0, 1),
          reason:
              'a newly mounted group must materialize '
              'rather than appear opaque',
        );
        final rect = tester.getRect(glass).deflate(.01);
        for (final clip
            in find
                .ancestor(of: glass, matching: find.byType(ClipRect))
                .evaluate()) {
          if ((clip.widget as ClipRect).clipBehavior == Clip.none) continue;
          final clipRect = tester.getRect(
            find.byElementPredicate((element) => identical(element, clip)),
          );
          expect(
            clipRect.contains(rect.topLeft) &&
                clipRect.contains(rect.bottomRight),
            isTrue,
            reason: 'materialization must retain the whole housing contour',
          );
        }
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets('an added item materializes in while the capsule widens', (
    tester,
  ) async {
    Widget group(List<PrismToolbarItem> items) => harness(
      PrismToolbar.group(size: PrismToolbarSize.navigation, items: items),
    );
    await tester.pumpWidget(group([item('Share'), item('More')]));
    final glass = find.byType(RawPrismSurface);

    expect(tester.getSize(glass).width, 100);

    await tester.pumpWidget(group([item('Share'), item('Edit'), item('More')]));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    final growing = tester.getSize(glass).width;
    expect(growing, greaterThan(100));
    expect(growing, lessThan(154));
    await tester.pumpAndSettle();
    expect(tester.getSize(glass).width, 154);

    expect(
      tester.getCenter(find.bySemanticsLabel('Edit')).dx,
      inExclusiveRange(
        tester.getCenter(find.bySemanticsLabel('Share')).dx,
        tester.getCenter(find.bySemanticsLabel('More')).dx,
      ),
    );

    await tester.pumpWidget(group([item('Share'), item('More')]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.bySemanticsLabel('Edit'),
      findsNothing,
      reason: 'a leaving item is out of the semantics tree at once',
    );
    expect(tester.getSize(glass).width, inExclusiveRange(100, 154));
    await tester.pumpAndSettle();
    expect(tester.getSize(glass).width, 100);
  });

  testWidgets('a lone item re-forms its circle as its neighbour leaves', (
    tester,
  ) async {
    Widget group(List<PrismToolbarItem> items) => harness(
      PrismToolbar.group(size: PrismToolbarSize.navigation, items: items),
    );
    await tester.pumpWidget(group([item('Share'), item('More')]));
    await tester.pumpWidget(group([item('More')]));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RawPrismSurface)), const Size(44, 44));
  });

  testWidgets('Reduce Motion and identity swap items at once', (tester) async {
    for (final (reduce, transition) in [
      (true, null),
      (false, PrismTransition.identity),
    ]) {
      Widget group(List<PrismToolbarItem> items) => harness(
        reduceMotion: reduce,
        PrismToolbar.group(
          size: PrismToolbarSize.navigation,
          style: PrismToolbarStyle(itemTransition: transition),
          items: items,
        ),
      );
      await tester.pumpWidget(group([item('Share')]));
      await tester.pumpWidget(group([item('Share'), item('More')]));
      await tester.pump();
      expect(tester.getSize(find.byType(RawPrismSurface)).width, 100);
    }
  });

  testWidgets('an emptied group materializes out and keeps no capsule', (
    tester,
  ) async {
    Widget group(List<PrismToolbarItem> items) => harness(
      PrismToolbar.group(size: PrismToolbarSize.navigation, items: items),
    );
    await tester.pumpWidget(group([item('Share')]));
    expect(find.byType(RawPrismSurface), findsOneWidget);
    await tester.pumpWidget(group(const []));
    await tester.pump();
    expect(find.byType(PrismPresence), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(RawPrismSurface), findsNothing);
    expect(tester.getSize(find.byType(PrismToolbar)), Size.zero);

    await tester.pumpWidget(group([item('Share'), item('More')]));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(RawPrismSurface)).width, 100);
  });

  testWidgets('a toolbar lays out groups with a gap and collapses empty ones', (
    tester,
  ) async {
    Widget toolbar(List<List<PrismToolbarItem>> groups) => harness(
      PrismToolbar(
        size: PrismToolbarSize.navigation,
        content: [for (final items in groups) PrismToolbarGroup(items: items)],
      ),
    );
    await tester.pumpWidget(
      toolbar([
        [item('Suggest')],
        [item('Sort'), item('More')],
      ]),
    );
    final capsules = find.byType(RawPrismSurface);
    expect(capsules, findsNWidgets(2));
    final first = tester.getRect(capsules.first);
    final second = tester.getRect(capsules.last);
    expect(first.width, 44, reason: 'a lone item is a circle');
    expect(second.left - first.right, 8);
    expect(tester.getSize(find.byType(PrismToolbar)).width, 44 + 8 + 100);

    await tester.pumpWidget(
      toolbar([
        const [],
        [item('Sort'), item('More')],
      ]),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final shrinking = tester.getSize(find.byType(PrismToolbar)).width;
    expect(shrinking, inExclusiveRange(100, 152));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PrismToolbar)).width, 100);
    expect(capsules, findsOneWidget);

    await tester.pumpWidget(
      toolbar([
        [item('Suggest')],
        [item('Sort'), item('More')],
      ]),
    );
    await tester.pumpAndSettle();
    expect(capsules, findsNWidgets(2));
    expect(tester.getSize(find.byType(PrismToolbar)).width, 152);
  });

  test('toolbar style merges the transition and spacing fields', () {
    const base = PrismToolbarStyle(
      itemTransition: PrismTransition.identity,
      groupSpacing: 12,
      itemTransitionStyle: PrismTransitionStyle(contentBlur: 2),
    );
    final merged = base.merge(
      const PrismToolbarStyle(
        groupSpacing: 6,
        itemTransitionStyle: PrismTransitionStyle(
          enterSpring: PrismSpring(response: Duration(milliseconds: 100)),
        ),
      ),
    );
    expect(merged.itemTransition, PrismTransition.identity);
    expect(merged.groupSpacing, 6);
    expect(merged.itemTransitionStyle!.contentBlur, 2);
    expect(
      merged.itemTransitionStyle!.enterSpring!.response,
      const Duration(milliseconds: 100),
    );
    expect(base.copyWith(groupSpacing: 0).groupSpacing, 0);
  });

  testWidgets('an entering item holds its final size and place, and blurs in', (
    tester,
  ) async {
    Widget group(List<PrismToolbarItem> items) => CupertinoApp(
      home: Align(
        alignment: Alignment.topRight,
        child: PrismToolbar.group(
          size: PrismToolbarSize.navigation,
          items: items,
        ),
      ),
    );
    final icon = find.descendant(
      of: find.bySemanticsLabel('Edit'),
      matching: find.byType(Icon),
    );
    await tester.pumpWidget(group([item('Share'), item('Edit')]));
    await tester.pumpAndSettle();
    final settled = tester.getRect(icon);

    await tester.pumpWidget(group([item('Share')]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(group([item('Share'), item('Edit')]));
    for (final ms in [40, 80, 120]) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getRect(icon), settled, reason: 'at $ms ms');
      final blur = tester
          .widgetList<ImageFiltered>(
            find.ancestor(of: icon, matching: find.byType(ImageFiltered)),
          )
          .first;
      expect(blur.enabled, isTrue, reason: 'it sharpens in at $ms ms');
    }
    expect(
      find
          .ancestor(of: icon, matching: find.byType(Transform))
          .evaluate()
          .where((e) => !(e.widget as Transform).transform.isIdentity()),
      isEmpty,
      reason: 'nothing scales or slides the item',
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(icon), settled);
  });

  testWidgets('a leading-aligned group pins entering items to its start', (
    tester,
  ) async {
    Widget group(List<PrismToolbarItem> items) => CupertinoApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: PrismToolbar.group(
          size: PrismToolbarSize.navigation,
          items: items,
        ),
      ),
    );
    final icon = find.descendant(
      of: find.bySemanticsLabel('Edit'),
      matching: find.byType(Icon),
    );
    await tester.pumpWidget(group([item('Share'), item('Edit'), item('More')]));
    await tester.pumpAndSettle();
    final settled = tester.getRect(icon);
    await tester.pumpWidget(group([item('Share'), item('More')]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(group([item('Share'), item('Edit'), item('More')]));

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getRect(icon), settled);
    }
  });
}
