import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'appearance.dart';
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
import 'title.dart';
import 'toolbar.dart';
import 'theme.dart';
import 'navigation_bar_style.dart';
import 'navigation_title_motion.dart';
import 'navigation_bar_minimization.dart';
import 'refresh.dart';
import 'scaffold_style.dart';

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

GlassChromePlacement _systemPlacement(
  EdgeInsets padding,
  GlassSystemChrome? system,
) => switch (system) {
  null => GlassChromePlacement.resolve(padding),
  GlassSystemChrome(hasVerticalBar: false) => GlassChromePlacement.bottom,
  GlassSystemChrome(verticalBarEdge: AxisDirection.left) =>
    GlassChromePlacement.leftRail,
  _ => GlassChromePlacement.rightRail,
};

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
/// On iPhone the [toolbar] sit at the top trailing edge and the [tabBar] floats
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
    this.style,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.toolbar = const [],
    this.trailing,
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

  /// Pull to refresh. Pulling the content down draws a black drop out of the
  /// Dynamic Island or a notch, or out of the top edge where the window has
  /// neither (iPhone Duo, a sheet, other platforms). Its ring fills as the
  /// pull grows; once whole, the drop pinches off into a circle, and a
  /// release then spins it until the returned future completes.
  ///
  /// It follows the scroll view that drives the bar (see [scrollDepth]) and
  /// floats over the content without moving it. [slivers] can always be
  /// pulled; a [body] scroll view shorter than the window needs
  /// [AlwaysScrollableScrollPhysics].
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
  final GlassScaffoldStyle? style;

  /// Fold the keyboard into body padding and consume its bottom view inset.
  /// False leaves keyboard avoidance to descendants.
  final bool resizeToAvoidBottomInset;

  /// A top-leading control, such as a back button. With horizontal bars it
  /// sits at the top bar's leading edge; with a vertical rail (iPhone Duo) it
  /// moves to the top of the rail, above the actions, as native back buttons
  /// do, within the 48 pt column. Null implies one; see
  /// [automaticallyImplyLeading].
  final Widget? leading;

  /// Whether a null [leading] becomes a [LiquidPrismBackButton] when the
  /// route can pop: a back chevron, or a close mark on a fullscreen dialog.
  final bool automaticallyImplyLeading;

  /// Typed toolbar content. Automatic items occupy the top trailing region.
  /// Explicit placements populate leading, principal and bottom regions.
  final List<GlassToolbarContent> toolbar;

  /// Additional content before the top trailing toolbar.
  final Widget? trailing;

  List<GlassToolbarContent> get _trailingContent =>
      glassToolbarAt(toolbar, GlassToolbarPlacement.topTrailing);
  List<GlassToolbarItem> get _allActions => [
    for (final entry in glassToolbarSegments(_trailingContent))
      if (entry is GlassToolbarGroup) ...entry.items,
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
  ///
  /// Turning it on after the page appears, as a page might once its entering
  /// transition settles, fades the effects in, blur and fade together, over
  /// [scrollEdgeFadeDuration]; turning it off fades them out.
  final bool scrollEdge;

  /// How long the scroll edge effects take to fade in or out when
  /// [scrollEdge] changes.
  static const scrollEdgeFadeDuration = Duration(milliseconds: 900);

  /// Overrides the theme's [GlassScrollEdgeStyle] field by field. Its
  /// `fadeColor` applies when [backgroundColor] is null. The bottom bar uses
  /// the soft variant. Set [scrollEdge] to false to disable both edges.
  final GlassScrollEdgeStyle? scrollEdgeStyle;

  /// The placement of the nearest scaffold, or null outside one.
  static GlassChromePlacement? placementOf(BuildContext context) =>
      LiquidPrismChrome.maybeOf(context)?.placement;

  /// Safe insets for content aligned with the scaffold, including a side rail.
  ///
  /// Use this for overlays outside the body, such as a sheet's drag handle.
  /// The body already receives these insets plus measured bar coverage through
  /// [MediaQuery.paddingOf]. [placement] overrides the nearest scaffold or the
  /// system's placement when the overlay belongs to a differently placed bar.
  static EdgeInsets contentInsetsOf(
    BuildContext context, {
    GlassChromePlacement? placement,
  }) {
    final padding = MediaQuery.viewPaddingOf(context);
    return _ChromeLayout.withRail(
      padding,
      placement ??
          placementOf(context) ??
          _systemPlacement(padding, LiquidPrismSystemChrome.of(context)),
    );
  }

  /// The top bar's measured height: 44 pt navigation capsules.
  static const double topBarHeight = 44;

  /// Native navigation frame clearance below its 44-point controls.
  static const double topBarClearance = 10;

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
  late final _titleHeight = RetargetableGlassSpring(vsync: this)
    ..addListener(() {
      if (mounted && !_configuringTitleHeight) setState(() {});
    });
  double? _titleHeightTarget;
  bool _configuringTitleHeight = false;

  double _animateTitleHeight(double target, {required bool immediate}) {
    if (_titleHeightTarget != target ||
        (immediate && _titleHeight.isAnimating)) {
      _configuringTitleHeight = true;
      springGlass(
        _titleHeight,
        target,
        titleCompositionSpring.description,
        immediate: immediate || _titleHeightTarget == null,
      );
      _titleHeightTarget = target;
      _configuringTitleHeight = false;
    }
    return math.max(0, _titleHeight.value);
  }

  /// The [LiquidPrismScaffold.header]'s laid-out height: the scroll at which
  /// the title swaps in.
  double _headerExtent = 0;

  /// Tab reselections, shared by this scaffold's tab bar and the pages in its
  /// body; each page's scroll view returns to the top.
  final _reselection = LiquidPrismTabReselection();
  late final _minimization = NavigationBarMinimization(vsync: this);

  final _statusBarKey = GlobalKey();
  final _refreshKey = GlobalKey<GlassRefreshLayerState>();
  final _appPointers = <int>{};
  bool _pointerEndedThisFrame = false;

  void _endAppPointer(int pointer) {
    _appPointers.remove(pointer);
    if (_pointerEndedThisFrame) return;
    _pointerEndedThisFrame = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pointerEndedThisFrame = false;
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// The scroll edge effects' presence: 1 while [LiquidPrismScaffold.scrollEdge]
  /// holds, easing in and out when it changes.
  late final _edgePresence =
      AnimationController(
        vsync: this,
        duration: LiquidPrismScaffold.scrollEdgeFadeDuration,
        value: widget.scrollEdge ? 1 : 0,
      )..addStatusListener((status) {
        if (status.isDismissed && mounted) setState(() {});
      });
  late final _edgeStrength = CurvedAnimation(
    parent: _edgePresence,
    curve: Curves.easeInOutCubic,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(LiquidPrismScaffold old) {
    super.didUpdateWidget(old);
    if (old.scrollEdge == widget.scrollEdge) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _edgePresence.value = widget.scrollEdge ? 1 : 0;
    } else if (widget.scrollEdge) {
      _edgePresence.forward();
    } else {
      _edgePresence.reverse();
    }
  }

  @override
  void handleStatusBarTap() {
    // iOS 27.2 can report a status-bar tap during an ordinary app touch.
    // Keep its duplicate notification from scrolling before the action fires.
    if (_appPointers.isNotEmpty || _pointerEndedThisFrame) return;
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

  /// How far that scroll view is pulled past its start: the large title
  /// follows the content down, as a native one does.
  final _overscroll = ValueNotifier<double>(0);

  /// How much of that scroll view's content lies beyond its end, under a
  /// [LiquidPrismScaffold.bottomBar].
  final _scrollRemaining = ValueNotifier<double>(0);

  /// [_scrollOffset] limited to the range the layout reads: the large title
  /// and its row stop moving once they have scrolled away, so further scroll
  /// frames no longer lay out (and repaint) the chrome.
  final _layoutOffset = ValueNotifier<double>(0);
  double _layoutCap = double.infinity;

  bool _onScroll(ScrollMetrics metrics, {bool dimensionsChanged = false}) {
    if (metrics.axis == Axis.vertical) {
      _minimization.update(metrics, dimensionsChanged: dimensionsChanged);
      _scrollOffset.value = math.max(
        0,
        metrics.pixels - metrics.minScrollExtent,
      );
      _overscroll.value = math.max(0, metrics.minScrollExtent - metrics.pixels);
      _layoutOffset.value = math.min(_scrollOffset.value, _layoutCap);
      _scrollRemaining.value = math.max(
        0,
        metrics.maxScrollExtent - metrics.pixels,
      );
      _syncTitle();
    }
    return false;
  }

  late final _largeFade = RetargetableGlassSpring(vsync: this);
  late final _inlineFade = RetargetableGlassSpring(vsync: this);
  bool _collapsed = false;
  double _collapseAt = double.infinity;

  void _syncTitle() {
    final collapsed =
        _scrollOffset.value > 0 && _scrollOffset.value >= _collapseAt;
    if (collapsed == _collapsed) return;
    _collapsed = collapsed;
    final navigation =
        (LiquidPrismTheme.of(context).navigationBar ??
                const GlassNavigationBarStyle())
            .merge(widget.navigationBarStyle);
    animateNavigationTitle(
      large: _largeFade,
      inline: _inlineFade,
      style: navigation,
      collapsed: collapsed,
      immediate: MediaQuery.disableAnimationsOf(context),
      isMounted: () => mounted,
    );
  }

  /// How far the sidebar is shown: it slides the panel and reflows the body.
  late final _reveal = RetargetableGlassSpring(vsync: this)
    ..value = 1
    ..addStatusListener((status) {
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
    _titleHeight.dispose();
    _edgeStrength.dispose();
    _edgePresence.dispose();
    _reveal.dispose();
    _largeFade.dispose();
    _inlineFade.dispose();
    _scrollOffset.dispose();
    _overscroll.dispose();
    _layoutOffset.dispose();
    _minimization.dispose();
    _scrollRemaining.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _reselection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        widget.placement ?? _systemPlacement(media.viewPadding, system);
    final rail = resolved.isRail;
    final explicitDock = switch (widget.tabBarPlacement) {
      GlassTabBarPlacement.bottom ||
      GlassTabBarPlacement.top ||
      GlassTabBarPlacement.leading ||
      GlassTabBarPlacement.trailing => widget.tabBarPlacement,
      _ => null,
    };
    final verticalTabs = explicitDock == null
        ? rail
        : explicitDock == GlassTabBarPlacement.leading ||
              explicitDock == GlassTabBarPlacement.trailing;
    final scaffoldStyle =
        (LiquidPrismTheme.of(context).scaffold ?? const GlassScaffoldStyle())
            .merge(widget.style);
    final keyboard = media.viewInsets.bottom > 0;

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
    final sidebar =
        sidebarTabs != null && (!_sidebarHidden || _reveal.value > 0);
    final sidebarToggle = sidebarTabs != null && _sidebarHidden;
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
    final corner = rail || widget.sheet
        ? null
        : _ChromeLayout.topCorner(media.size, occlusions);
    final showTabBar =
        tabBar != null &&
        sidebarTabs == null &&
        (verticalTabs || explicitDock == GlassTabBarPlacement.top || !keyboard);
    final leadingContent = glassToolbarAt(
      widget.toolbar,
      GlassToolbarPlacement.topLeading,
    );
    final principal = glassToolbarAt(
      widget.toolbar,
      GlassToolbarPlacement.principal,
    );
    final leadingWidget =
        widget.leading ??
        (widget.automaticallyImplyLeading ? _impliedLeading(context) : null);
    final leading = leadingContent.isEmpty
        ? leadingWidget
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingWidget != null) ...[
                leadingWidget,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: LiquidPrismToolbar(
                  content: leadingContent,
                  style: glassToolbarStyleFor(
                    context,
                    GlassToolbarSize.navigation,
                  ),
                ),
              ),
            ],
          );
    final inlineTitle = principal.isEmpty
        ? widget.title
        : LiquidPrismToolbar(
            content: principal,
            style: glassToolbarStyleFor(context, GlassToolbarSize.navigation),
          );
    final bottomContent = glassBottomToolbarContent(widget.toolbar);
    final bottomBar = bottomContent.isEmpty
        ? widget.bottomBar
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidPrismToolbar(content: bottomContent),
              if (widget.bottomBar != null) ...[
                const SizedBox(height: 8),
                widget.bottomBar!,
              ],
            ],
          );
    final railLeading = rail && leading != null
        ? 48 + _ChromeLayout._railGap
        : 0;
    final content =
        rail &&
            !_fitsRail(
              railBottom - actionsTop - railLeading,
              tabs: showTabBar && explicitDock == null ? tabBar : null,
            )
        ? _overflowRailContent()
        : widget._trailingContent;
    final features = addFeatures
        ? system?.displayFeatures ?? const []
        : const <DisplayFeature>[];
    final top = widget.sheet
        ? _ChromeLayout._sheetTop
        : math.max(media.viewPadding.top, _ChromeLayout._minimumTop);
    final navigation =
        (LiquidPrismTheme.of(context).navigationBar ??
                const GlassNavigationBarStyle())
            .merge(widget.navigationBarStyle);
    final titleStyle = TextStyle(
      fontFamily: 'CupertinoSystemText',
      fontSize: widget.subtitle == null ? 17 : 15,
      fontWeight: FontWeight.w600,
      letterSpacing: widget.subtitle == null ? -.41 : -.23,
      color: GlassColors.of(context).label,
    ).merge(navigation.titleStyle);
    final largeTitleStyle = TextStyle(
      fontFamily: 'CupertinoSystemDisplay',
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: .38,
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
    final titleLine =
        scaler.scale(titleStyle.fontSize ?? 17) * (titleStyle.height ?? 1.2);
    final barHeight =
        navigation.controlRowHeight ??
        (rail ? 48.0 : LiquidPrismScaffold.topBarHeight);
    final controlRowHeight = inlineTitle == null
        ? barHeight
        : math.max(barHeight, titleLine + 8);
    final targetTitleRowHeight = switch (inlineTitle) {
      final LiquidPrismTitle title => math.max(
        controlRowHeight,
        LiquidPrismTitle.extentOf(
          title,
          (navigation.titleCapsule ?? const GlassTitleStyle()).merge(
            title.style,
          ),
          titleLine,
        ),
      ),
      _ => controlRowHeight,
    };
    final titleRowHeight = math.max(
      controlRowHeight,
      _animateTitleHeight(
        targetTitleRowHeight,
        immediate: media.disableAnimations || inlineTitle is! LiquidPrismTitle,
      ),
    );
    final expandedHeight = widget.largeTitle == null
        ? 0.0
        : navigation.largeTitleExtent ??
              scaler.scale(largeTitleStyle.fontSize ?? 34) *
                      (largeTitleStyle.height ?? 1.2) +
                  11.33 +
                  (widget.subtitle == null
                      ? 0
                      : scaler.scale(largeSubtitleStyle.fontSize ?? 11) * 1.2 +
                            6.13);
    final extent = navigation.revealExtent ?? expandedHeight;
    _layoutCap = math.max(extent, expandedHeight) + largeTitleLead + 1;
    _layoutOffset.value = math.min(_scrollOffset.value, _layoutCap);
    final revealExtent =
        GlassScrollEdgeStyle.resolve(
          context,
          widget.scrollEdgeStyle,
        ).revealExtent ??
        GlassScrollEdgeStyle.defaultRevealExtent;
    final swaps = widget.largeTitle != null || widget.header != null;
    final hidesOnScrollDown =
        navigation.minimizationBehavior ==
        GlassToolbarMinimizationBehavior.onScrollDown;
    final scrollsAway =
        hidesOnScrollDown &&
        navigation.minimizationRestoration ==
            GlassToolbarMinimizationRestoration.atScrollEdge;
    final minimizes = switch (navigation.minimizationBehavior) {
      GlassToolbarMinimizationBehavior.onScrollDown ||
      GlassToolbarMinimizationBehavior.onScrollUp => true,
      _ => false,
    };
    final edges = widget.scrollEdge || !_edgePresence.isDismissed;
    _collapseAt = widget.header != null
        ? (_headerExtent > 0 ? _headerExtent : double.infinity)
        : widget.largeTitle == null
        ? double.infinity
        : extent;
    if (!swaps && _collapsed) {
      _collapsed = false;
      _largeFade.value = _inlineFade.value = 0;
    }
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
      if (!swaps && !minimizes) return text;
      return AnimatedBuilder(
        animation: Listenable.merge([
          _largeFade,
          _inlineFade,
          _minimization.progress,
          _minimization.revealed,
        ]),
        builder: (context, child) {
          final eligible =
              large ||
              !swaps ||
              !hidesOnScrollDown ||
              _minimization.revealed.value;
          final visible =
              eligible && (!swaps || (large ? !_collapsed : _collapsed));
          final inline = _inlineFade.value;
          final opacity =
              (swaps ? (large ? 1 - _largeFade.value : inline) : 1.0) *
              (1 - _minimization.progress.value) *
              (eligible ? 1 : 0);
          return ExcludeSemantics(
            excluding: !visible,
            child: ExcludeFocus(
              excluding: !visible,
              child: IgnorePointer(
                ignoring: !visible,
                child: GlassContentPresence(
                  presence: opacity,
                  blur: large ? 0 : titleBlur,
                  child: large || !swaps
                      ? child!
                      : Transform.translate(
                          offset: Offset(0, 15 * (1 - inline)),
                          child: child,
                        ),
                ),
              ),
            ),
          );
        },
        child: text,
      );
    }

    final topBar =
        inlineTitle != null ||
        widget.largeTitle != null ||
        (!rail && leading != null) ||
        widget.trailing != null ||
        sidebarTabs != null ||
        (!rail && glassToolbarHasContent(content));
    _minimization.configure(
      navigation,
      collapseExtent: widget.largeTitle == null ? 0 : extent + largeTitleLead,
    );
    final layout = CustomMultiChildLayout(
      delegate: _ChromeLayout(
        placement: resolved,
        minimization: _minimization.progress,
        onMinimizationExtent: _minimization.setExtent,
        adjustsMinimizationInsets:
            navigation.minimizationSafeAreaAdjustment ==
            GlassToolbarMinimizationSafeAreaAdjustment.enabled,
        tabDock: explicitDock,
        style: scaffoldStyle,
        viewPadding: padding,
        keyboard: widget.resizeToAvoidBottomInset ? media.viewInsets.bottom : 0,
        textDirection: Directionality.of(context),
        iOS: defaultTargetPlatform == TargetPlatform.iOS,
        topBar: topBar,
        accessoryHeight: widget.accessory?.preferredSize.height ?? 0,
        titleRowHeight: titleRowHeight,
        controlRowHeight: controlRowHeight,
        contentSpacing:
            navigation.contentSpacing ??
            (rail || sidebar || corner != null
                ? 16
                : LiquidPrismScaffold.topBarClearance),
        titleAlignment:
            navigation.titleAlignment ?? GlassTitleAlignment.automatic,
        contentPadding: (navigation.contentPadding ?? EdgeInsets.zero).resolve(
          Directionality.of(context),
        ),
        expandedHeight: expandedHeight,
        largeTitleTop: widget.subtitle == null ? 3.67 : 6.67,
        collapseExtent: extent,
        scrollOffset: _layoutOffset,
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
      children:
          [
            LayoutId(
              id: _Slot.body,
              child: LiquidPrismChrome(
                placement: resolved,
                child: _InsetBody(
                  consumeKeyboard: widget.resizeToAvoidBottomInset,
                  media: features.isEmpty
                      ? media
                      : media.copyWith(
                          displayFeatures: [
                            ...media.displayFeatures,
                            ...features,
                          ],
                        ),
                  child:
                      ((edges || swaps || minimizes) &&
                              (topBar || widget.accessory != null)) ||
                          bottomBar != null ||
                          widget.onRefresh != null
                      ? NotificationListener<ScrollMetricsNotification>(
                          onNotification: (n) =>
                              n.depth == widget.scrollDepth &&
                              _onScroll(n.metrics, dimensionsChanged: true),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.depth != widget.scrollDepth) return false;
                              _refreshKey.currentState?.handleScroll(n);
                              return _onScroll(n.metrics);
                            },
                            child: _content(),
                          ),
                        )
                      : _content(),
                ),
              ),
            ),
            if (edges && (topBar || widget.accessory != null))
              LayoutId(
                id: _Slot.scrollEdge,
                child: GlassGroupMembers(
                  child: ScrollEdgeProgressBuilder(
                    listenable: Listenable.merge([
                      _scrollOffset,
                      _edgeStrength,
                      _minimization.revealed,
                    ]),
                    progress: () =>
                        (widget.accessory != null ||
                                !hidesOnScrollDown ||
                                _minimization.revealed.value
                            ? _edgeStrength.value
                            : 0) *
                        LiquidPrismScrollEdge.progressFor(
                          _scrollOffset.value,
                          revealExtent: revealExtent,
                        ),
                    builder: (context, progress) => LiquidPrismScrollEdge(
                      progress: progress,
                      color: widget.backgroundColor,
                      style: widget.scrollEdgeStyle,
                    ),
                  ),
                ),
              ),
            if (edges && bottomBar != null)
              LayoutId(
                id: _Slot.bottomScrollEdge,
                child: GlassGroupMembers(
                  child: IgnorePointer(
                    child: ScrollEdgeProgressBuilder(
                      listenable: Listenable.merge([
                        _scrollRemaining,
                        _edgeStrength,
                      ]),
                      progress: () =>
                          _edgeStrength.value *
                          LiquidPrismScrollEdge.progressFor(
                            _scrollRemaining.value,
                            revealExtent: revealExtent,
                          ),
                      builder: (context, progress) => LiquidPrismScrollEdge(
                        edge: GlassEdge.bottom,
                        progress: progress,
                        color: widget.backgroundColor,
                        style:
                            (widget.scrollEdgeStyle ??
                                    const GlassScrollEdgeStyle())
                                .copyWith(variant: GlassScrollEdgeVariant.soft),
                      ),
                    ),
                  ),
                ),
              ),
            if (bottomBar case final bottomBar?)
              LayoutId(
                id: _Slot.bottomBar,
                child: GlassGroupMembers(child: bottomBar),
              ),
            if (inlineTitle case final title? when !(scrollsAway && swaps))
              LayoutId(
                id: _Slot.title,
                child: header(
                  glassTitled(
                    title,
                    widget.subtitle,
                    subtitleStyle,
                    large: false,
                    alignment:
                        navigation.titleAlignment == null ||
                            navigation.titleAlignment ==
                                GlassTitleAlignment.automatic
                        ? GlassTitleAlignment.center
                        : navigation.titleAlignment!,
                  ),
                  titleStyle,
                  large: false,
                ),
              ),
            if (widget.largeTitle case final title?)
              LayoutId(
                id: _Slot.largeTitle,
                child: ValueListenableBuilder<double>(
                  valueListenable: _overscroll,
                  builder: (context, overscroll, child) => Transform.translate(
                    offset: Offset(0, overscroll),
                    child: child,
                  ),
                  child: Align(
                    alignment: glassTitleBoxAlignment(
                      navigation.largeTitleAlignment ??
                          GlassTitleAlignment.leading,
                    ),
                    child: header(
                      glassTitled(
                        title,
                        widget.subtitle,
                        largeSubtitleStyle,
                        large: true,
                        alignment:
                            navigation.largeTitleAlignment ??
                            GlassTitleAlignment.leading,
                        subtitleOffset:
                            scaler.scale(largeTitleStyle.fontSize ?? 34) *
                            38.33 /
                            34,
                      ),
                      largeTitleStyle,
                      large: true,
                    ),
                  ),
                ),
              ),
            if (widget.accessory case final accessory?)
              LayoutId(
                id: _Slot.accessory,
                child: GlassGroupMembers(child: accessory),
              ),
            if (sidebarTabs != null)
              LayoutId(
                id: _Slot.sidebarToggle,
                child: LiquidPrismVisibility(
                  visible: sidebarToggle,
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
            if (leading case final leading?)
              LayoutId(
                id: _Slot.leading,
                child: GlassGroupMembers(child: leading),
              ),
            if (content.isNotEmpty)
              LayoutId(
                id: _Slot.actions,
                child: GlassGroupMembers(
                  child: LiquidPrismToolbar(
                    content: content,
                    style: glassToolbarStyleFor(
                      context,
                      rail || corner != null
                          ? GlassToolbarSize.bottom
                          : GlassToolbarSize.navigation,
                    ),
                    axis: rail ? Axis.vertical : Axis.horizontal,
                  ),
                ),
              ),
            if (widget.trailing case final trailing?)
              LayoutId(
                id: _Slot.trailing,
                child: GlassGroupMembers(child: trailing),
              ),
            if (showTabBar)
              LayoutId(
                id: _Slot.tabBar,
                child: GlassGroupMembers(
                  child: LiquidPrismChrome(
                    placement: resolved,
                    axis: verticalTabs ? Axis.vertical : Axis.horizontal,
                    child: tabBar,
                  ),
                ),
              ),
          ].map((child) {
            final moves = switch (child.id) {
              _Slot.title ||
              _Slot.largeTitle ||
              _Slot.sidebarToggle ||
              _Slot.trailing => true,
              _Slot.leading || _Slot.actions => !rail,
              _Slot.scrollEdge => widget.accessory == null,
              _Slot.tabBar => explicitDock == GlassTabBarPlacement.top,
              _ => false,
            };
            return moves
                ? LayoutId(
                    id: child.id,
                    child: NavigationBarPresence(
                      progress: _minimization.progress,
                      child: child.child,
                    ),
                  )
                : child;
          }).toList(),
    );
    Widget hosted = Listener(
      onPointerDown: (event) => _appPointers.add(event.pointer),
      onPointerUp: (event) => _endAppPointer(event.pointer),
      onPointerCancel: (event) => _endAppPointer(event.pointer),
      child: GlassGroupHost(
        child: Stack(
          children: [
            Positioned.fill(child: layout),
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
      ),
    );
    if (widget.onRefresh case final onRefresh?) {
      // Above the glass group: its hoisted edge blur would soften the drop.
      hosted = Stack(
        children: [
          Positioned.fill(child: hosted),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: GlassRefreshLayer.extent,
            child: GlassRefreshLayer(
              key: _refreshKey,
              onRefresh: onRefresh,
              sideInsets: EdgeInsets.only(
                left: padding.left,
                right: padding.right,
              ),
              // Level with the bar's controls, where they form a top row.
              barCenter: rail || corner != null
                  ? null
                  : top + controlRowHeight / 2,
              sensorHousing: !widget.sheet,
            ),
          ),
        ],
      );
    }
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
      onHeaderExtent: (extent) {
        if (extent == _headerExtent || !mounted) return;
        setState(() => _headerExtent = extent);
        _syncTitle();
      },
    );
  }

  List<GlassToolbarContent> _overflowRailContent() {
    final actions = widget._allActions
        .where((item) => item.child == null)
        .toList();
    if (actions.length < 2) return widget._trailingContent;
    final result = <GlassToolbarContent>[];
    var inserted = false;
    for (final entry in glassToolbarSegments(widget._trailingContent)) {
      if (entry is! GlassToolbarGroup) {
        result.add(entry);
        continue;
      }
      if (!inserted && entry.items.any((item) => item.child == null)) {
        result.add(LiquidPrismScaffold._overflow(actions));
        inserted = true;
      }
      final custom = entry.items.where((item) => item.child != null).toList();
      if (custom.isNotEmpty) {
        result.add(
          GlassToolbarGroup(key: entry.key, style: entry.style, items: custom),
        );
      }
    }
    return result;
  }

  bool _fitsRail(double height, {required Widget? tabs}) {
    final theme =
        LiquidPrismTheme.of(context).toolbar ?? const GlassToolbarStyle();
    var length = 0.0, gap = 0.0;
    for (final entry in glassToolbarSegments(widget._trailingContent)) {
      if (entry is GlassToolbarSpacer) {
        length += entry.extent ?? 0;
        gap = 0;
      } else if (entry is GlassToolbarItem) {
        length += gap + (entry.width ?? 48);
        gap = theme.groupSpacing ?? 8;
      } else if (entry is GlassToolbarGroup && entry.items.isNotEmpty) {
        final style = theme.merge(entry.style);
        final extent = style.height ?? 48, inset = style.inset ?? 5;
        length +=
            gap + inset * 2 + (entry.items.length - 1) * (style.spacing ?? 14);
        for (final item in entry.items) {
          length += glassToolbarItemExtent(
            context,
            item,
            style,
            lone: entry.items.length == 1,
            height: extent,
            inset: inset,
            vertical: true,
          );
        }
        gap = theme.groupSpacing ?? 8;
      }
    }
    final tabsLength = switch (tabs) {
      LiquidPrismTabBar(:final tabs) => 50.0 * tabs.length + 12,
      _ => 0.0,
    };
    return length + _ChromeLayout._railGap + tabsLength <= height;
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
  trailing,
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

/// Measured on iOS 27: the bar frame ends 10 points below 44-point controls
/// (62 to 116) and the large title's 52-point row starts there, so its line
/// sits 13.67 points below the controls and content starts at the row's end.
const double largeTitleLead = 10;

class _ChromeLayout extends MultiChildLayoutDelegate {
  _ChromeLayout({
    required this.placement,
    required this.minimization,
    required this.onMinimizationExtent,
    required this.adjustsMinimizationInsets,
    required this.tabDock,
    required this.style,
    required this.viewPadding,
    required this.keyboard,
    required this.textDirection,
    required this.iOS,
    required this.topBar,
    required this.accessoryHeight,
    required this.titleRowHeight,
    required this.controlRowHeight,
    required this.contentSpacing,
    required this.titleAlignment,
    required this.contentPadding,
    required this.expandedHeight,
    required this.largeTitleTop,
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
  }) : super(relayout: Listenable.merge([reveal, scrollOffset, minimization]));

  final GlassChromePlacement placement;
  final EdgeInsets viewPadding;
  final GlassTabBarPlacement? tabDock;
  final Animation<double> minimization;
  final ValueChanged<double> onMinimizationExtent;
  final bool adjustsMinimizationInsets;
  final GlassScaffoldStyle style;
  final double keyboard, actionsTop, railBottom;
  final bool sheet;

  /// Extra depth of the top edge effect below the controls: measured on iOS
  /// 27, a hard edge ends at the bar frame, 10 points below 44-point
  /// controls; with an accessory the accessory ends the frame.
  final double edgeFrame;

  /// Height of the row below the top bar, 0 without one.
  final double accessoryHeight;

  final double contentSpacing;
  final GlassTitleAlignment titleAlignment;
  final EdgeInsets contentPadding;
  final double titleRowHeight,
      controlRowHeight,
      expandedHeight,
      collapseExtent,
      titleGutter,
      largeTitleTop,
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
    if (reported || viewPadding.top > 0) {
      return math.max(viewPadding.top, _minimumTop);
    }
    return size.width > size.height
        ? _railActionsTopLandscape
        : _railActionsTopPortrait;
  }

  static const _edge = 16.0;

  /// Between [LiquidPrismScaffold.trailing] and the first capsule, as the
  /// capsules space themselves.
  static const _trailingGap = 8.0;
  static const _minimumTop = 24.0;
  static const _sheetTop = 16.0;
  static const _bottomBarGap = 21.0;
  static const _railGap = 12.0;
  static const _railEdge = 24.0;
  static const _railStrip = _railGap + 48 + _railEdge;
  static const _railActionsTopPortrait = 170.0;
  static const _railActionsTopLandscape = 120.0;

  @override
  void performLayout(Size size) {
    final rail = placement.isRail;
    final right = placement == GlassChromePlacement.rightRail;
    var top =
        (sheet
            ? _sheetTop
            : corner == null
            ? math.max(viewPadding.top, _minimumTop)
            : _minimumTop) +
        contentPadding.top;
    final naturalTop = top;
    final rtl = textDirection == TextDirection.rtl;
    final railLeft = viewPadding.left;
    final railRight = size.width - viewPadding.right;
    final sidebarWidth = NativeSidebar.width;
    final shown = sidebar == null ? 0.0 : reveal.value.clamp(0.0, 1.0);
    var contentLeft = sidebar == AxisDirection.left
        ? railLeft + (math.max(railLeft, sidebarWidth) - railLeft) * shown
        : railLeft;
    var contentRight = sidebar == AxisDirection.right
        ? railRight -
              (railRight - math.min(railRight, size.width - sidebarWidth)) *
                  shown
        : railRight;
    final barRow = topBar ? titleRowHeight + contentPadding.bottom : 0.0;
    final lead = expandedHeight > 0 ? largeTitleLead : 0.0;
    final expanded = expandedHeight + lead;
    final collapse = collapseExtent == 0
        ? (scrollOffset.value > 0 ? 1.0 : 0.0)
        : (scrollOffset.value / (collapseExtent + lead)).clamp(0.0, 1.0);
    final largeHeight = expanded * (1 - collapse);
    // Retain the expanded inset so content follows scrolling one for one.
    var covered = EdgeInsets.only(
      top: topBar || accessoryHeight > 0
          ? top +
                barRow +
                expanded +
                accessoryHeight +
                (lead > 0 && accessoryHeight == 0 ? 0 : contentSpacing)
          : top,
    );
    var topDockHeight = 0.0;
    final dockMargin = style.tabBarMargin?.resolve(textDirection);
    final dockAlignment = (style.tabBarAlignment ?? Alignment.center).resolve(
      textDirection,
    );
    final sideDock =
        tabDock == GlassTabBarPlacement.leading ||
        tabDock == GlassTabBarPlacement.trailing;
    if (hasChild(_Slot.tabBar) &&
        (sideDock || tabDock == GlassTabBarPlacement.top)) {
      final margin = dockMargin ?? const EdgeInsets.all(12);
      final dockTop = top + barRow + largeHeight + accessoryHeight;
      final availableHeight = math.max(
        0.0,
        size.height -
            math.max(keyboard, viewPadding.bottom) -
            dockTop -
            margin.vertical,
      );
      final availableWidth = math.max(
        0.0,
        contentRight - contentLeft - margin.horizontal,
      );
      final bar = layoutChild(
        _Slot.tabBar,
        BoxConstraints.loose(
          Size(
            math.min(availableWidth, style.tabBarMaxWidth ?? 440),
            availableHeight,
          ),
        ),
      );
      if (sideDock) {
        final left = (tabDock == GlassTabBarPlacement.leading) != rtl;
        final x = left
            ? contentLeft + margin.left
            : contentRight - margin.right - bar.width;
        final y =
            dockTop +
            margin.top +
            (availableHeight - bar.height) * (dockAlignment.y + 1) / 2;
        positionChild(_Slot.tabBar, Offset(x, y));
        if (left) {
          contentLeft += bar.width + margin.horizontal;
        } else {
          contentRight -= bar.width + margin.horizontal;
        }
      } else {
        positionChild(
          _Slot.tabBar,
          Offset(
            contentLeft +
                margin.left +
                (availableWidth - bar.width) * (dockAlignment.x + 1) / 2,
            dockTop +
                margin.top -
                (barRow +
                        (accessoryHeight == 0 ? contentSpacing : 0) +
                        bar.height +
                        margin.vertical) *
                    minimization.value,
          ),
        );
        topDockHeight = bar.height + margin.vertical;
        covered = covered.copyWith(top: covered.top + topDockHeight);
      }
    }
    final minimizedExtent =
        barRow + (accessoryHeight == 0 ? contentSpacing : 0) + topDockHeight;
    onMinimizationExtent(minimizedExtent);
    top -= minimizedExtent * minimization.value;
    if (adjustsMinimizationInsets) {
      covered = covered.copyWith(
        top: math.max(
          naturalTop,
          covered.top - minimizedExtent * minimization.value,
        ),
      );
    }
    final barLeft =
        contentPadding.left +
        (corner != null && corner!.left <= 1
            ? math.max(contentLeft, corner!.right)
            : contentLeft);
    final barRight =
        (corner != null && corner!.left > 1
            ? math.min(contentRight, corner!.left)
            : contentRight) -
        contentPadding.right;

    if (hasChild(_Slot.scrollEdge)) {
      layoutChild(
        _Slot.scrollEdge,
        BoxConstraints.tight(
          Size(
            math.max(0, contentRight - contentLeft),
            math.max(
              0,
              top +
                  barRow +
                  largeHeight +
                  accessoryHeight +
                  topDockHeight +
                  edgeFrame -
                  (accessoryHeight == 0 ? math.min(lead, largeHeight) : 0),
            ),
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
        Offset(contentLeft, math.max(naturalTop, top + barRow + largeHeight)),
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

    final controlRow = topBar ? controlRowHeight : 0.0;
    double centred(Size child) => top + (controlRow - child.height) / 2;
    var leadingOffset = _edge;
    var leadingEnd = barLeft;
    var actionsInBar = false;
    var trailingStart = barRight;
    if (hasChild(_Slot.sidebarToggle)) {
      final toggle = layoutChild(
        _Slot.sidebarToggle,
        BoxConstraints.loose(size),
      );
      const inset = NativeSidebar.toggleInset;
      positionChild(
        _Slot.sidebarToggle,
        Offset(rtl ? railRight - inset - toggle.width : railLeft + inset, top),
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
    double railX(double width) => right
        ? railRight + _railGap + (48 - width) / 2
        : railLeft - _railGap - 48 + (48 - width) / 2;

    var railTop = actionsTop;
    if (rail && hasChild(_Slot.leading)) {
      final child = layoutChild(
        _Slot.leading,
        BoxConstraints.loose(Size(48, size.height)),
      );
      positionChild(_Slot.leading, Offset(railX(child.width), railTop));
      if (!child.isEmpty) railTop += child.height + _railGap;
    }

    if (hasChild(_Slot.actions)) {
      final actions = layoutChild(_Slot.actions, BoxConstraints.loose(size));
      if (rail) {
        positionChild(_Slot.actions, Offset(railX(actions.width), railTop));
      } else {
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
        actionsInBar = true;
        positionChild(
          _Slot.actions,
          Offset(x, top + math.max(0, (controlRow - actions.height) / 2)),
        );
      }
    }

    if (hasChild(_Slot.trailing)) {
      final child = layoutChild(_Slot.trailing, BoxConstraints.loose(size));
      final edge = rail && right != rtl ? 0.0 : _edge;
      final x = rtl
          ? (actionsInBar ? leadingEnd + _trailingGap : barLeft + edge)
          : (actionsInBar ? trailingStart - _trailingGap : barRight - edge) -
                child.width;
      if (rtl) {
        leadingEnd = x + child.width;
      } else {
        trailingStart = x;
      }
      actionsInBar = true;
      positionChild(_Slot.trailing, Offset(x, centred(child)));
    }

    if (!rail && hasChild(_Slot.leading)) {
      final room = rtl
          ? barRight -
                leadingOffset -
                (actionsInBar ? leadingEnd + titleGap : barLeft + _edge)
          : (actionsInBar ? trailingStart - titleGap : barRight - _edge) -
                barLeft -
                leadingOffset;
      final child = layoutChild(
        _Slot.leading,
        BoxConstraints.loose(Size(math.max(0, room), size.height)),
      );
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

    if (hasChild(_Slot.title)) {
      final centre =
          (contentLeft +
              contentPadding.left +
              contentRight -
              contentPadding.right) /
          2;
      final left = math.max(
        barLeft + titleGutter,
        leadingEnd + (leadingEnd > barLeft ? titleGap : 0),
      );
      final right = math.min(
        barRight - titleGutter,
        trailingStart - (trailingStart < barRight ? titleGap : 0),
      );
      final alignment = titleAlignment == GlassTitleAlignment.automatic
          ? GlassTitleAlignment.center
          : titleAlignment;
      if (alignment != GlassTitleAlignment.center) {
        final title = layoutChild(
          _Slot.title,
          BoxConstraints.loose(Size(math.max(0, right - left), barRow)),
        );
        positionChild(
          _Slot.title,
          Offset(
            (alignment == GlassTitleAlignment.trailing) != rtl
                ? right - title.width
                : left,
            top + (barRow - title.height) / 2,
          ),
        );
      } else {
        final half = math.min(centre - left, right - centre);
        // Keep an interactive title usable when controls cross the center.
        final width = math.max(0.0, 2 * half >= 44 ? 2 * half : right - left);
        final title = layoutChild(
          _Slot.title,
          BoxConstraints.loose(Size(width, barRow)),
        );
        final x = (centre - title.width / 2)
            .clamp(left, math.max(left, right - title.width))
            .toDouble();
        positionChild(
          _Slot.title,
          Offset(x, top + (barRow - title.height) / 2),
        );
      }
    }
    if (hasChild(_Slot.largeTitle)) {
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
          top +
              barRow +
              lead +
              largeTitleTop -
              math.min(scrollOffset.value, expandedHeight + lead),
        ),
      );
    }
    if (hasChild(_Slot.tabBar) &&
        !sideDock &&
        tabDock != GlassTabBarPlacement.top) {
      if (rail && tabDock == null) {
        final bar = layoutChild(
          _Slot.tabBar,
          BoxConstraints.loose(
            Size(size.width, math.max(0, railBottom - naturalTop)),
          ),
        );
        positionChild(
          _Slot.tabBar,
          Offset(railX(bar.width), railBottom - bar.height),
        );
      } else {
        final margin =
            dockMargin ??
            EdgeInsets.fromLTRB(
              24,
              0,
              24,
              iOS ? _bottomBarGap : viewPadding.bottom + 10,
            );
        final width = math.max(
          0.0,
          contentRight - contentLeft - margin.horizontal,
        );
        final bar = layoutChild(
          _Slot.tabBar,
          BoxConstraints.loose(
            Size(
              math.min(width, style.tabBarMaxWidth ?? 440),
              math.max(0.0, size.height - covered.top - margin.vertical),
            ),
          ),
        );
        positionChild(
          _Slot.tabBar,
          Offset(
            contentLeft +
                margin.left +
                (width - bar.width) * (dockAlignment.x + 1) / 2,
            size.height - margin.bottom - bar.height,
          ),
        );
        covered = covered.copyWith(bottom: margin.vertical + bar.height + 3);
      }
    }

    if (hasChild(_Slot.bottomBar)) {
      final margin = style.bottomBarMargin?.resolve(textDirection);
      final floor = keyboard > 0
          ? keyboard + (margin?.bottom ?? 0)
          : covered.bottom > 0
          ? covered.bottom + (margin?.bottom ?? 8)
          : margin?.bottom ?? (iOS ? _bottomBarGap : viewPadding.bottom);
      final width = math.max(
        0.0,
        contentRight - contentLeft - (margin?.horizontal ?? 0),
      );
      final bar = layoutChild(
        _Slot.bottomBar,
        BoxConstraints.loose(
          Size(
            math.min(width, style.bottomBarMaxWidth ?? double.infinity),
            math.max(
              0.0,
              size.height - floor - covered.top - (margin?.top ?? 0),
            ),
          ),
        ),
      );
      final barTop = size.height - floor - bar.height;
      final alignment = (style.bottomBarAlignment ?? Alignment.center).resolve(
        textDirection,
      );
      positionChild(
        _Slot.bottomBar,
        Offset(
          contentLeft +
              (margin?.left ?? 0) +
              (width - bar.width) * (alignment.x + 1) / 2,
          barTop,
        ),
      );
      covered = covered.copyWith(
        bottom: size.height - barTop + (margin?.top ?? 0),
      );
      if (hasChild(_Slot.bottomScrollEdge)) {
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
      minimization != old.minimization ||
      adjustsMinimizationInsets != old.adjustsMinimizationInsets ||
      onMinimizationExtent != old.onMinimizationExtent ||
      tabDock != old.tabDock ||
      style != old.style ||
      viewPadding != old.viewPadding ||
      keyboard != old.keyboard ||
      textDirection != old.textDirection ||
      iOS != old.iOS ||
      topBar != old.topBar ||
      accessoryHeight != old.accessoryHeight ||
      titleRowHeight != old.titleRowHeight ||
      controlRowHeight != old.controlRowHeight ||
      contentSpacing != old.contentSpacing ||
      titleAlignment != old.titleAlignment ||
      contentPadding != old.contentPadding ||
      expandedHeight != old.expandedHeight ||
      largeTitleTop != old.largeTitleTop ||
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
/// as slivers, the header and a return to the top on a tab reselection.
class _SliverPage extends StatefulWidget {
  const _SliverPage({
    required this.slivers,
    required this.header,
    required this.controller,
    required this.onHeaderExtent,
  });
  final List<Widget> slivers;
  final Widget? header;
  final ScrollController? controller;
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
    final header = widget.header;
    return CustomScrollView(
      controller: widget.controller,
      primary: widget.controller == null ? true : null,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPersistentHeader(pinned: true, delegate: _TopInset(padding.top)),
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

/// The bar's inset as a pinned sliver that paints nothing.
class _TopInset extends SliverPersistentHeaderDelegate {
  _TopInset(this.extent);
  final double extent;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      const SizedBox.expand();
  @override
  bool shouldRebuild(_TopInset old) => old.extent != extent;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
