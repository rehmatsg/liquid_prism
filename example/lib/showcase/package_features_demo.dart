import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'widgets.dart';

/// Scroll, hold a tab, or change a segment to exercise package-owned chrome.
class PackageFeaturesDemo extends StatefulWidget {
  const PackageFeaturesDemo({super.key});
  @override
  State<PackageFeaturesDemo> createState() => _PackageFeaturesDemoState();
}

class _PackageFeaturesDemoState extends State<PackageFeaturesDemo> {
  int tab = 0, segment = 0;
  String? held;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 420,
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
      child: LiquidPrismScaffold(
        automaticallyImplyLeading: false,
        title: const Text('Inbox'),
        largeTitle: const Text('Inbox'),
        backgroundColor: GlassColors.of(context).groupedBackground,
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
        tabBar: LiquidPrismTabBar(
          selectedIndex: tab,
          onSelected: (value) => setState(() => tab = value),
          onLongPressed: (value) =>
              setState(() => held = ['Inbox', 'Saved'][value]),
          tabs: const [
            LiquidPrismTab(
              label: 'Inbox',
              icon: Icon(CupertinoIcons.tray),
              badge: GlassBadge.count(125),
            ),
            LiquidPrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
          ],
        ),
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                held == null
                    ? 'Scroll to collapse the title. Hold a tab for its action.'
                    : 'Held $held; selection remains ${['Inbox', 'Saved'][tab]}.',
              ),
            ),
            Center(
              child: LiquidPrismSegmentedControl<int>(
                selectedValue: segment,
                onValueChanged: (value) => setState(() => segment = value),
                style: const GlassSegmentedStyle(
                  sizing: GlassSegmentedSizing.fitLabels,
                ),
                children: const {0: Text('All'), 1: Text('Unread messages')},
              ),
            ),
            for (var i = 0; i < 16; i++)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Message ${i + 1}'),
              ),
          ],
        ),
      ),
    ),
  );
}
