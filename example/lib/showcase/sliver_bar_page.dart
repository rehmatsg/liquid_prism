import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'package:liquid_prism_example/showcase/widgets.dart';

/// A demo of a navigation bar inside a custom scroll view.
class SliverBarPage extends StatefulWidget {
  /// Creates a [SliverBarPage].
  const new({super.key, this.scrollEdge = true});

  /// Whether the demo enables the scroll-edge effect.
  final bool scrollEdge;

  @override
  State<SliverBarPage> createState() => _SliverBarPageState();
}

class _SliverBarPageState extends State<SliverBarPage> {
  var _segment = 0;

  @override
  Widget build(BuildContext context) {
    final colors = PrismColors.of(context);
    return ColoredBox(
      color: colors.groupedBackground,
      child: CustomScrollView(
        key: const ValueKey('sliver-bar-scroll'),
        slivers: [
          PrismSliverAppBar(
            title: const Text('Library'),
            largeTitle: const Text('Library'),
            backgroundColor: colors.groupedBackground,
            scrollEdge: widget.scrollEdge,
            toolbar: [
              PrismToolbarGroup(
                items: [
                  PrismToolbarItem(
                    icon: const Icon(CupertinoIcons.bell),
                    label: 'Activity',
                    badge: const PrismBadge.dot(),
                    onPressed: () {},
                  ),
                ],
              ),
              PrismToolbarGroup(
                items: [
                  PrismToolbarItem(
                    icon: const Icon(CupertinoIcons.square_arrow_up),
                    label: 'Share',
                    onPressed: () {},
                  ),
                  PrismToolbarItem(
                    icon: const Icon(CupertinoIcons.ellipsis),
                    label: 'More',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
            accessory: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Center(
                child: PrismSegmentedControl<int>(
                  selectedValue: _segment,
                  onValueChanged: (v) => setState(() => _segment = v),
                  children: const {0: Text('All'), 1: Text('Saved')},
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: 40,
              itemBuilder: (context, i) => Container(
                height: 64,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: HSLColor.fromAHSL(1, (i * 23) % 360, .7, .6).toColor(),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Row $i: fine detail to show the glass',
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
