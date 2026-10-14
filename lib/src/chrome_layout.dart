import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'glass_transition.dart';
import 'menu/menu.dart';
import 'menu/menu_elements.dart';
import 'motion.dart';
import 'edge_fade.dart' show GlassEdge;
import 'scroll_edge.dart';
import 'sidebar.dart';
import 'system_chrome.dart';
import 'tab_bar.dart';
import 'tab_reselection.dart';
import 'toolbar.dart';
import 'theme.dart';
import 'navigation_bar_style.dart';

/// Where [LiquidPrismScaffold] floats its tab bar and actions.
///
/// iOS moves bar chrome into a vertical rail when the window has a deep safe
/// area on one side only, as beside the sensor bar of iPhone Duo. An iPhone in
/// landscape has equal side insets and keeps the bottom tab bar.
enum GlassChromePlacement {
  /// Actions in the top bar, tab bar floating above the bottom edge.
  bottom,

  /// Actions and tab bar stacked in a rail inside the left safe area.
  leftRail,

  /// Actions and tab bar stacked in a rail inside the right safe area.
  rightRail;

  bool get isRail => this != bottom;

  /// Chooses a placement from window safe-area insets ([MediaQueryData.viewPadding]).
  ///
  /// [LiquidPrismScaffold] prefers the system's answer: on iOS 27.1 and later
  /// the plugin reports `UITraitCollection.verticalBarEdge`. This fallback is
  /// for earlier systems and tests: a rail needs one side to be at least
  /// [railInset] deeper than the other, fitted to measured iOS 27.1 layouts.
  static GlassChromePlacement resolve(
    EdgeInsets viewPadding, {
    double railInset = 48,
  }) {
    final difference = viewPadding.right - viewPadding.left;
    if (difference >= railInset) return rightRail;
    if (-difference >= railInset) return leftRail;
    return bottom;
  }
}

/// Placement and bar axis published below a [LiquidPrismScaffold].
@immutable
class LiquidPrismChrome extends InheritedWidget {
  const LiquidPrismChrome({
    super.key,
    required this.placement,
    this.axis,
    required super.child,
  });

  final GlassChromePlacement placement;

  /// The axis bar components adopt; null where content should keep its own.
  final Axis? axis;

  static LiquidPrismChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidPrismChrome>();

  @override
  bool updateShouldNotify(LiquidPrismChrome oldWidget) =>
      placement != oldWidget.placement || axis != oldWidget.axis;
}

/// A full-window layout that floats glass chrome over scrolling content and
/// puts it where iOS would for the current window.
///
/// On iPhone the [actions] sit at the top trailing edge and the [tabBar] floats
/// above the bottom edge. Wherever iOS uses a vertical bar, as on iPhone Duo,
/// both move into a rail on that edge, below the status bar, and the tab bar
/// turns icon-only. When the rail is too short, the actions collapse into one
/// overflow menu before the tab bar compresses, as native bars do. The layout
/// follows the window as it resizes, folds or rotates.
///
/// On iOS 27.1 and later the placement, the status bar's position in the rail
/// and any partial fold come from UIKit (`verticalBarEdge` and reserved
/// regions). The fold reaches the body as a [MediaQueryData.displayFeatures]
/// entry, so `DisplayFeatureSubScreen` can keep content out of it.
///
/// [body] fills the whole window, so content stays visible through the glass.
/// Its [MediaQueryData.padding] includes the space the chrome covers, which
/// scroll views apply automatically. Use [SafeArea] or read the padding for
/// anything else that must stay clear.
class LiquidPrismScaffold extends StatefulWidget {
  const LiquidPrismScaffold({
    super.key,
    this.body,
    this.slivers,
    this.scrollController,
    this.onRefresh,
    this.bottomBar,
    this.scrollDepth = 0,
    this.title,
    this.largeTitle,
    this.header,
    this.subtitle,
    this.sheet = false,
    this.navigationBarStyle,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions = const [],
    this.accessory,
    this.tabBar,
    this.placement,
    this.backgroundColor,
    this.tabBarPlacement = GlassTabBarPlacement.automatic,
    this.resizeToAvoidBottomInset = true,
    this.scrollEdge = true,
    this.scrollEdgeStyle,
  }) : assert(
         (body == null) != (slivers == null),
         'Pass either body or slivers.',
       ),
       assert(
         onRefresh == null || slivers != null,
         'onRefresh needs slivers; a body adds its own refresh control.',
       ),
       assert(
         header == null || slivers != null,
         'header needs slivers; it scrolls with them.',
       ),
       assert(
         header == null || largeTitle == null,
         'Use a header or a large title, not both.',
       );

  /// Full-window content, usually a scroll view, laid out under the chrome.
  /// The chrome's insets reach it as `MediaQuery.padding`: a [ListView] or
  /// [GridView] without its own padding applies them, any other scroll view
  /// pads itself. Prefer [slivers] for a page that scrolls.
  final Widget? body;

  /// The page's content as slivers, in place of [body]. The scaffold builds
  /// the [CustomScrollView]: it pads the content below the bar, large title
  /// and accessory and above the tab bar, [bottomBar] and keyboard, follows
  /// its scroll for the edge effects and the large title, and dismisses the
  /// keyboard on drag. A pinned [SliverPersistentHeader] among them pins
  /// below the bar; [SliverFillRemaining] fills the space between the insets.
  final List<Widget>? slivers;

  /// The controller of the scroll view built from [slivers], for a page that
  /// scrolls it itself. Null makes it the primary scroll view, which a
  /// tab bar's reselection or a status bar tap scrolls to the top.
  final ScrollController? scrollController;

  /// Pull to refresh for [slivers]: a native refresh control that appears
  /// below the bar as the content is pulled down.
  final Future<void> Function()? onRefresh;

  /// A bar pinned to the bottom of the page, above the home indicator and
  /// the keyboard, such as a primary action. The body is padded to clear it,
  /// and content scrolled under it takes a bottom scroll edge effect that its
  /// glass refracts through, as at the top.
  final Widget? bottomBar;

  /// Which scroll view drives the edge effects and the large title, counted
  /// in nested scrollables from the body: 0 is its outermost one. A page of
  /// lists one level down, such as a horizontal tab view of vertical lists,
  /// passes 1; the visible tab's list then drives the bar.
  final int scrollDepth;

  /// Inline header, centred between leading and trailing chrome.
  final Widget? title;

  /// Expanded header beneath the inline row; collapses with the outermost
  /// vertical scroll view even when [scrollEdge] is false. Supply [title] too
  /// for the collapsed header. Only the visible header contributes semantics.
  final Widget? largeTitle;

  /// Content at the top of [slivers] that scrolls away under the bar, such as
  /// a page's own heading or hero, in place of a [largeTitle]. While it shows
  /// the bar's [title] is hidden; once it has scrolled under the bar the
  /// title fades in, with the same timing as after a large title.
  final Widget? header;

  /// A second line under the title, as SwiftUI's `navigationSubtitle`: with
  /// it the inline title is 15-point semibold over a 12-point secondary
  /// subtitle, centred on the controls, and a large title gains an 11-point
  /// subtitle below it that collapses with it (measured on iOS 27).
  final Widget? subtitle;

  /// Lays the bar out for a sheet: its controls 16 points below the sheet's
  /// top, with no status bar inset, as a navigation stack in a sheet does on
  /// iOS 27.
  final bool sheet;
  final GlassNavigationBarStyle? navigationBarStyle;

  /// Fold the keyboard into body padding and consume its bottom view inset.
  /// False leaves keyboard avoidance to descendants.
  final bool resizeToAvoidBottomInset;

  /// A top-leading control, such as a back button. It stays in the top bar in
  /// every placement. Null implies one; see [automaticallyImplyLeading].
  final Widget? leading;

  /// Whether a null [leading] becomes a [LiquidPrismBackButton] when the
  /// route can pop: a back chevron, or a close mark on a fullscreen dialog.
  final bool automaticallyImplyLeading;

  /// Top-trailing actions, or atop the rail. Each element is a
  /// [GlassToolbarItem] or a list of them: loose items next to each other
  /// share one capsule, and each list is a capsule of its own, so
  /// `[share, more]` is one capsule and `[[filter], [share, more]]` two.
  /// Capsules lay out as [LiquidPrismToolbar] does: declare every group the
  /// bar can show and let the lists carry state, so an empty list draws
  /// nothing and materializes in when it gains an item. In the rail they
  /// stack, and fold into one "More" menu when they do not fit.
  final List<Object> actions;

  /// The trailing capsules, in order.
  List<List<GlassToolbarItem>> get _actionGroups => glassActionGroups(actions);

  /// Every trailing action, in order.
  List<GlassToolbarItem> get _allActions => [
    for (final group in _actionGroups) ...group,
  ];

  /// A row below the top bar and inside its scroll edge effect, such as
  /// segmented tabs, sized by its preferred height and spanning the content
  /// width. Pair it with [GlassScrollEdgeVariant.hard] for a bar with a
  /// hard edge, as a native navigation bar with a bottom palette.
  final PreferredSizeWidget? accessory;

  /// Usually a [LiquidPrismTabBar]. It adopts the placement's axis unless it
  /// sets its own.
  final Widget? tabBar;

  /// Forces a placement. Null follows the system's vertical bar edge, or
  /// [GlassChromePlacement.resolve] where the system doesn't report one.
  final GlassChromePlacement? placement;

  /// Painted behind [body]. Null leaves the window transparent.
  final Color? backgroundColor;

  /// [GlassTabBarPlacement.sidebar] lists a [LiquidPrismTabBar]'s tabs in a
  /// leading sidebar while the window has regular width, as on the unfolded
  /// iPhone Duo. People can hide it; the tabs then return to the tab bar.
  final GlassTabBarPlacement tabBarPlacement;

  /// Whether content scrolled under the top bar takes a [LiquidPrismScrollEdge]
  /// effect, as under native bars: a progressive blur and a partial fade into
  /// [backgroundColor] that cover the status bar and the bar. The effect
  /// follows the body's outermost scroll view and shares the chrome's backdrop
  /// captures, so the leading control and actions refract the unblurred
  /// content beneath them. Without a top bar nothing is drawn.
  final bool scrollEdge;

  /// Overrides the theme's [GlassScrollEdgeStyle] field by field. Its
  /// `fadeColor` applies when [backgroundColor] is null.
  final GlassScrollEdgeStyle? scrollEdgeStyle;

  /// The placement of the nearest scaffold, or null outside one.
  static GlassChromePlacement? placementOf(BuildContext context) =>
      LiquidPrismChrome.maybeOf(context)?.placement;

  /// The top bar's measured height: 44 pt navigation capsules.
  static const double topBarHeight = 44;

  /// Space the body keeps below the top bar. Measured: the content safe area
  /// on iPhone Duo starts 58 pt below the bar's top, 14 pt under its capsules.
  static const double topBarClearance = 14;

  @override
  State<LiquidPrismScaffold> createState() => _LiquidPrismScaffoldState();

  /// One "More" item whose native menu holds every action.
  static GlassToolbarItem _overflow(List<GlassToolbarItem> actions) =>
      GlassToolbarItem.menu(
        icon: const _Ellipsis(),
        label: 'More',
        menu: LiquidMenu(
          children: [
            for (final item in actions)
              if (item.menu case final menu?)
                LiquidSubmenu(title: item.label, children: menu.children)
              else
                LiquidMenuAction<void>(
                  title: item.label,
                  enabled: item.onPressed != null,
                  onSelected: () => item.onPressed?.call(),
                ),
          ],
        ),
      );
}

class _LiquidPrismScaffoldState extends State<LiquidPrismScaffold>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _sidebarHidden = false;

  /// The [LiquidPrismScaffold.header]'s laid-out height: the scroll at which
  /// the title swaps in.
  double _headerExtent = 0;

  /// Tab reselections, shared by this scaffold's tab bar and the pages in its
  /// body; each page's scroll view returns to the top.
  final _reselection = LiquidPrismTabReselection();

  final _statusBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // A tap on the iOS status bar scrolls the page to the top, as a Material
  // Scaffold does, for the scaffold in front only.
  @override
  void handleStatusBarTap() {
    final controller =
        widget.scrollController ?? PrimaryScrollController.maybeOf(context);
    final box = _statusBarKey.currentContext?.findRenderObject();
    if (controller == null || !controller.hasClients || box == null) return;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      Offset.zero,
      View.of(context).viewId,
    );
    if (!result.path.any((entry) => entry.target == box)) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCirc,
    );
  }

  /// How far the body's outermost scroll view is scrolled past its start.
  final _scrollOffset = ValueNotifier<double>(0);

  /// How much of that scroll view's content lies beyond its end, under a
  /// [LiquidPrismScaffold.bottomBar].
  final _scrollRemaining = ValueNotifier<double>(0);

  bool _onScroll(ScrollMetrics metrics) {
    if (metrics.axis == Axis.vertical) {
      _scrollOffset.value = math.max(
        0,
        metrics.pixels - metrics.minScrollExtent,
      );
      _scrollRemaining.value = math.max(
        0,
        metrics.maxScrollExtent - metrics.pixels,
      );
      _syncTitle();
    }
    return false;
  }

  // Measured on iOS 27: the large title scrolls with the content and, once
  // the scroll passes its row, the titles swap on a timer rather than with the
  // scroll. The large title fades out in about 0.18 s; the inline title fades
  // in over about 0.53 s while rising 15 points, and back out over about 0.8 s.
  late final _largeFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final _inlineFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 530),
    reverseDuration: const Duration(milliseconds: 800),
  );
  bool _collapsed = false;
  double _collapseAt = double.infinity;

  void _syncTitle() {
    final collapsed = _scrollOffset.value >= _collapseAt;
    if (collapsed == _collapsed) return;
    _collapsed = collapsed;
    if (MediaQuery.disableAnimationsOf(context)) {
      _largeFade.value = _inlineFade.value = collapsed ? 1 : 0;
    } else if (collapsed) {
      _largeFade.forward();
      _inlineFade.forward();
    } else {
      _largeFade.reverse();
      _inlineFade.reverse();
    }
  }

  /// How far the sidebar is shown: it slides the panel and reflows the body.
  late final _reveal = RetargetableGlassSpring(vsync: this)
    ..value = 1
    ..addStatusListener((status) {
      // Remove the panel once it has slid out.
      if (status.isCompleted || status.isDismissed) setState(() {});
    });

  void _setSidebarHidden(bool hidden) {
    setState(() => _sidebarHidden = hidden);
    springGlass(
      _reveal,
      hidden ? 0 : 1,
      NativeSidebar.spring,
      immediate: MediaQuery.disableAnimationsOf(context),
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    _largeFade.dispose();
    _inlineFade.dispose();
    _scrollOffset.dispose();
    _scrollRemaining.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _reselection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // An app-level LiquidPrismSystemChrome already added the fold to
    // MediaQuery; otherwise listen directly and add it for the body.
    if (LiquidPrismSystemChrome.scopeOf(context) case final scope?) {
      return _build(context, scope.chrome, addFeatures: false);
    }
    return ValueListenableBuilder<GlassSystemChrome?>(
      valueListenable: LiquidPrismSystemChrome.listenable,
      builder: (context, system, _) =>
          _build(context, system, addFeatures: true),
    );
  }

  Widget _build(
    BuildContext context,
    GlassSystemChrome? system, {
    required bool addFeatures,
  }) {
    final media = MediaQuery.of(context);
    final resolved =
        widget.placement ??
        switch (system) {
          null => GlassChromePlacement.resolve(media.viewPadding),
          GlassSystemChrome(hasVerticalBar: false) =>
            GlassChromePlacement.bottom,
          GlassSystemChrome(verticalBarEdge: AxisDirection.left) =>
            GlassChromePlacement.leftRail,
          _ => GlassChromePlacement.rightRail,
        };
    final rail = resolved.isRail;
    final keyboard = media.viewInsets.bottom > 0;

    // The sidebar replaces the tab bar at regular width when requested. Use
    // UIKit's size class where reported; elsewhere, a width fallback.
    final regular = switch (system?.horizontalSizeClass) {
      GlassSizeClass.regular => true,
      GlassSizeClass.compact => false,
      null => media.size.width >= 700,
    };
    final tabBar = widget.tabBar;
    final sidebarTabs =
        widget.tabBarPlacement == GlassTabBarPlacement.sidebar &&
            regular &&
            tabBar is LiquidPrismTabBar
        ? tabBar
        : null;
    // The panel stays while it slides out. Native hides the tabs with it.
    final sidebar =
        sidebarTabs != null && (!_sidebarHidden || _reveal.value > 0);
    final sidebarToggle = sidebarTabs != null && _sidebarHidden;
    // Native: leading, unless the vertical bar already holds that edge.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sidebarLeft = resolved == GlassChromePlacement.leftRail
        ? false
        : !rtl;

    final occlusions = [
      for (final region in system?.occlusions ?? const <GlassReservedRegion>[])
        if (region.active) region.frame,
    ];
    final padding = _ChromeLayout.withRail(media.viewPadding, resolved);
    final actionsTop = _ChromeLayout.railActionsTop(
      media.size,
      padding,
      resolved,
      occlusions,
      reported: system != null,
    );
    final railBottom = _ChromeLayout.railBottomOf(
      media.size,
      padding,
      resolved,
      occlusions,
    );
    // With horizontal bars, a status bar in a top corner shares the top bar's
    // row, as on the unfolded iPhone Duo in portrait.
    final corner = rail
        ? null
        : _ChromeLayout.topCorner(media.size, occlusions);
    final showTabBar =
        tabBar != null && sidebarTabs == null && (rail || !keyboard);
    final groups =
        rail &&
            !_fitsRail(
              railBottom - actionsTop,
              tabs: showTabBar ? tabBar : null,
            )
        ? [
            [LiquidPrismScaffold._overflow(widget._allActions)],
          ]
        : widget._actionGroups;
    final features = addFeatures
        ? system?.displayFeatures ?? const []
        : const <DisplayFeature>[];
    final top = widget.sheet
        ? _ChromeLayout._sheetTop
        : math.max(media.viewPadding.top, _ChromeLayout._minimumTop);
    final leading =
        widget.leading ??
        (widget.automaticallyImplyLeading ? _impliedLeading(context) : null);
    final navigation =
        (LiquidPrismTheme.of(context).navigationBar ??
                const GlassNavigationBarStyle())
            .merge(widget.navigationBarStyle);
    final titleStyle = TextStyle(
      fontSize: widget.subtitle == null ? 17 : 15,
      fontWeight: FontWeight.w600,
      color: GlassColors.of(context).label,
    ).merge(navigation.titleStyle);
    final largeTitleStyle = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: GlassColors.of(context).label,
    ).merge(navigation.largeTitleStyle);
    final colors = GlassColors.of(context);
    final subtitleStyle = TextStyle(
      fontSize: 12,
      color: colors.secondaryLabel,
    ).merge(navigation.subtitleStyle);
    final largeSubtitleStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: colors.secondaryLabel,
    ).merge(navigation.largeSubtitleStyle);
    final scaler = media.textScaler;
    final titleRowHeight = widget.title == null
        ? LiquidPrismScaffold.topBarHeight
        : math.max(
            LiquidPrismScaffold.topBarHeight,
            scaler.scale(titleStyle.fontSize ?? 17) *
                    (titleStyle.height ?? 1.2) +
                8,
          );
    // Measured: a 52-point row holding the 40.67-point 34-point bold line,
    // 3.67 points below the row's top.
    // With a subtitle the row grows to 71.33 points for its 11-point line,
    // which sits 38.33 points below the large title's top.
    final expandedHeight = widget.largeTitle == null
        ? 0.0
        : scaler.scale(largeTitleStyle.fontSize ?? 34) *
                  (largeTitleStyle.height ?? 1.2) +
              11.33 +
              (widget.subtitle == null
                  ? 0
                  : scaler.scale(largeSubtitleStyle.fontSize ?? 11) * 1.2 +
                        6.13);
    final extent = navigation.revealExtent ?? expandedHeight;
    final swaps = widget.largeTitle != null || widget.header != null;
    _collapseAt = widget.header != null
        ? (_headerExtent > 0 ? _headerExtent : double.infinity)
        : widget.largeTitle == null
        ? double.infinity
        : extent;
    if (!swaps && _collapsed) {
      _collapsed = false;
      _largeFade.value = _inlineFade.value = 0;
    }
    final inline = CurvedAnimation(
      parent: _inlineFade,
      curve: navigation.revealCurve ?? Curves.easeOutCubic,
      reverseCurve: (navigation.revealCurve ?? Curves.easeOutCubic).flipped,
    );
    // The shared glass content blur, so titles focus in like glass content.
    final titleBlur = LiquidPrismTheme.of(context).transition?.contentBlur ?? 8;
    Widget header(Widget child, TextStyle style, {required bool large}) {
      Widget text = Semantics(
        header: true,
        child: DefaultTextStyle(
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: child,
        ),
      );
      // Without a large title or header the inline title simply shows.
      if (!swaps) return IgnorePointer(child: text);
      return AnimatedBuilder(
        animation: Listenable.merge([_largeFade, _inlineFade]),
        builder: (context, child) {
          final visible = large ? !_collapsed : _collapsed;
          final opacity = large ? 1 - _largeFade.value : inline.value;
          return ExcludeSemantics(
            excluding: !visible,
            child: IgnorePointer(
              // The titles focus in and out as they fade, as native soft
              // bars do: blurred when absent, sharp when present.
              child: GlassContentPresence(
                presence: opacity,
                blur: titleBlur,
                child: large
                    ? child!
                    : Transform.translate(
                        offset: Offset(0, 15 * (1 - inline.value)),
                        child: child,
                      ),
              ),
            ),
          );
        },
        child: text,
      );
    }

    final topBar =
        widget.title != null ||
        widget.largeTitle != null ||
        leading != null ||
        // Native keeps the bar row with the sidebar shown or hidden, so
        // content does not jump when the toggle moves into it.
        sidebarTabs != null ||
        (!rail && widget._allActions.isNotEmpty);
    final layout = CustomMultiChildLayout(
      delegate: _ChromeLayout(
        placement: resolved,
        viewPadding: padding,
        keyboard: widget.resizeToAvoidBottomInset ? media.viewInsets.bottom : 0,
        textDirection: Directionality.of(context),
        iOS: defaultTargetPlatform == TargetPlatform.iOS,
        topBar: topBar,
        accessoryHeight: widget.accessory?.preferredSize.height ?? 0,
        titleRowHeight: titleRowHeight,
        expandedHeight: expandedHeight,
        collapseExtent: extent,
        scrollOffset: _scrollOffset,
        titleGutter: navigation.gutter ?? 16,
        titleGap: navigation.controlGap ?? 12,
        actionsTop: actionsTop,
        railBottom: railBottom,
        sheet: widget.sheet,
        edgeFrame:
            widget.accessory == null &&
                GlassScrollEdgeStyle.resolve(
                      context,
                      widget.scrollEdgeStyle,
                    ).variant ==
                    GlassScrollEdgeVariant.hard
            ? 10
            : 0,
        corner: corner,
        sidebar: sidebar
            ? (sidebarLeft ? AxisDirection.left : AxisDirection.right)
            : null,
        reveal: _reveal,
      ),
      children: [
        LayoutId(
          id: _Slot.body,
          child: LiquidPrismChrome(
            placement: resolved,
            child: _InsetBody(
              consumeKeyboard: widget.resizeToAvoidBottomInset,
              media: features.isEmpty
                  ? media
                  : media.copyWith(
                      displayFeatures: [...media.displayFeatures, ...features],
                    ),
              child:
                  ((widget.scrollEdge || swaps) &&
                          (topBar || widget.accessory != null)) ||
                      widget.bottomBar != null
                  ? NotificationListener<ScrollMetricsNotification>(
                      onNotification: (n) =>
                          n.depth == widget.scrollDepth && _onScroll(n.metrics),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) =>
                            n.depth == widget.scrollDepth &&
                            _onScroll(n.metrics),
                        child: _content(),
                      ),
                    )
                  : _content(),
            ),
          ),
        ),
        // Behind the bar's controls, over the body: it shares their captures
        // and is cut out of their contours (see LiquidPrismEdgeBlur).
        if (widget.scrollEdge && (topBar || widget.accessory != null))
          LayoutId(
            id: _Slot.scrollEdge,
            child: GlassGroupMembers(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (context, offset, _) => LiquidPrismScrollEdge(
                  progress: LiquidPrismScrollEdge.progressFor(
                    offset,
                    revealExtent:
                        GlassScrollEdgeStyle.resolve(
                          context,
                          widget.scrollEdgeStyle,
                        ).revealExtent ??
                        GlassScrollEdgeStyle.defaultRevealExtent,
                  ),
                  color: widget.backgroundColor,
                  style: widget.scrollEdgeStyle,
                ),
              ),
            ),
          ),
        if (widget.scrollEdge && widget.bottomBar != null)
          LayoutId(
            id: _Slot.bottomScrollEdge,
            child: GlassGroupMembers(
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollRemaining,
                  builder: (context, remaining, _) => LiquidPrismScrollEdge(
                    edge: GlassEdge.bottom,
                    progress: LiquidPrismScrollEdge.progressFor(
                      remaining,
                      revealExtent:
                          GlassScrollEdgeStyle.resolve(
                            context,
                            widget.scrollEdgeStyle,
                          ).revealExtent ??
                          GlassScrollEdgeStyle.defaultRevealExtent,
                    ),
                    color: widget.backgroundColor,
                    style: widget.scrollEdgeStyle,
                  ),
                ),
              ),
            ),
          ),
        if (widget.bottomBar case final bottomBar?)
          LayoutId(
            id: _Slot.bottomBar,
            child: GlassGroupMembers(child: bottomBar),
          ),
        if (widget.title case final title?)
          LayoutId(
            id: _Slot.title,
            child: header(
              glassTitled(title, widget.subtitle, subtitleStyle, large: false),
              titleStyle,
              large: false,
            ),
          ),
        if (widget.largeTitle case final title?)
          LayoutId(
            id: _Slot.largeTitle,
            // Unclipped: it scrolls up into the bar and fades there.
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: header(
                glassTitled(
                  title,
                  widget.subtitle,
                  largeSubtitleStyle,
                  large: true,
                  subtitleOffset:
                      scaler.scale(largeTitleStyle.fontSize ?? 34) * 38.33 / 34,
                ),
                largeTitleStyle,
                large: true,
              ),
            ),
          ),
        if (widget.accessory case final accessory?)
          LayoutId(
            id: _Slot.accessory,
            child: GlassGroupMembers(child: accessory),
          ),
        // Beneath the panel, as natively: the panel slides over it.
        if (sidebarTabs != null)
          LayoutId(
            id: _Slot.sidebarToggle,
            child: LiquidPrismVisibility(
              visible: sidebarToggle,
              // It materializes as the panel leaves and goes at once when the
              // panel returns over it.
              transition: sidebarToggle
                  ? GlassTransition.materialize
                  : GlassTransition.identity,
              style: GlassTransitionStyle(
                enterSpring: GlassSpring.physical(NativeSidebar.spring),
              ),
              child: Builder(
                builder: (context) => Transform.scale(
                  scale:
                      NativeSidebar.toggleEntryScale -
                      (NativeSidebar.toggleEntryScale - 1) *
                          LiquidPrismPresence.of(context),
                  child: SidebarToggle(
                    label: 'Show sidebar',
                    onPressed: () => _setSidebarHidden(false),
                  ),
                ),
              ),
            ),
          ),
        if (sidebar)
          LayoutId(
            id: _Slot.sidebar,
            child: IgnorePointer(
              ignoring: _sidebarHidden,
              child: ExcludeSemantics(
                excluding: _sidebarHidden,
                child: GlassSidebar(
                  tabBar: sidebarTabs,
                  top: top,
                  onHide: () => _setSidebarHidden(true),
                ),
              ),
            ),
          ),
        // The floating chrome shares backdrop captures: it paints over the
        // body with nothing between its surfaces (see GlassGroupHost).
        if (leading case final leading?)
          LayoutId(
            id: _Slot.leading,
            child: GlassGroupMembers(child: leading),
          ),
        if (groups.isNotEmpty)
          LayoutId(
            id: _Slot.actions,
            child: GlassGroupMembers(
              child: groups.length == 1
                  ? LiquidPrismToolbarGroup(
                      items: groups.single,
                      // Measured: a 44 pt navigation capsule in the top bar,
                      // a 48 pt wide column in the rail.
                      size: rail || corner != null
                          ? GlassToolbarSize.bottom
                          : GlassToolbarSize.navigation,
                      axis: rail ? Axis.vertical : Axis.horizontal,
                    )
                  : LiquidPrismToolbar(
                      groups: groups,
                      size: rail || corner != null
                          ? GlassToolbarSize.bottom
                          : GlassToolbarSize.navigation,
                      axis: rail ? Axis.vertical : Axis.horizontal,
                    ),
            ),
          ),
        // A bottom tab bar would sit under the keyboard; native hides it too.
        if (showTabBar)
          LayoutId(
            id: _Slot.tabBar,
            child: GlassGroupMembers(
              child: LiquidPrismChrome(
                placement: resolved,
                axis: rail ? Axis.vertical : Axis.horizontal,
                child: tabBar,
              ),
            ),
          ),
      ],
    );
    Widget hosted = GlassGroupHost(
      child: Stack(
        children: [
          Positioned.fill(child: layout),
          // Hit at the status bar only while this scaffold is in front.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: math.max(1, media.viewPadding.top),
            child: MetaData(
              key: _statusBarKey,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
    if (widget.tabBar != null) {
      hosted = LiquidPrismTabReselection.scope(
        reselection: _reselection,
        child: hosted,
      );
    }
    return switch (widget.backgroundColor) {
      final color? => ColoredBox(color: color, child: hosted),
      null => hosted,
    };
  }

  /// A back control for a route that can pop, or a close control for a
  /// fullscreen dialog, which arrives modally and reads truer with a mark.
  Widget? _impliedLeading(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null || !route.canPop) return null;
    return LiquidPrismBackButton(
      close: route is PageRoute && route.fullscreenDialog,
    );
  }

  /// The body, or a scroll view built from the slivers with the chrome's
  /// insets as slivers of their own.
  Widget _content() {
    final body = widget.body;
    if (body != null) return body;
    return _SliverPage(
      slivers: widget.slivers!,
      header: widget.header,
      controller: widget.scrollController,
      onRefresh: widget.onRefresh,
      onHeaderExtent: (extent) {
        if (extent == _headerExtent || !mounted) return;
        setState(() => _headerExtent = extent);
        _syncTitle();
      },
    );
  }

  /// Whether the actions and [tabs] both fit a rail of [height] below the
  /// actions' top, with the measured gaps.
  bool _fitsRail(double height, {required Widget? tabs}) {
    final actions = widget._allActions;
    if (actions.length < 2) return true;
    final groups = widget._actionGroups.where((g) => g.isNotEmpty).length;
    final actionsLength =
        actions.fold<double>(0, (sum, item) => sum + item.width) +
        14 * (actions.length - groups) +
        // Each further capsule adds its own insets and the gap between.
        (10 + 8) * (groups - 1) +
        10;
    final tabsLength = switch (tabs) {
      LiquidPrismTabBar(:final tabs) => 50.0 * tabs.length + 12,
      _ => 0.0,
    };
    return actionsLength + _ChromeLayout._railGap + tabsLength <= height;
  }
}

/// Three dots in the icon theme's size and color: the overflow symbol,
/// without depending on an icon font.
class _Ellipsis extends StatelessWidget {
  const _Ellipsis();

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    final dot = size * .16;
    return Semantics(
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: theme.color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Slot {
  body,
  bottomScrollEdge,
  bottomBar,
  title,
  largeTitle,
  scrollEdge,
  accessory,
  sidebar,
  sidebarToggle,
  leading,
  actions,
  tabBar,
}

/// Body constraints that also carry the chrome's coverage, the technique
/// Flutter's own Scaffold uses to hand layout-time sizes to its body.
class _BodyConstraints extends BoxConstraints {
  _BodyConstraints(super.size, this.covered) : super.tight();
  final EdgeInsets covered;

  @override
  bool operator ==(Object other) =>
      other is _BodyConstraints && covered == other.covered && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, covered);
}

class _InsetBody extends StatelessWidget {
  const _InsetBody({
    required this.media,
    required this.child,
    required this.consumeKeyboard,
  });
  final bool consumeKeyboard;
  final MediaQueryData media;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final covered = constraints is _BodyConstraints
          ? constraints.covered
          : EdgeInsets.zero;
      return MediaQuery(
        data: media.copyWith(
          viewInsets: consumeKeyboard
              ? media.viewInsets.copyWith(bottom: 0)
              : media.viewInsets,
          padding: EdgeInsets.fromLTRB(
            math.max(media.padding.left, covered.left),
            math.max(media.padding.top, covered.top),
            math.max(media.padding.right, covered.right),
            math.max(media.padding.bottom, covered.bottom),
          ),
        ),
        child: child,
      );
    },
  );
}

class _ChromeLayout extends MultiChildLayoutDelegate {
  _ChromeLayout({
    required this.placement,
    required this.viewPadding,
    required this.keyboard,
    required this.textDirection,
    required this.iOS,
    required this.topBar,
    required this.accessoryHeight,
    required this.titleRowHeight,
    required this.expandedHeight,
    required this.collapseExtent,
    required this.scrollOffset,
    required this.titleGutter,
    required this.titleGap,
    required this.actionsTop,
    required this.railBottom,
    required this.sheet,
    required this.edgeFrame,
    required this.corner,
    required this.sidebar,
    required this.reveal,
  }) : super(relayout: Listenable.merge([reveal, scrollOffset]));

  final GlassChromePlacement placement;
  final EdgeInsets viewPadding;
  final double keyboard, actionsTop, railBottom;
  final bool sheet;

  /// Extra depth of the top edge effect below the controls: measured on iOS
  /// 27, a hard edge ends at the bar frame, 10 points below 44-point
  /// controls; with an accessory the accessory ends the frame.
  final double edgeFrame;

  /// Height of the row below the top bar, 0 without one.
  final double accessoryHeight;
  final double titleRowHeight,
      expandedHeight,
      collapseExtent,
      titleGutter,
      titleGap;
  final ValueListenable<double> scrollOffset;

  /// A status bar region in a top corner, which the top bar's row avoids.
  final Rect? corner;
  final TextDirection textDirection;
  final bool iOS, topBar;

  /// The physical edge of a visible sidebar.
  final AxisDirection? sidebar;

  /// How far the sidebar is shown, from 0 to 1.
  final Animation<double> reveal;

  /// Where rail actions start: below the system UI that UIKit reports in the
  /// rail (the status bar), else below the top safe area, else the measured
  /// Duo offsets for systems without reserved regions.
  /// The window safe area with room for the rail. UIKit reserves the strip
  /// when the status bar shares it; in Split View on the left the status bar
  /// belongs to the other app and only native bars would add the inset, so
  /// the scaffold reserves the measured 84 pt strip itself.
  static EdgeInsets withRail(
    EdgeInsets viewPadding,
    GlassChromePlacement placement,
  ) => switch (placement) {
    GlassChromePlacement.leftRail => viewPadding.copyWith(
      left: math.max(viewPadding.left, _railStrip),
    ),
    GlassChromePlacement.rightRail => viewPadding.copyWith(
      right: math.max(viewPadding.right, _railStrip),
    ),
    GlassChromePlacement.bottom => viewPadding,
  };

  /// Where the rail's tab bar ends: above any system UI that UIKit reports in
  /// the lower half of the rail (the closed iPhone Duo in landscape puts the
  /// status bar and camera there), else 24 pt above the window's edge.
  static double railBottomOf(
    Size size,
    EdgeInsets viewPadding,
    GlassChromePlacement placement,
    List<Rect> occlusions,
  ) {
    final column = _railColumn(size, viewPadding, placement);
    final below = [
      for (final region in occlusions)
        if (region.overlaps(column) && region.center.dy >= size.height / 2)
          region.top,
    ];
    return below.isEmpty ? size.height - _railEdge : below.reduce(math.min);
  }

  /// An occlusion touching the top edge in a corner, outside any rail.
  static Rect? topCorner(Size size, List<Rect> occlusions) {
    for (final region in occlusions) {
      final touchesTop = region.top <= 1;
      final corner = region.left <= 1 || (size.width - region.right).abs() <= 1;
      if (touchesTop && corner && region.width < size.width / 2) {
        return region;
      }
    }
    return null;
  }

  static Rect _railColumn(
    Size size,
    EdgeInsets viewPadding,
    GlassChromePlacement placement,
  ) => placement == GlassChromePlacement.rightRail
      ? Rect.fromLTRB(
          size.width - viewPadding.right,
          0,
          size.width,
          size.height,
        )
      : Rect.fromLTRB(0, 0, viewPadding.left, size.height);

  static double railActionsTop(
    Size size,
    EdgeInsets viewPadding,
    GlassChromePlacement placement,
    List<Rect> occlusions, {
    bool reported = false,
  }) {
    final column = _railColumn(size, viewPadding, placement);
    final inRail = [
      for (final region in occlusions)
        if (region.overlaps(column) && region.center.dy < size.height / 2)
          region.bottom,
    ];
    if (inRail.isNotEmpty) return inRail.reduce(math.max);
    // UIKit reports nothing in this rail: no status bar shares it.
    if (reported || viewPadding.top > 0) {
      return math.max(viewPadding.top, _minimumTop);
    }
    return size.width > size.height
        ? _railActionsTopLandscape
        : _railActionsTopPortrait;
  }

  // Measured on iOS 27 simulators; see doc/native_adaptive_layout.md.
  static const _edge = 16.0;
  static const _minimumTop = 24.0;
  // Measured: in a sheet the bar's controls sit 16 pt below its top.
  static const _sheetTop = 16.0;
  static const _bottomBarGap = 21.0;
  static const _railGap = 12.0;
  static const _railEdge = 24.0;
  static const _railStrip = _railGap + 48 + _railEdge;
  // Without reserved regions: measured at y 170 in the folded (portrait)
  // window and y 120 in the unfolded (landscape) one, where the status bar's
  // occlusion region ends.
  static const _railActionsTopPortrait = 170.0;
  static const _railActionsTopLandscape = 120.0;

  @override
  void performLayout(Size size) {
    final rail = placement.isRail;
    final right = placement == GlassChromePlacement.rightRail;
    // The top bar starts at the status bar's bottom; with the status bar in
    // the rail it keeps a 24 pt margin.
    final top = sheet
        ? _sheetTop
        : corner == null
        ? math.max(viewPadding.top, _minimumTop)
        : _minimumTop;
    final rtl = textDirection == TextDirection.rtl;
    // The rail sits inside the safe area; the bars and content sit beside
    // the sidebar too.
    final railLeft = viewPadding.left;
    final railRight = size.width - viewPadding.right;
    final sidebarWidth = NativeSidebar.width;
    final shown = sidebar == null ? 0.0 : reveal.value.clamp(0.0, 1.0);
    // The panel slides by its width while the body reflows with it.
    final contentLeft = sidebar == AxisDirection.left
        ? railLeft + (math.max(railLeft, sidebarWidth) - railLeft) * shown
        : railLeft;
    final contentRight = sidebar == AxisDirection.right
        ? railRight -
              (railRight - math.min(railRight, size.width - sidebarWidth)) *
                  shown
        : railRight;
    final barRow = topBar ? titleRowHeight : 0.0;
    final collapse = collapseExtent == 0
        ? (scrollOffset.value > 0 ? 1.0 : 0.0)
        : (scrollOffset.value / collapseExtent).clamp(0.0, 1.0);
    final largeHeight = expandedHeight * (1 - collapse);
    // The body keeps the expanded bar's inset while the large title collapses:
    // content scrolls one for one beneath the title and accessory riding up
    // over it. A shrinking inset moved content twice as fast as the finger.
    var covered = EdgeInsets.only(
      top: topBar || accessoryHeight > 0
          ? top +
                barRow +
                expandedHeight +
                accessoryHeight +
                LiquidPrismScaffold.topBarClearance
          : top,
    );
    // The top bar row ends where a corner status bar begins.
    final barLeft = corner != null && corner!.left <= 1
        ? math.max(contentLeft, corner!.right)
        : contentLeft;
    final barRight = corner != null && corner!.left > 1
        ? math.min(contentRight, corner!.left)
        : contentRight;

    if (hasChild(_Slot.scrollEdge)) {
      // The bar's box, status bar and accessory included; a soft effect
      // reaches below it.
      layoutChild(
        _Slot.scrollEdge,
        BoxConstraints.tight(
          Size(
            math.max(0, contentRight - contentLeft),
            top + barRow + largeHeight + accessoryHeight + edgeFrame,
          ),
        ),
      );
      positionChild(_Slot.scrollEdge, Offset(contentLeft, 0));
    }
    if (hasChild(_Slot.accessory)) {
      layoutChild(
        _Slot.accessory,
        BoxConstraints.tightFor(
          width: math.max(0, contentRight - contentLeft),
          height: accessoryHeight,
        ),
      );
      positionChild(
        _Slot.accessory,
        Offset(contentLeft, top + barRow + largeHeight),
      );
    }

    if (hasChild(_Slot.sidebar)) {
      layoutChild(
        _Slot.sidebar,
        BoxConstraints.tight(Size(sidebarWidth, size.height)),
      );
      final hidden = sidebarWidth * (1 - shown);
      positionChild(
        _Slot.sidebar,
        Offset(
          sidebar == AxisDirection.right
              ? size.width - sidebarWidth + hidden
              : -hidden,
          0,
        ),
      );
    }

    double centred(Size child) => top + (barRow - child.height) / 2;
    // The show-sidebar toggle holds its measured place while the body
    // reflows beneath the panel; the leading widget follows the body.
    var leadingOffset = _edge;
    var leadingEnd = barLeft;
    var trailingStart = barRight;
    if (hasChild(_Slot.sidebarToggle)) {
      final toggle = layoutChild(
        _Slot.sidebarToggle,
        BoxConstraints.loose(size),
      );
      const inset = NativeSidebar.toggleInset;
      positionChild(
        _Slot.sidebarToggle,
        Offset(
          rtl ? railRight - inset - toggle.width : railLeft + inset,
          // Measured at the top bar's top, as the panel's own toggle.
          top,
        ),
      );
      if (!toggle.isEmpty) leadingOffset = inset + toggle.width + 8;
      if (!toggle.isEmpty) {
        if (rtl) {
          trailingStart = barRight - leadingOffset;
        } else {
          leadingEnd = barLeft + leadingOffset;
        }
      }
    }
    if (hasChild(_Slot.leading)) {
      final child = layoutChild(_Slot.leading, BoxConstraints.loose(size));
      if (rtl) {
        trailingStart = barRight - leadingOffset - child.width;
      } else {
        leadingEnd = barLeft + leadingOffset + child.width;
      }
      positionChild(
        _Slot.leading,
        Offset(
          rtl
              ? barRight - leadingOffset - child.width
              : barLeft + leadingOffset,
          centred(child),
        ),
      );
    }

    // Rail column: 48 pt wide, 12 pt outside the safe area's edge.
    double railX(double width) => right
        ? railRight + _railGap + (48 - width) / 2
        : railLeft - _railGap - 48 + (48 - width) / 2;

    if (hasChild(_Slot.actions)) {
      final actions = layoutChild(_Slot.actions, BoxConstraints.loose(size));
      if (rail) {
        positionChild(_Slot.actions, Offset(railX(actions.width), actionsTop));
      } else {
        // Beside a corner status bar the group meets its edge, as measured.
        final x = rtl
            ? barLeft + (corner != null && barLeft > contentLeft ? 0 : _edge)
            : barRight -
                  (corner != null && barRight < contentRight ? 0 : _edge) -
                  actions.width;
        if (rtl) {
          leadingEnd = x + actions.width;
        } else {
          trailingStart = x;
        }
        positionChild(
          _Slot.actions,
          Offset(x, top + math.max(0, (barRow - actions.height) / 2)),
        );
      }
    }

    if (hasChild(_Slot.title)) {
      final centre = (barLeft + barRight) / 2;
      final left = math.max(
        barLeft + titleGutter,
        leadingEnd + (leadingEnd > barLeft ? titleGap : 0),
      );
      final right = math.min(
        barRight - titleGutter,
        trailingStart - (trailingStart < barRight ? titleGap : 0),
      );
      final half = math.max(0.0, math.min(centre - left, right - centre));
      final title = layoutChild(
        _Slot.title,
        BoxConstraints.loose(Size(2 * half, barRow)),
      );
      positionChild(
        _Slot.title,
        Offset(centre - title.width / 2, centred(title)),
      );
    }
    if (hasChild(_Slot.largeTitle)) {
      // The title rides the content up, as measured, while the row shrinks.
      layoutChild(
        _Slot.largeTitle,
        BoxConstraints.tightFor(
          width: math.max(0, barRight - barLeft - 2 * titleGutter),
        ),
      );
      positionChild(
        _Slot.largeTitle,
        Offset(
          barLeft + titleGutter,
          top + barRow + 3.67 - math.min(scrollOffset.value, expandedHeight),
        ),
      );
    }
    if (hasChild(_Slot.tabBar)) {
      if (rail) {
        final bar = layoutChild(
          _Slot.tabBar,
          BoxConstraints.loose(Size(size.width, math.max(0, railBottom - top))),
        );
        positionChild(
          _Slot.tabBar,
          Offset(railX(bar.width), railBottom - bar.height),
        );
      } else {
        // Native floating housing sits 21 pt from the screen edge on iOS
        // (doc/native_tab_bar_spec.md), within the gesture inset.
        final gap = iOS ? _bottomBarGap : viewPadding.bottom + 10;
        final width = math.max(0.0, contentRight - contentLeft - 2 * 24);
        final bar = layoutChild(
          _Slot.tabBar,
          BoxConstraints.loose(Size(math.min(width, 440), size.height)),
        );
        positionChild(
          _Slot.tabBar,
          Offset(
            contentLeft + (contentRight - contentLeft - bar.width) / 2,
            size.height - gap - bar.height,
          ),
        );
        // Measured: content clears the bar by 3 pt (safe area 86 for a 62 pt bar).
        covered = covered.copyWith(bottom: gap + bar.height + 3);
      }
    }

    if (hasChild(_Slot.bottomBar)) {
      // Above the keyboard, else above the tab bar or the home indicator.
      final floor = keyboard > 0
          ? keyboard
          : covered.bottom > 0
          ? covered.bottom + 8
          : viewPadding.bottom;
      final bar = layoutChild(
        _Slot.bottomBar,
        BoxConstraints.loose(
          Size(math.max(0, contentRight - contentLeft), size.height),
        ),
      );
      final barTop = size.height - floor - bar.height;
      positionChild(
        _Slot.bottomBar,
        Offset(
          contentLeft + (contentRight - contentLeft - bar.width) / 2,
          barTop,
        ),
      );
      covered = covered.copyWith(bottom: size.height - barTop);
      if (hasChild(_Slot.bottomScrollEdge)) {
        // From the bar's top to the screen's bottom; a soft effect reaches
        // above it.
        layoutChild(
          _Slot.bottomScrollEdge,
          BoxConstraints.tight(
            Size(math.max(0, contentRight - contentLeft), size.height - barTop),
          ),
        );
        positionChild(_Slot.bottomScrollEdge, Offset(contentLeft, barTop));
      }
    }
    covered = covered.copyWith(
      bottom: math.max(covered.bottom, keyboard),
      left: contentLeft,
      right: size.width - contentRight,
    );
    layoutChild(_Slot.body, _BodyConstraints(size, covered));
    positionChild(_Slot.body, Offset.zero);
  }

  @override
  bool shouldRelayout(_ChromeLayout old) =>
      placement != old.placement ||
      viewPadding != old.viewPadding ||
      keyboard != old.keyboard ||
      textDirection != old.textDirection ||
      iOS != old.iOS ||
      topBar != old.topBar ||
      accessoryHeight != old.accessoryHeight ||
      titleRowHeight != old.titleRowHeight ||
      expandedHeight != old.expandedHeight ||
      collapseExtent != old.collapseExtent ||
      titleGutter != old.titleGutter ||
      titleGap != old.titleGap ||
      actionsTop != old.actionsTop ||
      railBottom != old.railBottom ||
      sheet != old.sheet ||
      edgeFrame != old.edgeFrame ||
      corner != old.corner ||
      sidebar != old.sidebar ||
      reveal != old.reveal;
}

/// The scroll view [LiquidPrismScaffold.slivers] builds: the chrome's insets
/// as slivers, the header, pull to refresh and a return to the top on a tab
/// reselection.
class _SliverPage extends StatefulWidget {
  const _SliverPage({
    required this.slivers,
    required this.header,
    required this.controller,
    required this.onRefresh,
    required this.onHeaderExtent,
  });
  final List<Widget> slivers;
  final Widget? header;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;
  final ValueChanged<double> onHeaderExtent;

  @override
  State<_SliverPage> createState() => _SliverPageState();
}

class _SliverPageState extends State<_SliverPage> {
  LiquidPrismTabReselection? _reselection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reselection = LiquidPrismTabReselection.maybeOf(context);
    if (reselection != _reselection) {
      _reselection?.removeListener(_toTop);
      _reselection = reselection?..addListener(_toTop);
    }
  }

  @override
  void dispose() {
    _reselection?.removeListener(_toTop);
    super.dispose();
  }

  /// Back to the top, for the visible page of the current route only.
  void _toTop() {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final controller =
        widget.controller ?? PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(0);
    } else {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final onRefresh = widget.onRefresh;
    final header = widget.header;
    return CustomScrollView(
      controller: widget.controller,
      primary: widget.controller == null ? true : null,
      // Pull to refresh and the bounce need room to scroll on a short page.
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (onRefresh != null)
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
            // The control sits above the top inset; its indicator draws below
            // the bar, in the gap the pull opens over the content.
            builder:
                (
                  context,
                  mode,
                  pulledExtent,
                  triggerDistance,
                  indicatorExtent,
                ) => Transform.translate(
                  offset: Offset(0, padding.top),
                  child: CupertinoSliverRefreshControl.buildRefreshIndicator(
                    context,
                    mode,
                    pulledExtent,
                    triggerDistance,
                    indicatorExtent,
                  ),
                ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: padding.top)),
        SliverPadding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (header != null)
                SliverToBoxAdapter(
                  child: _SizeReporter(
                    onHeight: widget.onHeaderExtent,
                    child: header,
                  ),
                ),
              ...widget.slivers,
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: padding.bottom)),
      ],
    );
  }
}

/// Reports its child's laid-out height after each layout that changes it.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reported;
  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // Outside layout: the scaffold rebuilds with the new threshold.
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
