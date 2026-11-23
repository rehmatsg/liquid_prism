import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/core/prism_colors.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/menu/menu.dart';
import 'package:liquid_prism/src/menu/menu_elements.dart';
import 'package:liquid_prism/src/navigation/navigation_bar_minimization.dart';
import 'package:liquid_prism/src/navigation/navigation_bar_titles.dart';
import 'package:liquid_prism/src/navigation/navigation_title_motion.dart';
import 'package:liquid_prism/src/navigation/prism_navigation_bar_style.dart';
import 'package:liquid_prism/src/navigation/prism_refresh.dart';
import 'package:liquid_prism/src/navigation/prism_scaffold_style.dart';
import 'package:liquid_prism/src/navigation/prism_scroll_edge.dart';
import 'package:liquid_prism/src/navigation/prism_scroll_edge_style.dart';
import 'package:liquid_prism/src/navigation/prism_sidebar.dart';
import 'package:liquid_prism/src/navigation/prism_system_chrome.dart';
import 'package:liquid_prism/src/navigation/prism_tab_bar.dart';
import 'package:liquid_prism/src/navigation/prism_tab_reselection.dart';
import 'package:liquid_prism/src/navigation/prism_title.dart';
import 'package:liquid_prism/src/navigation/prism_title_style.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar_content.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar_style.dart';
import 'package:liquid_prism/src/navigation/scaffold/chrome_placement.dart';
import 'package:liquid_prism/src/rendering/edge_fade.dart' show PrismEdge;
import 'package:liquid_prism/src/rendering/glass_group.dart';
import 'package:liquid_prism/src/rendering/prism_transition.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

part 'chrome_layout_delegate.dart';
part 'sliver_page.dart';

/// Adaptive navigation chrome, scroll insets, and refresh for a page.
class PrismScaffold extends StatefulWidget {
  /// Creates a page from either a body or scaffold-owned slivers.
  const new({
    super.key,
    this.body,
    this.slivers,
    this.scrollController,
    this.onRefresh,
    this.refreshController,
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
    this.tabBarPlacement = PrismTabBarPlacement.automatic,
    this.resizeToAvoidBottomInset = true,
    this.scrollEdge = true,
    this.scrollEdgeStyle,
    this.hiddenScrollEdges = const {},
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

  /// Page body; supply either this or [slivers].
  final Widget? body;

  /// Page slivers; supply either these or [body].
  final List<Widget>? slivers;

  /// Borrowed controller for the scaffold-owned scroll view.
  final ScrollController? scrollController;

  /// Refresh callback; null disables pull to refresh.
  final Future<void> Function()? onRefresh;

  /// Borrowed controller for programmatic refresh.
  final PrismRefreshController? refreshController;

  /// Additional floating bottom chrome.
  final Widget? bottomBar;

  /// Scroll notification depth observed by this scaffold.
  final int scrollDepth;

  /// Compact navigation title.
  final Widget? title;

  /// Expanded navigation title.
  final Widget? largeTitle;

  /// Header that scrolls with scaffold-owned slivers.
  final Widget? header;

  /// Secondary text below the navigation title.
  final Widget? subtitle;

  /// Whether to use navigation spacing for a presented route.
  final bool sheet;

  /// Navigation typography, layout, and minimization overrides.
  final PrismNavigationBarStyle? navigationBarStyle;

  /// Local appearance overrides merged over the component theme.
  final PrismScaffoldStyle? style;

  /// Whether body layout consumes the keyboard inset.
  final bool resizeToAvoidBottomInset;

  /// Leading navigation control or inline title content.
  final Widget? leading;

  /// Whether to infer a back button from the current route.
  final bool automaticallyImplyLeading;

  /// Toolbar content assigned to scaffold regions.
  final List<PrismToolbarContent> toolbar;

  /// Additional trailing navigation content.
  final Widget? trailing;

  List<PrismToolbarContent> get _trailingContent =>
      prismToolbarAt(toolbar, PrismToolbarPlacement.topTrailing);

  /// Fixed-height content beneath the navigation controls.
  final PreferredSizeWidget? accessory;

  /// Tab bar displayed by the scaffold or sidebar.
  final Widget? tabBar;

  /// Scaffold region that receives this content.
  final PrismChromePlacement? placement;

  /// Page background and scroll-edge fade color.
  final Color? backgroundColor;

  /// Preferred tab dock or sidebar placement.
  final PrismTabBarPlacement tabBarPlacement;

  /// Whether navigation scroll-edge effects are enabled.
  final bool scrollEdge;

  /// Default scroll-edge disappearance duration.
  static const scrollEdgeFadeDuration = Duration(milliseconds: 900);

  /// Appearance and timing overrides for scroll edges.
  final PrismScrollEdgeStyle? scrollEdgeStyle;

  /// Edges whose navigation effects are suppressed.
  final Set<PrismEdge> hiddenScrollEdges;

  /// Returns the enclosing scaffold's resolved chrome placement.
  static PrismChromePlacement? placementOf(BuildContext context) =>
      PrismChrome.maybeOf(context)?.placement;

  /// Returns the safe-area clearance for the resolved chrome placement.
  static EdgeInsets contentInsetsOf(
    BuildContext context, {
    PrismChromePlacement? placement,
  }) {
    final padding = MediaQuery.viewPaddingOf(context);
    return _ChromeLayout.withRail(
      padding,
      placement ??
          placementOf(context) ??
          prismSystemChromePlacement(padding, PrismSystemChrome.of(context)),
    );
  }

  /// Default navigation control row height.
  static const double topBarHeight = 44;

  /// Default clearance beneath the top navigation row.
  static const double topBarClearance = 12;

  @override
  State<PrismScaffold> createState() => _PrismScaffoldState();

  static PrismToolbarItem _overflow(List<PrismToolbarItem> actions) =>
      PrismToolbarItem.menu(
        icon: const _Ellipsis(),
        label: 'More',
        menu: PrismMenu(
          children: [
            for (final item in actions)
              if (item.menu case final menu?)
                PrismSubmenu(title: item.label, children: menu.children)
              else
                PrismMenuAction<void>(
                  title: item.label,
                  enabled: item.onPressed != null,
                  onSelected: () => item.onPressed?.call(),
                ),
          ],
        ),
      );
}

class _PrismScaffoldState extends State<PrismScaffold>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _sidebarHidden = false;
  late final _titleHeight = RetargetablePrismSpring(vsync: this)
    ..addListener(() {
      if (mounted && !_configuringTitleHeight) setState(() {});
    });
  double? _titleHeightTarget;
  bool _configuringTitleHeight = false;

  double _animateTitleHeight(double target, {required bool immediate}) {
    if (_titleHeightTarget != target ||
        (immediate && _titleHeight.isAnimating)) {
      _configuringTitleHeight = true;
      springPrism(
        _titleHeight,
        target,
        titleCompositionSpring.description,
        immediate: immediate || _titleHeightTarget == null,
      );
      _titleHeightTarget = target;
      _configuringTitleHeight = false;
    }
    return math.max<double>(0, _titleHeight.value);
  }

  double _headerExtent = 0;

  final _reselection = PrismTabReselection();
  late final _minimization = NavigationBarMinimization(vsync: this);

  final GlobalKey<State<StatefulWidget>> _statusBarKey = GlobalKey();
  final _refreshKey = GlobalKey<PrismRefreshLayerState>();
  final _refreshBoundary = ValueNotifier<Rect>(Rect.zero);
  final _refreshDisplacement = ValueNotifier<double>(0);
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

  late final _edgePresence =
      AnimationController(
        vsync: this,
        duration: PrismScaffold.scrollEdgeFadeDuration,
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
    SystemChromeListener.instance.island.addListener(_islandChanged);
  }

  void _islandChanged() {
    if (mounted) setState(() {});
  }

  ({double target, double height, PrismScrollEdgeStyle style}) _compactEdge(
    BuildContext context,
    MediaQueryData media, {
    required bool statusBarAboveContent,
  }) {
    final island = SystemChromeListener.instance.island.value;
    final target = !statusBarAboveContent
        ? 0.0
        : island != null
        ? island.bottom + math.max(0.0, island.top)
        : media.viewPadding.top;
    final extension = math.min(
      PrismScrollEdgeStyle.resolve(context, widget.scrollEdgeStyle).extension ??
          PrismScrollEdgeStyle.defaultExtension,
      target,
    );
    return (
      target: target,
      height: target - extension,
      style: (widget.scrollEdgeStyle ?? const PrismScrollEdgeStyle()).copyWith(
        variant: PrismScrollEdgeVariant.soft,
        extension: extension,
      ),
    );
  }

  @override
  void didUpdateWidget(PrismScaffold old) {
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

  final _scrollOffset = ValueNotifier<double>(0);

  final _overscroll = ValueNotifier<double>(0);

  final _scrollRemaining = ValueNotifier<double>(0);

  final _bottomBarExtent = ValueNotifier<double>(0);

  final _layoutOffset = ValueNotifier<double>(0);
  double _layoutCap = double.infinity;

  bool _onScroll(ScrollMetrics metrics, {bool dimensionsChanged = false}) {
    if (metrics.axis == Axis.vertical) {
      _minimization.update(metrics, dimensionsChanged: dimensionsChanged);
      _scrollOffset.value = math.max<double>(
        0,
        metrics.pixels - metrics.minScrollExtent,
      );
      _overscroll.value = math.max<double>(
        0,
        metrics.minScrollExtent - metrics.pixels,
      );
      _layoutOffset.value = math.min(_scrollOffset.value, _layoutCap);
      _scrollRemaining.value = math.max<double>(
        0,
        metrics.maxScrollExtent - metrics.pixels,
      );
      _syncTitle();
    }
    return false;
  }

  final GlobalKey<State<StatefulWidget>> _sharedTitleKey = GlobalKey();
  late final _titleMotion = Listenable.merge([_largeFade, _inlineFade]);
  late final _largeFade = RetargetablePrismSpring(vsync: this);
  late final _inlineFade = RetargetablePrismSpring(vsync: this);
  bool _collapsed = false;
  double _collapseAt = double.infinity;

  void _syncTitle() {
    final collapsed =
        _scrollOffset.value > 0 && _scrollOffset.value >= _collapseAt;
    if (collapsed == _collapsed) return;
    _collapsed = collapsed;
    final navigation =
        (PrismTheme.of(context).navigationBar ??
                const PrismNavigationBarStyle())
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

  late final _reveal = RetargetablePrismSpring(vsync: this)
    ..value = 1
    ..addStatusListener((status) {
      if (status.isCompleted || status.isDismissed) setState(() {});
    });

  void _setSidebarHidden(bool hidden) {
    setState(() => _sidebarHidden = hidden);
    springPrism(
      _reveal,
      hidden ? 0 : 1,
      NativeSidebar.spring,
      immediate: MediaQuery.disableAnimationsOf(context),
    );
  }

  @override
  void dispose() {
    SystemChromeListener.instance.island.removeListener(_islandChanged);
    _refreshDisplacement.dispose();
    _refreshBoundary.dispose();
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
    _bottomBarExtent.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _reselection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PrismSystemChrome.scopeOf(context) case final scope?) {
      return _build(context, scope.chrome, addFeatures: false);
    }
    return ValueListenableBuilder<PrismSystemChromeData?>(
      valueListenable: PrismSystemChrome.listenable,
      builder: (context, system, _) =>
          _build(context, system, addFeatures: true),
    );
  }

  Widget _build(
    BuildContext context,
    PrismSystemChromeData? system, {
    required bool addFeatures,
  }) {
    final media = MediaQuery.of(context);
    final resolved =
        widget.placement ??
        prismSystemChromePlacement(media.viewPadding, system);
    final rail = resolved.isRail;
    final explicitDock = switch (widget.tabBarPlacement) {
      PrismTabBarPlacement.bottom ||
      PrismTabBarPlacement.top ||
      PrismTabBarPlacement.leading ||
      PrismTabBarPlacement.trailing => widget.tabBarPlacement,
      _ => null,
    };
    final verticalTabs = explicitDock == null
        ? rail
        : explicitDock == PrismTabBarPlacement.leading ||
              explicitDock == PrismTabBarPlacement.trailing;
    final scaffoldStyle =
        (PrismTheme.of(context).scaffold ?? const PrismScaffoldStyle()).merge(
          widget.style,
        );
    final keyboard = media.viewInsets.bottom > 0;

    final regular = switch (system?.horizontalSizeClass) {
      PrismSizeClass.regular => true,
      PrismSizeClass.compact => false,
      null => media.size.width >= 700,
    };
    final tabBar = widget.tabBar;
    final sidebarTabs =
        widget.tabBarPlacement == PrismTabBarPlacement.sidebar &&
            regular &&
            tabBar is PrismTabBar
        ? tabBar
        : null;
    final sidebar =
        sidebarTabs != null && (!_sidebarHidden || _reveal.value > 0);
    final sidebarToggle = sidebarTabs != null && _sidebarHidden;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sidebarLeft = !(resolved == PrismChromePlacement.leftRail) && !rtl;

    final occlusions = [
      for (final region in system?.occlusions ?? const <PrismReservedRegion>[])
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
        : prismTopChromeCorner(media.size, occlusions);
    final showTabBar =
        tabBar != null &&
        sidebarTabs == null &&
        (verticalTabs || explicitDock == PrismTabBarPlacement.top || !keyboard);

    final leadingSplit = _byAxis(
      prismToolbarAt(widget.toolbar, PrismToolbarPlacement.topLeading),
      rail: rail,
    );
    final leadingContent = leadingSplit.vertical;
    final barLeading = leadingSplit.horizontal;
    final trailingSplit = _byAxis(widget._trailingContent, rail: rail);
    final barActions = trailingSplit.horizontal;
    final principal = prismToolbarAt(
      widget.toolbar,
      PrismToolbarPlacement.principal,
    );
    final leadingWidget =
        widget.leading ??
        (widget.automaticallyImplyLeading ? _impliedLeading(context) : null);
    final leading = leadingContent.isEmpty
        ? leadingWidget
        : rail
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingWidget != null) ...[
                leadingWidget,
                const SizedBox(height: _ChromeLayout._railGap),
              ],
              PrismToolbar(
                content: leadingContent,
                style: prismToolbarStyleFor(context, PrismToolbarSize.bottom),
                axis: Axis.vertical,
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingWidget != null) ...[
                leadingWidget,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: PrismToolbar(
                  content: leadingContent,
                  style: prismToolbarStyleFor(
                    context,
                    PrismToolbarSize.navigation,
                  ),
                ),
              ),
            ],
          );
    final suppliedTitle = principal.isEmpty
        ? widget.title
        : PrismToolbar(
            content: principal,
            style: prismToolbarStyleFor(context, PrismToolbarSize.navigation),
          );

    final railBottomContent = rail
        ? _byAxis([
            for (final placement in const [
              PrismToolbarPlacement.bottomLeading,
              PrismToolbarPlacement.bottom,
              PrismToolbarPlacement.bottomTrailing,
            ])
              ...prismToolbarAt(widget.toolbar, placement),
          ], rail: true).vertical
        : const <PrismToolbarContent>[];
    List<PrismToolbarContent> bottomAt(PrismToolbarPlacement placement) => [
      for (final entry in prismToolbarAt(widget.toolbar, placement))
        if (!railBottomContent.contains(entry)) entry,
    ];
    final bottomLeading = bottomAt(PrismToolbarPlacement.bottomLeading);
    final bottomCenter = bottomAt(PrismToolbarPlacement.bottom);
    final bottomTrailing = bottomAt(PrismToolbarPlacement.bottomTrailing);
    final bottomBar =
        bottomLeading.isEmpty && bottomCenter.isEmpty && bottomTrailing.isEmpty
        ? widget.bottomBar
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BottomToolbar(
                leading: bottomLeading,
                center: bottomCenter,
                trailing: bottomTrailing,
              ),
              if (widget.bottomBar != null) ...[
                const SizedBox(height: 8),
                widget.bottomBar!,
              ],
            ],
          );
    final railLeading = rail && leading != null
        ? 48 + _ChromeLayout._railGap
        : 0;
    final railBottomLength = railBottomContent.isEmpty
        ? 0.0
        : _railLength(railBottomContent) + _ChromeLayout._railGap;
    final content =
        rail &&
            !_fitsRail(
              railBottom - actionsTop - railLeading - railBottomLength,
              trailingSplit.vertical,
              tabs: showTabBar && explicitDock == null ? tabBar : null,
            )
        ? _overflowRailContent(trailingSplit.vertical)
        : trailingSplit.vertical;
    final features = addFeatures
        ? system?.displayFeatures ?? const []
        : const <DisplayFeature>[];
    final top = widget.sheet
        ? _ChromeLayout._sheetTop
        : math.max(media.viewPadding.top, _ChromeLayout._minimumTop);
    final merged =
        (PrismTheme.of(context).navigationBar ??
                const PrismNavigationBarStyle())
            .merge(widget.navigationBarStyle);
    final horizontalDuo =
        !rail &&
        (corner != null ||
            prismSystemChromePlacement(media.viewPadding, system).isRail);
    final titles = PrismNavigationTitles(
      title: suppliedTitle,
      largeTitle: rail && principal.isNotEmpty ? null : widget.largeTitle,
      style: merged,
      rail: rail,
      horizontalDuo:
          !rail &&
          (corner != null ||
              prismSystemChromePlacement(media.viewPadding, system).isRail),
      customTitle:
          suppliedTitle is PrismTitle ||
          principal.isNotEmpty ||
          widget.header != null,
    );
    final inlineTitle = titles.inRow;
    final expandedTitle = titles.expanded;
    final largeInRow = titles.largeInRow != null;
    final navigation = resolveNavigationMinimization(
      merged,
      rail: rail,

      hasTitle:
          widget.header == null &&
          (inlineTitle != null || expandedTitle != null),
    );
    final colors = PrismColors.of(context);
    final hasSubtitle = widget.subtitle != null;
    final titleStyle = prismNavigationTitleTypography(
      context,
      large: false,
      rail: rail,
      hasSubtitle: hasSubtitle,
      color: colors.label,
      override: titles.compactStyle,
    );
    final largeTitleStyle = prismNavigationTitleTypography(
      context,
      large: true,
      rail: rail && largeInRow,
      hasSubtitle: hasSubtitle,
      color: colors.label,
      override: titles.largeStyle,
    );
    final subtitleStyle = prismNavigationSubtitleTypography(
      context,
      large: false,
      color: colors.secondaryLabel,
      override: navigation.subtitleStyle,
    );
    final largeSubtitleStyle = prismNavigationSubtitleTypography(
      context,
      large: true,
      color: colors.secondaryLabel,
      override: navigation.largeSubtitleStyle,
    );
    final rowTitleStyle = largeInRow ? largeTitleStyle : titleStyle;
    final rowSubtitleStyle = largeInRow ? largeSubtitleStyle : subtitleStyle;
    final nativeDuoRow =
        (rail || horizontalDuo) &&
        inlineTitle != null &&
        inlineTitle is! PrismTitle;
    final scaler = media.textScaler;
    final titleLine =
        scaler.scale(rowTitleStyle.fontSize!) * (rowTitleStyle.height ?? 1.2);
    final barHeight =
        navigation.controlRowHeight ??
        (nativeDuoRow
            ? 58.0
            : rail
            ? 48.0
            : PrismScaffold.topBarHeight);
    final controlRowHeight = inlineTitle == null
        ? barHeight
        : math.max(
            barHeight,
            titleLine +
                8 +
                (nativeDuoRow && hasSubtitle
                    ? scaler.scale(rowSubtitleStyle.fontSize!) *
                          (rowSubtitleStyle.height ?? 1.2)
                    : 0),
          );
    final titleControlHeight =
        prismToolbarStyleFor(
          context,
          rail || corner != null
              ? PrismToolbarSize.bottom
              : PrismToolbarSize.navigation,
        ).height ??
        (rail || corner != null ? 48.0 : 44.0);
    final targetTitleRowHeight = switch (inlineTitle) {
      final PrismTitle title => math.max(
        controlRowHeight,
        PrismTitle.extentOf(
          title,
          (navigation.titleCapsule ?? const PrismTitleStyle()).merge(
            title.style,
          ),
          titleLine,
          controlHeight: titleControlHeight,
          subtitleHeight: widget.subtitle == null
              ? 0
              : scaler.scale(subtitleStyle.fontSize ?? 12) *
                        (subtitleStyle.height ?? 1.2) +
                    2,
        ),
      ),
      _ => controlRowHeight,
    };
    final titleRowHeight = math.max(
      controlRowHeight,
      _animateTitleHeight(
        targetTitleRowHeight,
        immediate: media.disableAnimations || inlineTitle is! PrismTitle,
      ),
    );
    final expandedHeight = expandedTitle == null
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
    final expandedLead = horizontalDuo ? 0.0 : largeTitleLead;
    _layoutCap = math.max(extent, expandedHeight) + expandedLead + 1;
    _layoutOffset.value = math.min(_scrollOffset.value, _layoutCap);
    final revealExtent =
        PrismScrollEdgeStyle.resolve(
          context,
          widget.scrollEdgeStyle,
        ).revealExtent ??
        PrismScrollEdgeStyle.defaultRevealExtent;
    final swaps = expandedTitle != null || widget.header != null;
    final hidesOnScrollDown =
        navigation.minimizationBehavior ==
        PrismMinimizationBehavior.onScrollDown;
    final scrollsAway =
        hidesOnScrollDown &&
        navigation.minimizationRestoration ==
            PrismMinimizationRestoration.atScrollEdge;
    final minimizes = switch (navigation.minimizationBehavior) {
      PrismMinimizationBehavior.onScrollDown ||
      PrismMinimizationBehavior.onScrollUp => true,
      _ => false,
    };
    final edges = widget.scrollEdge || !_edgePresence.isDismissed;

    final fullEdge =
        widget.accessory != null ||
        inlineTitle != null ||
        expandedTitle != null;
    final compactEdge = _compactEdge(
      context,
      media,
      statusBarAboveContent:
          !widget.sheet &&
          corner == null &&
          !(system?.hasVerticalBar ?? (rail && media.viewPadding.top == 0)),
    );

    final compactWhenHidden =
        hidesOnScrollDown && widget.accessory == null && compactEdge.target > 0;
    double edgePresence() =>
        widget.accessory == null && fullEdge && !compactWhenHidden
        ? 1 - _minimization.progress.value
        : 1;
    final fullEdgeStyle = PrismScrollEdgeStyle.resolve(
      context,
      widget.scrollEdgeStyle,
    );
    double edgeScrollOffset(bool revealed) {
      if (hidesOnScrollDown &&
          widget.accessory == null &&
          fullEdge &&
          !compactWhenHidden &&
          !revealed) {
        return _scrollOffset.value - _minimization.distance;
      }
      return _scrollOffset.value;
    }

    final collapseAt = widget.header != null
        ? (_headerExtent > 0 ? _headerExtent : double.infinity)
        : expandedTitle == null
        ? double.infinity
        : extent;
    if (_collapseAt != collapseAt) {
      _collapseAt = collapseAt;
      _collapsed =
          _scrollOffset.value > 0 && _scrollOffset.value >= _collapseAt;
      _largeFade.value = _inlineFade.value = _collapsed ? 1 : 0;
    }
    final sharedTitle =
        expandedTitle != null && identical(expandedTitle, inlineTitle);
    Widget titleSlot(Widget child, {required bool large}) => sharedTitle
        ? prismNavigationTitleSlot(
            motion: _titleMotion,
            visible: () => large != _collapsed,
            child: child,
          )
        : child;
    Widget titleContent(Widget child) =>
        sharedTitle ? KeyedSubtree(key: _sharedTitleKey, child: child) : child;
    final titleBlur = PrismTheme.of(context).transition?.contentBlur ?? 4;
    Widget header(Widget child, TextStyle style, {required bool large}) {
      final Widget text = Semantics(
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
              (hidesOnScrollDown ? 1.0 : 1 - _minimization.progress.value) *
              (eligible ? 1 : 0);
          final moved = large || !swaps
              ? child!
              : Transform.translate(
                  offset: Offset(0, 15 * (1 - inline)),
                  child: child,
                );
          final presentation = !large && inlineTitle is PrismTitle
              ? PrismPresence(
                  progress: AlwaysStoppedAnimation(opacity),
                  contentBlur: titleBlur,
                  materialize: !media.disableAnimations,
                  child: moved,
                )
              : PrismContentPresence(
                  presence: opacity,
                  blur: large ? 0 : titleBlur,
                  child: moved,
                );
          return ExcludeSemantics(
            excluding: !visible,
            child: ExcludeFocus(
              excluding: !visible,
              child: IgnorePointer(ignoring: !visible, child: presentation),
            ),
          );
        },
        child: text,
      );
    }

    final topBar =
        inlineTitle != null ||
        expandedTitle != null ||
        (!rail && leading != null) ||
        widget.trailing != null ||
        sidebarTabs != null ||
        (!rail && prismToolbarHasContent(content)) ||
        prismToolbarHasContent(barLeading) ||
        prismToolbarHasContent(barActions);

    final hasChrome =
        inlineTitle != null ||
        expandedTitle != null ||
        leading != null ||
        widget.trailing != null ||
        widget.accessory != null ||
        prismToolbarHasContent(content) ||
        prismToolbarHasContent(barLeading) ||
        prismToolbarHasContent(barActions);
    _minimization.configure(
      navigation,
      collapseExtent: expandedTitle == null ? 0 : extent + expandedLead,
    );

    final titleAlignment = prismDefaultTitleAlignment(
      requested: largeInRow && widget.largeTitle != null
          ? navigation.largeTitleAlignment ?? navigation.titleAlignment
          : navigation.titleAlignment,
      glassTitle: inlineTitle is PrismTitle,
      actions:
          prismToolbarItemCount(widget._trailingContent) +
          (widget.trailing != null ? 1 : 0),
      foldedRail: rail && !regular,
      sheet: widget.sheet,
    );
    final layout = CustomMultiChildLayout(
      delegate: _ChromeLayout(
        refreshBoundary: _refreshBoundary,
        bottomBarExtent: _bottomBarExtent,
        placement: resolved,
        minimization: _minimization.progress,
        onMinimizationExtent: _minimization.setExtent,
        adjustsMinimizationInsets:
            navigation.minimizationSafeArea ==
            PrismMinimizationSafeArea.enabled,
        slidesOff: hidesOnScrollDown,
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
            (nativeDuoRow && widget.accessory == null
                ? 0
                : rail || sidebar || corner != null
                ? 16
                : PrismScaffold.topBarClearance),
        titleAlignment: titleAlignment,
        contentPadding: (navigation.contentPadding ?? EdgeInsets.zero).resolve(
          Directionality.of(context),
        ),
        expandedHeight: expandedHeight,
        expandedLead: expandedLead,
        largeTitleTop: widget.subtitle == null ? 3.67 : 6.67,
        collapseExtent: extent,
        scrollOffset: _layoutOffset,
        titleGutter: navigation.gutter ?? 16,
        titleGap: navigation.controlGap ?? 12,
        actionsTop: actionsTop,
        railBottom: railBottom,
        sheet: widget.sheet,
        fullEdge: fullEdge,
        compactEdgeHeight: compactEdge.height,
        compactWhenHidden: compactWhenHidden,
        revealed: _minimization.revealed,
        edgeFrame:
            widget.accessory == null &&
                PrismScrollEdgeStyle.resolve(
                      context,
                      widget.scrollEdgeStyle,
                    ).variant ==
                    PrismScrollEdgeVariant.hard
            ? 10
            : 0,
        edgeInset: topEdgeInset(
          inlineTitle,
          bareRows: widget.accessory != null || expandedTitle != null,
          style: PrismScrollEdgeStyle.resolve(context, widget.scrollEdgeStyle),
        ),
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
              child: PrismChrome(
                placement: resolved,
                child: _InsetBody(
                  consumeKeyboard: widget.resizeToAvoidBottomInset,
                  ownsScrollView: widget.slivers != null,
                  media: features.isEmpty
                      ? media
                      : media.copyWith(
                          displayFeatures: [
                            ...media.displayFeatures,
                            ...features,
                          ],
                        ),

                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: (n) =>
                        n.depth == widget.scrollDepth &&
                        _onScroll(n.metrics, dimensionsChanged: true),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.depth != widget.scrollDepth) return false;
                        _refreshKey.currentState?.handleScroll(n);
                        return _onScroll(n.metrics);
                      },
                      child: ValueListenableBuilder<double>(
                        valueListenable: _refreshDisplacement,
                        builder: (context, displacement, child) =>
                            Transform.translate(
                              offset: Offset(0, displacement),
                              child: child,
                            ),
                        child: _content(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (edges &&
                !widget.hiddenScrollEdges.contains(PrismEdge.top) &&
                (fullEdge || (compactEdge.target > 0 && hasChrome)))
              LayoutId(
                id: _Slot.scrollEdge,
                child: PrismGroupMembers(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _minimization.revealed,
                    builder: (context, revealed, _) =>
                        ScrollEdgeProgressBuilder(
                          listenable: Listenable.merge([
                            _scrollOffset,
                            _edgeStrength,
                            _minimization.progress,
                          ]),
                          progress: () =>
                              edgePresence() *
                              _edgeStrength.value *
                              PrismScrollEdge.progressFor(
                                edgeScrollOffset(revealed),
                                revealExtent: revealExtent,
                              ),
                          builder: (context, progress) => PrismScrollEdge(
                            progress: progress,
                            color: widget.backgroundColor,
                            style: !fullEdge || (compactWhenHidden && !revealed)
                                ? compactEdge.style
                                : navigationScrollEdgeStyle(
                                    fullEdgeStyle,
                                    edgePresence(),
                                  ),
                          ),
                        ),
                  ),
                ),
              ),
            if (edges &&
                bottomBar != null &&
                !widget.hiddenScrollEdges.contains(PrismEdge.bottom))
              LayoutId(
                id: _Slot.bottomScrollEdge,
                child: PrismGroupMembers(
                  child: IgnorePointer(
                    child: ScrollEdgeProgressBuilder(
                      listenable: Listenable.merge([
                        _scrollRemaining,
                        _edgeStrength,
                        _bottomBarExtent,
                      ]),
                      progress: () =>
                          _edgeStrength.value *
                          (_bottomBarExtent.value / revealExtent).clamp(
                            0.0,
                            1.0,
                          ) *
                          PrismScrollEdge.progressFor(
                            _scrollRemaining.value,
                            revealExtent: revealExtent,
                          ),
                      builder: (context, progress) => PrismScrollEdge(
                        edge: PrismEdge.bottom,
                        progress: progress,
                        color: widget.backgroundColor,
                        style:
                            (widget.scrollEdgeStyle ??
                                    const PrismScrollEdgeStyle())
                                .copyWith(variant: PrismScrollEdgeVariant.soft),
                      ),
                    ),
                  ),
                ),
              ),
            if (bottomBar case final bottomBar?)
              LayoutId(
                id: _Slot.bottomBar,
                child: PrismGroupMembers(child: bottomBar),
              ),
            if (inlineTitle case final title? when !(scrollsAway && swaps))
              LayoutId(
                id: _Slot.title,
                child: largeInRow && !minimizes
                    ? ValueListenableBuilder<double>(
                        valueListenable: _scrollOffset,
                        builder: (context, offset, _) =>
                            prismNavigationPinnedTitle(
                              title: title,
                              compact: titles.compact ?? title,
                              subtitle: widget.subtitle,
                              largeStyle: largeTitleStyle,
                              compactStyle: titleStyle,
                              largeSubtitleStyle: largeSubtitleStyle,
                              compactSubtitleStyle: subtitleStyle,
                              alignment: titleAlignment,
                              collapsed:
                                  offset >= (navigation.revealExtent ?? 52) &&
                                  offset > 0,
                              controlHeight: titleControlHeight,
                              decorate: (child, style) =>
                                  header(child, style, large: false),
                            ),
                      )
                    : titleSlot(
                        header(
                          prismTitled(
                            titleContent(title),
                            widget.subtitle,
                            rowSubtitleStyle,
                            large: false,
                            controlHeight: titleControlHeight,
                            alignment:
                                titleAlignment == PrismTitleAlignment.automatic
                                ? PrismTitleAlignment.center
                                : titleAlignment,
                          ),
                          rowTitleStyle,
                          large: false,
                        ),
                        large: false,
                      ),
              ),
            if (expandedTitle case final title?)
              LayoutId(
                id: _Slot.largeTitle,
                child: titleSlot(
                  ValueListenableBuilder<double>(
                    valueListenable: _overscroll,
                    builder: (context, overscroll, child) =>
                        Transform.translate(
                          offset: Offset(0, overscroll),
                          child: child,
                        ),
                    child: Align(
                      alignment: prismTitleBoxAlignment(
                        navigation.largeTitleAlignment ??
                            PrismTitleAlignment.leading,
                      ),
                      child: header(
                        prismTitled(
                          titleContent(title),
                          widget.subtitle,
                          largeSubtitleStyle,
                          large: true,
                          alignment:
                              navigation.largeTitleAlignment ??
                              PrismTitleAlignment.leading,
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
                  large: true,
                ),
              ),
            if (widget.accessory case final accessory?)
              LayoutId(
                id: _Slot.accessory,
                child: PrismGroupMembers(child: accessory),
              ),
            if (sidebarTabs != null)
              LayoutId(
                id: _Slot.sidebarToggle,
                child: PrismVisibility(
                  visible: sidebarToggle,
                  transition: sidebarToggle
                      ? PrismTransition.materialize
                      : PrismTransition.identity,
                  style: PrismTransitionStyle(
                    enterSpring: PrismSpring.physical(NativeSidebar.spring),
                  ),
                  child: Builder(
                    builder: (context) => Transform.scale(
                      scale:
                          NativeSidebar.toggleEntryScale -
                          (NativeSidebar.toggleEntryScale - 1) *
                              PrismPresence.of(context),
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
                    child: PrismSidebar(
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
                child: PrismGroupMembers(child: leading),
              ),
            if (content.isNotEmpty)
              LayoutId(
                id: _Slot.actions,
                child: PrismGroupMembers(
                  child: PrismToolbar(
                    content: content,
                    style: prismToolbarStyleFor(
                      context,
                      rail || corner != null
                          ? PrismToolbarSize.bottom
                          : PrismToolbarSize.navigation,
                    ),
                    axis: rail ? Axis.vertical : Axis.horizontal,
                  ),
                ),
              ),
            if (prismToolbarHasContent(barLeading))
              LayoutId(
                id: _Slot.barLeading,
                child: PrismGroupMembers(
                  child: PrismToolbar(
                    content: barLeading,
                    style: prismToolbarStyleFor(
                      context,
                      PrismToolbarSize.navigation,
                    ),
                    axis: Axis.horizontal,
                  ),
                ),
              ),
            if (prismToolbarHasContent(barActions))
              LayoutId(
                id: _Slot.barActions,
                child: PrismGroupMembers(
                  child: PrismToolbar(
                    content: barActions,
                    style: prismToolbarStyleFor(
                      context,
                      PrismToolbarSize.navigation,
                    ),
                    axis: Axis.horizontal,
                  ),
                ),
              ),
            if (railBottomContent.isNotEmpty)
              LayoutId(
                id: _Slot.railBottom,
                child: PrismGroupMembers(
                  child: PrismToolbar(
                    content: railBottomContent,
                    style: prismToolbarStyleFor(
                      context,
                      PrismToolbarSize.bottom,
                    ),
                    axis: Axis.vertical,
                  ),
                ),
              ),
            if (widget.trailing case final trailing?)
              LayoutId(
                id: _Slot.trailing,
                child: PrismGroupMembers(child: trailing),
              ),
            if (showTabBar)
              LayoutId(
                id: _Slot.tabBar,
                child: PrismGroupMembers(
                  child: PrismChrome(
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
              _Slot.barLeading ||
              _Slot.barActions ||
              _Slot.trailing => true,
              _Slot.leading || _Slot.actions => !rail,
              _Slot.tabBar => explicitDock == PrismTabBarPlacement.top,
              _ => false,
            };
            return moves
                ? LayoutId(
                    id: child.id,
                    child: NavigationBarPresence(
                      progress: _minimization.progress,
                      fades: !hidesOnScrollDown,
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
      child: PrismGroupHost(
        child: Stack(
          children: [
            Positioned.fill(child: layout),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: math.max<double>(1, media.viewPadding.top),
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

    hosted = Stack(
      children: [
        Positioned.fill(child: hosted),
        Positioned.fill(
          child: PrismRefreshLayer(
            key: _refreshKey,
            onRefresh: widget.onRefresh,
            controller: widget.refreshController,
            belowHeader:
                !swaps && (inlineTitle != null || widget.accessory != null),
            headerBoundary: _refreshBoundary,
            contentDisplacement: _refreshDisplacement,
            sideInsets: EdgeInsets.only(
              left: padding.left,
              right: padding.right,
            ),

            barCenter: rail || corner != null
                ? null
                : top + controlRowHeight / 2,
            sensorHousing: !widget.sheet,
          ),
        ),
      ],
    );
    if (widget.tabBar != null) {
      hosted = PrismTabReselection.scope(
        reselection: _reselection,
        child: hosted,
      );
    }
    return switch (widget.backgroundColor) {
      final color? => ColoredBox(color: color, child: hosted),
      null => hosted,
    };
  }

  Widget? _impliedLeading(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null || !route.canPop) return null;
    return PrismBackButton(close: route is PageRoute && route.fullscreenDialog);
  }

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

  static ({
    List<PrismToolbarContent> vertical,
    List<PrismToolbarContent> horizontal,
  })
  _byAxis(List<PrismToolbarContent> content, {required bool rail}) => rail
      ? prismToolbarSplitByAxis(content)
      : (vertical: content, horizontal: const []);

  List<PrismToolbarContent> _overflowRailContent(
    List<PrismToolbarContent> content,
  ) {
    final actions = [
      for (final entry in prismToolbarSegments(content))
        if (entry is PrismToolbarGroup)
          for (final item in entry.items)
            if (item.child == null) item,
    ];
    if (actions.length < 2) return content;
    final result = <PrismToolbarContent>[];
    var inserted = false;
    for (final entry in prismToolbarSegments(content)) {
      if (entry is! PrismToolbarGroup) {
        result.add(entry);
        continue;
      }
      if (!inserted && entry.items.any((item) => item.child == null)) {
        result.add(PrismScaffold._overflow(actions));
        inserted = true;
      }
      final custom = entry.items.where((item) => item.child != null).toList();
      if (custom.isNotEmpty) {
        result.add(
          PrismToolbarGroup(key: entry.key, style: entry.style, items: custom),
        );
      }
    }
    return result;
  }

  bool _fitsRail(
    double height,
    List<PrismToolbarContent> content, {
    required Widget? tabs,
  }) {
    final tabsLength = switch (tabs) {
      PrismTabBar(:final tabs) => 50.0 * tabs.length + 12,
      _ => 0.0,
    };
    return _railLength(content) + _ChromeLayout._railGap + tabsLength <= height;
  }

  double _railLength(List<PrismToolbarContent> content) {
    final theme = PrismTheme.of(context).toolbar ?? const PrismToolbarStyle();
    var length = 0.0;
    var gap = 0.0;
    for (final entry in prismToolbarSegments(content)) {
      if (entry is PrismToolbarSpacer) {
        length += entry.extent ?? 0;
        gap = 0;
      } else if (entry is PrismToolbarItem) {
        length += gap + (entry.width ?? 48);
        gap = theme.groupSpacing ?? 8;
      } else if (entry is PrismToolbarGroup && entry.items.isNotEmpty) {
        final style = theme.merge(entry.style);
        final extent = style.height ?? 48;
        final inset = style.inset ?? 5;
        length +=
            gap + inset * 2 + (entry.items.length - 1) * (style.spacing ?? 14);
        for (final item in entry.items) {
          length += prismToolbarItemExtent(
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
    return length;
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
  barLeading,
  barActions,
  railBottom,
  trailing,
  tabBar,
}

/// Default spacing above the expanded large title.
const double largeTitleLead = 10;

/// Resolves the top scroll edge inset for glass title chrome.
double topEdgeInset(
  Widget? inlineTitle, {
  required bool bareRows,
  required PrismScrollEdgeStyle style,
}) {
  final glass =
      inlineTitle is PrismTitle ||
      (inlineTitle is PrismToolbar && inlineTitle.items == null);
  if (!glass || bareRows) return 0;
  return style.extension ??
      (style.variant == PrismScrollEdgeVariant.hard
          ? 0
          : PrismScrollEdgeStyle.defaultExtension);
}
