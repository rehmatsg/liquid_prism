import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  testWidgets(
    'native dispatch updates configuration and reduced-motion press overlay',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const system = MethodChannel('dev.liquidprism/system');
      final updates = <Map<Object?, Object?>>[];
      final channels = <MethodChannel>[];
      final supportCalls = <String>[];
      messenger.setMockMethodCallHandler(system, (call) async {
        supportCalls.add(call.method);
        return switch (call.method) {
          'isSupported' => true,
          'appearanceVersion' => 27,
          _ => throw MissingPluginException(),
        };
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          expect(args['viewType'], 'dev.liquidprism/material');
          final channel = MethodChannel(
            'dev.liquidprism/material/${args['id']}',
          );
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'update');
            updates.add(Map<Object?, Object?>.from(call.arguments as Map));
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(system, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      await Future.wait([LiquidPrism.preload(), LiquidPrism.preload()]);
      expect(supportCalls, ['isSupported', 'appearanceVersion']);
      final imageKey = GlobalKey();
      var taps = 0;
      Future<void> render({
        Glass glass = Glass.regular,
        Brightness brightness = Brightness.dark,
        GlassShape shape = GlassShape.capsule,
        LiquidPrismStyle? optics,
        double? blur,
        GlassRendering? rendering,
        bool reduceMotion = false,
      }) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            platformBrightness: brightness,
            reduceMotion: reduceMotion,
            child: LiquidPrism(
              glass: glass,
              shape: shape,
              optics: optics,
              blur: blur,
              rendering: rendering,
              child: GestureDetector(
                onTap: () => taps++,
                child: const SizedBox(
                  width: 160,
                  height: 80,
                  child: ColoredBox(color: Color(0xFF00FF00)),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      await render();
      expect(find.byType(UiKitView), findsOneWidget);
      expect(updates.last['clear'], false);
      expect(updates.last['dark'], true);
      final count = channels.length;
      await render(
        glass: Glass.clear.tint(const Color(0x80FF0000)),
        brightness: Brightness.light,
        shape: const GlassShape.rect(cornerRadius: 19),
      );
      expect(
        channels,
        hasLength(count),
        reason: 'Configuration updates must not recreate the native view',
      );
      expect(updates.last, containsPair('tint', 0x80FF0000));
      expect(updates.last, containsPair('clear', true));
      expect(updates.last, containsPair('dark', false));
      expect(updates.last, containsPair('smooth', true));
      expect(updates.last, containsPair('radius', 19.0));
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(taps, 1);

      await render(glass: Glass.regular.interactive(), reduceMotion: true);
      final nativeView = find.byType(UiKitView);
      final overlay = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color.r == 1 &&
            widget.color.g == 1 &&
            widget.color.b == 1,
      );
      expect(overlay, findsOneWidget);
      final restingBounds = tester.getRect(nativeView);
      final restingUpdates = updates.length;
      final restingViews = channels.length;
      expect(tester.widget<ColoredBox>(overlay).color.a, 0);
      final held = await tester.startGesture(tester.getCenter(nativeView));
      await tester.pump();
      expect(
        tester.widget<ColoredBox>(overlay).color.a,
        greaterThan(0),
        reason: 'Reduce Motion preserves the Flutter press overlay',
      );
      expect(tester.getRect(nativeView), restingBounds);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<ColoredBox>(overlay).color.a, greaterThan(0));
      await held.up();
      await tester.pump();
      expect(tester.widget<ColoredBox>(overlay).color.a, 0);
      expect(tester.getRect(nativeView), restingBounds);
      expect(taps, 2);
      expect(
        updates,
        hasLength(restingUpdates),
        reason: 'Press frames must not send native configuration updates',
      );
      expect(channels, hasLength(restingViews));

      for (final override in ['shader', 'optics', 'zero blur', 'identity']) {
        await render(
          rendering: override == 'shader' ? GlassRendering.shader : null,
          optics: override == 'optics' ? LiquidPrismStyle.clear : null,
          blur: override == 'zero blur' ? 0 : null,
          glass: override == 'identity' ? Glass.identity : Glass.regular,
        );
        expect(find.byType(UiKitView), findsNothing, reason: override);
      }
      await verifySystemTabAppearance(tester, legacy: false);
      expect(supportCalls, ['isSupported', 'appearanceVersion']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

// Shared by the separate legacy-plugin isolate: initialization is process-wide.
Future<void> verifySystemTabAppearance(
  WidgetTester tester, {
  required bool legacy,
}) async {
  final imageKey = GlobalKey();
  const iconKey = ValueKey('calibrated-icon');
  const buttonIconKey = ValueKey('button-icon');
  const customIconKey = ValueKey('theme-aware-icon');
  const symbol = IconData(0x4D, fontFamily: 'Ahem');
  for (final rendering in [GlassRendering.system, GlassRendering.shader]) {
    var customCreations = 0;
    State? nativeTabState;
    final requests = <int>[];
    for (final brightness in [Brightness.dark, Brightness.light]) {
      Future<void> render({
        Color? selectionColor,
        Color? tint,
        Color? selectedColor,
        Color? buttonColor,
        Color? appForeground,
        Color? nestedForeground,
        bool inherit = true,
        bool enabled = true,
        int selectedIndex = 0,
        GlassButtonStyle buttonStyle = GlassButtonStyle.glass,
        Color background = const Color(0xFF666666),
      }) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            platformBrightness: brightness,
            background: background,
            reduceMotion: true,
            child: LiquidPrismTheme(
              tint: tint,
              data: LiquidPrismThemeData(foregroundColor: appForeground),
              child: LiquidPrismTheme(
                inherit: inherit,
                data: LiquidPrismThemeData(foregroundColor: nestedForeground),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiquidPrismTabBar(
                      selectedIndex: selectedIndex,
                      onSelected: enabled ? requests.add : null,
                      rendering: rendering,
                      style: GlassTabBarStyle(
                        haptics: false,
                        padding: EdgeInsets.zero,
                        labelStyle: const TextStyle(
                          fontFamily: 'Ahem',
                          fontSize: 20,
                        ),
                        selectionColor: selectionColor,
                        selectedColor: selectedColor,
                      ),
                      tabs: [
                        const LiquidPrismTab(
                          label: 'M',
                          icon: Icon(symbol, key: iconKey),
                        ),
                        LiquidPrismTab(
                          label: 'N',
                          icon: _ThemeAwareIcon(
                            key: customIconKey,
                            onCreate: () => customCreations++,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LiquidPrismButton(
                      label: 'Button',
                      onPressed: enabled ? () {} : null,
                      rendering: rendering,
                      foregroundColor: buttonColor,
                      buttonStyle: buttonStyle,
                      padding: const EdgeInsets.all(10),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(symbol, key: buttonIconKey),
                          SizedBox(width: 8),
                          Text(
                            'B',
                            style: TextStyle(fontFamily: 'Ahem', fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        if (rendering == GlassRendering.system) {
          final currentNative = tester.state(find.byType(UiKitView).first);
          nativeTabState ??= currentNative;
          expect(currentNative, same(nativeTabState));
          expect(customCreations, 1);
        }
      }

      await render();
      expect(
        find.byType(UiKitView),
        rendering == GlassRendering.system ? findsNWidgets(2) : findsNothing,
      );
      final origin = tester.getTopLeft(find.byKey(imageKey));
      final pill = tester.getRect(find.byType(LiquidPrismSelection));
      final points = [
        tester.getCenter(find.byKey(iconKey)) - origin,
        tester.getCenter(find.text('M')) - origin,
        Offset(pill.left + 15, pill.center.dy) - origin,
        Offset(pill.left + 135, pill.center.dy) - origin,
      ];
      final pixels = await pixelsAt(tester, imageKey, points);
      final buttonPoints = [
        tester.getCenter(find.byKey(buttonIconKey)) - origin,
        tester.getCenter(find.text('B')) - origin,
      ];
      final restingButton = await pixelsAt(tester, imageKey, buttonPoints);
      if (!legacy || rendering == GlassRendering.system) {
        final expected = brightness == Brightness.dark
            ? (legacy ? const Color(0xFF14DAFF) : const Color(0xFF3BCCFF))
            : (legacy ? const Color(0xFF0065DF) : const Color(0xFF005DC7));
        final rgba = [
          (expected.r * 255).round(),
          (expected.g * 255).round(),
          (expected.b * 255).round(),
          255,
        ];
        for (var channel = 0; channel < 4; channel++) {
          expect(pixels[0][channel], closeTo(rgba[channel], 1));
          expect(pixels[1][channel], closeTo(rgba[channel], 1));
        }
        expect(
          restingButton,
          [pixels[0], pixels[1]],
          reason:
              'Ordinary button icon and text use the same blue as navigation',
        );
      }
      const appForeground = Color(0xFFCC4400);
      final foregroundPoints = [...points.take(2), ...buttonPoints];
      await render(appForeground: appForeground);
      expect(await pixelsAt(tester, imageKey, foregroundPoints), [
        for (var i = 0; i < 4; i++) [204, 68, 0, 255],
      ], reason: 'A partial nested theme inherits the literal app foreground');
      await render(
        appForeground: appForeground,
        nestedForeground: const Color(0xFF00AA66),
      );
      expect(await pixelsAt(tester, imageKey, foregroundPoints), [
        for (var i = 0; i < 4; i++) [0, 170, 102, 255],
      ]);
      await render(
        appForeground: appForeground,
        selectedColor: const Color(0xFF2266AA),
        buttonColor: const Color(0xFFAA22DD),
      );
      expect(await pixelsAt(tester, imageKey, points.take(2).toList()), [
        [34, 102, 170, 255],
        [34, 102, 170, 255],
      ]);
      expect(await pixelsAt(tester, imageKey, buttonPoints), [
        [170, 34, 221, 255],
        [170, 34, 221, 255],
      ]);
      await render(appForeground: appForeground, inherit: false);
      expect(await pixelsAt(tester, imageKey, foregroundPoints), [
        ...pixels.take(2),
        ...restingButton,
      ], reason: 'inherit:false resets the literal app foreground');
      await render(enabled: false);
      final disabledPixels = await pixelsAt(tester, imageKey, foregroundPoints);
      await render(appForeground: appForeground, enabled: false);
      expect(
        await pixelsAt(tester, imageKey, foregroundPoints),
        disabledPixels,
      );
      await render(
        appForeground: appForeground,
        buttonStyle: GlassButtonStyle.glassProminent,
      );
      expect(await pixelsAt(tester, imageKey, buttonPoints), [
        [255, 255, 255, 255],
        [255, 255, 255, 255],
      ]);
      await render(
        appForeground: appForeground,
        buttonStyle: GlassButtonStyle.glassProminent,
        buttonColor: const Color(0xFFAA22DD),
      );
      expect(await pixelsAt(tester, imageKey, buttonPoints), [
        [170, 34, 221, 255],
        [170, 34, 221, 255],
      ]);
      await render();
      expect(await pixelsAt(tester, imageKey, foregroundPoints), [
        ...pixels.take(2),
        ...restingButton,
      ], reason: 'Removing the app foreground restores calibrated appearance');
      final pillShouldBrighten = legacy && brightness == Brightness.dark;
      expect(
        pixels[2][0],
        pillShouldBrighten ? greaterThan(pixels[3][0]) : lessThan(pixels[3][0]),
        reason: '$rendering $brightness keeps the calibrated selection sign',
      );
      await render(selectionColor: const Color(0xFFFF00AA));
      expect((await pixelsAt(tester, imageKey, [points[2]])).single, [
        255,
        0,
        170,
        255,
      ], reason: 'Explicit selectionColor bypasses the material treatment');
      await render();
      expect((await pixelsAt(tester, imageKey, [points[2]])).single, pixels[2]);
      await render(background: const Color(0xFFBBBBBB));
      final brightBackdrop = await pixelsAt(
        tester,
        imageKey,
        points.take(2).toList(),
      );
      for (var foreground = 0; foreground < 2; foreground++) {
        expect(
          brightBackdrop[foreground],
          legacy && rendering == GlassRendering.shader
              ? isNot(pixels[foreground])
              : pixels[foreground],
          reason: 'Only the iOS 26 shader foreground samples the backdrop',
        );
      }
      const translucentTint = Color(0x806622AA);
      await render(tint: translucentTint);
      final translucent = await pixelsAt(
        tester,
        imageKey,
        points.take(2).toList(),
      );
      await render(tint: translucentTint, selectedColor: translucentTint);
      expect(
        await pixelsAt(tester, imageKey, points.take(2).toList()),
        translucent,
        reason: 'Translucent tint retains the same pixels as an explicit source color',
      );
      if (!legacy || rendering == GlassRendering.system) {
        await render(selectedIndex: 1);
        final customPoint =
            tester.getCenter(find.byKey(customIconKey)) - origin;
        expect(
          (await pixelsAt(tester, imageKey, [customPoint])).single,
          pixels[0],
          reason: 'IconTheme-aware custom artwork inherits the calibrated source color',
        );
        final semantics = tester.getSemantics(find.bySemanticsLabel('N'));
        expect(semantics.label, 'N');
        final previousRequests = requests.length;
        tester.semantics.tap(find.semantics.byLabel('N'));
        await tester.pump();
        expect(requests.skip(previousRequests), [1]);
        await render();
      }
    }
  }
}

class _ThemeAwareIcon extends StatefulWidget {
  const _ThemeAwareIcon({super.key, required this.onCreate});
  final VoidCallback onCreate;
  @override
  State<_ThemeAwareIcon> createState() => _ThemeAwareIconState();
}

class _ThemeAwareIconState extends State<_ThemeAwareIcon> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: ColoredBox(color: IconTheme.of(context).color!),
  );
}
