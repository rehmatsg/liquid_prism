import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'app.dart';
import 'model.dart';
import 'previews.dart';
import 'widgets.dart';

class ComponentPage extends StatelessWidget {
  const ComponentPage({super.key, required this.info, required this.model});
  final ComponentInfo info;
  final ShowcaseModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => LiquidPrismScaffold(
      backgroundColor: GlassColors.of(context).groupedBackground,
      actions: appearanceActions(model),
      body: LargeTitlePage(
        key: ValueKey('detail-${info.id}'),
        title: info.title,
        subtitle: info.description,
        children: [
          ComponentPreview(kind: info.kind, model: model),
          const SizedBox(height: 28),
          if (_disabled() case final disabled?)
            InsetSection(
              header: 'Disabled',
              footer: 'Disabled controls keep their place, quietly.',
              children: [
                Padding(padding: const EdgeInsets.all(16), child: disabled),
              ],
            ),
          InsetSection(
            header: 'Details',
            children: [
              for (final (title, detail) in info.details)
                ListRow(title: title, subtitle: detail),
            ],
          ),
        ],
      ),
    ),
  );

  Widget? _disabled() => switch (info.kind) {
    ComponentKind.buttons => const Align(
      alignment: AlignmentDirectional.centerStart,
      child: LiquidPrismButton(
        label: 'Unavailable action',
        onPressed: null,
        child: Text('Taking a moment'),
      ),
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
    ComponentKind.toolbar => Align(
      alignment: AlignmentDirectional.centerStart,
      child: LiquidPrismToolbarGroup(
        items: const [
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
    ),
    _ => null,
  };
}
