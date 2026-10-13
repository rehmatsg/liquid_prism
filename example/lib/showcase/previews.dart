import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'model.dart';
import 'widgets.dart';
import 'package_features_demo.dart';
import 'search_page.dart';

class LensPlayground extends StatefulWidget {
  const LensPlayground({
    super.key,
    required this.model,
    this.expert = false,
    this.glass,
  });
  final ShowcaseModel model;
  final bool expert;
  final Glass? glass;
  @override
  State<LensPlayground> createState() => _LensPlaygroundState();
}

class _LensPlaygroundState extends State<LensPlayground> {
  Offset position = const Offset(.5, .5);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 44).clamp(80.0, 200.0);
      final titleStyle = TextStyle(
        color: GlassColors.light.label,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -.6,
      );
      final captionStyle = TextStyle(
        fontSize: 11,
        color: GlassColors.light.label,
      );
      double textHeight(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        )..layout(maxWidth: width - 28);
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final height =
          MediaQuery.textScalerOf(context).scale(30) +
          textHeight('A new view.', titleStyle) +
          textHeight('Hold. Move. Explore.', captionStyle) +
          49;
      final canvasHeight = height + 130;
      final travelX = (constraints.maxWidth - width - 24).clamp(
        0.0,
        double.infinity,
      );
      final travelY = canvasHeight - height - 24;
      return ClipPath(
        clipper: const CanvasClip(),
        child: SizedBox(
          height: canvasHeight,
          child: Art(
            variant: widget.model.wallpaper,
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 18,
                  child: Text(
                    'DRAG THE GLASS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Art.inks[widget.model.wallpaper],
                    ),
                  ),
                ),
                Positioned(
                  left: 12 + position.dx * travelX,
                  top: 12 + position.dy * travelY,
                  child: Semantics(
                    label: 'Draggable glass preview',
                    child: GestureDetector(
                      onPanUpdate: (details) => setState(
                        () => position = Offset(
                          travelX == 0
                              ? 0
                              : (position.dx + details.delta.dx / travelX)
                                    .clamp(0, 1),
                          (position.dy + details.delta.dy / travelY).clamp(
                            0,
                            1,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: LiquidPrism(
                          key: const ValueKey('studio-lens'),
                          glass: widget.glass ?? widget.model.glass,
                          optics: widget.expert
                              ? LiquidPrismStyle(
                                  frost: widget.model.frost,
                                  refraction: widget.model.refraction,
                                  tint: widget.model.tint.withValues(
                                    alpha: .08,
                                  ),
                                )
                              : null,
                          shape: const GlassShape.rect(cornerRadius: 28),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.cube,
                                    size: 30,
                                    color: GlassColors.light.label,
                                  ),
                                  const SizedBox(height: 10),
                                  Text('A new view.', style: titleStyle),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Hold. Move. Explore.',
                                    style: captionStyle,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 17,
                  child: Icon(
                    CupertinoIcons.move,
                    size: 19,
                    color: Art.inks[widget.model.wallpaper].withValues(
                      alpha: .65,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class ComponentPreview extends StatefulWidget {
  const ComponentPreview({super.key, required this.kind, required this.model});
  final ComponentKind kind;
  final ShowcaseModel model;
  @override
  State<ComponentPreview> createState() => _ComponentPreviewState();
}

class _ComponentPreviewState extends State<ComponentPreview> {
  int selectedTab = 0, selectedSurface = 0, actions = 0;
  bool extraAction = false;
  String query = '';
  String menuResult = 'Choose something. See what happens.';
  ShowcaseModel get m => widget.model;
  @override
  Widget build(BuildContext context) {
    if (widget.kind == ComponentKind.surfaces) {
      return Column(
        children: [
          LensPlayground(
            model: m,
            glass: selectedSurface == 0
                ? Glass.regular
                : selectedSurface == 1
                ? Glass.clear
                : selectedSurface == 2
                ? Glass.regular.tint(m.tint.withValues(alpha: .3))
                : Glass.identity,
          ),
          const SizedBox(height: 16),
          LiquidPrismGroup(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < 4; i++)
                  LiquidPrismButton(
                    label: 'Select surface $i',
                    selected: selectedSurface == i,
                    onPressed: () => setState(() => selectedSurface = i),
                    glass: i == 0
                        ? Glass.regular
                        : i == 1
                        ? Glass.clear
                        : i == 2
                        ? Glass.regular.tint(m.tint.withValues(alpha: .3))
                        : Glass.identity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: selectedSurface == i
                                ? const Icon(
                                    CupertinoIcons.check_mark,
                                    size: 14,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ['Regular', 'Clear', 'Tinted', 'Identity'][i],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return ArtCanvas(
      variant: m.wallpaper,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'LIVE PREVIEW',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          ...switch (widget.kind) {
            ComponentKind.buttons => [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  LiquidPrismButton(
                    label: 'Add a tap',
                    onPressed: () => m.change(() => m.taps++),
                    child: const Text('Glass'),
                  ),
                  LiquidPrismButton(
                    label: 'Add a prominent tap',
                    buttonStyle: GlassButtonStyle.glassProminent,
                    onPressed: () => m.change(() => m.taps++),
                    child: const Text('Prominent'),
                  ),
                  LiquidPrismButton(
                    label: 'Favorite',
                    selected: m.favorite,
                    shape: GlassShape.circle,
                    padding: const EdgeInsets.all(15),
                    onPressed: () => m.change(() => m.favorite = !m.favorite),
                    child: Icon(
                      m.favorite
                          ? CupertinoIcons.heart_fill
                          : CupertinoIcons.heart,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                '${m.taps} ${m.taps == 1 ? 'tap' : 'taps'}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Press and hold any button.',
                style: TextStyle(fontSize: 13),
              ),
            ],
            ComponentKind.switches => [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Let it glow',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  LiquidPrismSwitch(
                    label: 'Let it glow',
                    value: m.enabled,
                    onChanged: (v) => m.change(() => m.enabled = v),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Icon(
                m.enabled
                    ? CupertinoIcons.sun_max_fill
                    : CupertinoIcons.moon_fill,
                size: 52,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  m.enabled ? 'A brighter outlook.' : 'A moment of quiet.',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
            ComponentKind.sliders => [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Just the right amount.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${(m.level * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              LiquidPrismSlider(
                key: const ValueKey('component-slider'),
                label: 'Intensity',
                value: m.level,
                onChanged: (v) => m.change(() => m.level = v),
              ),
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(CupertinoIcons.sun_min, size: 19),
                  Icon(CupertinoIcons.sun_max, size: 25),
                ],
              ),
            ],
            ComponentKind.segments => [
              LiquidPrismSegmentedControl<int>(
                label: 'Perspective',
                selectedValue: m.segment,
                onValueChanged: (v) => m.change(() => m.segment = v),
                children: const {
                  0: Text('Day'),
                  1: Text('Dusk'),
                  2: Text('Night'),
                },
              ),
              const SizedBox(height: 30),
              Icon(
                [
                  CupertinoIcons.sun_max,
                  CupertinoIcons.sunset,
                  CupertinoIcons.moon_stars,
                ][m.segment],
                size: 50,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  [
                    'Start with a little light.',
                    'Take the scenic route.',
                    'Find your quiet moment.',
                  ][m.segment],
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
            ComponentKind.tabs => [
              const Text(
                'Take a different path.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                [
                  'Discover something new.',
                  'Keep what speaks to you.',
                  'Make yourself at home.',
                ][selectedTab],
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 30),
              LiquidPrismTabBar(
                selectedIndex: selectedTab,
                onSelected: (v) => setState(() => selectedTab = v),
                tabs: _demoTabs,
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'Beside the iPhone Duo sensor bar, the same tabs '
                      'stack into an icon-only rail. Hold the pill and '
                      'glide in either direction.',
                      style: TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 16),
                  LiquidPrismTabBar(
                    key: const ValueKey('demo-rail'),
                    axis: Axis.vertical,
                    selectedIndex: selectedTab,
                    onSelected: (v) => setState(() => selectedTab = v),
                    tabs: _demoTabs,
                  ),
                ],
              ),
            ],
            ComponentKind.toolbar => [
              const Text(
                'A little group effort.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 26),
              // One toolbar, two groups: the first fills and empties as the
              // plus item is tapped, so its capsule and the gap materialize.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: LiquidPrismToolbar(
                  key: const ValueKey('demo-toolbar'),
                  size: GlassToolbarSize.navigation,
                  groups: [
                    [
                      if (extraAction)
                        GlassToolbarItem(
                          icon: const Icon(CupertinoIcons.star),
                          label: 'Star',
                          width: 42 + 1 / 3,
                          onPressed: () => setState(() => actions++),
                        ),
                    ],
                    [
                      GlassToolbarItem(
                        icon: Icon(
                          extraAction
                              ? CupertinoIcons.minus_circle
                              : CupertinoIcons.plus_circle,
                        ),
                        label: extraAction ? 'Remove star' : 'Add star',
                        onPressed: () =>
                            setState(() => extraAction = !extraAction),
                      ),
                      GlassToolbarItem(
                        icon: const Icon(CupertinoIcons.share),
                        label: 'Share',
                        width: 38 + 2 / 3,
                        onPressed: () => setState(() => actions++),
                      ),
                      if (extraAction)
                        GlassToolbarItem(
                          icon: const Icon(CupertinoIcons.square_pencil),
                          label: 'Compose',
                          onPressed: () => setState(() => actions++),
                        ),
                      GlassToolbarItem.menu(
                        icon: const Icon(CupertinoIcons.ellipsis),
                        label: 'More',
                        menu: _actionMenu(),
                        onSelected: _menuSelected,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: LiquidPrismToolbarGroup(
                  items: [
                    GlassToolbarItem(
                      icon: const Icon(CupertinoIcons.chevron_left),
                      label: 'Previous',
                      onPressed: () => setState(() => actions++),
                    ),
                    GlassToolbarItem(
                      icon: const Icon(CupertinoIcons.chevron_right),
                      label: 'Next',
                      onPressed: () => setState(() => actions++),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '$actions actions. Tap the plus to add items and a '
                      'group. Hold an icon to lift its capsule. In a side '
                      'rail, groups stack vertically.',
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 16),
                  LiquidPrismToolbarGroup(
                    axis: Axis.vertical,
                    items: [
                      GlassToolbarItem(
                        icon: const Icon(CupertinoIcons.heart),
                        label: 'Like',
                        onPressed: () => setState(() => actions++),
                      ),
                      GlassToolbarItem(
                        icon: const Icon(CupertinoIcons.bookmark),
                        label: 'Bookmark',
                        onPressed: () => setState(() => actions++),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            ComponentKind.scrollEdges => [
              const Text(
                'Soft where it meets the bar.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scroll the list. The bar’s glass stays clear of the blur.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              ScrollEdgePreview(model: m),
              const SizedBox(height: 20),
              const PackageFeaturesDemo(),
              const SizedBox(height: 20),
              const Text(
                'A scroll fade softens whichever edge content runs past.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              const ScrollFadePreview(),
            ],
            ComponentKind.menus => [
              const Text(
                'A familiar kind of magic.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your glass trigger. The system’s popup.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LiquidPrismButton.menu(
                    key: const ValueKey('native-menu-button'),
                    label: 'Open native menu',
                    menu: _actionMenu(),
                    buttonStyle: GlassButtonStyle.glassProminent,
                    onSelected: _menuSelected,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text('Choose an action')),
                        SizedBox(width: 8),
                        Icon(CupertinoIcons.chevron_down, size: 16),
                      ],
                    ),
                  ),
                  LiquidPrismToolbarGroup(
                    items: [
                      GlassToolbarItem.menu(
                        key: const ValueKey('native-menu-toolbar'),
                        icon: const Icon(CupertinoIcons.ellipsis),
                        label: 'Open toolbar menu',
                        menu: _actionMenu(),
                        onSelected: _menuSelected,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LiquidMenuRegion(
                key: const ValueKey('native-context-menu'),
                trigger: LiquidMenuTrigger.longPress,
                anchor: LiquidMenuAnchorMode.tapPoint,
                menu: _actionMenu(),
                onSelected: _menuSelected,
                child: LiquidPrism(
                  shape: const GlassShape.rect(cornerRadius: 18),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.hand_draw, size: 23),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Hold here for a context menu',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(menuResult, style: const TextStyle(fontSize: 13)),
            ],
            ComponentKind.search => [
              const Text(
                'What’s on your mind?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 22),
              LiquidPrismSearchField(
                key: const ValueKey('demo-search'),
                placeholder: 'Search your ideas',
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 22),
              Text(
                query.isEmpty
                    ? 'Try typing “a fresh start”.'
                    : 'Looking for “$query”',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 22),
              LiquidPrismButton(
                key: const ValueKey('open-search-page'),
                label: 'Open the search page',
                onPressed: () => Navigator.of(context).push<void>(
                  CupertinoPageRoute(builder: (_) => SearchPage(model: m)),
                ),
                child: const Text('Search Page'),
              ),
            ],
            ComponentKind.surfaces => <Widget>[],
          },
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static const _demoTabs = [
    LiquidPrismTab(label: 'Discover', icon: Icon(CupertinoIcons.compass)),
    LiquidPrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
    LiquidPrismTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
  ];

  void _menuSelected(Object? value) {
    if (mounted && value != null) {
      setState(() => menuResult = 'Selected: $value');
    }
  }

  LiquidMenu _actionMenu() => LiquidMenu(
    children: [
      LiquidMenuAction<String>(
        id: 'menu-favorite',
        title: m.favorite ? 'Remove favorite' : 'Add to favorites',
        value: 'Favorite',
        icon: const LiquidMenuSfSymbol('heart'),
        state: m.favorite ? MenuElementState.on : MenuElementState.off,
        onSelected: () => m.change(() => m.favorite = !m.favorite),
      ),
      LiquidMenuAction<String>(
        id: 'menu-new',
        title: 'A new idea',
        value: 'A new idea',
        icon: const LiquidMenuSfSymbol('sparkles'),
        onSelected: () => m.change(() => m.taps++),
      ),
      const LiquidMenuDivider(),
      LiquidSubmenu(
        title: 'Artwork',
        icon: const LiquidMenuSfSymbol('photo'),
        singleSelection: true,
        children: [
          for (var i = 0; i < 3; i++)
            LiquidMenuAction<String>(
              id: 'menu-art-$i',
              title: ['Meadow', 'Dusk', 'Apricot'][i],
              value: ['Meadow', 'Dusk', 'Apricot'][i],
              state: m.wallpaper == i
                  ? MenuElementState.on
                  : MenuElementState.off,
              onSelected: () => m.change(() => m.wallpaper = i),
            ),
        ],
      ),
      LiquidMenuSection(
        title: 'On opening',
        children: [
          LiquidMenuDeferred(
            id: 'menu-deferred',
            loader: () async => [
              LiquidMenuAction<String>(
                id: 'menu-count',
                title: '${m.taps} ideas so far',
                value: 'Idea count',
                icon: const LiquidMenuSfSymbol('lightbulb'),
              ),
            ],
          ),
        ],
      ),
      const LiquidMenuAction<String>(
        id: 'menu-unavailable',
        title: 'Coming soon',
        enabled: false,
        icon: LiquidMenuSfSymbol('clock'),
      ),
      const LiquidMenuDivider(),
      LiquidMenuAction<String>(
        id: 'menu-reset',
        title: 'Reset this demo',
        value: 'Demo reset',
        destructive: true,
        icon: const LiquidMenuSfSymbol('arrow.counterclockwise'),
        onSelected: () => m.change(() {
          m.taps = 0;
          m.favorite = false;
        }),
      ),
    ],
  );
}

/// A bar over a scrolling list inside one [LiquidPrismGroup]: the scroll edge
/// effect and the bar's capsules share captures, so the glass refracts the
/// rows beneath it while the strip around it blurs and fades.
class ScrollEdgePreview extends StatefulWidget {
  const ScrollEdgePreview({super.key, required this.model});
  final ShowcaseModel model;
  @override
  State<ScrollEdgePreview> createState() => _ScrollEdgePreviewState();
}

class _ScrollEdgePreviewState extends State<ScrollEdgePreview> {
  final controller = ScrollController();
  int likes = 0;
  bool hard = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = Art.inks[widget.model.wallpaper];
    const barHeight = 60.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 300,
        child: LiquidPrismGroup(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ListView.builder(
                key: const ValueKey('scroll-edge-list'),
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, barHeight + 8, 12, 12),
                itemCount: 24,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: index.isEven ? .85 : .6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      child: Text(
                        'Row ${index + 1} stays sharp until it meets the bar',
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The bar: its effect fills the bar's box and reaches below it;
              // the capsules paint above it. All of them are group members.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: barHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => LiquidPrismScrollEdge(
                        progress: LiquidPrismScrollEdge.progressFor(
                          controller.hasClients ? controller.offset : 0,
                        ),
                        color: Art.backgrounds[widget.model.wallpaper],
                        style: GlassScrollEdgeStyle(
                          variant: hard
                              ? GlassScrollEdgeVariant.hard
                              : GlassScrollEdgeVariant.soft,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          LiquidPrismToolbarGroup(
                            size: GlassToolbarSize.navigation,
                            items: [
                              GlassToolbarItem(
                                icon: const Icon(CupertinoIcons.chevron_back),
                                label: 'Back to top',
                                onPressed: () => controller.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          LiquidPrismToolbarGroup(
                            size: GlassToolbarSize.navigation,
                            items: [
                              GlassToolbarItem(
                                icon: Icon(
                                  likes.isOdd
                                      ? CupertinoIcons.heart_fill
                                      : CupertinoIcons.heart,
                                ),
                                label: 'Like',
                                onPressed: () => setState(() => likes++),
                              ),
                              GlassToolbarItem(
                                icon: Icon(
                                  hard
                                      ? CupertinoIcons
                                            .rectangle_compress_vertical
                                      : CupertinoIcons
                                            .rectangle_expand_vertical,
                                ),
                                label: hard ? 'Soft edge' : 'Hard edge',
                                onPressed: () => setState(() => hard = !hard),
                              ),
                            ],
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
    );
  }
}

/// A horizontal row of chips whose edges soften while more lie past them.
class ScrollFadePreview extends StatelessWidget {
  const ScrollFadePreview({super.key});
  static const _names = [
    'Meadow',
    'Dusk',
    'Apricot',
    'Harbor',
    'Moss',
    'Ember',
    'Slate',
    'Lilac',
    'Sand',
    'Tide',
    'Fern',
    'Plum',
    'Clay',
    'Mist',
  ];
  @override
  Widget build(BuildContext context) {
    final ink = DefaultTextStyle.of(context).style.color!;
    return SizedBox(
      height: 44,
      child: LiquidPrismScrollFade(
        key: const ValueKey('scroll-fade'),
        axis: Axis.horizontal,
        extent: 48,
        sigma: 3,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _names.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: ink.withValues(alpha: .35)),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  _names[index],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
