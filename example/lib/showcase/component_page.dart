import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'model.dart';
import 'widgets.dart';
import 'previews.dart';

class ComponentPage extends StatelessWidget {
  const ComponentPage({super.key, required this.info, required this.model});
  final ComponentInfo info;
  final ShowcaseModel model;
  static const descriptions = {
    ComponentKind.surfaces: 'Glass bends the scene behind it while keeping your content crisp. Move the lens, then try regular, clear, and tinted materials.',
    ComponentKind.buttons: 'An everyday action with a tactile response. Try a quiet glass button, a prominent action, or a circular favorite.',
    ComponentKind.switches: 'Tap to change your outlook. Hold and drag the thumb to feel its lift and the spring that brings it home.',
    ComponentKind.sliders: 'A little precision, a little play. Drag the thumb to change the value and watch it lift under your finger.',
    ComponentKind.segments: 'A shared track with a gliding selection. Tap a perspective or hold the pill and slide to a new one.',
    ComponentKind.tabs: 'A floating home for navigation. The selection lifts, follows your finger, and settles into its next destination.',
    ComponentKind.toolbar: 'Related actions share a single glass capsule. Each icon responds individually while the whole group lifts together.',
    ComponentKind.menus: 'A glass button, a real native popup. Try sections, checkmarks, SF Symbols, submenus, and items loaded when the menu opens. UIKit handles the presentation.',
    ComponentKind.search: 'A field that makes space when you need it. Type a thought, clear it, or cancel to return to the moment.',
    ComponentKind.sheets: 'A presentation that follows your hand. Open at half height, pull it up, scroll through, and glide it away.',
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle
          .copyWith(color: ink(context)),
      child: ShowcaseBackdrop(
        model: model,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Row(
                    children: [
                      IconAction(
                        icon: CupertinoIcons.chevron_left,
                        label: 'Back to showcase',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          info.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconAction(
                        icon: model.dark
                            ? CupertinoIcons.sun_max
                            : CupertinoIcons.moon,
                        label: 'Toggle appearance',
                        onPressed: () =>
                            model.change(() => model.dark = !model.dark),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey('detail-${info.id}'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow('The collection / ${info.id}'),
                            const SizedBox(height: 14),
                            Text(
                              info.title,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Note(descriptions[info.kind]!),
                            const SizedBox(height: 28),
                            ComponentPreview(kind: info.kind, model: model),
                            const SizedBox(height: 26),
                            if ([
                              ComponentKind.buttons,
                              ComponentKind.switches,
                              ComponentKind.sliders,
                              ComponentKind.segments,
                              ComponentKind.toolbar,
                            ].contains(info.kind)) ...[
                              const SectionTitle('At rest, too.'),
                              const SizedBox(height: 8),
                              const Note(
                                'Disabled controls keep their place, quietly.',
                              ),
                              const SizedBox(height: 14),
                              Panel(child: _disabled()),
                              const SizedBox(height: 26),
                            ],
                            Panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Eyebrow('The finishing touches'),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Made to feel familiar.',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Note(
                                    'Native palette colors, continuous corners, and touch-driven springs. Your appearance and accent from Studio follow you here.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _disabled() => switch (info.kind) {
    ComponentKind.buttons => const LiquidPrismButton(
      label: 'Unavailable action',
      onPressed: null,
      child: Text('Taking a moment'),
    ),
    ComponentKind.switches => const Row(
      children: [
        Expanded(child: Text('Unavailable switch')),
        LiquidPrismSwitch(
          label: 'Unavailable switch',
          value: true,
          onChanged: null,
        ),
      ],
    ),
    ComponentKind.sliders => const LiquidPrismSlider(
      label: 'Unavailable slider',
      value: .62,
      onChanged: null,
    ),
    ComponentKind.segments => const LiquidPrismSegmentedControl<int>(
      label: 'Unavailable segments',
      selectedValue: 0,
      onValueChanged: null,
      children: {0: Text('Day'), 1: Text('Dusk'), 2: Text('Night')},
    ),
    ComponentKind.toolbar => LiquidPrismToolbarGroup(
      items: [
        GlassToolbarItem(
          icon: Icon(CupertinoIcons.star),
          label: 'Unavailable star',
          onPressed: null,
        ),
        GlassToolbarItem(
          icon: Icon(CupertinoIcons.share),
          label: 'Unavailable share',
          onPressed: null,
        ),
      ],
    ),
    _ => const SizedBox.shrink(),
  };
}
