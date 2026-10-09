import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(const LiquidPrismExample());
}

/// A self-contained consumer of the public Liquid Prism API.
class LiquidPrismExample extends StatefulWidget {
  const LiquidPrismExample({super.key});
  @override
  State<LiquidPrismExample> createState() => _LiquidPrismExampleState();
}

class _LiquidPrismExampleState extends State<LiquidPrismExample> {
  bool _dark = true, _labels = true, _clear = false, _favorite = false;
  int _selected = 0, _count = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = _dark ? Brightness.dark : Brightness.light;
    return CupertinoApp(
      title: 'Liquid Prism',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: brightness),
      home: LiquidPrismTheme(
        data: LiquidPrismThemeData(
          brightness: brightness,
          glass: _clear ? Glass.clear : Glass.regular,
          tabBar: GlassTabBarStyle(
            labelBehavior: _labels
                ? GlassTabLabelBehavior.always
                : GlassTabLabelBehavior.never,
          ),
        ),
        child: Builder(
          builder: (context) => DefaultTextStyle(
            style: TextStyle(
              color: LiquidPrismTheme.colorsOf(context).label,
              fontSize: 17,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Background(dark: _dark),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 24,
                            children: [
                              const Text(
                                'Liquid Prism',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text('Glass that responds to your touch.'),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  LiquidPrismButton(
                                    label: 'Toggle appearance',
                                    onPressed: () =>
                                        setState(() => _dark = !_dark),
                                    child: Text(_dark ? 'Dark' : 'Light'),
                                  ),
                                  LiquidPrismButton(
                                    label: 'Toggle glass material',
                                    onPressed: () =>
                                        setState(() => _clear = !_clear),
                                    child: Text(_clear ? 'Clear' : 'Regular'),
                                  ),
                                  LiquidPrismButton(
                                    label: 'Toggle tab labels',
                                    onPressed: () =>
                                        setState(() => _labels = !_labels),
                                    child: Text(
                                      _labels ? 'Hide labels' : 'Show labels',
                                    ),
                                  ),
                                ],
                              ),
                              LiquidPrism(
                                shape: const GlassShape.rect(cornerRadius: 28),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 12,
                                    children: [
                                      Text(
                                        [
                                          'Explore',
                                          'Saved',
                                          'Settings',
                                        ][_selected],
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Text(
                                        'Use the tabs below. Hold and slide the selection pill to feel its spring.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  LiquidPrismButton(
                                    label: 'Add a tap',
                                    onPressed: () => setState(() => _count++),
                                    child: const Text('Glass'),
                                  ),
                                  LiquidPrismButton(
                                    label: 'Add a prominent tap',
                                    buttonStyle:
                                        GlassButtonStyle.glassProminent,
                                    onPressed: () => setState(() => _count++),
                                    child: const Text('Prominent'),
                                  ),
                                  LiquidPrismButton(
                                    label: 'Favorite',
                                    selected: _favorite,
                                    shape: GlassShape.circle,
                                    padding: const EdgeInsets.all(18),
                                    onPressed: () =>
                                        setState(() => _favorite = !_favorite),
                                    child: Icon(
                                      _favorite
                                          ? CupertinoIcons.heart_fill
                                          : CupertinoIcons.heart,
                                    ),
                                  ),
                                ],
                              ),
                              Text('$_count taps'),
                              LiquidPrism(
                                glass: Glass.regular.tint(
                                  const Color(0x550088FF),
                                ),
                                shape: const GlassShape.rect(cornerRadius: 24),
                                child: const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'A tinted surface. Material tint is independent of icon and text color.',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                        child: LiquidPrismTabBar(
                          selectedIndex: _selected,
                          onSelected: (index) =>
                              setState(() => _selected = index),
                          tabs: const [
                            LiquidPrismTab(
                              label: 'Explore',
                              icon: Icon(CupertinoIcons.square_grid_2x2),
                              selectedIcon: Icon(
                                CupertinoIcons.square_grid_2x2_fill,
                              ),
                            ),
                            LiquidPrismTab(
                              label: 'Saved',
                              icon: Icon(CupertinoIcons.bookmark),
                              selectedIcon: Icon(CupertinoIcons.bookmark_fill),
                            ),
                            LiquidPrismTab(
                              label: 'Settings',
                              icon: Icon(CupertinoIcons.settings),
                            ),
                          ],
                        ),
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
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF092B50), Color(0xFF207B8A), Color(0xFF493B72)]
            : const [Color(0xFFDCEFFF), Color(0xFF9DDACA), Color(0xFFE9C9DF)],
      ),
    ),
    child: const CustomPaint(painter: _RibbonPainter()),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x4475CEFA);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * .8,
        size.height * .1,
        size.width * 1.8,
        size.height * .65,
      ),
      paint,
    );
    paint.color = const Color(0x55FFBC76);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .6,
        size.height * .4,
        size.width,
        size.height * .8,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => false;
}
