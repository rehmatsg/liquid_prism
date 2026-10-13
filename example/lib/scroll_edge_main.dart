import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// A bar with glass controls over scrolling content: the scaffold's scroll
/// edge effect, a two-group toolbar whose items come and go, and a page-level
/// group below so a sliver app bar's capsules share the effect's captures.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(
    const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: Brightness.dark),
      home: ScrollEdgeDemo(),
    ),
  );
}

class ScrollEdgeDemo extends StatefulWidget {
  const ScrollEdgeDemo({super.key});
  @override
  State<ScrollEdgeDemo> createState() => _ScrollEdgeDemoState();
}

class _ScrollEdgeDemoState extends State<ScrollEdgeDemo> {
  // Starts scrolled so the effect shows at once.
  final _scroll = ScrollController(initialScrollOffset: 160);
  var _tab = 0;
  var _extra = false;
  var _dark = true;
  var _sliver = false;
  var _hard = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Color get _background =>
      _dark ? const Color(0xFF141416) : const Color(0xFFF4F2EE);

  @override
  Widget build(BuildContext context) {
    final brightness = _dark ? Brightness.dark : Brightness.light;
    return CupertinoTheme(
      data: CupertinoThemeData(brightness: brightness),
      child: LiquidPrismTheme(
        brightness: brightness,
        child: Builder(
          builder: (context) {
            final colors = GlassColors.of(context);
            final actions = [
              GlassToolbarItem(
                icon: const Icon(CupertinoIcons.moon_stars),
                label: 'Appearance',
                onPressed: () => setState(() => _dark = !_dark),
              ),
              GlassToolbarItem(
                icon: const Icon(CupertinoIcons.rectangle_stack),
                label: _sliver ? 'Scaffold bar' : 'Sliver bar',
                onPressed: () => setState(() => _sliver = !_sliver),
              ),
              GlassToolbarItem(
                icon: Icon(
                  _hard
                      ? CupertinoIcons.rectangle_compress_vertical
                      : CupertinoIcons.rectangle_expand_vertical,
                ),
                label: _hard ? 'Soft edge' : 'Hard edge',
                onPressed: () => setState(() => _hard = !_hard),
              ),
            ];
            final edgeStyle = GlassScrollEdgeStyle(
              variant: _hard
                  ? GlassScrollEdgeVariant.hard
                  : GlassScrollEdgeVariant.soft,
            );
            final content = Builder(
              builder: (context) => _Rows(
                colors: colors,
                top: _sliver ? 12 : MediaQuery.paddingOf(context).top,
              ),
            );
            return DefaultTextStyle(
              style: TextStyle(color: colors.label, fontSize: 17),
              child: _sliver
                  ? _SliverPage(
                      background: _background,
                      extra: _extra,
                      onToggle: () => setState(() => _extra = !_extra),
                      actions: actions,
                      tabBar: _tabBar(),
                      body: content,
                      controller: _scroll,
                    )
                  : LiquidPrismScaffold(
                      backgroundColor: _background,
                      scrollEdgeStyle: edgeStyle,
                      // A hard-edged bar carries its tabs inside the effect.
                      accessory: _hard
                          ? PreferredSize(
                              preferredSize: const Size.fromHeight(44),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  8,
                                ),
                                child: LiquidPrismSegmentedControl<int>(
                                  label: 'Section',
                                  selectedValue: _tab,
                                  onValueChanged: (value) =>
                                      setState(() => _tab = value),
                                  children: const {
                                    0: Text('Overview'),
                                    1: Text('Jobs'),
                                    2: Text('People'),
                                  },
                                ),
                              ),
                            )
                          : null,
                      leading: LiquidPrismToolbarGroup(
                        size: GlassToolbarSize.navigation,
                        items: [
                          GlassToolbarItem(
                            icon: const Icon(CupertinoIcons.chevron_back),
                            label: 'Back',
                            onPressed: () {},
                          ),
                        ],
                      ),
                      actions: [
                        GlassToolbarItem(
                          icon: Icon(
                            _extra
                                ? CupertinoIcons.minus_circle
                                : CupertinoIcons.plus_circle,
                          ),
                          label: 'Toggle item',
                          onPressed: () => setState(() => _extra = !_extra),
                        ),
                        if (_extra)
                          GlassToolbarItem(
                            icon: const Icon(CupertinoIcons.star),
                            label: 'Favorite',
                            onPressed: () {},
                          ),
                        ...actions,
                      ],
                      tabBar: _tabBar(),
                      body: SingleChildScrollView(
                        controller: _scroll,
                        child: content,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _tabBar() => LiquidPrismTabBar(
    selectedIndex: _tab,
    onSelected: (index) => setState(() => _tab = index),
    tabs: const [
      LiquidPrismTab(icon: Icon(CupertinoIcons.house), label: 'Home'),
      LiquidPrismTab(icon: Icon(CupertinoIcons.search), label: 'Search'),
      LiquidPrismTab(icon: Icon(CupertinoIcons.person), label: 'You'),
    ],
  );
}

/// A Material-style page: a pinned sliver bar with capsules and the scroll
/// edge effect in its background, inside one group with the effect.
class _SliverPage extends StatelessWidget {
  const _SliverPage({
    required this.background,
    required this.extra,
    required this.onToggle,
    required this.actions,
    required this.tabBar,
    required this.body,
    required this.controller,
  });
  final ScrollController controller;
  final Color background;
  final bool extra;
  final VoidCallback onToggle;
  final List<GlassToolbarItem> actions;
  final Widget tabBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return LiquidPrismScaffold(
      backgroundColor: background,
      tabBar: tabBar,
      body: LiquidPrismGroup(
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _BarDelegate(
                height: top + 44,
                builder: (context, scrollOffset) => Stack(
                  fit: StackFit.expand,
                  children: [
                    LiquidPrismScrollEdge(
                      progress: LiquidPrismScrollEdge.progressFor(scrollOffset),
                      color: background,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, top, 16, 0),
                      child: Row(
                        children: [
                          LiquidPrismToolbarGroup(
                            size: GlassToolbarSize.navigation,
                            items: [
                              GlassToolbarItem(
                                icon: const Icon(CupertinoIcons.chevron_back),
                                label: 'Back',
                                onPressed: () {},
                              ),
                            ],
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Sliver bar',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          LiquidPrismToolbar(
                            size: GlassToolbarSize.navigation,
                            groups: [
                              [
                                if (extra)
                                  GlassToolbarItem(
                                    icon: const Icon(CupertinoIcons.star),
                                    label: 'Favorite',
                                    onPressed: () {},
                                  ),
                              ],
                              [
                                GlassToolbarItem(
                                  icon: Icon(
                                    extra
                                        ? CupertinoIcons.minus_circle
                                        : CupertinoIcons.plus_circle,
                                  ),
                                  label: 'Toggle item',
                                  onPressed: onToggle,
                                ),
                                ...actions,
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: body),
          ],
        ),
      ),
    );
  }
}

class _BarDelegate extends SliverPersistentHeaderDelegate {
  const _BarDelegate({required this.height, required this.builder});
  final double height;
  final Widget Function(BuildContext context, double scrollOffset) builder;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      _ScrollOffsetReader(builder: builder);

  @override
  bool shouldRebuild(_BarDelegate old) =>
      height != old.height || builder != old.builder;
}

/// Reads the enclosing sliver's scroll offset for the pinned bar.
class _ScrollOffsetReader extends StatelessWidget {
  const _ScrollOffsetReader({required this.builder});
  final Widget Function(BuildContext context, double scrollOffset) builder;

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.of(context).position;
    return AnimatedBuilder(
      animation: position,
      builder: (context, _) => builder(
        context,
        !position.hasPixels
            ? 0
            : position.hasContentDimensions
            ? position.pixels - position.minScrollExtent
            : position.pixels,
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.colors, required this.top});
  final GlassColors colors;
  final double top;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Column(
      children: [
        SizedBox(height: top),
        for (var i = 0; i < 40; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    HSLColor.fromAHSL(1, (i * 37) % 360, .7, .5).toColor(),
                    HSLColor.fromAHSL(1, (i * 37 + 60) % 360, .7, .4).toColor(),
                  ],
                ),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Row $i · sharp text under the bar',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        SizedBox(height: padding.bottom),
      ],
    );
  }
}
