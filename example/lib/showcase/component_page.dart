import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'package:liquid_prism_example/showcase/app.dart';
import 'package:liquid_prism_example/showcase/model.dart';
import 'package:liquid_prism_example/showcase/previews.dart';
import 'package:liquid_prism_example/showcase/widgets.dart';

/// A detail page with a live component preview.
class ComponentPage extends StatelessWidget {
  /// Creates a [ComponentPage].
  const new({super.key, required this.info, required this.model});

  /// The component metadata displayed on this page.
  final ComponentInfo info;

  /// Shared showcase appearance and interaction state.
  final ShowcaseModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PrismScaffold(
      backgroundColor: PrismColors.of(context).groupedBackground,
      toolbar: appearanceActions(model),
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
      child: PrismButton(
        label: 'Unavailable action',
        onPressed: null,
        child: Text('Taking a moment'),
      ),
    ),
    ComponentKind.switches => const Row(
      children: [
        Expanded(child: Text('Unavailable switch')),
        PrismSwitch(label: 'Unavailable switch', value: true, onChanged: null),
      ],
    ),
    ComponentKind.sliders => const PrismSlider(
      label: 'Unavailable slider',
      value: .62,
      onChanged: null,
    ),
    ComponentKind.segments => const PrismSegmentedControl<int>(
      label: 'Unavailable segments',
      selectedValue: 0,
      onValueChanged: null,
      children: {0: Text('Day'), 1: Text('Dusk'), 2: Text('Night')},
    ),
    ComponentKind.toolbar => const Align(
      alignment: AlignmentDirectional.centerStart,
      child: PrismToolbar.group(
        items: [
          PrismToolbarItem(
            icon: Icon(CupertinoIcons.star),
            label: 'Unavailable star',
            onPressed: null,
          ),
          PrismToolbarItem(
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
