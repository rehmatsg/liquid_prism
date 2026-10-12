import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'model.dart';
import 'previews.dart';
import 'widgets.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({
    super.key,
    required this.model,
    required this.open,
    required this.onStudio,
    this.controller,
  });
  final ShowcaseModel model;
  final ValueChanged<ComponentInfo> open;
  final VoidCallback onStudio;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => LargeTitlePage(
    title: 'Explore',
    subtitle: 'Liquid glass for Flutter, made to feel native.',
    controller: controller,
    children: [
      ExploreHero(model: model, onStudio: onStudio),
      const SizedBox(height: 32),
      InsetSection(
        header: 'Try it',
        children: [
          ListRow(
            title: 'A brighter idea',
            icon: CupertinoIcons.lightbulb_fill,
            iconColor: GlassColors.of(context).yellow,
            trailing: LiquidPrismSwitch(
              label: 'A brighter idea',
              value: model.enabled,
              onChanged: (v) => model.change(() => model.enabled = v),
            ),
          ),
          SliderRow(
            title: 'Intensity',
            value: model.level,
            display: '${(model.level * 100).round()}%',
            onChanged: (v) => model.change(() => model.level = v),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LiquidPrismButton(
                  label: 'Try a button',
                  buttonStyle: GlassButtonStyle.glassProminent,
                  onPressed: () => model.change(() => model.taps++),
                  child: const Text('Try a button'),
                ),
                FavoriteButton(model: model),
                Text(
                  model.taps == 0
                      ? 'Hold to feel the lift.'
                      : '${model.taps} ${model.taps == 1 ? 'tap' : 'taps'}',
                  style: TextStyle(fontSize: 15, color: muted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
      InsetSection(
        header: 'Featured',
        children: [
          for (final info in [components[0], components[5], components[7]])
            ComponentRow(info: info, onPressed: () => open(info)),
        ],
      ),
    ],
  );
}

class ExploreHero extends StatelessWidget {
  const ExploreHero({super.key, required this.model, required this.onStudio});
  final ShowcaseModel model;
  final VoidCallback onStudio;

  @override
  Widget build(BuildContext context) => ArtCanvas(
    variant: model.wallpaper,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          Art.names[model.wallpaper].toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: LiquidPrism(
              key: const ValueKey('hero-glass'),
              shape: const GlassShape.rect(cornerRadius: 28),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.sparkles,
                      size: 30,
                      color: GlassColors.light.label,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hello, glass.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GlassColors.light.label,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A fresh perspective.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: GlassColors.light.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 14,
          children: [
            const Text(
              'Real refraction,\nright on the artwork.',
              style: TextStyle(fontSize: 15, height: 1.3),
            ),
            LiquidPrismButton(
              label: 'Make it yours',
              buttonStyle: GlassButtonStyle.glassProminent,
              onPressed: onStudio,
              child: const Text('Make it yours'),
            ),
          ],
        ),
      ],
    ),
  );
}

class StudioPage extends StatelessWidget {
  const StudioPage({super.key, required this.model, this.controller});
  final ShowcaseModel model;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return LargeTitlePage(
      title: 'Studio',
      subtitle: 'Shape the glass. Every screen follows.',
      controller: controller,
      children: [
        LensPlayground(model: model, expert: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          child: Text(
            'Drag the glass across the artwork.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
          ),
        ),
        InsetSection(
          header: 'Appearance',
          children: [
            ListRow(
              title: 'Dark appearance',
              icon: CupertinoIcons.moon_fill,
              iconColor: colors.indigo,
              trailing: LiquidPrismSwitch(
                label: 'Dark appearance',
                value: model.dark,
                onChanged: (v) => model.change(() => model.dark = v),
              ),
            ),
            ListRow(
              title: 'Clear material',
              icon: CupertinoIcons.drop_fill,
              iconColor: colors.cyan,
              trailing: LiquidPrismSwitch(
                label: 'Clear material',
                value: model.clear,
                onChanged: (v) => model.change(() => model.clear = v),
              ),
            ),
            ListRow(
              title: 'Tab labels',
              icon: CupertinoIcons.textformat,
              iconColor: colors.orange,
              trailing: LiquidPrismSwitch(
                label: 'Tab labels',
                value: model.labels,
                onChanged: (v) => model.change(() => model.labels = v),
              ),
            ),
          ],
        ),
        InsetSection(
          header: 'Accent',
          footer: 'Buttons, switches and the selected tab use your accent.',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in colors.accents.entries)
                    LiquidPrismPressable(
                      label: 'Use ${entry.key} tint',
                      selected: model.accent == entry.key,
                      onPressed: () =>
                          model.change(() => model.accent = entry.key),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                          border: model.accent == entry.key
                              ? Border.all(color: colors.cell, width: 3)
                              : null,
                          boxShadow: model.accent == entry.key
                              ? [BoxShadow(color: entry.value, spreadRadius: 2)]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        InsetSection(
          header: 'Optics',
          footer: 'Frost and refraction apply to the canvas above.',
          children: [
            SliderRow(
              title: 'Frost',
              value: model.frost,
              min: 0,
              max: 12,
              display: model.frost.toStringAsFixed(1),
              onChanged: (v) => model.change(() => model.frost = v),
            ),
            SliderRow(
              title: 'Refraction',
              value: model.refraction,
              min: 0,
              max: 64,
              display: '${model.refraction.round()}',
              onChanged: (v) => model.change(() => model.refraction = v),
            ),
          ],
        ),
        InsetSection(
          header: 'Artwork',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LiquidPrismSegmentedControl<int>(
                label: 'Artwork',
                selectedValue: model.wallpaper,
                onValueChanged: (v) => model.change(() => model.wallpaper = v),
                children: {
                  for (var i = 0; i < Art.names.length; i++)
                    i: Text(Art.names[i]),
                },
              ),
            ),
          ],
        ),
        InsetSection(
          children: [
            LiquidPrismPressable(
              label: 'Restore defaults',
              onPressed: model.reset,
              child: SizedBox(
                height: 52,
                child: Center(
                  child: Text(
                    'Restore Defaults',
                    style: TextStyle(fontSize: 17, color: colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.model,
    required this.search,
    required this.focus,
    required this.open,
    this.controller,
  });
  final ShowcaseModel model;
  final TextEditingController search;
  final FocusNode focus;
  final ValueChanged<ComponentInfo> open;
  final ScrollController? controller;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.trim().toLowerCase();
    final results = components
        .where((c) => '${c.title} ${c.subtitle}'.toLowerCase().contains(query))
        .toList();
    return LargeTitlePage(
      title: 'Library',
      subtitle: 'Every component, with a live preview.',
      controller: widget.controller,
      children: [
        LiquidPrismSearchField(
          key: const ValueKey('library-search'),
          controller: widget.search,
          focusNode: widget.focus,
          placeholder: 'Search components',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        if (results.isEmpty)
          InsetSection(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                child: Column(
                  children: [
                    const Text(
                      'Nothing here just yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try “glass”, “slider” or “button”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: muted(context)),
                    ),
                    const SizedBox(height: 16),
                    LiquidPrismButton(
                      label: 'Reset library search',
                      onPressed: () {
                        widget.search.clear();
                        setState(() {});
                      },
                      child: const Text('Clear Search'),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          InsetSection(
            header:
                '${results.length} ${results.length == 1 ? 'component' : 'components'}',
            children: [
              for (final info in results)
                ComponentRow(info: info, onPressed: () => widget.open(info)),
            ],
          ),
      ],
    );
  }
}

/// A list row for one component, opening its detail page.
class ComponentRow extends StatelessWidget {
  const ComponentRow({super.key, required this.info, required this.onPressed});
  final ComponentInfo info;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ListRow(
    title: info.title,
    subtitle: info.subtitle,
    icon: info.icon,
    iconColor: info.color,
    label: 'Explore ${info.title}',
    onPressed: onPressed,
  );
}

/// A titled slider with its value, in a list.
class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.display,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
  });
  final String title, display;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
            Text(
              display,
              style: TextStyle(fontSize: 17, color: muted(context)),
            ),
          ],
        ),
        LiquidPrismSlider(
          label: title,
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.model});
  final ShowcaseModel model;

  @override
  Widget build(BuildContext context) => LiquidPrismButton(
    label: 'Favorite',
    selected: model.favorite,
    shape: GlassShape.circle,
    padding: const EdgeInsets.all(12),
    onPressed: () => model.change(() => model.favorite = !model.favorite),
    child: Icon(
      model.favorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
      size: 22,
      color: model.favorite ? GlassColors.of(context).pink : null,
    ),
  );
}
