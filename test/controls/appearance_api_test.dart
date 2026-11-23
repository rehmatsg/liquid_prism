import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';

Widget host(Widget child, {PrismThemeData theme = const PrismThemeData()}) =>
    CupertinoApp(
      home: PrismTheme(
        data: theme,
        child: Center(
          child: SizedBox(
            width: 300,
            child: Align(heightFactor: 1, child: child),
          ),
        ),
      ),
    );

void main() {
  test('partial component themes preserve nested fields, false and zero', () {
    const base = PrismThemeData(
      lens: PrismLensStyle(shadow: false, shadowBlur: 7),
      slider: PrismSliderStyle(
        trackHeight: 8,
        lens: PrismLensStyle(blur: 2, shadow: true),
      ),
      toolbar: PrismToolbarStyle(spacing: 14),
      controlMotion: PrismControlMotion(maxStretch: .08),
    );
    final merged = base.merge(
      const PrismThemeData(
        slider: PrismSliderStyle(lens: PrismLensStyle(blur: 0, shadow: false)),
        toolbar: PrismToolbarStyle(spacing: 0),
        controlMotion: PrismControlMotion(flexStrength: 0),
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
      const PrismTabBarStyle(sizing: PrismTabBarSizing.fill)
          .copyWith(sizing: PrismTabBarSizing.compact)
          .sizing,
      PrismTabBarSizing.compact,
    );
    const physical = PrismSpring.physical(
      SpringDescription(mass: 1, stiffness: 300, damping: 26),
    );
    expect(physical.copyWith().description.stiffness, 300);
    expect(
      physical.copyWith(response: const Duration(milliseconds: 500)).physics,
      isNull,
    );
  });

  testWidgets('switch scale and local colors override the component theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PrismSwitch(
          value: true,
          onChanged: (_) {},
          style: const PrismSwitchStyle(
            scale: 2,
            activeColor: Color(0xFFFF0000),
          ),
        ),
        theme: const PrismThemeData(
          switchStyle: PrismSwitchStyle(activeColor: Color(0xFF0000FF)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PrismSwitch)), const Size(126, 88));
    expect(tester.getSize(find.byType(RawPrismSurface)), const Size(74, 48));
    final boxes = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(PrismSwitch),
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
            builder: (context, update) => PrismSlider(
              value: value,
              min: 0,
              max: 100,
              divisions: 10,
              label: 'Level',
              semanticFormatterCallback: (v) => 'Level ${v.round()}',
              onChanged: (v) => update(() => value = v),
              style: const PrismSliderStyle(
                width: 160,
                thumbSize: Size(40, 20),
                heldScale: 2,
                lens: PrismLensStyle(
                  shape: PrismShape.roundedRect(cornerRadius: 4),
                  shadow: false,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(PrismSlider)).width, 160);
      final lens = find.byType(RawPrismSurface);
      expect(
        tester.widget<RawPrismSurface>(lens).shape,
        const PrismShape.roundedRect(cornerRadius: 4),
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
            builder: (context, update) => PrismSwitch(
              value: value,
              onChanged: (v) => update(() => value = v),
              style: const PrismSwitchStyle(
                motion: PrismControlMotion(
                  minimumLiftDuration: Duration(milliseconds: 500),
                ),
              ),
            ),
          ),
          theme: const PrismThemeData(
            controlMotion: PrismControlMotion(
              travel: PrismSpring(response: Duration(seconds: 2), bounce: 0),
            ),
          ),
        ),
      );
      final lens = find.byType(RawPrismSurface);
      final start = tester.getCenter(lens);
      await tester.tap(find.byType(PrismSwitch));
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
          PrismToolbar.group(
            items: [
              PrismToolbarItem(
                icon: const Icon(CupertinoIcons.star),
                label: 'Star',
                onPressed: () {},
              ),
              PrismToolbarItem(
                icon: const Icon(CupertinoIcons.share),
                label: 'Share',
                onPressed: () {},
              ),
            ],
            style: const PrismToolbarStyle(spacing: 0, inset: 0, iconSize: 19),
          ),
          theme: const PrismThemeData(toolbar: PrismToolbarStyle(spacing: 30)),
        ),
      );
      expect(tester.getSize(find.byType(RawPrismSurface)).width, 76);
      expect(
        IconTheme.of(tester.element(find.byIcon(CupertinoIcons.star))).size,
        19,
      );
      await tester.pumpWidget(
        host(
          PrismButton.icon(
            icon: const Icon(CupertinoIcons.heart),
            label: 'Favorite',
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(RawPrismSurface)), const Size(48, 48));
      expect(
        tester.widget<RawPrismSurface>(find.byType(RawPrismSurface)).shape,
        PrismShape.circle,
      );
    },
  );

  testWidgets(
    'search forwards editor behavior and honors local style overrides',
    (tester) async {
      await tester.pumpWidget(
        host(
          PrismSearchField(
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            readOnly: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            prefix: const Text('Find'),
            style: const PrismSearchStyle(
              height: 52,
              showCancelButton: false,
              restingInset: 0,
              textStyle: TextStyle(fontSize: 21),
            ),
          ),
          theme: const PrismThemeData(
            search: PrismSearchStyle(
              restingInset: 20,
              showCancelButton: true,
              textStyle: TextStyle(fontSize: 19),
            ),
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
      expect(tester.getSize(find.byType(RawPrismSurface)).width, 300);
    },
  );

  testWidgets('segmented styles and tab layout can be tuned independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PrismSegmentedControl<int>(
          selectedValue: 0,
          onValueChanged: (_) {},
          children: const {0: Text('A'), 1: Text('B')},
          style: const PrismSegmentedStyle(
            width: 180,
            thumbHeight: 30,
            selectionInset: 3,
            labelStyle: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PrismSegmentedControl<int>)).width, 180);
    expect(tester.getSize(find.byType(RawPrismSurface)), const Size(84, 30));
    await tester.pumpWidget(
      host(
        PrismTabBar(
          selectedIndex: 0,
          onSelected: (_) {},
          tabs: const [
            PrismTab(label: 'A', icon: Icon(CupertinoIcons.star)),
            PrismTab(label: 'B', icon: Icon(CupertinoIcons.heart)),
          ],
          style: const PrismTabBarStyle(
            minimumTabWidth: 70,
            labelPadding: 10,
            refractContent: false,
          ),
        ),
      ),
    );
    final housing = find.byType(RawPrismSurface).first;
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
          builder: (context, update) => PrismSwitch(
            value: toggled,
            onChanged: (v) => update(() => toggled = v),
            onChangeStart: (v) => phases.add('start:$v'),
            onChangeEnd: (v) => phases.add('end:$v'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PrismSwitch));
    await tester.pumpAndSettle();
    expect(phases, ['start:false', 'end:true']);
    phases.clear();
    var selected = 'left';
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, update) => PrismSegmentedControl<String>(
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
        PrismSearchField(
          controller: controller,
          focusNode: focus,
          onChanged: changes.add,
          onCleared: () => cleared++,
          style: const PrismSearchStyle(cancelWidth: 64, cancelSpacing: 20),
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
    PrismSliderStyle appearance = const PrismSliderStyle(
      lens: PrismLensStyle(optics: PrismOptics(frost: 3)),
    );
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return PrismSlider(
              value: value,
              onChanged: (v) => setState(() => value = v),
              style: appearance,
            );
          },
        ),
      ),
    );
    expect(
      tester.widget<RawPrismSurface>(find.byType(RawPrismSurface)).blur,
      3,
    );
    update(
      () => appearance = appearance.copyWith(
        lens: appearance.lens!.copyWith(blur: 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<RawPrismSurface>(find.byType(RawPrismSurface)).blur,
      0,
    );
  });
  testWidgets('local segment foreground overrides the theme label color', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PrismSegmentedControl<int>(
          selectedValue: 0,
          children: const {0: Text('One'), 1: Text('Two')},
          onValueChanged: (_) {},
          style: const PrismSegmentedStyle(foregroundColor: Color(0xFFFF0000)),
        ),
        theme: const PrismThemeData(
          segmentedControl: PrismSegmentedStyle(
            foregroundColor: Color(0xFF00FF00),
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
  testWidgets('local tab material overrides the themed packet', (tester) async {
    await tester.pumpWidget(
      host(
        PrismTabBar(
          selectedIndex: 0,
          onSelected: (_) {},
          tabs: const [
            PrismTab(label: 'One', icon: Icon(CupertinoIcons.star)),
            PrismTab(label: 'Two', icon: Icon(CupertinoIcons.heart)),
          ],
          style: const PrismTabBarStyle(blur: 0, glass: PrismGlass.clear),
        ),
        theme: const PrismThemeData(tabBar: PrismTabBarStyle(blur: 7)),
      ),
    );
    final bar = tester.widget<RawPrismSurface>(
      find.byType(RawPrismSurface).first,
    );
    expect(bar.blur, 0);
    expect(bar.glass!.variant, PrismGlassVariant.clear);
  });
  testWidgets('chrome optics frost wins over inherited blur', (tester) async {
    await tester.pumpWidget(
      host(
        PrismToolbar.group(
          style: const PrismToolbarStyle(optics: PrismOptics(frost: 0)),
          items: [
            PrismToolbarItem(
              label: 'Add',
              icon: const Icon(CupertinoIcons.plus),
              onPressed: () {},
            ),
          ],
        ),
        theme: const PrismThemeData(blur: 7),
      ),
    );
    expect(
      tester.widget<RawPrismSurface>(find.byType(RawPrismSurface)).blur,
      0,
    );
  });
  testWidgets('held slider rim defaults and per-component lens precedence', (
    tester,
  ) async {
    var underlay = 0.0;
    PrismOptics held(PrismRole role) {
      final prism = tester.widget<RawPrismSurface>(
        find.byWidgetPredicate(
          (widget) => widget is RawPrismSurface && widget.role == role,
        ),
      );
      underlay = prism.underlay;
      return prism.optics!;
    }

    Future<PrismOptics> hold(
      Widget control,
      PrismRole role, {
      PrismThemeData theme = const PrismThemeData(),
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

    final slider = PrismSlider(value: .5, onChanged: (_) {});

    var optics = await hold(slider, PrismRole.sliderLens);
    expect(optics.edgeWidth, closeTo(6.66, 1e-6));
    expect(optics.refraction, closeTo(11.1, 1e-6));
    expect(optics.tint.a, closeTo(.1, 1e-6));
    expect(optics.light, closeTo(1, 1e-6));

    expect(underlay, 0);

    optics = await hold(
      PrismSlider(
        value: .5,
        onChanged: (_) {},
        style: const PrismSliderStyle(
          lens: PrismLensStyle(faceBlack: 0, rimRefraction: 0),
        ),
      ),
      PrismRole.sliderLens,
      theme: const PrismThemeData(
        lens: PrismLensStyle(rimLight: .3, faceBlack: .4, rimWidth: 3.72),
      ),
    );
    expect(optics.tint.a, 0);
    expect(optics.refraction, 0);
    expect(optics.light, closeTo(.3, 1e-6));
    expect(optics.edgeWidth, closeTo(3.72, 1e-6));

    final toggle = PrismSwitch(value: false, onChanged: (_) {});
    optics = await hold(toggle, PrismRole.controlThumb);
    expect(optics.edgeWidth, closeTo(6.9, 1e-6));
    expect(optics.refraction, closeTo(11.5, 1e-6));
    expect(underlay, closeTo(9, 1e-6));
    expect(optics.light, closeTo(.6, 1e-6));
    expect(optics.tint.a, 0);

    optics = await hold(
      PrismSegmentedControl<int>(
        children: const {0: Text('One'), 1: Text('Two')},
        selectedValue: 0,
        onValueChanged: (_) {},
      ),
      PrismRole.segmentLens,
    );
    expect(optics.edgeWidth, closeTo(7.04, 1e-6));
    expect(optics.refraction, closeTo(8.8, 1e-6));
    expect(underlay, closeTo(9, 1e-6));

    optics = await hold(
      PrismSwitch(
        value: false,
        onChanged: (_) {},
        style: const PrismSwitchStyle(
          lens: PrismLensStyle(rimRefraction: 3.72),
        ),
      ),
      PrismRole.controlThumb,
    );
    expect(optics.refraction, closeTo(3.72 * (115 / 3) / 37.2, 1e-6));
    expect(underlay, closeTo(9, 1e-6));
    optics = await hold(
      PrismSwitch(
        value: false,
        onChanged: (_) {},
        style: const PrismSwitchStyle(
          lens: PrismLensStyle(optics: PrismOptics(refraction: 5)),
        ),
      ),
      PrismRole.controlThumb,
    );
    expect(underlay, 5);
    optics = await hold(
      PrismSwitch(
        value: false,
        onChanged: (_) {},
        style: const PrismSwitchStyle(lens: PrismLensStyle(faceBlack: .1)),
      ),
      PrismRole.controlThumb,
    );
    expect(optics.tint.a, closeTo(.1, 1e-6));
  });

  test('lens rim fields survive copyWith and merge', () {
    const base = PrismLensStyle(
      rimWidth: 5,
      rimRefraction: 8,
      rimLight: .8,
      faceBlack: .2,
      heldContactShadow: true,
    );
    final merged = base.merge(
      const PrismLensStyle(rimLight: 0, heldContactShadow: false),
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
      const PrismSliderStyle(haptics: false)
          .merge(const PrismSliderStyle(trackHeight: 4))
          .haptics,
      false,
    );
    expect(
      const PrismSliderStyle(haptics: true).copyWith(haptics: false).haptics,
      false,
    );
  });
}
