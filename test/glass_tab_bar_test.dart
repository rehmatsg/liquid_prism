import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/pressable.dart';
import 'package:liquid_prism/src/recipe.dart';

import 'support/rendering.dart';

void main() {
  _motionTests();
  _scaleBeneathFilterTest();
  _rimTests();
  testWidgets(
    'tabs select once and update semantic foreground with live theme',
    (tester) async {
      var selected = 0;
      var changes = 0;
      var brightness = Brightness.dark;
      Color? foreground;
      late StateSetter update;
      final imageKey = GlobalKey();
      await tester.pumpWidget(
        glassHarness(
          imageKey: imageKey,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LiquidPrismTheme(
                brightness: brightness,
                data: LiquidPrismThemeData(foregroundColor: foreground),
                child: LiquidPrismTabBar(
                  tabs: const [
                    LiquidPrismTab(
                      label: 'Gallery',
                      icon: SizedBox(width: 25, height: 25),
                    ),
                    LiquidPrismTab(
                      label: 'Favorites',
                      icon: SizedBox(width: 25, height: 25),
                    ),
                    LiquidPrismTab(
                      label: 'Settings',
                      icon: SizedBox(width: 25, height: 25),
                    ),
                  ],
                  selectedIndex: selected,
                  onSelected: (index) => setState(() {
                    selected = index;
                    changes++;
                  }),
                ),
              );
            },
          ),
        ),
      );
      Color? textColor(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;
      void expectSelection(String selectedLabel) {
        for (final label in ['Gallery', 'Favorites', 'Settings']) {
          final node = tester.getSemantics(find.bySemanticsLabel(label));
          expect(node.label, label);
          expect(node.flagsCollection.isButton, isTrue);
          expect(
            node.flagsCollection.isSelected,
            label == selectedLabel ? ui.Tristate.isTrue : ui.Tristate.isFalse,
          );
        }
      }

      expectSelection('Gallery');
      final darkAccent = textColor('Gallery');
      final darkLabel = textColor('Favorites');
      expect(darkAccent, isNot(darkLabel));
      await tester.tap(find.bySemanticsLabel('Favorites'));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expectSelection('Favorites');
      expect(textColor('Favorites'), darkAccent);
      expect(textColor('Gallery'), darkLabel);
      update(() => brightness = Brightness.light);
      await tester.pump();
      expect(textColor('Gallery'), isNot(darkLabel));
      expect(textColor('Favorites'), isNot(darkAccent));
      update(() => foreground = const Color(0xFFAA00CC));
      await tester.pump();
      expect(textColor('Favorites'), const Color(0xFFAA00CC));
      tester.semantics.tap(find.semantics.byLabel('Settings'));
      await tester.pump();
      expect(changes, 2);
      expectSelection('Settings');
      // The selected colour travels with the pill and lands when it settles.
      await tester.pumpAndSettle();
      expect(textColor('Settings'), const Color(0xFFAA00CC));
      update(() => foreground = null);
      await tester.pump();
      expect(textColor('Settings'), isNot(const Color(0xFFAA00CC)));
    },
  );
}

const _names = ['Gallery', 'Favorites', 'Settings'];
Finder _tab(String name) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == name,
);
Rect _pill(WidgetTester tester) =>
    tester.getRect(find.byType(LiquidPrismSelection));

class _TabHarness extends StatefulWidget {
  const _TabHarness({super.key, this.scrollable = false});
  final bool scrollable;
  @override
  State<_TabHarness> createState() => _TabHarnessState();
}

class _TabHarnessState extends State<_TabHarness> {
  final barKey = GlobalKey();
  final scroll = ScrollController();
  final requests = <int>[];
  int selected = 0, count = 3;
  bool accept = true, enabled = true, reduced = false, rtl = false;
  bool show = true, reparent = false;
  double width = 360, textScale = 1;
  GlassMotion? motion;
  LiquidPrismThemeData theme = const LiquidPrismThemeData();
  GlassTabBarStyle style = const GlassTabBarStyle(
    expanded: true,
    padding: EdgeInsets.zero,
    labelBehavior: GlassTabLabelBehavior.never,
    haptics: false,
  );
  void update(VoidCallback change) => setState(change);
  @override
  Widget build(BuildContext context) {
    final bar = SizedBox(
      width: width,
      child: KeyedSubtree(
        key: ValueKey(reparent),
        child: show
            ? LiquidPrismTabBar(
                key: barKey,
                tabs: [
                  for (var i = 0; i < count; i++)
                    LiquidPrismTab(
                      label: _names[i],
                      icon: SizedBox(
                        key: ValueKey('icon-$i'),
                        width: 22,
                        height: 22,
                      ),
                      selectedIcon: SizedBox(
                        key: ValueKey('selected-icon-$i'),
                        width: 22,
                        height: 22,
                      ),
                    ),
                ],
                selectedIndex: selected,
                motion: motion,
                style: style,
                onSelected: enabled
                    ? (index) {
                        requests.add(index);
                        if (accept) setState(() => selected = index);
                      }
                    : null,
              )
            : const SizedBox.shrink(),
      ),
    );
    return WidgetsApp(
      color: const Color(0xFF666666),
      builder: (context, _) => MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(textScale),
          platformBrightness: Brightness.dark,
        ),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: LiquidPrismTheme(
            data: theme,
            child: widget.scrollable
                ? SingleChildScrollView(
                    controller: scroll,
                    child: Column(
                      children: [
                        const SizedBox(height: 80),
                        bar,
                        const SizedBox(height: 1400),
                      ],
                    ),
                  )
                : Center(child: bar),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }
}

Future<_TabHarnessState> _mountTabs(
  WidgetTester tester, {
  bool scrollable = false,
}) async {
  final key = GlobalKey<_TabHarnessState>();
  await tester.pumpWidget(_TabHarness(key: key, scrollable: scrollable));
  return key.currentState!;
}

void _expectSelected(WidgetTester tester, int selected) {
  for (var i = 0; i < 3; i++) {
    final node = tester.getSemantics(_tab(_names[i]));
    expect(node.label, _names[i]);
    expect(
      node.flagsCollection.isSelected,
      i == selected ? ui.Tristate.isTrue : ui.Tristate.isFalse,
    );
  }
}

void _motionTests() {
  testWidgets('dark held tab highlight has no concentrated white hotspot', (
    tester,
  ) async {
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      glassHarness(
        imageKey: imageKey,
        background: const Color(0xFF151B20),
        child: LiquidPrismTabBar(
          tabs: const [
            LiquidPrismTab(label: 'A', icon: SizedBox(width: 22, height: 22)),
            LiquidPrismTab(label: 'B', icon: SizedBox(width: 22, height: 22)),
            LiquidPrismTab(label: 'C', icon: SizedBox(width: 22, height: 22)),
          ],
          style: const GlassTabBarStyle(
            labelBehavior: GlassTabLabelBehavior.never,
            haptics: false,
          ),
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ),
    );
    final finger = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('A')),
    );
    await tester.pumpAndSettle();
    final centre =
        _pill(tester).center - tester.getTopLeft(find.byKey(imageKey));
    final pixels = await pixelsAt(tester, imageKey, [
      centre,
      centre + const Offset(24, 0),
    ]);
    // Blank icons isolate the halo. Native's broad blur changes gently across
    // the face; a white gradient at the contact produces a steep bright spot.
    for (var channel = 0; channel < 3; channel++) {
      expect((pixels[0][channel] - pixels[1][channel]).abs(), lessThan(12));
    }
    await finger.up();
    await tester.pumpAndSettle();
  });
  testWidgets('fast tab drag retains the researched stretch and stop recoil', (
    tester,
  ) async {
    final state = await _mountTabs(tester);
    state.update(() {
      state.width = 274;
    });
    await tester.pump();
    final start = tester.getCenter(_tab('Gallery'));
    final finger = await tester.startGesture(start);
    await tester.pumpAndSettle();
    final held = _pill(tester).size;
    var widest = held.width, shortest = held.height;
    for (var i = 1; i <= 10; i++) {
      await finger.moveTo(start + Offset(16.0 * i, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final size = _pill(tester).size;
      if (size.width > widest) widest = size.width;
      if (size.height < shortest) shortest = size.height;
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final size = _pill(tester).size;
      if (size.width > widest) widest = size.width;
      if (size.height < shortest) shortest = size.height;
    }
    expect(widest, greaterThan(held.width + 10));
    expect(shortest, lessThan(held.height - 10));
    await tester.pumpAndSettle();
    expect(_pill(tester).width, closeTo(held.width, .1));
    expect(_pill(tester).height, closeTo(held.height, .1));
    await finger.cancel();
    await tester.pumpAndSettle();
    expect(state.requests, isEmpty);
  });
  testWidgets('held lens matches the native 94 to 110 point lift', (
    tester,
  ) async {
    final state = await _mountTabs(tester);
    state.update(() {
      state.width = 274;
      state.style = const GlassTabBarStyle(haptics: false, expanded: true);
    });
    await tester.pump();
    expect(_pill(tester).size, const Size(94, 54));
    final gesture = await tester.startGesture(
      tester.getCenter(_tab('Gallery')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(_pill(tester).width, closeTo(115.7, .3));
    expect(_pill(tester).height, closeTo(73.6, .3));
    final housing = find.byWidgetPredicate(
      (widget) => widget is LiquidPrism && widget.role == GlassRole.tabBar,
    );
    expect(
      LiquidPrismPressFeedback.scaleOf(tester.element(housing)),
      closeTo(1 + 14.1379310344828 / 274, .001),
    );
    for (var i = 0; i < 3; i++) {
      final icon = find.byKey(
        ValueKey(i == 0 ? 'selected-icon-$i' : 'icon-$i'),
      );
      for (final foreground in [icon, find.text(_names[i])]) {
        final box = tester.renderObject<RenderBox>(foreground);
        expect(
          box.getTransformTo(null).getMaxScaleOnAxis(),
          closeTo(1 + 14.1379310344828 / 274, .001),
        );
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_pill(tester).size, const Size(94, 54));
  });

  testWidgets(
    'four-tab-width housing uses the directly read native transform',
    (tester) async {
      final state = await _mountTabs(tester);
      state.update(() {
        state.width = 360;
        state.style = const GlassTabBarStyle(haptics: false, expanded: true);
      });
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(_tab('Gallery')),
      );
      await tester.pumpAndSettle();
      final housing = find.byWidgetPredicate(
        (widget) => widget is LiquidPrism && widget.role == GlassRole.tabBar,
      );
      final box = tester.renderObject<RenderBox>(housing);
      // Glass applies its flex scale inside its renderer, while the
      // foreground exposes the same transform as a RenderTransform.
      final foreground = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('selected-icon-0')),
      );
      final transform = foreground.getTransformTo(null);
      final size = MatrixUtils.transformRect(
        transform,
        Offset.zero & box.size,
      ).size;
      // UIKit presentation read: 360 × 62 at 1.039272030651341.
      expect(size.width, closeTo(374.1379310344828, .001));
      expect(size.height, closeTo(64.4348659003831, .001));
      await gesture.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('quick tap completes the tall launch and wide arrival', (
    tester,
  ) async {
    final state = await _mountTabs(tester);
    state.update(() {
      state.width = 274;
      state.style = const GlassTabBarStyle(haptics: false, expanded: true);
    });
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(_tab('Favorites')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 65));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 85));
    final launch = _pill(tester);
    expect(launch.height, greaterThan(72));
    expect(launch.width, lessThan(104));
    await tester.pump(const Duration(milliseconds: 175));
    final arrival = _pill(tester);
    expect(arrival.width, greaterThan(launch.width + 10));
    expect(arrival.height, lessThan(launch.height - 10));
    expect(state.requests, [1]);
    await tester.pumpAndSettle();
    expect(_pill(tester).size, const Size(94, 54));
  });

  testWidgets('continuous pointer samples advance the spring on every frame', (
    tester,
  ) async {
    await _mountTabs(tester);
    final start = tester.getCenter(_tab('Gallery'));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    var previous = _pill(tester).center.dx;
    for (var i = 1; i <= 18; i++) {
      await gesture.moveTo(start + Offset(i * 6, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final current = _pill(tester).center.dx;
      if (i > 5) expect(current, greaterThan(previous));
      previous = current;
    }
    expect(previous, greaterThan(start.dx + 65));
    final beforeRelease = _pill(tester).size;
    await gesture.up();
    await tester.pump();
    expect(_pill(tester).width, closeTo(beforeRelease.width, .01));
    expect(_pill(tester).height, closeTo(beforeRelease.height, .01));
    await tester.pumpAndSettle();
  });

  testWidgets('semantic retarget preserves the moving pill velocity', (
    tester,
  ) async {
    await _mountTabs(tester);
    tester.semantics.tap(find.semantics.byLabel('Settings'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final earlier = _pill(tester).center.dx;
    await tester.pump(const Duration(milliseconds: 20));
    final before = _pill(tester).center.dx;
    expect(before, greaterThan(earlier));
    tester.semantics.tap(find.semantics.byLabel('Gallery'));
    await tester.pump();
    await tester.pump();
    expect(_pill(tester).center.dx, closeTo(before, .001));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      _pill(tester).center.dx,
      greaterThan(before),
      reason: 'Reversing the target must retain the current positive velocity',
    );
    await tester.pumpAndSettle();
    expect(_pill(tester).center.dx, tester.getCenter(_tab('Gallery')).dx);
  });
  testWidgets(
    'controlled requests reconcile rejection and interrupt a moving pill without jumping',
    (tester) async {
      final state = await _mountTabs(tester);
      final initial = _pill(tester);
      state.update(() => state.accept = false);
      await tester.pump();
      await tester.tap(_tab('Settings'));
      await tester.pumpAndSettle();
      expect(state.requests, [2]);
      expect(_pill(tester), initial);
      _expectSelected(tester, 0);
      state.update(() => state.accept = true);
      await tester.pump();
      await tester.tap(_tab('Settings'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final moving = _pill(tester).center.dx;
      expect(moving, greaterThan(initial.center.dx));
      expect(moving, lessThan(tester.getCenter(_tab('Settings')).dx));
      state.update(() => state.selected = 1);
      await tester.pump();
      expect(_pill(tester).center.dx, closeTo(moving, .001));
      await tester.pumpAndSettle();
      expect(_pill(tester).center.dx, tester.getCenter(_tab('Favorites')).dx);
      expect(state.requests, [2, 2]);
      await tester.tap(_tab('Favorites'));
      await tester.pumpAndSettle();
      expect(state.requests, [2, 2, 1]);
    },
  );

  testWidgets(
    'drag previews without selecting and commits the projected tab under the finger on release',
    (tester) async {
      final state = await _mountTabs(tester);
      state.update(() => state.motion = const GlassMotion(dragProjection: 0));
      await tester.pump();
      final origin = _pill(tester).center.dx;
      final pointer = await tester.startGesture(
        tester.getCenter(_tab('Favorites')),
      );
      await pointer.moveBy(const Offset(30, 0));
      await pointer.moveBy(const Offset(65, 0));
      // The lens chases the finger through a spring rather than following 1:1.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_pill(tester).center.dx, greaterThan(origin + 40));
      expect(state.requests, isEmpty);
      _expectSelected(tester, 0);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(state.requests, [2]);
      expect(_pill(tester).center.dx, tester.getCenter(_tab('Settings')).dx);
      state.update(() {
        state.selected = 0;
        state.motion = const GlassMotion(dragProjection: .12);
      });
      await tester.pumpAndSettle();
      await tester.flingFrom(
        tester.getCenter(_tab('Gallery')),
        const Offset(50, 0),
        1800,
      );
      await tester.pumpAndSettle();
      expect(state.requests, [2, 2]);
      _expectSelected(tester, 2);
    },
  );

  testWidgets(
    'RTL pointer keyboard and semantic actions follow visible order once',
    (tester) async {
      final state = await _mountTabs(tester);
      state.update(() => state.rtl = true);
      await tester.pump();
      expect(
        tester.getCenter(_tab('Gallery')).dx,
        greaterThan(tester.getCenter(_tab('Settings')).dx),
      );
      await tester.tap(_tab('Favorites'));
      await tester.pumpAndSettle();
      expect(state.requests, [1]);
      Focus.of(tester.element(find.byKey(const ValueKey('selected-icon-1'))))
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.requests, [1, 2]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(state.requests, [1, 2, 1]);
      final focused = FocusManager.instance.primaryFocus!;
      final focusedTab = _names.indexWhere(
        (name) => find
            .ancestor(
              of: find.byElementPredicate(
                (element) => element == focused.context,
              ),
              matching: _tab(name),
            )
            .evaluate()
            .isNotEmpty,
      );
      expect(focusedTab, isNonNegative);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        state.requests.sublist(3),
        [1, 1],
        reason:
            'Arrow selection was Favorites but focus stayed on ${_names[focusedTab]}',
      );
      tester.semantics.tap(find.semantics.byLabel('Settings'));
      await tester.pumpAndSettle();
      expect(state.requests.last, 2);
      expect(state.requests.length, 6);
      state.update(() => state.enabled = false);
      await tester.pump();
      expect(
        tester
            .getSemantics(_tab('Settings'))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      await tester.tap(_tab('Favorites'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state.requests.length, 6);
    },
  );

  testWidgets(
    'hidden labels preserve names and custom selected icons at large text',
    (tester) async {
      final state = await _mountTabs(tester);
      state.update(() {
        state.width = 240;
        state.textScale = 2;
      });
      await tester.pump();
      for (final behavior in GlassTabLabelBehavior.values) {
        state.update(
          () => state.style = GlassTabBarStyle(
            labelBehavior: behavior,
            haptics: false,
          ),
        );
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          expect(
            find.text(_names[i]),
            behavior == GlassTabLabelBehavior.always ||
                    (behavior == GlassTabLabelBehavior.selected &&
                        i == state.selected)
                ? findsOneWidget
                : findsNothing,
          );
        }
        _expectSelected(tester, state.selected);
        expect(
          find.byKey(ValueKey('selected-icon-${state.selected}')),
          findsOneWidget,
        );
        expect(find.byKey(ValueKey('icon-${state.selected}')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(_tab(_names[(state.selected + 1) % 3]));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'Reduce Motion changes stop spring scaling but keep direct drag and immediate settlement',
    (tester) async {
      final state = await _mountTabs(tester);
      final restingWidth = _pill(tester).width;
      final pointer = await tester.startGesture(
        tester.getCenter(_tab('Gallery')),
      );
      await tester.pumpAndSettle();
      expect(_pill(tester).width, greaterThan(restingWidth));
      state.update(() => state.reduced = true);
      await tester.pump();
      expect(_pill(tester).width, restingWidth);
      await pointer.moveBy(const Offset(30, 0));
      await pointer.moveBy(const Offset(70, 0));
      await tester.pump();
      expect(
        _pill(tester).center.dx,
        greaterThan(tester.getCenter(_tab('Gallery')).dx + 50),
      );
      expect(state.requests, isEmpty);
      await pointer.up();
      await tester.pump();
      expect(state.requests, [1]);
      expect(_pill(tester).center.dx, tester.getCenter(_tab('Favorites')).dx);
      final settled = _pill(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_pill(tester), settled);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'a contact owns the drag against an ancestor scroll; overlapping pointers cancel',
    (tester) async {
      final state = await _mountTabs(tester, scrollable: true);
      final restingWidth = _pill(tester).width;
      // A touch on the bar belongs to it: a vertical drag does not scroll the
      // list, and the pill stays lifted on the touched tab until release.
      var pointer = await tester.startGesture(
        tester.getCenter(_tab('Favorites')),
      );
      await pointer.moveBy(const Offset(0, -40));
      await pointer.moveBy(const Offset(0, -30));
      await tester.pumpAndSettle();
      expect(state.scroll.offset, 0);
      expect(_pill(tester).width, greaterThan(restingWidth));
      expect(_pill(tester).center.dx, tester.getCenter(_tab('Favorites')).dx);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(state.requests, [1]);
      // Outside the bar the list still scrolls.
      await tester.dragFrom(const Offset(20, 400), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(state.scroll.offset, greaterThan(0));
      state.scroll.jumpTo(0);
      state.update(() {
        state.selected = 0;
        state.requests.clear();
      });
      await tester.pumpAndSettle();
      pointer = await tester.startGesture(
        tester.getCenter(_tab('Gallery')),
        pointer: 1,
      );
      await pointer.moveBy(const Offset(50, 0));
      final second = await tester.startGesture(
        tester.getCenter(_tab('Settings')),
        pointer: 2,
      );
      await tester.pumpAndSettle();
      await pointer.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(state.requests, isEmpty);
      await tester.tap(_tab('Favorites'));
      await tester.pumpAndSettle();
      expect(state.requests, [1]);
    },
  );

  for (final degrees in [30.0, 60.0]) {
    testWidgets(
      'a drag $degrees degrees off the bar axis selects inside a list',
      (tester) async {
        final state = await _mountTabs(tester, scrollable: true);
        final from = tester.getCenter(_tab('Gallery'));
        final along = tester.getCenter(_tab('Settings')).dx - from.dx;
        final across = along * math.tan(degrees * math.pi / 180);
        final pointer = await tester.startGesture(from);
        for (var i = 1; i <= 10; i++) {
          await pointer.moveTo(from + Offset(along * i / 10, across * i / 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          _pill(tester).center.dx,
          greaterThan(tester.getCenter(_tab('Favorites')).dx),
        );
        expect(state.scroll.offset, 0);
        await pointer.up();
        await tester.pumpAndSettle();
        expect(state.requests, [2]);
        _expectSelected(tester, 2);
      },
    );
  }

  testWidgets('a quick flick without a hold selects the projected tab', (
    tester,
  ) async {
    final state = await _mountTabs(tester, scrollable: true);
    // About 40 points in under 30 ms: well past the touch slop, no hold.
    await tester.flingFrom(
      tester.getCenter(_tab('Gallery')),
      const Offset(40, -12),
      1500,
    );
    await tester.pumpAndSettle();
    expect(state.requests, [2]);
    expect(state.scroll.offset, 0);
    // Rejected by the parent: the pill settles back to the parent's tab.
    state.update(() => state.accept = false);
    await tester.flingFrom(
      tester.getCenter(_tab('Settings')),
      const Offset(-40, 8),
      1500,
    );
    await tester.pumpAndSettle();
    expect(state.requests, [2, 0]);
    _expectSelected(tester, 2);
    expect(_pill(tester).center.dx, tester.getCenter(_tab('Settings')).dx);
    // A cancelled drag commits nothing and settles on the selection.
    final pointer = await tester.startGesture(
      tester.getCenter(_tab('Settings')),
    );
    await pointer.moveBy(const Offset(-150, 30));
    await tester.pump(const Duration(milliseconds: 100));
    await pointer.cancel();
    await tester.pumpAndSettle();
    expect(state.requests, [2, 0]);
    expect(_pill(tester).center.dx, tester.getCenter(_tab('Settings')).dx);
  });

  testWidgets(
    'disabled contacts and external updates reject stale commits across reenabling',
    (tester) async {
      final state = await _mountTabs(tester);
      for (final beganDisabled in [false, true]) {
        state.update(() => state.enabled = !beganDisabled);
        await tester.pump();
        final first = await tester.startGesture(
          tester.getCenter(_tab('Gallery')),
          pointer: 1,
        );
        if (!beganDisabled) {
          state.update(() => state.enabled = false);
          await tester.pump();
        }
        state.update(() => state.enabled = true);
        await tester.pump();
        final second = await tester.startGesture(
          tester.getCenter(_tab('Settings')),
          pointer: 2,
        );
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
        expect(state.requests, isEmpty);
      }
      final pointer = await tester.startGesture(
        tester.getCenter(_tab('Gallery')),
      );
      await pointer.moveBy(const Offset(60, 0));
      await tester.pump();
      state.update(() => state.selected = 2);
      await tester.pump();
      await pointer.up();
      await tester.pumpAndSettle();
      expect(state.requests, isEmpty);
      expect(_pill(tester).center.dx, tester.getCenter(_tab('Settings')).dx);
      await tester.tap(_tab('Favorites'));
      await tester.pumpAndSettle();
      expect(state.requests, [1]);
    },
  );

  testWidgets(
    'resize reparent and removal cancel a held drag without later actions',
    (tester) async {
      final state = await _mountTabs(tester);
      for (final action in ['resize', 'reparent', 'remove']) {
        final pointer = await tester.startGesture(
          tester.getCenter(_tab('Gallery')),
        );
        await pointer.moveBy(const Offset(80, 0));
        await tester.pump();
        state.update(() {
          switch (action) {
            case 'resize':
              state.width = 300;
            case 'reparent':
              state.reparent = true;
            case 'remove':
              state.show = false;
          }
        });
        await tester.pump();
        await pointer.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: action);
        expect(state.requests, isEmpty, reason: action);
        if (action != 'remove') {
          expect(_pill(tester).center.dx, tester.getCenter(_tab('Gallery')).dx);
        }
      }
    },
  );

  testWidgets('unchanged custom icon state survives selection styling', (
    tester,
  ) async {
    final creations = <int, int>{};
    var selected = 0;
    var light = false;
    var customized = false;
    late StateSetter rebuild;
    final tabs = [
      for (var i = 0; i < 3; i++)
        LiquidPrismTab(
          label: _names[i],
          icon: _StatefulIcon(
            onCreate: () =>
                creations.update(i, (value) => value + 1, ifAbsent: () => 1),
          ),
        ),
    ];
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF666666),
        builder: (context, _) => Center(
          child: SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (context, update) {
                rebuild = update;
                return LiquidPrismTheme(
                  brightness: light ? Brightness.light : Brightness.dark,
                  child: LiquidPrismTabBar(
                    tabs: tabs,
                    selectedIndex: selected,
                    style: GlassTabBarStyle(
                      haptics: false,
                      labelBehavior: customized
                          ? GlassTabLabelBehavior.never
                          : GlassTabLabelBehavior.always,
                      selectedColor: customized
                          ? const Color(0xFFAA00CC)
                          : null,
                      labelStyle: customized
                          ? const TextStyle(color: Color(0xFFDD8800))
                          : null,
                    ),
                    onSelected: (index) => update(() => selected = index),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(creations, {0: 1, 1: 1, 2: 1});
    await tester.tap(_tab('Favorites'));
    await tester.pumpAndSettle();
    expect(creations, {0: 1, 1: 1, 2: 1});
    rebuild(() {
      light = true;
      customized = true;
    });
    await tester.pump();
    expect(creations, {0: 1, 1: 1, 2: 1});
    for (var i = 0; i < _names.length; i++) {
      final node = tester.getSemantics(_tab(_names[i]));
      expect(node.label, _names[i]);
      expect(
        node.flagsCollection.isSelected,
        i == selected ? ui.Tristate.isTrue : ui.Tristate.isFalse,
      );
      expect(find.text(_names[i]), findsNothing);
    }
    await tester.tap(_tab('Gallery'));
    await tester.pumpAndSettle();
    expect(creations, {0: 1, 1: 1, 2: 1});
    rebuild(() => customized = false);
    await tester.pump();
    expect(creations, {0: 1, 1: 1, 2: 1});
    final held = await tester.startGesture(tester.getCenter(_tab('Gallery')));
    await tester.pumpAndSettle();
    await held.moveBy(const Offset(86, 0));
    await tester.pumpAndSettle();
    expect(creations, {0: 1, 1: 1, 2: 1});
    await held.up();
    await tester.pumpAndSettle();
    expect(creations, {0: 1, 1: 1, 2: 1});
    expect(tester.getSemantics(_tab('Gallery')).label, 'Gallery');
  });
}

class _StatefulIcon extends StatefulWidget {
  const _StatefulIcon({required this.onCreate});
  final VoidCallback onCreate;
  @override
  State<_StatefulIcon> createState() => _StatefulIconState();
}

class _StatefulIconState extends State<_StatefulIcon> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: ColoredBox(color: Color(0xFF0088FF)),
  );
}

void _scaleBeneathFilterTest() {
  testWidgets(
    'held tabs scale beneath the content filter, not under a transform',
    (tester) async {
      await tester.pumpWidget(
        glassHarness(
          imageKey: GlobalKey(),
          child: LiquidPrismTabBar(
            tabs: const [
              LiquidPrismTab(
                label: 'Gallery',
                icon: SizedBox(width: 25, height: 25),
              ),
              LiquidPrismTab(
                label: 'Favorites',
                icon: SizedBox(width: 25, height: 25),
              ),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      final label = find.text('Favorites');
      final rest = tester.getRect(label);
      final hold = await tester.startGesture(tester.getCenter(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // The housing's flex still reaches the foreground...
      final held = tester.getRect(label);
      expect(held.width, greaterThan(rest.width));
      // ...but no ancestor transform scales it: an animating scale above the
      // refraction filter made the selected copy pop between device pixels.
      for (final transform in tester.widgetList<Transform>(
        find.ancestor(of: label, matching: find.byType(Transform)),
      )) {
        expect(transform.transform.getMaxScaleOnAxis(), 1);
      }
      await hold.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(label), rest);
    },
  );
}

void _rimTests() {
  Finder lensGlass(GlassRole role) => find.byWidgetPredicate(
    (widget) => widget is LiquidPrism && widget.role == role,
  );

  test('the pill rim reaches the shader slot and survives presence', () {
    final recipe = GlassRecipe.resolve(
      Glass.clear,
      Brightness.dark,
      GlassRole.tabLens,
      customOptics: false,
    );
    // u_state.w, slot 45 overall (19 into the recipe packet), stays zero for
    // every surface that does not ask for it.
    expect(recipe.uniforms[19], 0);
    final rim = recipe.withLensRim(.8).withPresence(.5);
    expect(rim.uniforms[19], .8);
    expect(rim.uniforms[18], .5);
  });

  testWidgets('held pill rim resolves widget style over theme, keeps zero', (
    tester,
  ) async {
    Future<double> heldRim({
      GlassTabBarStyle? theme,
      GlassTabBarStyle? style,
    }) async {
      await tester.pumpWidget(
        glassHarness(
          imageKey: GlobalKey(),
          child: LiquidPrismTheme(
            data: LiquidPrismThemeData(tabBar: theme),
            child: LiquidPrismTabBar(
              tabs: const [
                LiquidPrismTab(
                  label: 'A',
                  icon: SizedBox(width: 22, height: 22),
                ),
                LiquidPrismTab(
                  label: 'B',
                  icon: SizedBox(width: 22, height: 22),
                ),
              ],
              style: style,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('A')),
      );
      await tester.pumpAndSettle();
      final rim = tester.widget<LiquidPrism>(lensGlass(GlassRole.tabLens));
      // Only the pill carries it; the housing keeps the shared recipe.
      expect(
        tester.widget<LiquidPrism>(lensGlass(GlassRole.tabBar)).lensRim,
        0,
      );
      await finger.up();
      await tester.pumpAndSettle();
      expect(lensGlass(GlassRole.tabLens), findsNothing);
      return rim.lensRim;
    }

    expect(await heldRim(), 1);
    const half = GlassTabBarStyle(rimRefraction: .5);
    expect(await heldRim(theme: half), .5);
    expect(
      await heldRim(
        theme: half,
        style: const GlassTabBarStyle(rimRefraction: 0),
      ),
      0,
    );
    expect(
      half.merge(const GlassTabBarStyle(haptics: false)).rimRefraction,
      .5,
    );
    expect(half.copyWith(rimRefraction: 0).rimRefraction, 0);
  });

  testWidgets('shared lenses outside the tab bar carry no pill rim', (
    tester,
  ) async {
    var on = false;
    await tester.pumpWidget(
      glassHarness(
        imageKey: GlobalKey(),
        child: LiquidPrismTheme(
          data: const LiquidPrismThemeData(
            tabBar: GlassTabBarStyle(rimRefraction: 2),
          ),
          child: StatefulBuilder(
            builder: (context, update) => LiquidPrismSwitch(
              value: on,
              onChanged: (value) => update(() => on = value),
            ),
          ),
        ),
      ),
    );
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(LiquidPrismSwitch)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final lenses = tester.widgetList<LiquidPrism>(find.byType(LiquidPrism));
    expect(lenses, isNotEmpty);
    for (final glass in lenses) {
      expect(glass.lensRim, 0);
    }
    await finger.up();
    await tester.pumpAndSettle();
  });

  testWidgets('touch glow is clipped to the expanded housing, not the rest', (
    tester,
  ) async {
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      glassHarness(
        imageKey: imageKey,
        background: const Color(0xFF151B20),
        child: LiquidPrismTabBar(
          tabs: const [
            LiquidPrismTab(label: 'A', icon: SizedBox(width: 22, height: 22)),
            LiquidPrismTab(label: 'B', icon: SizedBox(width: 22, height: 22)),
          ],
          style: const GlassTabBarStyle(
            labelBehavior: GlassTabLabelBehavior.never,
            haptics: false,
          ),
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ),
    );
    final housing = tester.getRect(lensGlass(GlassRole.tabBar));
    final finger = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('A')),
    );
    await tester.pumpAndSettle();
    // Hold between the tabs: the lens and its glow sit at the centre, and the
    // housing's resting top edge lies inside the expanded housing beside it.
    await finger.moveTo(housing.center);
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byKey(imageKey));
    final x = housing.center.dx + 62;
    final pixels = await pixelsAt(tester, imageKey, [
      Offset(x, housing.top - 1) - origin,
      Offset(x, housing.top + 1) - origin,
    ]);
    // Clipped to the resting contour, the glow ended in a hard edge inside
    // the expanded housing: a second rim with a lighter patch within it.
    for (var channel = 0; channel < 3; channel++) {
      expect((pixels[0][channel] - pixels[1][channel]).abs(), lessThan(6));
    }
    await finger.up();
    await tester.pumpAndSettle();
  });
}
