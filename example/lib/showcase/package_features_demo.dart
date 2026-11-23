import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'widgets.dart';

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
      child: PrismScaffold(
        automaticallyImplyLeading: false,
        title: const Text('Inbox'),
        largeTitle: const Text('Inbox'),
        backgroundColor: PrismColors.of(context).groupedBackground,
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
        tabBar: PrismTabBar(
          selectedIndex: tab,
          onSelected: (value) => setState(() => tab = value),
          onLongPressed: (value) =>
              setState(() => held = ['Inbox', 'Saved'][value]),
          tabs: const [
            PrismTab(
              label: 'Inbox',
              icon: Icon(CupertinoIcons.tray),
              badge: PrismBadge.count(125),
            ),
            PrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
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
              child: PrismSegmentedControl<int>(
                selectedValue: segment,
                onValueChanged: (value) => setState(() => segment = value),
                style: const PrismSegmentedStyle(
                  sizing: PrismSegmentedSizing.fitLabels,
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
