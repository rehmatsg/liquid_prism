import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'model.dart';
import 'widgets.dart';
import 'previews.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({
    super.key,
    required this.model,
    required this.open,
    required this.onStudio,
    required this.onLibrary,
  });
  final ShowcaseModel model;
  final ValueChanged<ComponentInfo> open;
  final VoidCallback onStudio, onLibrary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 10),
      const Eyebrow('An interactive collection'),
      const SizedBox(height: 13),
      const Text(
        'A little glass.\nA lot of possibility.',
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.8,
          height: 1.06,
        ),
      ),
      const SizedBox(height: 14),
      const Note('Beautifully tactile components.\nMade for the way you move.'),
      const SizedBox(height: 24),
      HeroCanvas(model: model),
      const SizedBox(height: 17),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ActionButton(
            'Make it yours',
            onPressed: onStudio,
            prominent: true,
            icon: CupertinoIcons.arrow_up_right,
          ),
          ActionButton('All components', onPressed: onLibrary),
        ],
      ),
      const SizedBox(height: 32),
      const SectionTitle('Made to be touched'),
      const SizedBox(height: 6),
      const Note('A few favorites. Go ahead, play.'),
      const SizedBox(height: 16),
      FlowGrid(
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('01 / Controls'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'A brighter idea',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    LiquidPrismSwitch(
                      label: 'A brighter idea',
                      value: model.enabled,
                      onChanged: (v) => model.change(() => model.enabled = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LiquidPrismSlider(
                  label: 'Preview intensity',
                  value: model.level,
                  onChanged: (v) => model.change(() => model.level = v),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(child: Note('A little or a lot')),
                    Note('${(model.level * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('02 / Actions'),
                const SizedBox(height: 16),
                const Text(
                  'Good things, on tap.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionButton(
                      'Try a button',
                      onPressed: () => model.change(() => model.taps++),
                      prominent: true,
                      icon: CupertinoIcons.plus,
                    ),
                    LiquidPrismButton(
                      label: 'Favorite',
                      selected: model.favorite,
                      shape: GlassShape.circle,
                      padding: const EdgeInsets.all(14),
                      onPressed: () =>
                          model.change(() => model.favorite = !model.favorite),
                      child: Icon(
                        model.favorite
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Note(
                  model.taps == 0
                      ? 'Press and hold to feel the lift.'
                      : '${model.taps} ${model.taps == 1 ? 'tap' : 'taps'}. One more?',
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 30),
      const SectionTitle('The collection'),
      const SizedBox(height: 14),
      FlowGrid(
        children: [
          for (final info in [components[0], components[5], components.last])
            ComponentRow(info: info, onPressed: () => open(info)),
        ],
      ),
      const SizedBox(height: 20),
      const Center(child: Eyebrow('Thoughtfully made. Delightfully fluid.')),
    ],
  );
}

class HeroCanvas extends StatelessWidget {
  const HeroCanvas({super.key, required this.model});
  final ShowcaseModel model;
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const CanvasClip(),
    child: Art(
      variant: model.wallpaper,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Eyebrow(
              'Light, with a life of its own',
              color: Color(0xFF314D47),
            ),
            const SizedBox(height: 25),
            Align(
              alignment: const Alignment(.12, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: LiquidPrism(
                  shape: const GlassShape.rect(cornerRadius: 27),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 22,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.sparkles,
                          size: 32,
                          color: GlassColors.light.label,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'Hello, glass.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: GlassColors.light.label,
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.7,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'A fresh perspective.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: GlassColors.light.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'LIVE MATERIAL',
                    style: TextStyle(
                      color: Color(0xFF314D47),
                      letterSpacing: 1.4,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                LiquidPrismToolbarGroup(
                  size: GlassToolbarSize.navigation,
                  foregroundColor: GlassColors.light.label,
                  items: [
                    GlassToolbarItem(
                      icon: const Icon(CupertinoIcons.arrow_2_circlepath),
                      label: 'Change artwork',
                      onPressed: () => model.change(
                        () => model.wallpaper = (model.wallpaper + 1) % 3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class StudioPage extends StatelessWidget {
  const StudioPage({super.key, required this.model});
  final ShowcaseModel model;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Eyebrow('Your creative playground'),
      const SizedBox(height: 12),
      const Text(
        'Find your feel.',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.4,
        ),
      ),
      const SizedBox(height: 10),
      const Note('Change the light. Shift the color. Make it yours.'),
      const SizedBox(height: 22),
      LensPlayground(model: model, expert: true),
      const SizedBox(height: 8),
      const Center(child: Note('Drag the glass across the artwork.')),
      const SizedBox(height: 24),
      FlowGrid(
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Look & feel'),
                const SizedBox(height: 18),
                SettingRow(
                  title: 'Dark appearance',
                  subtitle: 'A different kind of glow.',
                  child: LiquidPrismSwitch(
                    label: 'Dark appearance',
                    value: model.dark,
                    onChanged: (v) => model.change(() => model.dark = v),
                  ),
                ),
                const SizedBox(height: 18),
                SettingRow(
                  title: 'Clear material',
                  subtitle: 'Let more of the world through.',
                  child: LiquidPrismSwitch(
                    label: 'Clear material',
                    value: model.clear,
                    onChanged: (v) => model.change(() => model.clear = v),
                  ),
                ),
                const SizedBox(height: 18),
                SettingRow(
                  title: 'Tab labels',
                  subtitle: 'Keep a little context.',
                  child: LiquidPrismSwitch(
                    label: 'Tab labels',
                    value: model.labels,
                    onChanged: (v) => model.change(() => model.labels = v),
                  ),
                ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('A color story'),
                const SizedBox(height: 12),
                const Note('Native palette. Your signature accent.'),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in GlassColors.of(context).accents.entries)
                      LiquidPrismPressable(
                        label: 'Use ${entry.key} tint',
                        selected: model.accent == entry.key,
                        onPressed: () =>
                            model.change(() => model.accent = entry.key),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                          ),
                          child: model.accent == entry.key
                              ? const Icon(
                                  CupertinoIcons.check_mark,
                                  color: Color(0xFFFFFFFF),
                                  size: 19,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Note('Selected: ${model.accent}'),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('The optics'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Frost',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Note(model.frost.toStringAsFixed(1)),
                  ],
                ),
                LiquidPrismSlider(
                  label: 'Frost',
                  value: model.frost,
                  min: 0,
                  max: 12,
                  onChanged: (v) => model.change(() => model.frost = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Refraction',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Note('${model.refraction.round()}'),
                  ],
                ),
                LiquidPrismSlider(
                  label: 'Refraction',
                  value: model.refraction,
                  min: 0,
                  max: 64,
                  onChanged: (v) => model.change(() => model.refraction = v),
                ),
                const Note(
                  'These adjustments affect the glass in this canvas.',
                ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Behind the glass'),
                const SizedBox(height: 16),
                LiquidPrismSegmentedControl<int>(
                  label: 'Artwork',
                  selectedValue: model.wallpaper,
                  onValueChanged: (v) =>
                      model.change(() => model.wallpaper = v),
                  children: const {
                    0: Text('Meadow'),
                    1: Text('Dusk'),
                    2: Text('Apricot'),
                  },
                ),
                const SizedBox(height: 16),
                const Note('Three original canvases. A new view every time.'),
                const SizedBox(height: 16),
                ActionButton(
                  'Restore defaults',
                  onPressed: model.reset,
                  icon: CupertinoIcons.arrow_counterclockwise,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Note(subtitle),
          ],
        ),
      ),
      const SizedBox(width: 12),
      child,
    ],
  );
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.model,
    required this.controller,
    required this.focus,
    required this.open,
  });
  final ShowcaseModel model;
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<ComponentInfo> open;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim().toLowerCase();
    final results = components
        .where((c) => '${c.title} ${c.subtitle}'.toLowerCase().contains(query))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('The complete collection'),
        const SizedBox(height: 12),
        const Text(
          'The building blocks.',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 10),
        const Note(
          'Ten components. Endless possibilities.\nOpen one to get a feel for every detail.',
        ),
        const SizedBox(height: 22),
        LiquidPrismSearchField(
          key: const ValueKey('library-search'),
          controller: widget.controller,
          focusNode: widget.focus,
          placeholder: 'Find a component',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 22),
        Eyebrow(
          '${results.length} ${results.length == 1 ? 'component' : 'components'}',
        ),
        const SizedBox(height: 12),
        if (results.isEmpty)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nothing here just yet.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Note('Try “glass”, “slider”, or “sheet”.'),
                const SizedBox(height: 16),
                ActionButton(
                  'Clear search',
                  label: 'Reset library search',
                  onPressed: () {
                    widget.controller.clear();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        FlowGrid(
          children: [
            for (final info in results)
              ComponentRow(
                info: info,
                onPressed: () {
                  widget.focus.unfocus();
                  widget.open(info);
                },
              ),
          ],
        ),
      ],
    );
  }
}
