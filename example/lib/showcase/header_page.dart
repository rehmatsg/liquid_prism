import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'widgets.dart';

/// A detail page built on [LiquidPrismScaffold.slivers]: a header that
/// scrolls away under the bar before the title swaps in, sticky tabs that pin
/// below the bar, a trailing pill, pull to refresh and a bottom bar, with no
/// scroll view, padding or grouping of its own.
class HeaderPage extends StatefulWidget {
  const HeaderPage({super.key});

  @override
  State<HeaderPage> createState() => _HeaderPageState();
}

class _HeaderPageState extends State<HeaderPage> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return LiquidPrismScaffold(
      backgroundColor: colors.groupedBackground,
      title: const Text('Glass Surfaces'),
      subtitle: const Text('Component'),
      actions: [
        [
          GlassToolbarItem(
            icon: const Icon(CupertinoIcons.bookmark),
            label: 'Save',
            onPressed: () {},
          ),
          GlassToolbarItem(
            icon: const Icon(CupertinoIcons.ellipsis),
            label: 'More',
            onPressed: () {},
          ),
        ],
      ],
      trailing: Container(
        key: const ValueKey('header-trailing'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.blue.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '12 left',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.blue,
          ),
        ),
      ),
      onRefresh: () => Future<void>.delayed(const Duration(seconds: 1)),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Row(
          children: [
            const SymbolTile(
              icon: CupertinoIcons.layers,
              color: Color(0xFF30B0C7),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Glass Surfaces',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'A window into what’s underneath.',
                    style: TextStyle(fontSize: 15, color: muted(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: LiquidPrismButton(
          label: 'Use this surface',
          onPressed: () {},
          child: const Text('Use This Surface'),
        ),
      ),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabs(
            background: colors.groupedBackground,
            child: LiquidPrismSegmentedControl<int>(
              key: const ValueKey('header-tabs'),
              selectedValue: _tab,
              style: const GlassSegmentedStyle(
                sizing: GlassSegmentedSizing.fitLabels,
              ),
              onValueChanged: (v) => setState(() => _tab = v),
              children: const {
                0: Text('Overview'),
                1: Text('Activity'),
                2: Text('Notes'),
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: 30,
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
                'Detail $i',
                style: const TextStyle(fontSize: 17, color: Color(0xFF111111)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tabs that pin below the bar once the header has scrolled away.
class _StickyTabs extends SliverPersistentHeaderDelegate {
  _StickyTabs({required this.background, required this.child});
  final Color background;
  final Widget child;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(
        color: background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: child,
          ),
        ),
      );

  @override
  bool shouldRebuild(_StickyTabs old) =>
      old.background != background || old.child != child;
}
