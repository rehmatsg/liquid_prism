import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// Run with `flutter run -t lib/api_main.dart -d <device-id>`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(const ApiExample());
}

class ApiExample extends StatefulWidget {
  const ApiExample({super.key});

  @override
  State<ApiExample> createState() => _ApiExampleState();
}

class _ApiExampleState extends State<ApiExample> {
  final _search = TextEditingController();
  bool _enabled = true;
  double _level = .52;
  int _segment = 0;
  int _tab = 0;
  int _favorites = 0;

  // Unspecified fields retain the package's native defaults.
  static const _lens = GlassLensStyle(shadowOpacity: .07, ringOpacity: .035);
  static const _theme = LiquidPrismThemeData(
    lens: _lens,
    button: GlassButtonAppearance(
      minimumSize: Size(48, 48),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    slider: GlassSliderStyle(width: 320, trackHeight: 8),
    toolbar: GlassToolbarStyle(spacing: 2),
    search: GlassSearchStyle(showCancelButton: false),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    home: LiquidPrismTheme(
      data: _theme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3EB),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Make it yours.',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('Shared defaults. Local choices. Native motion.'),
              const SizedBox(height: 24),
              LiquidPrismSearchField(
                controller: _search,
                placeholder: 'Try the search field',
                autocorrect: false,
                appearance: const GlassSearchStyle(
                  height: 52,
                  iconColor: Color(0xFF426D62),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('A brighter idea'),
                  LiquidPrismSwitch(
                    value: _enabled,
                    label: 'A brighter idea',
                    onChanged: (value) => setState(() => _enabled = value),
                    style: const GlassSwitchStyle(scale: 1.1),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: LiquidPrismSlider(
                  value: _level,
                  label: 'Brightness',
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()} percent',
                  onChanged: (value) => setState(() => _level = value),
                  // The knob grows; the track behind its lens keeps its scale.
                  style: const GlassSliderStyle(
                    thumbSize: Size(40, 26),
                    heldScale: 1.6,
                    lens: GlassLensStyle(minifyUnderlay: false),
                  ),
                ),
              ),
              Text('${(_level * 100).round()}%'),
              const SizedBox(height: 24),
              LiquidPrismSegmentedControl<int>(
                selectedValue: _segment,
                onValueChanged: (value) => setState(() => _segment = value),
                children: const {
                  0: Text('Meadow'),
                  1: Text('Dusk'),
                  2: Text('Apricot'),
                },
                style: const GlassSegmentedStyle(
                  trackHeight: 36,
                  thumbHeight: 32,
                  labelStyle: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 170,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF82B8AB), Color(0xFFF0B588)],
                    ),
                  ),
                  child: Center(
                    child: LiquidPrism(
                      glass: Glass.clear,
                      shape: const GlassShape.rect(cornerRadius: 20),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Something to see through.'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LiquidPrismButton(
                    label: 'Favorite',
                    onPressed: () => setState(() => _favorites++),
                    child: Text('Favorite · $_favorites'),
                  ),
                  LiquidPrismButton.icon(
                    icon: const Icon(CupertinoIcons.heart),
                    label: 'Add favorite',
                    onPressed: () => setState(() => _favorites++),
                    // Opt out of the app's larger horizontal button padding.
                    padding: const EdgeInsets.all(12),
                  ),
                  LiquidPrismToolbarGroup(
                    items: [
                      GlassToolbarItem(
                        icon: const Icon(CupertinoIcons.minus),
                        label: 'Dim',
                        onPressed: () => setState(
                          () => _level = (_level - .1).clamp(0.0, 1.0),
                        ),
                      ),
                      GlassToolbarItem(
                        icon: const Icon(CupertinoIcons.plus),
                        label: 'Brighten',
                        onPressed: () => setState(
                          () => _level = (_level + .1).clamp(0.0, 1.0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              LiquidPrismTabBar(
                selectedIndex: _tab,
                onSelected: (value) => setState(() => _tab = value),
                tabs: const [
                  LiquidPrismTab(
                    icon: Icon(CupertinoIcons.sparkles),
                    label: 'Explore',
                  ),
                  LiquidPrismTab(
                    icon: Icon(CupertinoIcons.slider_horizontal_3),
                    label: 'Studio',
                  ),
                  LiquidPrismTab(
                    icon: Icon(CupertinoIcons.square_grid_2x2_fill),
                    label: 'Library',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'See doc/customization.md for inheritance and overrides.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
