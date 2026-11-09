import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'widgets.dart';
import 'sheet_route.dart';
import 'scaffold_lab_options.dart';

enum _Heading { large, header, inline }

enum _Edge { soft, hard, off }

enum _Scrolling { sticky, away, reveal }

/// Live scaffold and sliver-app-bar previews with native defaults and
/// independently resettable style overrides.
class ScaffoldLabPage extends StatefulWidget {
  const ScaffoldLabPage({
    super.key,
    this.sheet = false,
    this.scrollController,
    this.initialOptions,
  });

  final ScaffoldLabOptions? initialOptions;
  final bool sheet;
  final ScrollController? scrollController;

  @override
  State<ScaffoldLabPage> createState() => _ScaffoldLabPageState();
}

class _ScaffoldLabPageState extends State<ScaffoldLabPage> {
  late var _options = widget.initialOptions ?? ScaffoldLabOptions();
  var _tab = 0;
  var _heading = _Heading.large;
  var _edge = _Edge.soft;
  var _scrolling = _Scrolling.sticky;
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

  Widget _bodyScroll(List<Widget> content) => Builder(
    builder: (context) => CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverPadding(
          padding: MediaQuery.paddingOf(context),
          sliver: SliverMainAxisGroup(slivers: content),
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
      placement: _options.actionPlacement,
      onPressed: () {},
    );
    final more = GlassToolbarItem(
      icon: const Icon(CupertinoIcons.ellipsis),
      label: 'More',
      placement: _options.actionPlacement,
      onPressed: () {},
    );
    final inbox = GlassToolbarItem(
      icon: const Icon(CupertinoIcons.tray),
      label: 'Inbox',
      placement: _options.actionPlacement,
      badge: _badges ? const GlassBadge.count(3) : null,
      onPressed: () {},
    );
    final content = [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverList.list(
          children: [
            InsetSection(
              header: 'Heading',
              footer: 'Sticky keeps the bar visible. Scroll away restores it at the top; reveal restores it when scrolling up. An accessory stays visible in every mode.',
              children: [
                _choice<_Heading>('Style', _heading, {
                  _Heading.large: 'Large title',
                  if (!_options.bodyMode &&
                      !_options.sliverAppBar &&
                      _options.scrollDepth == 0)
                    _Heading.header: 'Header',
                  _Heading.inline: 'Inline',
                }, (v) => _heading = v),
                _choice<_Scrolling>('Scroll behavior', _scrolling, const {
                  _Scrolling.sticky: 'Sticky',
                  _Scrolling.away: 'Scroll away',
                  _Scrolling.reveal: 'Reveal',
                }, (v) => _scrolling = v),
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
                _toggle('Two capsules', _twoCapsules, (v) => _twoCapsules = v),
                _toggle('Badges', _badges, (v) => _badges = v),
                _toggle('Pull to refresh', _refresh, (v) => _refresh = v),
                _toggle('Subtitle', _subtitle, (v) => _subtitle = v),
              ],
            ),
            _options.controls(
              () => setState(() {
                if ((_options.bodyMode ||
                        _options.sliverAppBar ||
                        _options.scrollDepth > 0) &&
                    _heading == _Heading.header) {
                  _heading = _Heading.inline;
                }
              }),
            ),
            if (_options.textField)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoTextField(
                  placeholder: 'Show the keyboard to test insets',
                ),
              ),
            CupertinoButton(
              key: const ValueKey('lab-reset'),
              onPressed: () => setState(() {
                _options = ScaffoldLabOptions();
                _tab = 0;
                _segment = 0;
                _refreshed = 0;
                _heading = _Heading.large;
                _edge = _Edge.soft;
                _scrolling = _Scrolling.sticky;
                _accessory = false;
                _bottomBar = true;
                _twoCapsules = true;
                _badges = true;
                _refresh = true;
                _subtitle = false;
              }),
              child: const Text('Reset to native defaults'),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: LiquidPrismButton(
                key: const ValueKey('lab-open-sheet'),
                label: 'Open the same page in a sheet',
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  ShowcaseSheetRoute(
                    // The sheet's controller lets a pull at the top dismiss it.
                    scrollableBuilder: (_, controller) => ScaffoldLabPage(
                      sheet: true,
                      scrollController: controller,
                    ),
                  ),
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
    ];
    final scaffold = LiquidPrismScaffold(
      sheet: widget.sheet,
      scrollController: widget.scrollController,
      style: _options.scaffold,
      placement: _options.placement,
      tabBarPlacement: _options.tabPlacement,
      resizeToAvoidBottomInset: _options.resize,
      scrollDepth: _options.scrollDepth,
      automaticallyImplyLeading:
          _options.implyLeading && _options.leadingKind != 2,
      trailing: _options.trailing
          ? CupertinoButton(onPressed: () {}, child: const Text('Edit'))
          : null,
      tabBar: _options.tabs
          ? LiquidPrismTabBar(
              tabs: const [
                LiquidPrismTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
                LiquidPrismTab(
                  label: 'Saved',
                  icon: Icon(CupertinoIcons.bookmark),
                ),
                LiquidPrismTab(
                  label: 'Profile',
                  icon: Icon(CupertinoIcons.person),
                ),
              ],
              selectedIndex: _tab,
              onSelected: (value) => setState(() => _tab = value),
            )
          : null,
      leading: _options.leadingKind == 2
          ? null
          : _options.leadingKind == 1
          ? LiquidPrismButton(
              onPressed: () {},
              label: 'Custom leading',
              child: const Icon(CupertinoIcons.star),
            )
          : widget.sheet
          ? LiquidPrismBackButton(
              close: true,
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      navigationBarStyle: _options.navigation(
        _scrolling == _Scrolling.sticky
            ? GlassToolbarMinimizationBehavior.never
            : GlassToolbarMinimizationBehavior.onScrollDown,
        _scrolling == _Scrolling.away
            ? GlassToolbarMinimizationRestoration.atScrollEdge
            : GlassToolbarMinimizationRestoration.automatic,
      ),
      backgroundColor: switch (_options.background) {
        1 =>
          colors.brightness == Brightness.dark
              ? const Color(0xFF000000)
              : const Color(0xFFFFFFFF),
        2 => colors.blue.withValues(alpha: .12),
        _ => colors.groupedBackground,
      },
      title: switch (_options.titleKind) {
        0 => const Text('Scaffold Lab'),
        4 => null,
        _ => LiquidPrismTitle(
          avatar: _options.titleKind == 2 ? const _LabAvatar() : null,
          leading: _options.titleKind == 3 ? const _LabAvatar() : null,
          onPressed: () => setState(
            () => _options.titleKind = _options.titleKind == 3
                ? 1
                : _options.titleKind + 1,
          ),
          child: const Text('Scaffold Lab'),
        ),
      },
      subtitle: _subtitle ? const Text('Every page option, live') : null,
      largeTitle: _heading == _Heading.large
          ? const Text('Scaffold Lab')
          : null,
      header:
          !_options.bodyMode &&
              _options.scrollDepth == 0 &&
              _heading == _Heading.header
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
      toolbar: _twoCapsules
          ? [
              GlassToolbarGroup(
                placement: _options.actionPlacement,
                items: [inbox],
              ),
              GlassToolbarGroup(
                placement: _options.actionPlacement,
                items: [share, more],
              ),
            ]
          : [inbox, share, more],
      scrollEdge: _edge != _Edge.off,
      scrollEdgeStyle: _options.edge(
        _edge == _Edge.hard
            ? GlassScrollEdgeVariant.hard
            : GlassScrollEdgeVariant.soft,
        colors,
      ),
      accessory: _accessory
          ? PreferredSize(
              key: const ValueKey('lab-accessory'),
              preferredSize: Size.fromHeight(
                _options.n('accessoryHeight') ?? 48,
              ),
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
      onRefresh: _refresh && !_options.bodyMode && _options.scrollDepth == 0
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
      body: _options.bodyMode || _options.scrollDepth > 0
          ? (_options.scrollDepth > 0
                ? PageView(children: [_bodyScroll(content)])
                : _bodyScroll(content))
          : null,
      slivers: _options.bodyMode || _options.scrollDepth > 0 ? null : content,
    );
    final preview = _options.sliverAppBar
        ? LiquidPrismScaffold(
            sheet: widget.sheet,
            backgroundColor: scaffold.backgroundColor,
            placement: scaffold.placement,
            style: scaffold.style,
            bottomBar: scaffold.bottomBar,
            tabBar: scaffold.tabBar,
            tabBarPlacement: scaffold.tabBarPlacement,
            resizeToAvoidBottomInset: scaffold.resizeToAvoidBottomInset,
            automaticallyImplyLeading: false,
            body: Builder(
              builder: (context) => CustomScrollView(
                controller: widget.scrollController,
                slivers: [
                  LiquidPrismSliverAppBar(
                    title: scaffold.title,
                    largeTitle: scaffold.largeTitle,
                    subtitle: scaffold.subtitle,
                    sheet: widget.sheet,
                    leading: scaffold.leading,
                    automaticallyImplyLeading:
                        scaffold.automaticallyImplyLeading,
                    toolbar: scaffold.toolbar,
                    trailing: scaffold.trailing,
                    accessory: scaffold.accessory,
                    backgroundColor: scaffold.backgroundColor,
                    scrollEdge: scaffold.scrollEdge,
                    scrollEdgeStyle: scaffold.scrollEdgeStyle,
                    navigationBarStyle: scaffold.navigationBarStyle,
                  ),
                  if (scaffold.onRefresh != null)
                    CupertinoSliverRefreshControl(
                      onRefresh: scaffold.onRefresh,
                    ),
                  if (scaffold.header != null)
                    SliverToBoxAdapter(child: scaffold.header!),
                  SliverPadding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverMainAxisGroup(slivers: content),
                  ),
                ],
              ),
            ),
          )
        : scaffold;
    return Directionality(
      textDirection: _options.rtl
          ? TextDirection.rtl
          : Directionality.of(context),
      child: preview,
    );
  }
}

class _LabAvatar extends StatelessWidget {
  const _LabAvatar();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GlassColors.of(context).teal,
      shape: BoxShape.circle,
    ),
    child: const Center(
      child: Text('L', style: TextStyle(color: Color(0xFFFFFFFF))),
    ),
  );
}
