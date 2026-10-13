import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'glass_transition.dart';
import 'menu/menu.dart';
import 'menu/menu_elements.dart';
import 'motion.dart';
import 'scroll_edge.dart';
import 'sidebar.dart';
import 'system_chrome.dart';
import 'tab_bar.dart';
import 'toolbar.dart';

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
    required this.body,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions = const [],
    this.tabBar,
    this.placement,
    this.backgroundColor,
    this.tabBarPlacement = GlassTabBarPlacement.automatic,
    this.scrollEdge = true,
    this.scrollEdgeStyle,
  });

  /// Full-window content. Usually a scroll view.
  final Widget body;

  /// A top-leading control, such as a back button. It stays in the top bar in
  /// every placement. Null implies one; see [automaticallyImplyLeading].
  final Widget? leading;

  /// Whether a null [leading] becomes a [LiquidPrismBackButton] when the
  /// route can pop: a back chevron, or a close mark on a fullscreen dialog.
  final bool automaticallyImplyLeading;

  /// Actions sharing one glass capsule: top trailing, or atop the rail.
  final List<GlassToolbarItem> actions;

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
    with SingleTickerProviderStateMixin {
  bool _sidebarHidden = false;

  /// How far the body's outermost scroll view is scrolled past its start.
  final _scrollOffset = ValueNotifier<double>(0);

  bool _onScroll(ScrollMetrics metrics) {
    if (metrics.axis == Axis.vertical) {
      _scrollOffset.value = math.max(
        0,
        metrics.pixels - metrics.minScrollExtent,
      );
    }
    return false;
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
    _scrollOffset.dispose();
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
    final items =
        rail &&
            !_fitsRail(
              railBottom - actionsTop,
              tabs: showTabBar ? tabBar : null,
            )
        ? [LiquidPrismScaffold._overflow(widget.actions)]
        : widget.actions;
    final features = addFeatures
        ? system?.displayFeatures ?? const []
        : const <DisplayFeature>[];
    final top = math.max(media.viewPadding.top, _ChromeLayout._minimumTop);
    final leading =
        widget.leading ??
        (widget.automaticallyImplyLeading ? _impliedLeading(context) : null);
    final topBar =
        leading != null ||
        // Native keeps the bar row with the sidebar shown or hidden, so
        // content does not jump when the toggle moves into it.
        sidebarTabs != null ||
        (!rail && widget.actions.isNotEmpty);
    final layout = CustomMultiChildLayout(
      delegate: _ChromeLayout(
        placement: resolved,
        viewPadding: padding,
        keyboard: media.viewInsets.bottom,
        textDirection: Directionality.of(context),
        iOS: defaultTargetPlatform == TargetPlatform.iOS,
        topBar: topBar,
        actionsTop: actionsTop,
        railBottom: railBottom,
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
              media: features.isEmpty
                  ? media
                  : media.copyWith(
                      displayFeatures: [...media.displayFeatures, ...features],
                    ),
              child: widget.scrollEdge && topBar
                  ? NotificationListener<ScrollMetricsNotification>(
                      onNotification: (n) =>
                          n.depth == 0 && _onScroll(n.metrics),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) =>
                            n.depth == 0 && _onScroll(n.metrics),
                        child: widget.body,
                      ),
                    )
                  : widget.body,
            ),
          ),
        ),
        // Behind the bar's controls, over the body: it shares their captures
        // and is cut out of their contours (see LiquidPrismEdgeBlur).
        if (widget.scrollEdge && topBar)
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
        if (items.isNotEmpty)
          LayoutId(
            id: _Slot.actions,
            child: GlassGroupMembers(
              child: LiquidPrismToolbarGroup(
                items: items,
                // Measured: a 44 pt navigation capsule in the top bar, a 48 pt
                // wide column in the rail.
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
    final hosted = GlassGroupHost(child: layout);
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

  /// Whether the actions and [tabs] both fit a rail of [height] below the
  /// actions' top, with the measured gaps.
  bool _fitsRail(double height, {required Widget? tabs}) {
    final actions = widget.actions;
    if (actions.length < 2) return true;
    final actionsLength =
        actions.fold<double>(0, (sum, item) => sum + item.width) +
        14 * (actions.length - 1) +
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
  scrollEdge,
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
  const _InsetBody({required this.media, required this.child});
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
    required this.actionsTop,
    required this.railBottom,
    required this.corner,
    required this.sidebar,
    required this.reveal,
  }) : super(relayout: reveal);

  final GlassChromePlacement placement;
  final EdgeInsets viewPadding;
  final double keyboard, actionsTop, railBottom;

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
    final top = corner == null
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
    var covered = EdgeInsets.only(
      top: topBar
          ? top +
                LiquidPrismScaffold.topBarHeight +
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
      // The bar's box, status bar included; the effect reaches below it.
      layoutChild(
        _Slot.scrollEdge,
        BoxConstraints.tight(
          Size(
            math.max(0, contentRight - contentLeft),
            top + LiquidPrismScaffold.topBarHeight,
          ),
        ),
      );
      positionChild(_Slot.scrollEdge, Offset(contentLeft, 0));
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

    double centred(Size child) =>
        top + (LiquidPrismScaffold.topBarHeight - child.height) / 2;
    // The show-sidebar toggle holds its measured place while the body
    // reflows beneath the panel; the leading widget follows the body.
    var leadingOffset = _edge;
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
    }
    if (hasChild(_Slot.leading)) {
      final child = layoutChild(_Slot.leading, BoxConstraints.loose(size));
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
        positionChild(
          _Slot.actions,
          Offset(
            x,
            top +
                math.max(
                  0,
                  (LiquidPrismScaffold.topBarHeight - actions.height) / 2,
                ),
          ),
        );
      }
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
      actionsTop != old.actionsTop ||
      railBottom != old.railBottom ||
      corner != old.corner ||
      sidebar != old.sidebar ||
      reveal != old.reveal;
}
