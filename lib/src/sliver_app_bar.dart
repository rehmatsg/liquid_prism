import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'chrome_layout.dart';
import 'glass.dart';
import 'glass_transition.dart';
import 'motion.dart';
import 'navigation_bar_style.dart';
import 'navigation_title_motion.dart';
import 'navigation_bar_minimization.dart';
import 'scroll_edge.dart';
import 'theme.dart';
import 'toolbar.dart';

/// A pinned navigation bar for a [CustomScrollView], laid out as
/// [LiquidPrismScaffold]'s top bar: a [leading] control, an inline [title],
/// trailing [toolbar], a collapsing [largeTitle] and an [accessory] row, over
/// the scroll edge effect.
///
/// Its glass and its edge effect share one [LiquidPrismGroup], so the bar's
/// controls refract the content beneath them before the effect blurs and fades
/// it. Use it as the scroll view's first sliver:
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     LiquidPrismSliverAppBar(
///       title: const Text('Inbox'),
///       largeTitle: const Text('Inbox'),
///       toolbar: [GlassToolbarGroup(items: [filter]), GlassToolbarGroup(items: [share, more])],
///     ),
///     SliverList.builder(...),
///   ],
/// )
/// ```
///
/// The large title rides the scroll in its 52-point row and, once that row
/// has scrolled away, swaps to [title] on a timer, as measured on iOS 27; see
/// [GlassNavigationBarStyle].
class LiquidPrismSliverAppBar extends StatelessWidget {
  const LiquidPrismSliverAppBar({
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

  /// Inline header, centred between [leading] and [toolbar].
  final Widget? title;

  /// Expanded header in a row below the controls; supply [title] too for the
  /// collapsed header. Only the visible header contributes semantics.
  final Widget? largeTitle;

  /// A second line under the title, as [LiquidPrismScaffold.subtitle].
  final Widget? subtitle;

  /// Lays the bar out for a sheet, as [LiquidPrismScaffold.sheet].
  final bool sheet;

  /// A top-leading control. Null implies a [LiquidPrismBackButton] when the
  /// route can pop; see [automaticallyImplyLeading].
  final Widget? leading;

  /// Whether a null [leading] becomes a back control, or a close control on a
  /// fullscreen dialog, when the route can pop.
  final bool automaticallyImplyLeading;

  /// Typed toolbar content, as [LiquidPrismScaffold.toolbar]. Bottom placements
  /// form a pinned row below the accessory rather than a window footer.
  final List<GlassToolbarContent> toolbar;

  /// A widget before the [toolbar], as [LiquidPrismScaffold.trailing].
  final Widget? trailing;

  /// A row below the bar and inside its scroll edge effect, such as segmented
  /// tabs. Pair it with [GlassScrollEdgeVariant.hard] for a bar with a hard
  /// edge.
  final PreferredSizeWidget? accessory;

  /// The surface content fades into under the bar. Null uses the scroll edge
  /// style's `fadeColor`.
  final Color? backgroundColor;

  /// Whether content scrolled under the bar takes the scroll edge effect.
  /// Changing it fades the effect in or out, as
  /// [LiquidPrismScaffold.scrollEdge].
  final bool scrollEdge;

  /// Overrides the theme's [GlassScrollEdgeStyle] field by field.
  final GlassScrollEdgeStyle? scrollEdgeStyle;

  /// Overrides the theme's [GlassNavigationBarStyle] field by field.
  final GlassNavigationBarStyle? navigationBarStyle;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final navigation =
        (LiquidPrismTheme.of(context).navigationBar ??
                const GlassNavigationBarStyle())
            .merge(navigationBarStyle);
    final colors = GlassColors.of(context);
    final titleStyle = TextStyle(
      fontFamily: 'CupertinoSystemText',
      fontSize: subtitle == null ? 17 : 15,
      fontWeight: FontWeight.w600,
      letterSpacing: subtitle == null ? -.41 : -.23,
      color: colors.label,
    ).merge(navigation.titleStyle);
    final largeTitleStyle = TextStyle(
      fontFamily: 'CupertinoSystemDisplay',
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: .38,
      color: colors.label,
    ).merge(navigation.largeTitleStyle);
    final scaler = media.textScaler;
    final insets = (navigation.contentPadding ?? EdgeInsets.zero).resolve(
      Directionality.of(context),
    );
    final top = (sheet ? 16.0 : math.max(media.padding.top, 24.0)) + insets.top;
    final principal = glassToolbarAt(toolbar, GlassToolbarPlacement.principal);
    final inlineTitle = principal.isEmpty
        ? title
        : LiquidPrismToolbar(
            content: principal,
            style: glassToolbarStyleFor(context, GlassToolbarSize.navigation),
          );
    final bottom = glassBottomToolbarContent(toolbar);
    final accessoryHeight =
        (accessory?.preferredSize.height ?? 0) + (bottom.isEmpty ? 0 : 48);
    final Widget? barAccessory = bottom.isEmpty
        ? accessory
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accessory != null)
                SizedBox(
                  height: accessory!.preferredSize.height,
                  child: accessory,
                ),
              SizedBox(height: 48, child: LiquidPrismToolbar(content: bottom)),
            ],
          );
    final subtitleStyle = TextStyle(
      fontSize: 12,
      color: colors.secondaryLabel,
    ).merge(navigation.subtitleStyle);
    final largeSubtitleStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: colors.secondaryLabel,
    ).merge(navigation.largeSubtitleStyle);
    final rowHeight =
        navigation.controlRowHeight ?? LiquidPrismScaffold.topBarHeight;
    final barRow =
        (inlineTitle == null
            ? rowHeight
            : math.max(
                rowHeight,
                scaler.scale(titleStyle.fontSize ?? 17) *
                        (titleStyle.height ?? 1.2) +
                    8,
              )) +
        insets.bottom;
    final largeRow = largeTitle == null
        ? 0.0
        : navigation.largeTitleExtent ??
              scaler.scale(largeTitleStyle.fontSize ?? 34) *
                      (largeTitleStyle.height ?? 1.2) +
                  11.33 +
                  (subtitle == null
                      ? 0
                      : scaler.scale(largeSubtitleStyle.fontSize ?? 11) * 1.2 +
                            6.13);
    final lead = largeTitle == null ? 0.0 : largeTitleLead;
    final clearance =
        navigation.contentSpacing ??
        (lead > 0 && accessoryHeight == 0
            ? lead
            : LiquidPrismScaffold.topBarClearance);
    final minExtent = top + barRow + accessoryHeight + clearance;
    final maxExtent = largeTitle == null
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
            ? LiquidPrismBackButton(
                close: route is PageRoute && route.fullscreenDialog,
              )
            : null);
    final leadingContent = glassToolbarAt(
      toolbar,
      GlassToolbarPlacement.topLeading,
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
    final minimizingExtent = barRow + (accessoryHeight == 0 ? clearance : 0);
    return _MinimizingSliverBar(
      style: navigation,
      collapseExtent: largeTitle == null ? 0 : largeRow + lead,
      extent: minimizingExtent,
      builder: (minimization, revealed) {
        final reduction =
            navigation.minimizationSafeAreaAdjustment ==
                GlassToolbarMinimizationSafeAreaAdjustment.enabled
            ? minimizingExtent * minimization.value
            : 0.0;
        return SliverPersistentHeader(
          pinned: true,
          delegate: _SliverBarDelegate(
            bar: this,
            minimization: minimization,
            revealed: revealed,
            leading: barLeading,
            inlineTitle: inlineTitle,
            accessory: barAccessory,
            insets: insets,
            titleStyle: titleStyle,
            largeTitleStyle: largeTitleStyle,
            subtitleStyle: subtitleStyle,
            largeSubtitleStyle: largeSubtitleStyle,
            navigation: navigation,
            top: top,
            barRow: barRow,
            largeRow: largeRow,
            lead: lead,
            largeTitleTop: subtitle == null ? 3.67 : 6.67,
            accessoryHeight: accessoryHeight,
            minExtent: minExtent - reduction,
            maxExtent: maxExtent - reduction,
          ),
        );
      },
    );
  }
}

class _MinimizingSliverBar extends StatefulWidget {
  const _MinimizingSliverBar({
    required this.style,
    required this.collapseExtent,
    required this.extent,
    required this.builder,
  });
  final GlassNavigationBarStyle style;
  final double collapseExtent, extent;
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
  _SliverBarDelegate({
    required this.bar,
    required this.minimization,
    required this.revealed,
    required this.leading,
    required this.inlineTitle,
    required this.accessory,
    required this.insets,
    required this.titleStyle,
    required this.largeTitleStyle,
    required this.subtitleStyle,
    required this.largeSubtitleStyle,
    required this.navigation,
    required this.top,
    required this.barRow,
    required this.largeRow,
    required this.lead,
    required this.largeTitleTop,
    required this.accessoryHeight,
    required this.minExtent,
    required this.maxExtent,
  }) : minimizationValue = minimization.value;
  final double minimizationValue;
  final bool revealed;
  final LiquidPrismSliverAppBar bar;
  final Animation<double> minimization;
  final Widget? leading, inlineTitle, accessory;
  final EdgeInsets insets;
  final TextStyle titleStyle, largeTitleStyle;
  final TextStyle subtitleStyle, largeSubtitleStyle;
  final GlassNavigationBarStyle navigation;
  final double top, barRow, largeRow, lead, largeTitleTop, accessoryHeight;
  @override
  final double minExtent, maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      // The viewport repaints every sliver on each scroll frame; pinned, the
      // bar keeps its own layer and is re-recorded only when it changes.
      RepaintBoundary(
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
      old.maxExtent != maxExtent;
}

class _SliverBar extends StatefulWidget {
  const _SliverBar({required this.delegate, required this.shrinkOffset});
  final _SliverBarDelegate delegate;
  final double shrinkOffset;

  @override
  State<_SliverBar> createState() => _SliverBarState();
}

class _SliverBarState extends State<_SliverBar> with TickerProviderStateMixin {
  late final _largeFade = RetargetableGlassSpring(vsync: this);
  late final _inlineFade = RetargetableGlassSpring(vsync: this);
  bool _collapsed = false;

  ScrollPosition? _position;
  final _scrolled = ValueNotifier<double>(0);

  _SliverBarDelegate get _d => widget.delegate;

  /// The shared glass content blur, so titles focus in like glass content.
  double get _titleBlur =>
      LiquidPrismTheme.of(context).transition?.contentBlur ?? 8;

  /// The edge effect's presence, easing in and out as `scrollEdge` changes.
  late final _edgePresence =
      AnimationController(
        vsync: this,
        duration: LiquidPrismScaffold.scrollEdgeFadeDuration,
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
    return _d.bar.largeTitle != null &&
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

  /// How far content has scrolled under the collapsed bar: the large title's
  /// row scrolls away first.
  void _track() {
    final position = _position;
    if (position == null || !position.hasPixels) return;
    final start = position.hasContentDimensions
        ? position.minScrollExtent
        : 0.0;
    _scrolled.value = math.max(
      0,
      position.pixels - start - (_d.maxExtent - _d.minExtent),
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
    final swaps = _d.bar.largeTitle != null;
    final minimizes = switch (_d.navigation.minimizationBehavior) {
      GlassToolbarMinimizationBehavior.onScrollDown ||
      GlassToolbarMinimizationBehavior.onScrollUp => true,
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
                GlassToolbarMinimizationBehavior.onScrollDown ||
            _d.revealed;
        final visible =
            eligible && (!swaps || (large ? !_collapsed : _collapsed));
        final inline = _inlineFade.value;
        final opacity =
            (swaps ? (large ? 1 - _largeFade.value : inline) : 1.0) *
            (1 - _d.minimization.value) *
            (eligible ? 1 : 0);
        return ExcludeSemantics(
          excluding: !visible,
          child: ExcludeFocus(
            excluding: !visible,
            child: IgnorePointer(
              ignoring: !visible,
              child: GlassContentPresence(
                presence: opacity,
                blur: large ? 0 : _titleBlur,
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

  @override
  Widget build(BuildContext context) {
    final bar = _d.bar;
    final hidesOnScrollDown =
        _d.navigation.minimizationBehavior ==
        GlassToolbarMinimizationBehavior.onScrollDown;
    final scrollsAway =
        hidesOnScrollDown &&
        _d.navigation.minimizationRestoration ==
            GlassToolbarMinimizationRestoration.atScrollEdge;
    final content = glassToolbarAt(
      bar.toolbar,
      GlassToolbarPlacement.topTrailing,
    );
    final shrink = widget.shrinkOffset.clamp(0.0, _d.maxExtent - _d.minExtent);
    final edgeStyle = GlassScrollEdgeStyle.resolve(
      context,
      bar.scrollEdgeStyle,
    );
    return LiquidPrismGroup(
      child: CustomMultiChildLayout(
        delegate: _SliverBarLayout(
          textDirection: Directionality.of(context),
          largeTitleAlignment:
              _d.navigation.largeTitleAlignment ?? GlassTitleAlignment.leading,
          titleAlignment:
              _d.navigation.titleAlignment ?? GlassTitleAlignment.automatic,
          insets: _d.insets,
          top:
              _d.top -
              (_d.barRow +
                      (_d.accessoryHeight > 0
                          ? 0
                          : (_d.navigation.contentSpacing ??
                                (_d.lead > 0
                                    ? _d.lead
                                    : LiquidPrismScaffold.topBarClearance)))) *
                  _d.minimization.value,
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
                  edgeStyle.variant == GlassScrollEdgeVariant.hard
              ? 10
              : 0,
        ),
        children:
            [
              if (bar.scrollEdge || !_edgePresence.isDismissed)
                LayoutId(
                  id: _Slot.edge,
                  child: IgnorePointer(
                    child: ScrollEdgeProgressBuilder(
                      listenable: Listenable.merge([_scrolled, _edgeStrength]),
                      progress: () =>
                          (_d.accessory != null ||
                                  !hidesOnScrollDown ||
                                  _d.revealed
                              ? _edgeStrength.value
                              : 0) *
                          LiquidPrismScrollEdge.progressFor(
                            _scrolled.value,
                            revealExtent:
                                edgeStyle.revealExtent ??
                                GlassScrollEdgeStyle.defaultRevealExtent,
                          ),
                      builder: (context, progress) => LiquidPrismScrollEdge(
                        progress: progress,
                        color: bar.backgroundColor,
                        style: bar.scrollEdgeStyle,
                      ),
                    ),
                  ),
                ),
              if (bar.largeTitle case final large?)
                LayoutId(
                  id: _Slot.largeTitle,
                  child: _header(
                    glassTitled(
                      large,
                      bar.subtitle,
                      _d.largeSubtitleStyle,
                      large: true,
                      alignment:
                          _d.navigation.largeTitleAlignment ??
                          GlassTitleAlignment.leading,
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
                  when !(bar.largeTitle != null && scrollsAway))
                LayoutId(
                  id: _Slot.title,
                  child: _header(
                    glassTitled(
                      title,
                      bar.subtitle,
                      _d.subtitleStyle,
                      large: false,
                      alignment:
                          _d.navigation.titleAlignment == null ||
                              _d.navigation.titleAlignment ==
                                  GlassTitleAlignment.automatic
                          ? GlassTitleAlignment.center
                          : _d.navigation.titleAlignment!,
                    ),
                    _d.titleStyle,
                    large: false,
                  ),
                ),
              if (_d.leading case final leading?)
                LayoutId(id: _Slot.leading, child: leading),
              if (content.isNotEmpty)
                LayoutId(
                  id: _Slot.actions,
                  child: LiquidPrismToolbar(
                    content: content,
                    style: glassToolbarStyleFor(
                      context,
                      GlassToolbarSize.navigation,
                    ),
                  ),
                ),
              if (bar.trailing case final trailing?)
                LayoutId(id: _Slot.trailing, child: trailing),
            ].map((child) {
              final pinned =
                  child.id == _Slot.accessory ||
                  (child.id == _Slot.edge && _d.accessory != null);
              return pinned
                  ? child
                  : LayoutId(
                      id: child.id,
                      child: NavigationBarPresence(
                        progress: _d.minimization,
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
  _SliverBarLayout({
    required this.textDirection,
    required this.titleAlignment,
    required this.largeTitleAlignment,
    required this.insets,
    required this.top,
    required this.barRow,
    required this.largeRow,
    required this.lead,
    required this.largeTitleTop,
    required this.shrink,
    required this.accessoryHeight,
    required this.gutter,
    required this.gap,
    required this.edgeFrame,
  });
  final TextDirection textDirection;
  final GlassTitleAlignment titleAlignment, largeTitleAlignment;
  final EdgeInsets insets;
  final double top, barRow, largeRow, shrink, accessoryHeight, gutter, gap;

  /// The bar frame above a large title's row, and its line within the row.
  final double lead, largeTitleTop;

  /// Extra depth of a hard edge, to the bar frame 10 points below the
  /// controls, as measured; an accessory ends the frame itself.
  final double edgeFrame;

  /// The controls' measured inset from the screen edges.
  static const _edge = 16.0;

  /// Between the trailing widget and the first capsule.
  static const _trailingGap = 8.0;

  @override
  void performLayout(Size size) {
    final rtl = textDirection == TextDirection.rtl;
    final largeHeight = math.max(0.0, lead + largeRow - shrink);
    double centred(Size child) => top + (barRow - child.height) / 2;
    final leftInset = insets.left, rightInset = insets.right;
    var leadingEnd = leftInset, trailingStart = size.width - rightInset;

    if (hasChild(_Slot.edge)) {
      layoutChild(
        _Slot.edge,
        BoxConstraints.tight(
          Size(
            size.width,
            math.max(
              0,
              top +
                  barRow +
                  largeHeight +
                  accessoryHeight +
                  edgeFrame -
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
        BoxConstraints.loose(Size(math.max(0, room), size.height)),
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
            centred(title),
          ),
        );
      } else {
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
    }
    if (hasChild(_Slot.largeTitle)) {
      final child = layoutChild(
        _Slot.largeTitle,
        BoxConstraints(
          maxWidth: math.max(
            0,
            size.width - leftInset - rightInset - 2 * gutter,
          ),
        ),
      );
      positionChild(
        _Slot.largeTitle,
        Offset(switch (largeTitleAlignment) {
          GlassTitleAlignment.center =>
            (leftInset + size.width - rightInset - child.width) / 2,
          GlassTitleAlignment.trailing =>
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
      positionChild(_Slot.accessory, Offset(0, top + barRow + largeHeight));
    }
  }

  @override
  bool shouldRelayout(_SliverBarLayout old) =>
      old.textDirection != textDirection ||
      old.titleAlignment != titleAlignment ||
      old.largeTitleAlignment != largeTitleAlignment ||
      old.insets != insets ||
      old.top != top ||
      old.barRow != barRow ||
      old.largeRow != largeRow ||
      old.lead != lead ||
      old.largeTitleTop != largeTitleTop ||
      old.shrink != shrink ||
      old.accessoryHeight != accessoryHeight ||
      old.gutter != gutter ||
      old.gap != gap ||
      old.edgeFrame != edgeFrame;
}
