import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  _motionTests();
  testWidgets(
    'tabs select once and update semantic foreground with live theme',
    (tester) async {
      var selected = 0;
      var changes = 0;
      var brightness = Brightness.dark;
      Color? tint;
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
                tint: tint,
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
      update(() => tint = const Color(0xFFAA00CC));
      await tester.pump();
      expect(textColor('Favorites'), const Color(0xFFAA00CC));
      tester.semantics.tap(find.semantics.byLabel('Settings'));
      await tester.pump();
      expect(changes, 2);
      expectSelection('Settings');
      expect(textColor('Settings'), const Color(0xFFAA00CC));
      update(() => tint = null);
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
    'drag previews without selecting and commits one projected destination on release',
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
      await tester.pump();
      expect(_pill(tester).center.dx, greaterThan(origin + 40));
      expect(state.requests, isEmpty);
      _expectSelected(tester, 0);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(state.requests, [1]);
      expect(_pill(tester).center.dx, tester.getCenter(_tab('Favorites')).dx);
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
      expect(state.requests, [1, 2]);
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
    'vertical scroll and overlapping pointers cancel before release',
    (tester) async {
      final state = await _mountTabs(tester, scrollable: true);
      final restingWidth = _pill(tester).width;
      var pointer = await tester.startGesture(
        tester.getCenter(_tab('Favorites')),
      );
      await pointer.moveBy(const Offset(0, -40));
      await pointer.moveBy(const Offset(0, -30));
      await tester.pumpAndSettle();
      expect(state.scroll.offset, greaterThan(0));
      expect(_pill(tester).width, restingWidth);
      expect(_pill(tester).center.dx, tester.getCenter(_tab('Gallery')).dx);
      await pointer.up();
      expect(state.requests, isEmpty);
      state.scroll.jumpTo(0);
      await tester.pump();
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
