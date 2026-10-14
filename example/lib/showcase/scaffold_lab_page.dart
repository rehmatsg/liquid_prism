import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'widgets.dart';

enum _Heading { large, header, inline }

enum _Edge { soft, hard, off }

/// One [LiquidPrismScaffold] built from slivers, with every page-level option
/// switchable live: the heading, the edge effect, an accessory, a bottom bar,
/// one or two action capsules, badges and pull to refresh.
class ScaffoldLabPage extends StatefulWidget {
  const ScaffoldLabPage({super.key});

  @override
  State<ScaffoldLabPage> createState() => _ScaffoldLabPageState();
}

class _ScaffoldLabPageState extends State<ScaffoldLabPage> {
  var _heading = _Heading.large;
  var _edge = _Edge.soft;
  var _accessory = false;
  var _bottomBar = true;
  var _twoCapsules = true;
  var _badges = true;
  var _refresh = true;
  var _subtitle = false;
  var _segment = 0;
  var _refreshed = 0;

  Widget _toggle(String title, bool value, ValueChanged<bool> onChanged) =>
      ListRow(
        title: title,
        trailing: LiquidPrismSwitch(
          key: ValueKey('lab-$title'),
          label: title,
          value: value,
          onChanged: (v) => setState(() => onChanged(v)),
        ),
      );

  Widget _choice<T extends Object>(
    String title,
    T value,
    Map<T, String> options,
    ValueChanged<T> onChanged,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 10),
        LiquidPrismSegmentedControl<T>(
          label: title,
          selectedValue: value,
          style: const GlassSegmentedStyle(
            sizing: GlassSegmentedSizing.fitLabels,
          ),
          onValueChanged: (v) => setState(() => onChanged(v)),
          children: {for (final e in options.entries) e.key: Text(e.value)},
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final share = GlassToolbarItem(
      icon: const Icon(CupertinoIcons.square_arrow_up),
      label: 'Share',
      onPressed: () {},
    );
    final more = GlassToolbarItem(
      icon: const Icon(CupertinoIcons.ellipsis),
      label: 'More',
      onPressed: () {},
    );
    final inbox = GlassToolbarItem(
      icon: const Icon(CupertinoIcons.tray),
      label: 'Inbox',
      badge: _badges ? const GlassBadge.count(3) : null,
      onPressed: () {},
    );
    return LiquidPrismScaffold(
      backgroundColor: colors.groupedBackground,
      title: const Text('Scaffold Lab'),
      subtitle: _subtitle ? const Text('Every page option, live') : null,
      largeTitle: _heading == _Heading.large
          ? const Text('Scaffold Lab')
          : null,
      header: _heading == _Heading.header
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scaffold Lab',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A header of your own that scrolls away under the bar.',
                    style: TextStyle(fontSize: 15, color: muted(context)),
                  ),
                ],
              ),
            )
          : null,
      actions: _twoCapsules
          ? [
              [inbox],
              [share, more],
            ]
          : [inbox, share, more],
      scrollEdge: _edge != _Edge.off,
      scrollEdgeStyle: GlassScrollEdgeStyle(
        variant: _edge == _Edge.hard
            ? GlassScrollEdgeVariant.hard
            : GlassScrollEdgeVariant.soft,
      ),
      accessory: _accessory
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Center(
                child: LiquidPrismSegmentedControl<int>(
                  selectedValue: _segment,
                  style: const GlassSegmentedStyle(
                    sizing: GlassSegmentedSizing.fitLabels,
                  ),
                  onValueChanged: (v) => setState(() => _segment = v),
                  children: const {
                    0: Text('Overview'),
                    1: Text('Activity'),
                    2: Text('Notes'),
                  },
                ),
              ),
            )
          : null,
      onRefresh: _refresh
          ? () async {
              await Future<void>.delayed(const Duration(milliseconds: 900));
              if (mounted) setState(() => _refreshed++);
            }
          : null,
      bottomBar: _bottomBar
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: LiquidPrismButton(
                key: const ValueKey('lab-bottom-action'),
                label: 'Primary action',
                onPressed: () {},
                child: const Text('Continue'),
              ),
            )
          : null,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          sliver: SliverList.list(
            children: [
              InsetSection(
                header: 'Heading',
                children: [
                  _choice<_Heading>('Style', _heading, const {
                    _Heading.large: 'Large title',
                    _Heading.header: 'Header',
                    _Heading.inline: 'Inline',
                  }, (v) => _heading = v),
                ],
              ),
              InsetSection(
                header: 'Edge effect',
                footer:
                    'Content under the bar blurs and fades. The glass refracts '
                    'it as it is, before the effect.',
                children: [
                  _choice<_Edge>('Variant', _edge, const {
                    _Edge.soft: 'Soft',
                    _Edge.hard: 'Hard',
                    _Edge.off: 'Off',
                  }, (v) => _edge = v),
                ],
              ),
              InsetSection(
                header: 'Chrome',
                children: [
                  _toggle('Accessory row', _accessory, (v) => _accessory = v),
                  _toggle('Bottom bar', _bottomBar, (v) => _bottomBar = v),
                  _toggle(
                    'Two capsules',
                    _twoCapsules,
                    (v) => _twoCapsules = v,
                  ),
                  _toggle('Badges', _badges, (v) => _badges = v),
                  _toggle('Pull to refresh', _refresh, (v) => _refresh = v),
                  _toggle('Subtitle', _subtitle, (v) => _subtitle = v),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: LiquidPrismButton(
                  key: const ValueKey('lab-open-sheet'),
                  label: 'Open the same page in a sheet',
                  onPressed: () => showCupertinoSheet<void>(
                    context: context,
                    // The sheet's controller lets a pull at the top dismiss it.
                    scrollableBuilder: (_, controller) =>
                        _SheetPage(controller: controller),
                  ),
                  child: const Text('Open in a Sheet'),
                ),
              ),
              if (_refreshed > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Refreshed $_refreshed ${_refreshed == 1 ? 'time' : 'times'}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted(context)),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: 24,
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
                'Row $i: scroll it under the bar',
                style: const TextStyle(fontSize: 17, color: Color(0xFF111111)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A sheet built on the scaffold with `sheet: true`: the bar sits 16 points
/// below the sheet's top, without a status bar inset.
class _SheetPage extends StatelessWidget {
  const _SheetPage({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return LiquidPrismScaffold(
      sheet: true,
      scrollController: controller,
      backgroundColor: colors.groupedBackground,
      leading: LiquidPrismBackButton(
        close: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Sheet'),
      subtitle: const Text('Scaffold with sheet: true'),
      actions: [
        GlassToolbarItem(
          icon: const Icon(CupertinoIcons.checkmark),
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: 20,
            itemBuilder: (context, i) => Container(
              height: 56,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: HSLColor.fromAHSL(1, (i * 31) % 360, .6, .62).toColor(),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Sheet row $i'),
            ),
          ),
        ),
      ],
    );
  }
}
