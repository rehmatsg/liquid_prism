import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prism.initialize();
  runApp(const ApiExample());
}

/// A compact app demonstrating the main Liquid Prism APIs.
class ApiExample extends StatefulWidget {
  /// Creates an [ApiExample].
  const new({super.key});

  @override
  State<ApiExample> createState() => _ApiExampleState();
}

class _ApiExampleState extends State<ApiExample> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  final _suggestionLink = LayerLink();
  final _suggestions = OverlayPortalController();
  final _searchGroup = Object();
  static const _ideas = ['Glass', 'Lens', 'Prism', 'Refraction', 'Spring'];
  bool _enabled = true;
  double _level = .52;
  int _segment = 0;
  int _tab = 0;
  int _favorites = 0;

  static const _lens = PrismLensStyle(shadowOpacity: .07, ringOpacity: .035);
  static const _theme = PrismThemeData(
    lens: _lens,
    button: PrismButtonStyle(
      minimumSize: Size(48, 48),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    slider: PrismSliderStyle(width: 320, trackHeight: 8),
    toolbar: PrismToolbarStyle(spacing: 2),
    search: PrismSearchStyle(showCancelButton: false),
  );

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Widget _buildSuggestions(BuildContext context) => CompositedTransformFollower(
    link: _suggestionLink,
    targetAnchor: Alignment.bottomLeft,
    offset: const Offset(0, 8),
    showWhenUnlinked: false,
    child: Align(
      alignment: Alignment.topLeft,
      child: TapRegion(
        groupId: _searchGroup,
        child: ValueListenableBuilder(
          valueListenable: _search,
          builder: (context, value, _) {
            final query = value.text.toLowerCase();
            final matches = _ideas.where(
              (idea) => idea.toLowerCase().startsWith(query),
            );
            return Container(
              width: _suggestionLink.leaderSize?.width,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final idea in matches)
                    CupertinoListTile(
                      title: Text(idea),
                      onTap: () {
                        _search.text = idea;
                        _searchFocus.unfocus();
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    home: PrismTheme(
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
              PrismSearchField(
                controller: _search,
                focusNode: _searchFocus,
                placeholder: 'Try the search field',
                autocorrect: false,
                groupId: _searchGroup,
                onTapOutside: (_) => _searchFocus.unfocus(),
                onFocusChange: (focused) =>
                    focused ? _suggestions.show() : _suggestions.hide(),
                fieldBuilder: (context, field) => OverlayPortal(
                  controller: _suggestions,
                  overlayChildBuilder: _buildSuggestions,
                  child: CompositedTransformTarget(
                    link: _suggestionLink,
                    child: field,
                  ),
                ),
                style: const PrismSearchStyle(
                  height: 52,
                  iconColor: Color(0xFF426D62),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('A brighter idea'),
                  PrismSwitch(
                    value: _enabled,
                    label: 'A brighter idea',
                    onChanged: (value) => setState(() => _enabled = value),
                    style: const PrismSwitchStyle(scale: 1.1),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: PrismSlider(
                  value: _level,
                  label: 'Brightness',
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()} percent',
                  onChanged: (value) => setState(() => _level = value),

                  style: const PrismSliderStyle(
                    thumbSize: Size(40, 26),
                    heldScale: 1.6,
                    lens: PrismLensStyle(minifyUnderlay: false),
                  ),
                ),
              ),
              Text('${(_level * 100).round()}%'),
              const SizedBox(height: 24),
              PrismSegmentedControl<int>(
                selectedValue: _segment,
                onValueChanged: (value) => setState(() => _segment = value),
                children: const {
                  0: Text('Meadow'),
                  1: Text('Dusk'),
                  2: Text('Apricot'),
                },
                style: const PrismSegmentedStyle(
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
                  child: const Center(
                    child: PrismSurface(
                      glass: PrismGlass.clear,
                      shape: PrismShape.rect(cornerRadius: 20),
                      child: Padding(
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
                  PrismButton(
                    label: 'Favorite',
                    onPressed: () => setState(() => _favorites++),
                    child: Text('Favorite · $_favorites'),
                  ),
                  PrismButton.icon(
                    icon: const Icon(CupertinoIcons.heart),
                    label: 'Add favorite',
                    onPressed: () => setState(() => _favorites++),

                    style: const PrismButtonStyle(padding: EdgeInsets.all(12)),
                  ),
                  PrismToolbar.group(
                    items: [
                      PrismToolbarItem(
                        icon: const Icon(CupertinoIcons.minus),
                        label: 'Dim',
                        onPressed: () => setState(
                          () => _level = (_level - .1).clamp(0.0, 1.0),
                        ),
                      ),
                      PrismToolbarItem(
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
              PrismTabBar(
                selectedIndex: _tab,
                onSelected: (value) => setState(() => _tab = value),
                tabs: const [
                  PrismTab(
                    icon: Icon(CupertinoIcons.sparkles),
                    label: 'Explore',
                  ),
                  PrismTab(
                    icon: Icon(CupertinoIcons.slider_horizontal_3),
                    label: 'Studio',
                  ),
                  PrismTab(
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
