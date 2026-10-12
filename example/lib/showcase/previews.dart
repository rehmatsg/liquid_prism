import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'model.dart';
import 'widgets.dart';

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
                const Positioned(
                  left: 20,
                  top: 20,
                  child: Eyebrow('Move / Discover', color: Color(0xFF314D47)),
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
                const Positioned(
                  right: 18,
                  bottom: 17,
                  child: Icon(
                    CupertinoIcons.move,
                    size: 19,
                    color: Color(0xAA314D47),
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

class CanvasClip extends CustomClipper<Path> {
  const CanvasClip();
  @override
  Path getClip(Size size) => const GlassShape.rect(cornerRadius: 28).path(size);
  @override
  bool shouldReclip(CanvasClip old) => false;
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
  String query = '', sheetResult = 'A little more room to explore.';
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
                    child: LiquidPrismSelection(
                      selected: selectedSurface == i,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          ['Regular', 'Clear', 'Tinted', 'Identity'][i],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return DefaultTextStyle.merge(
      style: TextStyle(color: GlassColors.light.label),
      child: ClipPath(
        clipper: const CanvasClip(),
        child: Art(
          variant: m.wallpaper,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Eyebrow('The live preview', color: Color(0xFF314D47)),
                const SizedBox(height: 28),
                ...switch (widget.kind) {
                  ComponentKind.buttons => [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ActionButton(
                          'Glass',
                          label: 'Add a tap',
                          onPressed: () => m.change(() => m.taps++),
                        ),
                        ActionButton(
                          'Prominent',
                          label: 'Add a prominent tap',
                          onPressed: () => m.change(() => m.taps++),
                          prominent: true,
                        ),
                        LiquidPrismButton(
                          label: 'Favorite',
                          selected: m.favorite,
                          shape: GlassShape.circle,
                          padding: const EdgeInsets.all(15),
                          onPressed: () =>
                              m.change(() => m.favorite = !m.favorite),
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
                      color: GlassColors.light.label,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        m.enabled
                            ? 'A brighter outlook.'
                            : 'A moment of quiet.',
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
                      color: GlassColors.light.label,
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
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
                    const SizedBox(height: 34),
                    LiquidPrismTabBar(
                      selectedIndex: selectedTab,
                      onSelected: (v) => setState(() => selectedTab = v),
                      tabs: const [
                        LiquidPrismTab(
                          label: 'Discover',
                          icon: Icon(CupertinoIcons.compass),
                        ),
                        LiquidPrismTab(
                          label: 'Saved',
                          icon: Icon(CupertinoIcons.bookmark),
                        ),
                        LiquidPrismTab(
                          label: 'Home',
                          icon: Icon(CupertinoIcons.house),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hold the pill and glide between tabs.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  ComponentKind.toolbar => [
                    const Text(
                      'A little group effort.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LiquidPrismToolbarGroup(
                          key: const ValueKey('demo-toolbar'),
                          size: GlassToolbarSize.navigation,
                          items: [
                            GlassToolbarItem(
                              icon: const Icon(CupertinoIcons.star),
                              label: 'Star',
                              width: 42 + 1 / 3,
                              onPressed: () => setState(() => actions++),
                            ),
                            GlassToolbarItem(
                              icon: const Icon(CupertinoIcons.share),
                              label: 'Share',
                              width: 38 + 2 / 3,
                              onPressed: () => setState(() => actions++),
                            ),
                            GlassToolbarItem.menu(
                              icon: const Icon(CupertinoIcons.ellipsis),
                              label: 'More',
                              menu: _actionMenu(),
                              onSelected: _menuSelected,
                            ),
                          ],
                        ),
                        LiquidPrismToolbarGroup(
                          items: [
                            GlassToolbarItem(
                              icon: const Icon(CupertinoIcons.square_pencil),
                              label: 'Compose',
                              onPressed: () => setState(() => actions++),
                            ),
                          ],
                        ),
                      ],
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
                    Text(
                      '$actions actions. Hold an icon to lift its group.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                  ComponentKind.menus => [
                    const Text(
                      'A familiar kind of magic.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
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
                  ],
                  ComponentKind.sheets => [
                    const Icon(CupertinoIcons.rectangle_on_rectangle, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Make room for more.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ActionButton(
                        'Open a sheet',
                        onPressed: () => _openSheet(context),
                        prominent: true,
                        icon: CupertinoIcons.arrow_up,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      sheetResult,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                  ComponentKind.surfaces => <Widget>[],
                },
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Future<void> _openSheet(BuildContext context) async {
    final result = await showLiquidPrismSheet<String>(
      context: context,
      semanticLabel: 'A fresh perspective',
      builder: (context, scroll) => DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle
            .copyWith(color: GlassColors.light.label),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('A fresh perspective')),
                IconAction(
                  icon: CupertinoIcons.xmark,
                  label: 'Close sheet',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Good ideas\nneed a little space.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 14),
            const Note(
              'Pull up to see more. Pull down when you’re done. The glass follows your lead.',
            ),
            const SizedBox(height: 24),
            Panel(
              child: Row(
                children: [
                  Icon(CupertinoIcons.sparkles, color: m.tint),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Something worth keeping.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ActionButton(
              'Keep this feeling',
              onPressed: () =>
                  Navigator.of(context).pop('A good feeling, saved.'),
              prominent: true,
              icon: CupertinoIcons.check_mark,
            ),
            const SizedBox(height: 30),
            const SectionTitle('A few small details'),
            const SizedBox(height: 18),
            for (final text in [
              'Two heights, one fluid gesture.',
              'Smooth corners, all the way around.',
              'Content that scrolls with you.',
              'A backdrop that becomes a canvas.',
              'A natural place to pause.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.check_mark_circled,
                      color: m.tint,
                      size: 21,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(text, style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() => sheetResult = result ?? 'Back to the bigger picture.');
    }
  }
}
