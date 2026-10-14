import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'widgets.dart';

/// A detail page built on [LiquidPrismScaffold.slivers]: a header that
/// scrolls away under the bar before the title swaps in, pull to refresh and
/// a bottom bar, with no scroll view, padding or grouping of its own.
class HeaderPage extends StatelessWidget {
  const HeaderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return LiquidPrismScaffold(
      backgroundColor: colors.groupedBackground,
      title: const Text('Glass Surfaces'),
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
