import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/recipe.dart';

Widget host(
  Widget child, {
  LiquidPrismThemeData theme = const LiquidPrismThemeData(),
}) => CupertinoApp(
  home: LiquidPrismTheme(
    data: theme,
    child: Center(
      child: SizedBox(width: 300, child: Align(heightFactor: 1, child: child)),
    ),
  ),
);

void main() {
  test('partial component themes preserve nested fields, false and zero', () {
    const base = LiquidPrismThemeData(
      lens: GlassLensStyle(shadow: false, shadowBlur: 7),
      slider: GlassSliderStyle(
        trackHeight: 8,
        lens: GlassLensStyle(blur: 2, shadow: true),
      ),
      toolbar: GlassToolbarStyle(spacing: 14),
      controlMotion: GlassControlMotion(maxStretch: .08),
    );
    final merged = base.merge(
      const LiquidPrismThemeData(
        slider: GlassSliderStyle(lens: GlassLensStyle(blur: 0, shadow: false)),
        toolbar: GlassToolbarStyle(spacing: 0),
        controlMotion: GlassControlMotion(flexStrength: 0),
      ),
    );
    expect(merged.slider!.trackHeight, 8);
    expect(merged.slider!.lens!.blur, 0);
    expect(merged.slider!.lens!.shadow, false);
    expect(merged.lens!.shadowBlur, 7);
    expect(merged.toolbar!.spacing, 0);
    expect(merged.controlMotion!.maxStretch, .08);
    expect(merged.controlMotion!.flexStrength, 0);
    expect(
      merged.copyWith(tint: const Color(0xFF123456)).slider,
      same(merged.slider),
    );
    expect(
      const GlassTabBarStyle(expanded: true).copyWith(expanded: false).expanded,
      false,
    );
    const physical = GlassSpring.physical(
      SpringDescription(mass: 1, stiffness: 300, damping: 26),
    );
    expect(physical.copyWith().description.stiffness, 300);
    expect(
      physical.copyWith(response: const Duration(milliseconds: 500)).physics,
      isNull,
    );
  });

  testWidgets('switch scale and direct colors override component styles', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        LiquidPrismSwitch(
          value: true,
          onChanged: (_) {},
          activeColor: const Color(0xFFFF0000),
          style: const GlassSwitchStyle(
            scale: 2,
            activeColor: Color(0xFF00FF00),
          ),
        ),
        theme: const LiquidPrismThemeData(
          switchStyle: GlassSwitchStyle(activeColor: Color(0xFF0000FF)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(LiquidPrismSwitch)), const Size(126, 88));
    expect(tester.getSize(find.byType(LiquidPrism)), const Size(74, 48));
    final boxes = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(LiquidPrismSwitch),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(boxes.first.color, const Color(0xFFFF0000));
  });

  testWidgets(
    'slider style customizes geometry, lens and actual-value semantics',
    (tester) async {
      var value = 50.0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, update) => LiquidPrismSlider(
              value: value,
              min: 0,
              max: 100,
              divisions: 10,
              label: 'Level',
              semanticFormatterCallback: (v) => 'Level ${v.round()}',
              onChanged: (v) => update(() => value = v),
              style: const GlassSliderStyle(
                width: 160,
                thumbSize: Size(40, 20),
                heldScale: 2,
                lens: GlassLensStyle(
                  shape: GlassShape.roundedRect(cornerRadius: 4),
                  shadow: false,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(LiquidPrismSlider)).width, 160);
      final lens = find.byType(LiquidPrism);
      expect(
        tester.widget<LiquidPrism>(lens).shape,
        const GlassShape.roundedRect(cornerRadius: 4),
      );
      final semantics = tester.getSemantics(find.bySemanticsLabel('Level'));
      expect(semantics.value, 'Level 50');
      expect(semantics.increasedValue, 'Level 60');
      final contact = await tester.startGesture(tester.getCenter(lens));
      await tester.pumpAndSettle();
      expect(tester.getSize(lens), const Size(80, 40));
      await contact.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'component motion overrides theme and minimum lift keeps the cycle open',
    (tester) async {
      var value = false;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, update) => LiquidPrismSwitch(
              value: value,
              onChanged: (v) => update(() => value = v),
              motion: const GlassControlMotion(
                minimumLiftDuration: Duration(milliseconds: 500),
              ),
            ),
          ),
          theme: const LiquidPrismThemeData(
            controlMotion: GlassControlMotion(
              travel: GlassSpring(response: Duration(seconds: 2), bounce: 0),
            ),
          ),
        ),
      );
      final lens = find.byType(LiquidPrism);
      final start = tester.getCenter(lens);
      await tester.tap(find.byType(LiquidPrismSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(value, true);
      expect(tester.getCenter(lens).dx - start.dx, lessThan(5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(lens).width, closeTo(58, 1));
      await tester.pumpAndSettle();
      expect(tester.getSize(lens), const Size(37, 24));
    },
  );

  testWidgets(
    'toolbar zero spacing and icon button convenience honor the theme',
    (tester) async {
      await tester.pumpWidget(
        host(
          LiquidPrismToolbarGroup(
            items: [
              GlassToolbarItem(
                icon: const Icon(CupertinoIcons.star),
                label: 'Star',
                onPressed: () {},
              ),
              GlassToolbarItem(
                icon: const Icon(CupertinoIcons.share),
                label: 'Share',
                onPressed: () {},
              ),
            ],
            style: const GlassToolbarStyle(spacing: 0, inset: 0, iconSize: 19),
          ),
          theme: const LiquidPrismThemeData(
            toolbar: GlassToolbarStyle(spacing: 30),
          ),
        ),
      );
      expect(tester.getSize(find.byType(LiquidPrism)).width, 76);
      expect(
        IconTheme.of(tester.element(find.byIcon(CupertinoIcons.star))).size,
        19,
      );
      await tester.pumpWidget(
        host(
          LiquidPrismButton.icon(
            icon: const Icon(CupertinoIcons.heart),
            label: 'Favorite',
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(LiquidPrism)), const Size(48, 48));
      expect(
        tester.widget<LiquidPrism>(find.byType(LiquidPrism)).shape,
        GlassShape.circle,
      );
    },
  );

  testWidgets(
    'search forwards editor behavior and honors literal widget overrides',
    (tester) async {
      await tester.pumpWidget(
        host(
          LiquidPrismSearchField(
            showCancelButton: false,
            restingInset: 0,
            style: const TextStyle(fontSize: 21),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            readOnly: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            prefix: const Text('Find'),
            appearance: const GlassSearchStyle(
              height: 52,
              textStyle: TextStyle(fontSize: 19),
            ),
          ),
          theme: const LiquidPrismThemeData(
            search: GlassSearchStyle(restingInset: 20, showCancelButton: true),
          ),
        ),
      );
      final editor = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(editor.style!.fontSize, 21);
      expect(editor.keyboardType, TextInputType.number);
      expect(editor.textInputAction, TextInputAction.done);
      expect(editor.readOnly, true);
      expect(editor.autocorrect, false);
      expect(editor.inputFormatters!.length, 1);
      expect(find.text('Find'), findsOneWidget);
      expect(find.bySemanticsLabel('Cancel search'), findsNothing);
      expect(tester.getSize(find.byType(LiquidPrism)).width, 300);
    },
  );

  testWidgets('segmented styles and tab layout can be tuned independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        LiquidPrismSegmentedControl<int>(
          selectedValue: 0,
          onValueChanged: (_) {},
          children: const {0: Text('A'), 1: Text('B')},
          style: const GlassSegmentedStyle(
            width: 180,
            thumbHeight: 30,
            selectionInset: 3,
            labelStyle: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(LiquidPrismSegmentedControl<int>)).width,
      180,
    );
    expect(tester.getSize(find.byType(LiquidPrism)), const Size(84, 30));
    await tester.pumpWidget(
      host(
        LiquidPrismTabBar(
          selectedIndex: 0,
          onSelected: (_) {},
          tabs: const [
            LiquidPrismTab(label: 'A', icon: Icon(CupertinoIcons.star)),
            LiquidPrismTab(label: 'B', icon: Icon(CupertinoIcons.heart)),
          ],
          style: const GlassTabBarStyle(
            minimumTabWidth: 70,
            labelPadding: 10,
            refractContent: false,
          ),
        ),
      ),
    );
    final housing = find.byType(LiquidPrism).first;
    expect(tester.getSize(housing).width, 156);
  });

  testWidgets('phase callbacks use public switch and segment values', (
    tester,
  ) async {
    var toggled = false;
    final phases = <String>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, update) => LiquidPrismSwitch(
            value: toggled,
            onChanged: (v) => update(() => toggled = v),
            onChangeStart: (v) => phases.add('start:$v'),
            onChangeEnd: (v) => phases.add('end:$v'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(LiquidPrismSwitch));
    await tester.pumpAndSettle();
    expect(phases, ['start:false', 'end:true']);
    phases.clear();
    var selected = 'left';
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, update) => LiquidPrismSegmentedControl<String>(
            children: const {'left': Text('Left'), 'right': Text('Right')},
            selectedValue: selected,
            onValueChanged: (v) => update(() => selected = v),
            onChangeStart: (v) => phases.add('start:$v'),
            onChangeEnd: (v) => phases.add('end:$v'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();
    expect(phases, ['start:left', 'end:right']);
  });

  testWidgets('custom cancel geometry and clear callbacks are applied', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Prism');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final changes = <String>[];
    var cleared = 0;
    await tester.pumpWidget(
      host(
        LiquidPrismSearchField(
          controller: controller,
          focusNode: focus,
          onChanged: changes.add,
          onCleared: () => cleared++,
          appearance: const GlassSearchStyle(
            cancelWidth: 64,
            cancelSpacing: 20,
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final editor = find.byType(CupertinoTextField);
    final cancel = find.bySemanticsLabel('Cancel search');
    expect(tester.getSize(editor).width, 216);
    expect(tester.getSize(cancel).width, 64);
    expect(tester.getTopLeft(cancel).dx - tester.getTopRight(editor).dx, 20);
    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(changes, ['']);
    expect(cleared, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lens optics frost is used unless blur is explicitly zero', (
    tester,
  ) async {
    var value = .5;
    GlassSliderStyle appearance = const GlassSliderStyle(
      lens: GlassLensStyle(optics: LiquidPrismStyle(frost: 3)),
    );
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidPrismSlider(
              value: value,
              onChanged: (v) => setState(() => value = v),
              style: appearance,
            );
          },
        ),
      ),
    );
    expect(tester.widget<LiquidPrism>(find.byType(LiquidPrism)).blur, 3);
    update(
      () => appearance = appearance.copyWith(
        lens: appearance.lens!.copyWith(blur: 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidPrism>(find.byType(LiquidPrism)).blur, 0);
  });
  testWidgets('direct segment foreground beats label-style color', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        LiquidPrismSegmentedControl<int>(
          selectedValue: 0,
          children: const {0: Text('One'), 1: Text('Two')},
          onValueChanged: (_) {},
          foregroundColor: const Color(0xFFFF0000),
          style: const GlassSegmentedStyle(
            labelStyle: TextStyle(color: Color(0xFF0000FF)),
          ),
        ),
      ),
    );
    for (final label in ['One', 'Two']) {
      expect(
        DefaultTextStyle.of(tester.element(find.text(label))).style.color,
        const Color(0xFFFF0000),
      );
    }
  });
  testWidgets('tab material arguments override local and themed packets', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        LiquidPrismTabBar(
          selectedIndex: 0,
          onSelected: (_) {},
          blur: 0,
          glass: Glass.clear,
          style: const GlassTabBarStyle(blur: 3, glass: Glass.regular),
          tabs: const [
            LiquidPrismTab(label: 'One', icon: Icon(CupertinoIcons.star)),
            LiquidPrismTab(label: 'Two', icon: Icon(CupertinoIcons.heart)),
          ],
        ),
        theme: const LiquidPrismThemeData(tabBar: GlassTabBarStyle(blur: 7)),
      ),
    );
    final bar = tester.widget<LiquidPrism>(find.byType(LiquidPrism).first);
    expect(bar.blur, 0);
    expect(bar.glass!.variant, GlassVariant.clear);
  });
  testWidgets('chrome optics frost wins over inherited blur', (tester) async {
    await tester.pumpWidget(
      host(
        LiquidPrismToolbarGroup(
          style: const GlassToolbarStyle(optics: LiquidPrismStyle(frost: 0)),
          items: [
            GlassToolbarItem(
              label: 'Add',
              icon: const Icon(CupertinoIcons.plus),
              onPressed: () {},
            ),
          ],
        ),
        theme: const LiquidPrismThemeData(blur: 7),
      ),
    );
    expect(tester.widget<LiquidPrism>(find.byType(LiquidPrism)).blur, 0);
  });
  testWidgets('held slider rim defaults and per-component lens precedence', (
    tester,
  ) async {
    LiquidPrismStyle held(GlassRole role) => tester
        .widget<LiquidPrism>(
          find.byWidgetPredicate(
            (widget) => widget is LiquidPrism && widget.role == role,
          ),
        )
        .optics!;
    Future<LiquidPrismStyle> hold(
      Widget control,
      GlassRole role, {
      LiquidPrismThemeData theme = const LiquidPrismThemeData(),
    }) async {
      await tester.pumpWidget(host(control, theme: theme));
      final finger = await tester.startGesture(
        tester.getCenter(find.byWidget(control)),
      );
      await tester.pumpAndSettle();
      final optics = held(role);
      await finger.up();
      await tester.pumpAndSettle();
      return optics;
    }

    final slider = LiquidPrismSlider(value: .5, onChanged: (_) {});
    // Measured held slider inputs at its 37.2-point lens height.
    var optics = await hold(slider, GlassRole.sliderLens);
    expect(optics.edgeWidth, closeTo(6.66, 1e-6));
    expect(optics.refraction, closeTo(11.1, 1e-6));
    expect(optics.tint.a, closeTo(.1, 1e-6));
    expect(optics.light, closeTo(1, 1e-6));

    // Theme and component lenses merge per field; explicit zero wins.
    optics = await hold(
      LiquidPrismSlider(
        value: .5,
        onChanged: (_) {},
        style: const GlassSliderStyle(
          lens: GlassLensStyle(faceBlack: 0, rimRefraction: 0),
        ),
      ),
      GlassRole.sliderLens,
      theme: const LiquidPrismThemeData(
        lens: GlassLensStyle(rimLight: .3, faceBlack: .4, rimWidth: 3.72),
      ),
    );
    expect(optics.tint.a, 0);
    expect(optics.refraction, 0);
    expect(optics.light, closeTo(.3, 1e-6));
    expect(optics.edgeWidth, closeTo(3.72, 1e-6));

    // The switch keeps its accepted lens unless it opts in.
    final toggle = LiquidPrismSwitch(value: false, onChanged: (_) {});
    optics = await hold(toggle, GlassRole.controlThumb);
    expect(optics.edgeWidth, closeTo(12 * (115 / 3) / 70, 1e-6));
    expect(optics.light, closeTo(.6, 1e-6));
    expect(optics.tint.a, 0);
    optics = await hold(
      LiquidPrismSwitch(
        value: false,
        onChanged: (_) {},
        style: const GlassSwitchStyle(lens: GlassLensStyle(faceBlack: .1)),
      ),
      GlassRole.controlThumb,
    );
    expect(optics.tint.a, closeTo(.1, 1e-6));
  });

  test('lens rim fields survive copyWith and merge', () {
    const base = GlassLensStyle(
      rimWidth: 5,
      rimRefraction: 8,
      rimLight: .8,
      faceBlack: .2,
      heldContactShadow: true,
    );
    final merged = base.merge(
      const GlassLensStyle(rimLight: 0, heldContactShadow: false),
    );
    expect(merged.rimWidth, 5);
    expect(merged.rimRefraction, 8);
    expect(merged.rimLight, 0);
    expect(merged.faceBlack, .2);
    expect(merged.heldContactShadow, false);
    final copy = merged.copyWith(faceBlack: 0);
    expect(copy.faceBlack, 0);
    expect(copy.rimLight, 0);
    expect(
      const GlassSliderStyle(haptics: false)
          .merge(const GlassSliderStyle(trackHeight: 4))
          .haptics,
      false,
    );
    expect(
      const GlassSliderStyle(haptics: true).copyWith(haptics: false).haptics,
      false,
    );
  });
}
