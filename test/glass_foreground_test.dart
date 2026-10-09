import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  testWidgets(
    'preload and default controls use Flutter without platform messages',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const formerPlugin = MethodChannel('dev.liquidprism/system');
      final calls = <String>[];
      for (final channel in [formerPlugin, SystemChannels.platform_views]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add('${channel.name}/${call.method}');
          throw MissingPluginException();
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      await Future.wait([LiquidPrism.preload(), LiquidPrism.preload()]);
      var taps = 0;
      await tester.pumpWidget(
        glassHarness(
          imageKey: GlobalKey(),
          child: LiquidPrismButton(
            label: 'Action',
            onPressed: () => taps++,
            child: const Text('Action'),
          ),
        ),
      );
      await tester.tap(find.byType(LiquidPrismButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'buttons and tabs retain calibrated foreground, overrides and icon state',
    _verifyForeground,
  );
}

Future<void> _verifyForeground(WidgetTester tester) async {
  final imageKey = GlobalKey();
  const iconKey = ValueKey('calibrated-icon');
  const buttonIconKey = ValueKey('button-icon');
  const customIconKey = ValueKey('theme-aware-icon');
  const symbol = IconData(0x4D, fontFamily: 'Ahem');
  var customCreations = 0;
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
      expect(customCreations, 1);
    }

    await render();
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
    final expected = brightness == Brightness.dark
        ? const Color(0xFF3BCCFF)
        : const Color(0xFF005DC7);
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
    expect(restingButton, [
      pixels[0],
      pixels[1],
    ], reason: 'Ordinary button icon and text use the same blue as navigation');
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
    expect(await pixelsAt(tester, imageKey, foregroundPoints), disabledPixels);
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
    expect(
      pixels[2][0],
      lessThan(pixels[3][0]),
      reason: '$brightness keeps the selected pill darker than its peer',
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
        pixels[foreground],
        reason: 'The resting foreground palette remains independent of the backdrop',
      );
    }
    const customTint = Color(0xFF804020);
    await render(tint: customTint);
    final customPixels = await pixelsAt(tester, imageKey, foregroundPoints);
    expect(
      customPixels,
      everyElement(customPixels.first),
      reason:
          'A custom tint is calibrated consistently for button and tab content',
    );
    for (var channel = 0; channel < 3; channel++) {
      expect(
        customPixels.first[channel],
        brightness == Brightness.dark
            ? greaterThan([128, 64, 32][channel])
            : lessThan([128, 64, 32][channel]),
        reason:
            'Opaque tint uses a brighter dark accent and a darker light accent',
      );
    }
    const translucentTint = Color(0x806622AA);
    await render(tint: translucentTint);
    final translucent = await pixelsAt(tester, imageKey, foregroundPoints);
    await render(
      tint: translucentTint,
      selectedColor: translucentTint,
      buttonColor: translucentTint,
    );
    expect(
      await pixelsAt(tester, imageKey, foregroundPoints),
      translucent,
      reason: 'Translucent tint retains the same pixels as an explicit source color',
    );
    await render(selectedIndex: 1);
    final customPoint = tester.getCenter(find.byKey(customIconKey)) - origin;
    expect(
      (await pixelsAt(tester, imageKey, [customPoint])).single,
      pixels[0],
      reason:
          'IconTheme-aware custom artwork inherits the calibrated source color',
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
