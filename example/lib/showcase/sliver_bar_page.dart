import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'widgets.dart';

/// A page whose bar is a [LiquidPrismSliverAppBar]: the large title collapses
/// with the scroll and the bar's glass refracts the rows beneath it.
class SliverBarPage extends StatefulWidget {
  const SliverBarPage({super.key, this.scrollEdge = true});
  final bool scrollEdge;

  @override
  State<SliverBarPage> createState() => _SliverBarPageState();
}

class _SliverBarPageState extends State<SliverBarPage> {
  var _segment = 0;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return ColoredBox(
      color: colors.groupedBackground,
      child: CustomScrollView(
        key: const ValueKey('sliver-bar-scroll'),
        slivers: [
          LiquidPrismSliverAppBar(
            title: const Text('Library'),
            largeTitle: const Text('Library'),
            backgroundColor: colors.groupedBackground,
            scrollEdge: widget.scrollEdge,
            actions: [
              [
                GlassToolbarItem(
                  icon: const Icon(CupertinoIcons.bell),
                  label: 'Activity',
                  badge: const GlassBadge.dot(),
                  onPressed: () {},
                ),
              ],
              [
                GlassToolbarItem(
                  icon: const Icon(CupertinoIcons.square_arrow_up),
                  label: 'Share',
                  onPressed: () {},
                ),
                GlassToolbarItem(
                  icon: const Icon(CupertinoIcons.ellipsis),
                  label: 'More',
                  onPressed: () {},
                ),
              ],
            ],
            accessory: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Center(
                child: LiquidPrismSegmentedControl<int>(
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
