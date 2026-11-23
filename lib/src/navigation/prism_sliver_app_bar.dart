import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/core/prism_colors.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/navigation/navigation_bar_minimization.dart';
import 'package:liquid_prism/src/navigation/navigation_bar_titles.dart';
import 'package:liquid_prism/src/navigation/navigation_title_motion.dart';
import 'package:liquid_prism/src/navigation/prism_navigation_bar_style.dart';
import 'package:liquid_prism/src/navigation/prism_scroll_edge.dart';
import 'package:liquid_prism/src/navigation/prism_scroll_edge_style.dart';
import 'package:liquid_prism/src/navigation/prism_system_chrome.dart';
import 'package:liquid_prism/src/navigation/prism_title.dart';
import 'package:liquid_prism/src/navigation/prism_title_style.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar_content.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar_style.dart';
import 'package:liquid_prism/src/navigation/scaffold/chrome_placement.dart';
import 'package:liquid_prism/src/navigation/scaffold/prism_scaffold.dart';
import 'package:liquid_prism/src/rendering/glass_group.dart';
import 'package:liquid_prism/src/rendering/prism_transition.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Scroll-aware navigation chrome for a custom sliver scroll view.
class PrismSliverAppBar extends StatelessWidget {
  /// Creates adaptive navigation chrome within a sliver scroll view.
  const new({
    super.key,
    this.title,
    this.largeTitle,
    this.subtitle,
    this.sheet = false,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.toolbar = const [],
    this.trailing,
    this.accessory,
    this.backgroundColor,
    this.scrollEdge = true,
    this.scrollEdgeStyle,
    this.navigationBarStyle,
  });

  /// Compact navigation title.
  final Widget? title;

  /// Expanded navigation title.
  final Widget? largeTitle;

  /// Secondary text below the navigation title.
  final Widget? subtitle;

  /// Whether to use navigation spacing for a presented route.
  final bool sheet;

  /// Leading navigation control or inline title content.
  final Widget? leading;

  /// Whether to infer a back button from the current route.
  final bool automaticallyImplyLeading;

  /// Toolbar content assigned to scaffold regions.
  final List<PrismToolbarContent> toolbar;

  /// Additional trailing navigation content.
  final Widget? trailing;

  /// Fixed-height content beneath the navigation controls.
  final PreferredSizeWidget? accessory;

  /// Page background and scroll-edge fade color.
  final Color? backgroundColor;

  /// Whether navigation scroll-edge effects are enabled.
  final bool scrollEdge;

  /// Appearance and timing overrides for scroll edges.
  final PrismScrollEdgeStyle? scrollEdgeStyle;

  /// Navigation typography, layout, and minimization overrides.
  final PrismNavigationBarStyle? navigationBarStyle;

  @override
  Widget build(BuildContext context) {
    if (PrismSystemChrome.scopeOf(context) case final scope?) {
      return _build(context, scope.chrome);
    }
    return ValueListenableBuilder<PrismSystemChromeData?>(
      valueListenable: PrismSystemChrome.listenable,
      builder: (context, system, _) => _build(context, system),
    );
  }

  Widget _build(BuildContext context, PrismSystemChromeData? system) {
    final media = MediaQuery.of(context);
    final systemPlacement = prismSystemChromePlacement(
      media.viewPadding,
      system,
    );
    final rail = (PrismScaffold.placementOf(context) ?? systemPlacement).isRail;
    final merged =
        (PrismTheme.of(context).navigationBar ??
                const PrismNavigationBarStyle())
            .merge(navigationBarStyle);
    final principal = prismToolbarAt(toolbar, PrismToolbarPlacement.principal);
    final suppliedTitle = principal.isEmpty
        ? title
        : PrismToolbar(
            content: principal,
            style: prismToolbarStyleFor(context, PrismToolbarSize.navigation),
          );
    final corner = prismTopChromeCorner(media.size, [
      for (final region in system?.occlusions ?? const <PrismReservedRegion>[])
        if (region.active) region.frame,
    ]);
    final horizontalDuo = !rail && (systemPlacement.isRail || corner != null);
    final titles = PrismNavigationTitles(
      title: suppliedTitle,
      largeTitle: rail && principal.isNotEmpty ? null : largeTitle,
      style: merged,
      rail: rail,
      horizontalDuo: horizontalDuo,
      customTitle: suppliedTitle is PrismTitle || principal.isNotEmpty,
    );
    final inlineTitle = titles.inRow;
    final expandedTitle = titles.expanded;
    final largeInRow = titles.largeInRow != null;
    final navigation = resolveNavigationMinimization(
      merged,
      rail: rail,
      hasTitle: inlineTitle != null || expandedTitle != null,
    );
    final colors = PrismColors.of(context);
    final titleStyle = prismNavigationTitleTypography(
      context,
      large: false,
      rail: rail,
      hasSubtitle: subtitle != null,
      color: colors.label,
      override: titles.compactStyle,
    );
    final largeTitleStyle = prismNavigationTitleTypography(
      context,
      large: true,
      rail: rail && largeInRow,
      hasSubtitle: subtitle != null,
      color: colors.label,
      override: titles.largeStyle,
    );
    final nativeDuoRow =
        (rail || horizontalDuo) &&
        inlineTitle != null &&
        inlineTitle is! PrismTitle;
    final scaler = media.textScaler;
    final insets = (navigation.contentPadding ?? EdgeInsets.zero).resolve(
      Directionality.of(context),
    );
    final top =
        (sheet
            ? 16.0
            : corner == null || rail
            ? math.max(media.padding.top, 24)
            : 24.0) +
        insets.top;
    final bottom = prismBottomToolbarContent(toolbar);
    final accessoryHeight =
        (accessory?.preferredSize.height ?? 0) + (bottom.isEmpty ? 0 : 48);
    final barAccessory = bottom.isEmpty
        ? accessory
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accessory != null)
                SizedBox(
                  height: accessory!.preferredSize.height,
                  child: accessory,
                ),
              SizedBox(height: 48, child: PrismToolbar(content: bottom)),
            ],
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
    final rowHeight =
        navigation.controlRowHeight ??
        (nativeDuoRow ? 58.0 : PrismScaffold.topBarHeight);
    final titleLine =
        scaler.scale(rowTitleStyle.fontSize!) * (rowTitleStyle.height ?? 1.2);
    final subtitleLine = subtitle == null
        ? 0.0
        : scaler.scale(rowSubtitleStyle.fontSize!) *
              (rowSubtitleStyle.height ?? 1.2);
    final capsuleHeight = inlineTitle is PrismTitle
        ? PrismTitle.extentOf(
            inlineTitle,
            (navigation.titleCapsule ?? const PrismTitleStyle()).merge(
              inlineTitle.style,
            ),
            titleLine,
            controlHeight:
                prismToolbarStyleFor(
                  context,
                  PrismToolbarSize.navigation,
                ).height ??
                44,
            subtitleHeight: subtitle == null ? 0 : subtitleLine + 2,
          )
        : 0.0;
    final barRow =
        (inlineTitle == null
            ? rowHeight
            : math.max(
                math.max(rowHeight, capsuleHeight),
                titleLine + 8 + (nativeDuoRow ? subtitleLine : 0),
              )) +
        insets.bottom;
    final largeRow = expandedTitle == null
        ? 0.0
        : navigation.largeTitleExtent ??
              scaler.scale(largeTitleStyle.fontSize ?? 34) *
                      (largeTitleStyle.height ?? 1.2) +
                  11.33 +
                  (subtitle == null
                      ? 0
                      : scaler.scale(largeSubtitleStyle.fontSize ?? 11) * 1.2 +
                            6.13);
    final lead = expandedTitle == null || horizontalDuo ? 0.0 : largeTitleLead;
    final clearance =
        navigation.contentSpacing ??
        (nativeDuoRow
            ? (accessoryHeight == 0 ? 0.0 : 16.0)
            : lead > 0 && accessoryHeight == 0
            ? lead
            : PrismScaffold.topBarClearance);
    final minExtent = top + barRow + accessoryHeight + clearance;
    final maxExtent = expandedTitle == null
        ? minExtent
        : top +
              barRow +
              lead +
              largeRow +
              accessoryHeight +
              (accessoryHeight == 0 ? 0 : clearance);
    final route = ModalRoute.of(context);
    final impliedLeading =
        leading ??
        (automaticallyImplyLeading && route != null && route.canPop
            ? PrismBackButton(
                close: route is PageRoute && route.fullscreenDialog,
              )
            : null);
    final leadingContent = prismToolbarAt(
      toolbar,
      PrismToolbarPlacement.topLeading,
    );
    final barLeading = leadingContent.isEmpty
        ? impliedLeading
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (impliedLeading != null) ...[
                impliedLeading,
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
    final minimizingExtent = barRow + (accessoryHeight == 0 ? clearance : 0);

    final travel =
        minimizingExtent +
        (navigation.minimizationBehavior ==
                PrismMinimizationBehavior.onScrollDown
            ? top
            : 0);
    return _MinimizingSliverBar(
      style: navigation,
      collapseExtent: expandedTitle == null ? 0 : largeRow + lead,
      extent: travel,
      builder: (minimization, revealed) {
        final reduction =
            navigation.minimizationSafeArea == PrismMinimizationSafeArea.enabled
            ? math.min(travel * minimization.value, minimizingExtent)
            : 0.0;
        return SliverPersistentHeader(
          pinned: true,
          delegate: _SliverBarDelegate(
            bar: this,
            minimization: minimization,
            revealed: revealed,
            leading: barLeading,
            inlineTitle: inlineTitle,
            expandedTitle: expandedTitle,
            compactTitle: titles.compact,
            largeInRow: largeInRow,
            rail: rail,
            accessory: barAccessory,
            insets: insets,
            titleStyle: titleStyle,
            largeTitleStyle: largeTitleStyle,
            subtitleStyle: subtitleStyle,
            largeSubtitleStyle: largeSubtitleStyle,
            navigation: navigation,
            top: top,
            barRow: barRow,
            clearance: clearance,
            largeRow: largeRow,
            lead: lead,
            largeTitleTop: subtitle == null ? 3.67 : 6.67,
            accessoryHeight: accessoryHeight,
            minExtent: minExtent - reduction,

            maxExtent: maxExtent,
            titleCollapseExtent: maxExtent - minExtent,
          ),
        );
      },
    );
  }
}

class _MinimizingSliverBar extends StatefulWidget {
  const new({
    required this.style,
    required this.collapseExtent,
    required this.extent,
    required this.builder,
  });
  final PrismNavigationBarStyle style;
  final double collapseExtent;
  final double extent;
  final Widget Function(Animation<double> minimization, bool revealed) builder;

  @override
  State<_MinimizingSliverBar> createState() => _MinimizingSliverBarState();
}

class _MinimizingSliverBarState extends State<_MinimizingSliverBar>
    with SingleTickerProviderStateMixin {
  late final _minimization = NavigationBarMinimization(vsync: this);
  ScrollPosition? _position;

  void _configure() => _minimization.configure(
    widget.style,
    extent: widget.extent,
    collapseExtent: widget.collapseExtent,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_track);
      _position = position?..addListener(_track);
      _track();
    }
  }

  @override
  void didUpdateWidget(_MinimizingSliverBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  void _track() {
    final position = _position;
    if (position != null && position.hasContentDimensions) {
      _minimization.update(position);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_track);
    _minimization.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      _minimization.progress,
      _minimization.revealed,
    ]),
    builder: (context, _) =>
        widget.builder(_minimization.progress, _minimization.revealed.value),
  );
}

class _SliverBarDelegate extends SliverPersistentHeaderDelegate {
  new({
    required this.bar,
    required this.minimization,
    required this.revealed,
    required this.leading,
    required this.inlineTitle,
    required this.expandedTitle,
    required this.compactTitle,
    required this.largeInRow,
    required this.rail,
    required this.accessory,
    required this.insets,
    required this.titleStyle,
    required this.largeTitleStyle,
    required this.subtitleStyle,
    required this.largeSubtitleStyle,
    required this.navigation,
    required this.top,
    required this.barRow,
    required this.clearance,
    required this.largeRow,
    required this.lead,
    required this.largeTitleTop,
    required this.accessoryHeight,
    required this.minExtent,
    required this.maxExtent,
    required this.titleCollapseExtent,
  }) : minimizationValue = minimization.value;
  final double minimizationValue;
  final bool revealed;
  final PrismSliverAppBar bar;
  final Animation<double> minimization;
  final Widget? leading;
  final Widget? inlineTitle;
  final Widget? expandedTitle;
  final Widget? compactTitle;
  final Widget? accessory;
  final bool largeInRow;
  final bool rail;
  final double clearance;
  final EdgeInsets insets;
  final TextStyle titleStyle;
  final TextStyle largeTitleStyle;
  final TextStyle subtitleStyle;
  final TextStyle largeSubtitleStyle;
  final PrismNavigationBarStyle navigation;
  final double top;
  final double barRow;
  final double largeRow;
  final double lead;
  final double largeTitleTop;
  final double accessoryHeight;
  @override
  final double minExtent;
  @override
  final double maxExtent;
  final double titleCollapseExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => RepaintBoundary(
    child: _SliverBar(delegate: this, shrinkOffset: shrinkOffset),
  );

  @override
  bool shouldRebuild(_SliverBarDelegate old) =>
      old.bar != bar ||
      old.minimization != minimization ||
      old.minimizationValue != minimizationValue ||
      old.revealed != revealed ||
      old.leading != leading ||
      old.inlineTitle != inlineTitle ||
      old.expandedTitle != expandedTitle ||
      old.compactTitle != compactTitle ||
      old.largeInRow != largeInRow ||
      old.rail != rail ||
      old.clearance != clearance ||
      old.accessory != accessory ||
      old.insets != insets ||
      old.titleStyle != titleStyle ||
      old.largeTitleStyle != largeTitleStyle ||
      old.navigation != navigation ||
      old.top != top ||
      old.barRow != barRow ||
      old.largeRow != largeRow ||
      old.lead != lead ||
      old.largeTitleTop != largeTitleTop ||
      old.accessoryHeight != accessoryHeight ||
      old.minExtent != minExtent ||
      old.maxExtent != maxExtent ||
      old.titleCollapseExtent != titleCollapseExtent;
}

class _SliverBar extends StatefulWidget {
  const new({required this.delegate, required this.shrinkOffset});
  final _SliverBarDelegate delegate;
  final double shrinkOffset;

  @override
  State<_SliverBar> createState() => _SliverBarState();
}

class _SliverBarState extends State<_SliverBar> with TickerProviderStateMixin {
  final GlobalKey<State<StatefulWidget>> _sharedTitleKey = GlobalKey();
  late final _largeFade = RetargetablePrismSpring(vsync: this);
  late final _inlineFade = RetargetablePrismSpring(vsync: this);
  bool _collapsed = false;

  ScrollPosition? _position;
  final _scrolled = ValueNotifier<double>(0);

  _SliverBarDelegate get _d => widget.delegate;

  double get _titleBlur => PrismTheme.of(context).transition?.contentBlur ?? 4;

  late final _edgePresence =
      AnimationController(
        vsync: this,
        duration: PrismScaffold.scrollEdgeFadeDuration,
        value: _d.bar.scrollEdge ? 1 : 0,
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
    _collapsed = _isCollapsed;
    _largeFade.value = _inlineFade.value = _collapsed ? 1 : 0;
  }

  bool get _isCollapsed {
    final reveal = _d.navigation.revealExtent ?? _d.largeRow;
    return _d.expandedTitle != null &&
        widget.shrinkOffset >= math.min(reveal, _d.largeRow) - .01 &&
        widget.shrinkOffset > 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_track);
      _position = position?..addListener(_track);
      _track();
    }
  }

  @override
  void didUpdateWidget(_SliverBar old) {
    super.didUpdateWidget(old);
    final edge = _d.bar.scrollEdge;
    if (old.delegate.bar.scrollEdge != edge) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _edgePresence.value = edge ? 1 : 0;
      } else if (edge) {
        _edgePresence.forward();
      } else {
        _edgePresence.reverse();
      }
    }
    final collapsed = _isCollapsed;
    if (collapsed == _collapsed) return;
    _collapsed = collapsed;
    animateNavigationTitle(
      large: _largeFade,
      inline: _inlineFade,
      style: _d.navigation,
      collapsed: collapsed,
      immediate: MediaQuery.disableAnimationsOf(context),
      isMounted: () => mounted,
    );
  }

  void _track() {
    final position = _position;
    if (position == null || !position.hasPixels) return;
    final start = position.hasContentDimensions
        ? position.minScrollExtent
        : 0.0;
    _scrolled.value = math.max<double>(
      0,
      position.pixels - start - _d.titleCollapseExtent,
    );
  }

  @override
  void dispose() {
    _position?.removeListener(_track);
    _scrolled.dispose();
    _edgeStrength.dispose();
    _edgePresence.dispose();
    _largeFade.dispose();
    _inlineFade.dispose();
    super.dispose();
  }

  Widget _header(Widget child, TextStyle style, {required bool large}) {
    final text = Semantics(
      header: true,
      child: DefaultTextStyle(
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: child,
      ),
    );
    final swaps = _d.expandedTitle != null;
    final minimizes = switch (_d.navigation.minimizationBehavior) {
      PrismMinimizationBehavior.onScrollDown ||
      PrismMinimizationBehavior.onScrollUp => true,
      _ => false,
    };
    if (!swaps && !minimizes) return text;
    return AnimatedBuilder(
      animation: Listenable.merge([_largeFade, _inlineFade, _d.minimization]),
      builder: (context, child) {
        final eligible =
            large ||
            !swaps ||
            _d.navigation.minimizationBehavior !=
                PrismMinimizationBehavior.onScrollDown ||
            _d.revealed;
        final visible =
            eligible && (!swaps || (large ? !_collapsed : _collapsed));
        final inline = _inlineFade.value;

        final opacity =
            (swaps ? (large ? 1 - _largeFade.value : inline) : 1.0) *
            (_d.navigation.minimizationBehavior ==
                    PrismMinimizationBehavior.onScrollDown
                ? 1.0
                : 1 - _d.minimization.value) *
            (eligible ? 1 : 0);
        final moved = large || !swaps
            ? child!
            : Transform.translate(
                offset: Offset(0, 15 * (1 - inline)),
                child: child,
              );
        final presentation = !large && _d.inlineTitle is PrismTitle
            ? PrismPresence(
                progress: AlwaysStoppedAnimation(opacity),
                contentBlur: _titleBlur,
                materialize: !MediaQuery.disableAnimationsOf(context),
                child: moved,
              )
            : PrismContentPresence(
                presence: opacity,
                blur: large ? 0 : _titleBlur,
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

  @override
  Widget build(BuildContext context) {
    final bar = _d.bar;
    final hidesOnScrollDown =
        _d.navigation.minimizationBehavior ==
        PrismMinimizationBehavior.onScrollDown;
    final scrollsAway =
        hidesOnScrollDown &&
        _d.navigation.minimizationRestoration ==
            PrismMinimizationRestoration.atScrollEdge;
    final content = prismToolbarAt(
      bar.toolbar,
      PrismToolbarPlacement.topTrailing,
    );
    final shrink = widget.shrinkOffset.clamp(0.0, _d.titleCollapseExtent);
    final system =
        PrismSystemChrome.scopeOf(context)?.chrome ??
        PrismSystemChrome.listenable.value;
    final regular = switch (system?.horizontalSizeClass) {
      PrismSizeClass.regular => true,
      PrismSizeClass.compact => false,
      null => MediaQuery.sizeOf(context).width >= 700,
    };
    final titleAlignment = prismDefaultTitleAlignment(
      requested: _d.largeInRow && bar.largeTitle != null
          ? _d.navigation.largeTitleAlignment ?? _d.navigation.titleAlignment
          : _d.navigation.titleAlignment,
      glassTitle: _d.inlineTitle is PrismTitle,
      actions: prismToolbarItemCount(content) + (bar.trailing != null ? 1 : 0),
      foldedRail: _d.rail && !regular,
      sheet: bar.sheet,
    );
    final edgeStyle = PrismScrollEdgeStyle.resolve(
      context,
      bar.scrollEdgeStyle,
    );
    double edgePresence() {
      if (_d.accessory != null) return 1;
      if (hidesOnScrollDown && !_d.revealed) return 0;
      return 1 - _d.minimization.value;
    }

    final titleControlHeight =
        prismToolbarStyleFor(context, PrismToolbarSize.navigation).height ?? 44;
    final sharedTitle =
        _d.expandedTitle != null && identical(_d.expandedTitle, _d.inlineTitle);
    Widget titleContent(Widget title) =>
        sharedTitle ? KeyedSubtree(key: _sharedTitleKey, child: title) : title;
    return PrismGroup(
      child: CustomMultiChildLayout(
        delegate: _SliverBarLayout(
          textDirection: Directionality.of(context),
          largeTitleAlignment:
              _d.navigation.largeTitleAlignment ?? PrismTitleAlignment.leading,
          titleAlignment: titleAlignment,
          insets: _d.insets,
          top:
              _d.top -
              (_d.barRow +
                      (_d.accessoryHeight > 0 ? 0 : _d.clearance) +
                      (hidesOnScrollDown ? _d.top : 0)) *
                  _d.minimization.value,
          safeTop: _d.top,
          barRow: _d.barRow,
          largeRow: _d.largeRow,
          lead: _d.lead,
          largeTitleTop: _d.largeTitleTop,
          shrink: shrink,
          accessoryHeight: _d.accessoryHeight,
          gutter: _d.navigation.gutter ?? 16,
          gap: _d.navigation.controlGap ?? 12,
          edgeFrame:
              bar.accessory == null &&
                  edgeStyle.variant == PrismScrollEdgeVariant.hard
              ? 10
              : 0,
          edgeInset: topEdgeInset(
            _d.inlineTitle,
            bareRows: _d.accessoryHeight > 0 || _d.expandedTitle != null,
            style: edgeStyle,
          ),
        ),
        children:
            [
              if ((bar.scrollEdge || !_edgePresence.isDismissed) &&
                  (_d.inlineTitle != null || _d.expandedTitle != null))
                LayoutId(
                  id: _Slot.edge,
                  child: IgnorePointer(
                    child: ScrollEdgeProgressBuilder(
                      listenable: Listenable.merge([
                        _scrolled,
                        _edgeStrength,
                        _d.minimization,
                      ]),
                      progress: () =>
                          _edgeStrength.value *
                          edgePresence() *
                          PrismScrollEdge.progressFor(
                            _scrolled.value,
                            revealExtent:
                                edgeStyle.revealExtent ??
                                PrismScrollEdgeStyle.defaultRevealExtent,
                          ),
                      builder: (context, progress) => PrismScrollEdge(
                        progress: progress,
                        color: bar.backgroundColor,
                        style: navigationScrollEdgeStyle(
                          edgeStyle,
                          edgePresence(),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_d.expandedTitle case final large?
                  when !sharedTitle || !_collapsed)
                LayoutId(
                  id: _Slot.largeTitle,
                  child: _header(
                    prismTitled(
                      titleContent(large),
                      bar.subtitle,
                      _d.largeSubtitleStyle,
                      large: true,
                      alignment:
                          _d.navigation.largeTitleAlignment ??
                          PrismTitleAlignment.leading,
                      subtitleOffset:
                          MediaQuery.textScalerOf(context)
                              .scale(_d.largeTitleStyle.fontSize ?? 34) *
                          38.33 /
                          34,
                    ),
                    _d.largeTitleStyle,
                    large: true,
                  ),
                ),
              if (_d.accessory case final accessory?)
                LayoutId(id: _Slot.accessory, child: accessory),
              if (_d.inlineTitle case final title?
                  when !(_d.expandedTitle != null && scrollsAway) &&
                      (!sharedTitle || _collapsed))
                LayoutId(
                  id: _Slot.title,
                  child:
                      _d.largeInRow &&
                          !hidesOnScrollDown &&
                          _d.navigation.minimizationBehavior !=
                              PrismMinimizationBehavior.onScrollUp
                      ? ValueListenableBuilder<double>(
                          valueListenable: _scrolled,
                          builder: (context, offset, _) =>
                              prismNavigationPinnedTitle(
                                title: title,
                                compact: _d.compactTitle ?? title,
                                subtitle: bar.subtitle,
                                largeStyle: _d.largeTitleStyle,
                                compactStyle: _d.titleStyle,
                                largeSubtitleStyle: _d.largeSubtitleStyle,
                                compactSubtitleStyle: _d.subtitleStyle,
                                alignment: titleAlignment,
                                collapsed:
                                    offset > 0 &&
                                    offset >=
                                        (_d.navigation.revealExtent ?? 52),
                                controlHeight: titleControlHeight,
                                decorate: (child, style) =>
                                    _header(child, style, large: false),
                              ),
                        )
                      : _header(
                          prismTitled(
                            titleContent(title),
                            bar.subtitle,
                            _d.largeInRow
                                ? _d.largeSubtitleStyle
                                : _d.subtitleStyle,
                            large: false,
                            controlHeight: titleControlHeight,
                            alignment:
                                titleAlignment == PrismTitleAlignment.automatic
                                ? PrismTitleAlignment.center
                                : titleAlignment,
                          ),
                          _d.largeInRow ? _d.largeTitleStyle : _d.titleStyle,
                          large: false,
                        ),
                ),
              if (_d.leading case final leading?)
                LayoutId(id: _Slot.leading, child: leading),
              if (content.isNotEmpty)
                LayoutId(
                  id: _Slot.actions,
                  child: PrismToolbar(
                    content: content,
                    style: prismToolbarStyleFor(
                      context,
                      PrismToolbarSize.navigation,
                    ),
                  ),
                ),
              if (bar.trailing case final trailing?)
                LayoutId(id: _Slot.trailing, child: trailing),
            ].map((child) {
              final pinned =
                  child.id == _Slot.accessory || child.id == _Slot.edge;
              return pinned
                  ? child
                  : LayoutId(
                      id: child.id,
                      child: NavigationBarPresence(
                        progress: _d.minimization,
                        fades: !hidesOnScrollDown,
                        child: child.child,
                      ),
                    );
            }).toList(),
      ),
    );
  }
}

enum _Slot { edge, leading, actions, trailing, title, largeTitle, accessory }

class _SliverBarLayout extends MultiChildLayoutDelegate {
  new({
    required this.textDirection,
    required this.titleAlignment,
    required this.largeTitleAlignment,
    required this.insets,
    required this.top,
    required this.safeTop,
    required this.barRow,
    required this.largeRow,
    required this.lead,
    required this.largeTitleTop,
    required this.shrink,
    required this.accessoryHeight,
    required this.gutter,
    required this.gap,
    required this.edgeFrame,
    required this.edgeInset,
  });
  final TextDirection textDirection;
  final PrismTitleAlignment titleAlignment;
  final PrismTitleAlignment largeTitleAlignment;
  final EdgeInsets insets;
  final double top;
  final double barRow;
  final double largeRow;
  final double shrink;
  final double accessoryHeight;
  final double gutter;
  final double gap;

  final double safeTop;

  final double lead;
  final double largeTitleTop;

  final double edgeFrame;

  final double edgeInset;

  static const _edge = 16.0;

  static const _trailingGap = 8.0;

  @override
  void performLayout(Size size) {
    final rtl = textDirection == TextDirection.rtl;
    final largeHeight = math.max<double>(0, lead + largeRow - shrink);
    double centred(Size child) => top + (barRow - child.height) / 2;
    final leftInset = insets.left;
    final rightInset = insets.right;
    var leadingEnd = leftInset;
    var trailingStart = size.width - rightInset;

    if (hasChild(_Slot.edge)) {
      layoutChild(
        _Slot.edge,
        BoxConstraints.tight(
          Size(
            size.width,
            math.max<double>(
              0,
              (accessoryHeight > 0
                      ? math.max(safeTop, top + barRow + largeHeight)
                      : top + barRow + largeHeight) +
                  accessoryHeight +
                  edgeFrame -
                  edgeInset -
                  (accessoryHeight == 0 ? math.min(lead, largeHeight) : 0),
            ),
          ),
        ),
      );
      positionChild(_Slot.edge, Offset.zero);
    }
    if (hasChild(_Slot.actions)) {
      final child = layoutChild(_Slot.actions, BoxConstraints.loose(size));
      final x = rtl
          ? leftInset + _edge
          : size.width - rightInset - _edge - child.width;
      if (rtl) {
        leadingEnd = x + child.width;
      } else {
        trailingStart = x;
      }
      positionChild(_Slot.actions, Offset(x, centred(child)));
    }
    if (hasChild(_Slot.trailing)) {
      final actions = hasChild(_Slot.actions);
      final child = layoutChild(_Slot.trailing, BoxConstraints.loose(size));
      final x = rtl
          ? (actions ? leadingEnd + _trailingGap : leftInset + _edge)
          : (actions
                    ? trailingStart - _trailingGap
                    : size.width - rightInset - _edge) -
                child.width;
      if (rtl) {
        leadingEnd = x + child.width;
      } else {
        trailingStart = x;
      }
      positionChild(_Slot.trailing, Offset(x, centred(child)));
    }
    if (hasChild(_Slot.leading)) {
      final bounded = hasChild(_Slot.actions) || hasChild(_Slot.trailing);
      final room = rtl
          ? size.width -
                _edge -
                (bounded ? leadingEnd + gap : leftInset + _edge)
          : (bounded ? trailingStart - gap : size.width - rightInset - _edge) -
                _edge;
      final child = layoutChild(
        _Slot.leading,
        BoxConstraints.loose(Size(math.max<double>(0, room), size.height)),
      );
      final x = rtl
          ? size.width - rightInset - _edge - child.width
          : leftInset + _edge;
      if (rtl) {
        trailingStart = x;
      } else {
        leadingEnd = x + child.width;
      }
      positionChild(_Slot.leading, Offset(x, centred(child)));
    }
    if (hasChild(_Slot.title)) {
      final centre = (leftInset + size.width - rightInset) / 2;
      final left = math.max(
        leftInset + gutter,
        leadingEnd + (leadingEnd > 0 ? gap : 0),
      );
      final right = math.min(
        size.width - rightInset - gutter,
        trailingStart - (trailingStart < size.width ? gap : 0),
      );
      final centeredWidth = math.max<double>(
        0,
        2.0 * math.min(centre - left, right - centre),
      );
      final title = layoutChild(
        _Slot.title,
        BoxConstraints.loose(
          Size(
            titleAlignment == PrismTitleAlignment.center
                ? centeredWidth
                : math.max<double>(0, right - left),
            barRow,
          ),
        ),
      );
      final alignment = prismResolvedTitleAlignment(
        titleAlignment,
        title.width,
        centeredWidth,
      );
      final x = alignment == PrismTitleAlignment.center
          ? centre - title.width / 2
          : (alignment == PrismTitleAlignment.trailing) != rtl
          ? right - title.width
          : left;
      positionChild(_Slot.title, Offset(x, centred(title)));
    }
    if (hasChild(_Slot.largeTitle)) {
      final child = layoutChild(
        _Slot.largeTitle,
        BoxConstraints(
          maxWidth: math.max<double>(
            0,
            size.width - leftInset - rightInset - 2 * gutter,
          ),
        ),
      );
      positionChild(
        _Slot.largeTitle,
        Offset(switch (largeTitleAlignment) {
          PrismTitleAlignment.center =>
            (leftInset + size.width - rightInset - child.width) / 2,
          PrismTitleAlignment.trailing =>
            rtl
                ? leftInset + gutter
                : size.width - rightInset - gutter - child.width,
          _ =>
            rtl
                ? size.width - rightInset - gutter - child.width
                : leftInset + gutter,
        }, top + barRow + lead + largeTitleTop - shrink),
      );
    }
    if (hasChild(_Slot.accessory)) {
      layoutChild(
        _Slot.accessory,
        BoxConstraints.tightFor(width: size.width, height: accessoryHeight),
      );
      positionChild(
        _Slot.accessory,
        Offset(0, math.max(safeTop, top + barRow + largeHeight)),
      );
    }
  }

  @override
  bool shouldRelayout(_SliverBarLayout old) =>
      old.textDirection != textDirection ||
      old.titleAlignment != titleAlignment ||
      old.largeTitleAlignment != largeTitleAlignment ||
      old.insets != insets ||
      old.top != top ||
      old.safeTop != safeTop ||
      old.barRow != barRow ||
      old.largeRow != largeRow ||
      old.lead != lead ||
      old.largeTitleTop != largeTitleTop ||
      old.shrink != shrink ||
      old.accessoryHeight != accessoryHeight ||
      old.gutter != gutter ||
      old.gap != gap ||
      old.edgeFrame != edgeFrame ||
      old.edgeInset != edgeInset;
}
