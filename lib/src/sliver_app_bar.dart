import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'chrome_layout.dart';
import 'glass.dart';
import 'glass_transition.dart';
import 'motion.dart';
import 'navigation_bar_style.dart';
import 'scroll_edge.dart';
import 'theme.dart';
import 'toolbar.dart';

/// A pinned navigation bar for a [CustomScrollView], laid out as
/// [LiquidPrismScaffold]'s top bar: a [leading] control, an inline [title],
/// trailing [actions], a collapsing [largeTitle] and an [accessory] row, over
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
///       actions: [[filter], [share, more]],
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
    this.actions = const [],
    this.accessory,
    this.backgroundColor,
    this.scrollEdge = true,
    this.scrollEdgeStyle,
    this.navigationBarStyle,
  });

  /// Inline header, centred between [leading] and [actions].
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

  /// Top-trailing actions: [GlassToolbarItem]s or lists of them, as
  /// [LiquidPrismScaffold.actions].
  final List<Object> actions;

  /// A row below the bar and inside its scroll edge effect, such as segmented
  /// tabs. Pair it with [GlassScrollEdgeVariant.hard] for a bar with a hard
  /// edge.
  final PreferredSizeWidget? accessory;

  /// The surface content fades into under the bar. Null uses the scroll edge
  /// style's `fadeColor`.
  final Color? backgroundColor;

  /// Whether content scrolled under the bar takes the scroll edge effect.
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
      fontSize: subtitle == null ? 17 : 15,
      fontWeight: FontWeight.w600,
      color: colors.label,
    ).merge(navigation.titleStyle);
    final largeTitleStyle = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: colors.label,
    ).merge(navigation.largeTitleStyle);
    final scaler = media.textScaler;
    // The same measured geometry as LiquidPrismScaffold's top bar.
    final top = sheet ? 16.0 : math.max(media.padding.top, 24.0);
    final subtitleStyle = TextStyle(
      fontSize: 12,
      color: colors.secondaryLabel,
    ).merge(navigation.subtitleStyle);
    final largeSubtitleStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: colors.secondaryLabel,
    ).merge(navigation.largeSubtitleStyle);
    final barRow = title == null
        ? LiquidPrismScaffold.topBarHeight
        : math.max(
            LiquidPrismScaffold.topBarHeight,
            scaler.scale(titleStyle.fontSize ?? 17) *
                    (titleStyle.height ?? 1.2) +
                8,
          );
    // With a subtitle the row grows for its 11-point line (71.33 points).
    final largeRow = largeTitle == null
        ? 0.0
        : scaler.scale(largeTitleStyle.fontSize ?? 34) *
                  (largeTitleStyle.height ?? 1.2) +
              11.33 +
              (subtitle == null
                  ? 0
                  : scaler.scale(largeSubtitleStyle.fontSize ?? 11) * 1.2 +
                        6.13);
    final accessoryHeight = accessory?.preferredSize.height ?? 0;
    final minExtent =
        top + barRow + accessoryHeight + LiquidPrismScaffold.topBarClearance;
    final route = ModalRoute.of(context);
    final impliedLeading =
        leading ??
        (automaticallyImplyLeading && route != null && route.canPop
            ? LiquidPrismBackButton(
                close: route is PageRoute && route.fullscreenDialog,
              )
            : null);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverBarDelegate(
        bar: this,
        leading: impliedLeading,
        titleStyle: titleStyle,
        largeTitleStyle: largeTitleStyle,
        subtitleStyle: subtitleStyle,
        largeSubtitleStyle: largeSubtitleStyle,
        navigation: navigation,
        top: top,
        barRow: barRow,
        largeRow: largeRow,
        accessoryHeight: accessoryHeight,
        minExtent: minExtent,
        maxExtent: minExtent + largeRow,
      ),
    );
  }
}

class _SliverBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverBarDelegate({
    required this.bar,
    required this.leading,
    required this.titleStyle,
    required this.largeTitleStyle,
    required this.subtitleStyle,
    required this.largeSubtitleStyle,
    required this.navigation,
    required this.top,
    required this.barRow,
    required this.largeRow,
    required this.accessoryHeight,
    required this.minExtent,
    required this.maxExtent,
  });
  final LiquidPrismSliverAppBar bar;
  final Widget? leading;
  final TextStyle titleStyle, largeTitleStyle;
  final TextStyle subtitleStyle, largeSubtitleStyle;
  final GlassNavigationBarStyle navigation;
  final double top, barRow, largeRow, accessoryHeight;
  @override
  final double minExtent, maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => _SliverBar(delegate: this, shrinkOffset: shrinkOffset);

  @override
  bool shouldRebuild(_SliverBarDelegate old) =>
      old.bar != bar ||
      old.leading != leading ||
      old.titleStyle != titleStyle ||
      old.largeTitleStyle != largeTitleStyle ||
      old.navigation != navigation ||
      old.top != top ||
      old.barRow != barRow ||
      old.largeRow != largeRow ||
      old.accessoryHeight != accessoryHeight ||
      old.minExtent != minExtent;
}

class _SliverBar extends StatefulWidget {
  const _SliverBar({required this.delegate, required this.shrinkOffset});
  final _SliverBarDelegate delegate;
  final double shrinkOffset;

  @override
  State<_SliverBar> createState() => _SliverBarState();
}

class _SliverBarState extends State<_SliverBar> with TickerProviderStateMixin {
  // As in LiquidPrismScaffold: once the large title's row has scrolled away
  // the titles swap on springs (see GlassNavigationBarStyle).
  late final _largeFade = RetargetableGlassSpring(vsync: this);
  late final _inlineFade = RetargetableGlassSpring(vsync: this);
  bool _collapsed = false;

  ScrollPosition? _position;
  final _scrolled = ValueNotifier<double>(0);

  _SliverBarDelegate get _d => widget.delegate;

  /// The shared glass content blur, so titles focus in like glass content.
  double get _titleBlur =>
      LiquidPrismTheme.of(context).transition?.contentBlur ?? 8;

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
    final collapsed = _isCollapsed;
    if (collapsed == _collapsed) return;
    _collapsed = collapsed;
    final immediate = MediaQuery.disableAnimationsOf(context);
    final target = collapsed ? 1.0 : 0.0;
    springGlass(
      _largeFade,
      target,
      GlassNavigationBarStyle.largeTitleSpring.description,
      immediate: immediate,
    );
    springGlass(
      _inlineFade,
      target,
      (_d.navigation.revealSpring ?? GlassNavigationBarStyle.titleSpring)
          .description,
      immediate: immediate,
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
    _scrolled.value = math.max(0, position.pixels - start - _d.largeRow);
  }

  @override
  void dispose() {
    _position?.removeListener(_track);
    _scrolled.dispose();
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
    if (_d.bar.largeTitle == null) return IgnorePointer(child: text);
    return AnimatedBuilder(
      animation: Listenable.merge([_largeFade, _inlineFade]),
      builder: (context, child) {
        final visible = large ? !_collapsed : _collapsed;
        // Opacity clamps; the rise keeps the spring's overshoot.
        final inline = _inlineFade.value;
        final opacity = large ? 1 - _largeFade.value : inline;
        return ExcludeSemantics(
          excluding: !visible,
          child: IgnorePointer(
            // The titles focus in and out as they fade, as native soft bars
            // do: blurred when absent, sharp when present.
            child: GlassContentPresence(
              presence: opacity,
              blur: _titleBlur,
              child: large
                  ? child!
                  : Transform.translate(
                      offset: Offset(0, 15 * (1 - inline)),
                      child: child,
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
    final groups = glassActionGroups(bar.actions);
    final shrink = widget.shrinkOffset.clamp(0.0, _d.largeRow);
    final edgeStyle = GlassScrollEdgeStyle.resolve(
      context,
      bar.scrollEdgeStyle,
    );
    return LiquidPrismGroup(
      child: CustomMultiChildLayout(
        delegate: _SliverBarLayout(
          textDirection: Directionality.of(context),
          top: _d.top,
          barRow: _d.barRow,
          largeRow: _d.largeRow,
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
        children: [
          if (bar.scrollEdge)
            LayoutId(
              id: _Slot.edge,
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrolled,
                  builder: (context, scrolled, _) => LiquidPrismScrollEdge(
                    progress: LiquidPrismScrollEdge.progressFor(
                      scrolled,
                      revealExtent:
                          edgeStyle.revealExtent ??
                          GlassScrollEdgeStyle.defaultRevealExtent,
                    ),
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
          if (bar.accessory case final accessory?)
            LayoutId(id: _Slot.accessory, child: accessory),
          if (bar.title case final title?)
            LayoutId(
              id: _Slot.title,
              child: _header(
                glassTitled(
                  title,
                  bar.subtitle,
                  _d.subtitleStyle,
                  large: false,
                  leading: bar.actions.isNotEmpty,
                ),
                _d.titleStyle,
                large: false,
              ),
            ),
          if (_d.leading case final leading?)
            LayoutId(id: _Slot.leading, child: leading),
          if (groups.isNotEmpty)
            LayoutId(
              id: _Slot.actions,
              child: groups.length == 1
                  ? LiquidPrismToolbarGroup(
                      items: groups.single,
                      size: GlassToolbarSize.navigation,
                    )
                  : LiquidPrismToolbar(
                      groups: groups,
                      size: GlassToolbarSize.navigation,
                    ),
            ),
        ],
      ),
    );
  }
}

enum _Slot { edge, leading, actions, title, largeTitle, accessory }

class _SliverBarLayout extends MultiChildLayoutDelegate {
  _SliverBarLayout({
    required this.textDirection,
    required this.top,
    required this.barRow,
    required this.largeRow,
    required this.shrink,
    required this.accessoryHeight,
    required this.gutter,
    required this.gap,
    required this.edgeFrame,
  });
  final TextDirection textDirection;
  final double top, barRow, largeRow, shrink, accessoryHeight, gutter, gap;

  /// Extra depth of a hard edge, to the bar frame 10 points below the
  /// controls, as measured; an accessory ends the frame itself.
  final double edgeFrame;

  /// The controls' measured inset from the screen edges.
  static const _edge = 16.0;

  @override
  void performLayout(Size size) {
    final rtl = textDirection == TextDirection.rtl;
    final largeHeight = largeRow - shrink;
    double centred(Size child) => top + (barRow - child.height) / 2;
    var leadingEnd = 0.0, trailingStart = size.width;

    if (hasChild(_Slot.edge)) {
      // The bar's box, status bar and accessory included; a soft effect
      // reaches below it.
      layoutChild(
        _Slot.edge,
        BoxConstraints.tight(
          Size(
            size.width,
            top + barRow + largeHeight + accessoryHeight + edgeFrame,
          ),
        ),
      );
      positionChild(_Slot.edge, Offset.zero);
    }
    if (hasChild(_Slot.leading)) {
      final child = layoutChild(_Slot.leading, BoxConstraints.loose(size));
      final x = rtl ? size.width - _edge - child.width : _edge;
      if (rtl) {
        trailingStart = x;
      } else {
        leadingEnd = x + child.width;
      }
      positionChild(_Slot.leading, Offset(x, centred(child)));
    }
    if (hasChild(_Slot.actions)) {
      final child = layoutChild(_Slot.actions, BoxConstraints.loose(size));
      final x = rtl ? _edge : size.width - _edge - child.width;
      if (rtl) {
        leadingEnd = x + child.width;
      } else {
        trailingStart = x;
      }
      positionChild(_Slot.actions, Offset(x, centred(child)));
    }
    if (hasChild(_Slot.title)) {
      final centre = size.width / 2;
      final left = math.max(gutter, leadingEnd + (leadingEnd > 0 ? gap : 0));
      final right = math.min(
        size.width - gutter,
        trailingStart - (trailingStart < size.width ? gap : 0),
      );
      if (hasChild(_Slot.actions)) {
        // Beside actions the title leads, after the leading control.
        final title = layoutChild(
          _Slot.title,
          BoxConstraints.loose(Size(math.max(0, right - left), barRow)),
        );
        positionChild(
          _Slot.title,
          Offset(rtl ? right - title.width : left, centred(title)),
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
      // The title rides the content up, as measured, while its row shrinks.
      final child = layoutChild(
        _Slot.largeTitle,
        BoxConstraints(maxWidth: math.max(0, size.width - 2 * gutter)),
      );
      positionChild(
        _Slot.largeTitle,
        Offset(
          rtl ? size.width - gutter - child.width : gutter,
          top + barRow + 3.67 - shrink,
        ),
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
      old.top != top ||
      old.barRow != barRow ||
      old.largeRow != largeRow ||
      old.shrink != shrink ||
      old.accessoryHeight != accessoryHeight ||
      old.gutter != gutter ||
      old.gap != gap ||
      old.edgeFrame != edgeFrame;
}
