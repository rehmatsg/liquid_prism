import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import 'chrome_layout.dart';
import 'chrome_material.dart';
import 'foreground.dart';
import 'glass_transition.dart';
import 'material.dart';
import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'style.dart';
import 'theme.dart';
import 'appearance.dart';
import 'badge.dart';
import 'menu/menu.dart';
import 'menu/menus.dart';

/// Native navigation bars use 44-point capsules; bottom toolbars use 48.
export 'appearance.dart' show GlassToolbarSize;

/// One icon action in a shared toolbar capsule.
@immutable
class GlassToolbarItem {
  const GlassToolbarItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.key,
    this.selected = false,
    this.foregroundColor,
    this.badge,
    double? width,
  }) : menu = null,
       onMenuSelected = null,
       _menuEnabled = false,
       width = width ?? 38,
       _hasWidth = width != null,
       assert(width == null || width >= 36);

  const GlassToolbarItem.menu({
    required this.icon,
    required this.label,
    required LiquidMenu this.menu,
    ValueChanged<Object?>? onSelected,
    bool enabled = true,
    this.key,
    this.selected = false,
    this.foregroundColor,
    this.badge,
    double? width,
  }) : onPressed = null,
       onMenuSelected = onSelected,
       _menuEnabled = enabled,
       width = width ?? 38,
       _hasWidth = width != null,
       assert(width == null || width >= 36);
  final Widget icon;
  final GlassBadge? badge;
  final String label;
  final FutureOr<void> Function()? onPressed;

  /// Identifies the item across rebuilds, so a group animates the right item
  /// in or out when the list changes. Items without a key are matched by
  /// [label].
  final Key? key;
  final bool selected;
  final Color? foregroundColor;
  final LiquidMenu? menu;
  final ValueChanged<Object?>? onMenuSelected;
  final bool _menuEnabled;
  bool get _isEnabled => menu == null ? onPressed != null : _menuEnabled;

  /// Native item width depends on the symbol. The captured minimum is 38;
  /// callers can supply the measured width for wider or custom symbols.
  ///
  /// Left unset on the only item of a group, the item fills a circle: the
  /// group is as wide as it is tall (44 points in a navigation bar, 48 in a
  /// bottom toolbar), as native iOS draws a lone bar button. An explicit width
  /// is kept, so a wider custom item stays a capsule.
  final double width;
  final bool _hasWidth;
}

/// A lone navigation-bar control that pops the route: a back chevron, or a
/// close mark for a modally presented screen.
///
/// [LiquidPrismScaffold] implies one when its route can pop. Set an app's own
/// glyphs once with [GlassToolbarStyle.backIcon] and
/// [GlassToolbarStyle.closeIcon] in the theme, or pass [icon] here.
///
/// A back glyph's visual mass sits toward its point, so drawn on its box
/// centre it reads as sitting away from the circle's centre; it is shifted
/// [iconShift] toward its point, mirrored in right-to-left layouts while
/// [iconMirrors]. The close mark is symmetric and is not shifted.
class LiquidPrismBackButton extends StatelessWidget {
  const LiquidPrismBackButton({
    super.key,
    this.close = false,
    this.icon,
    this.label,
    this.onPressed,
    this.iconShift,
    this.iconMirrors,
    this.size = GlassToolbarSize.navigation,
    this.style,
    this.foregroundColor,
  }) : assert(iconShift == null || iconShift >= 0);

  /// Draw a close mark instead of a back chevron.
  final bool close;

  /// Replaces the glyph from the style. Defaults to
  /// [GlassToolbarStyle.backIcon] or [GlassToolbarStyle.closeIcon].
  final Widget? icon;

  /// The accessible name. Defaults to "Back" or "Close".
  final String? label;

  /// Defaults to popping the nearest navigator.
  final VoidCallback? onPressed;

  /// Overrides [GlassToolbarStyle.backIconShift] (default .5).
  final double? iconShift;

  /// Overrides [GlassToolbarStyle.backIconMirrors] (default true).
  final bool? iconMirrors;
  final GlassToolbarSize size;
  final GlassToolbarStyle? style;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final appearance =
        (LiquidPrismTheme.of(context).toolbar ?? const GlassToolbarStyle())
            .merge(style);
    final Widget glyph;
    if (close) {
      glyph = icon ?? appearance.closeIcon ?? const Icon(CupertinoIcons.xmark);
    } else {
      final shift = iconShift ?? appearance.backIconShift ?? .5;
      final mirrors = iconMirrors ?? appearance.backIconMirrors ?? true;
      final rtl = Directionality.of(context) == TextDirection.rtl;
      glyph = Transform.translate(
        // A mirrored glyph points right in RTL, and so does its shift.
        offset: Offset(mirrors && rtl ? shift : -shift, 0),
        child:
            icon ??
            appearance.backIcon ??
            const Icon(CupertinoIcons.chevron_back),
      );
    }
    return LiquidPrismToolbarGroup(
      size: size,
      style: style,
      foregroundColor: foregroundColor,
      items: [
        GlassToolbarItem(
          icon: glyph,
          label: label ?? (close ? 'Close' : 'Back'),
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

/// Capsules from a bar's `actions`: each element is a [GlassToolbarItem] or
/// a list of them. Loose items next to each other share one capsule, and each
/// list is a capsule of its own.
List<List<GlassToolbarItem>> glassActionGroups(List<Object> actions) {
  final groups = <List<GlassToolbarItem>>[];
  List<GlassToolbarItem>? loose;
  for (final entry in actions) {
    switch (entry) {
      case GlassToolbarItem():
        if (loose == null) groups.add(loose = []);
        loose.add(entry);
      case List():
        assert(
          entry.every((item) => item is GlassToolbarItem),
          'A list in actions holds only GlassToolbarItems.',
        );
        loose = null;
        groups.add(entry.whereType<GlassToolbarItem>().toList());
      default:
        assert(
          false,
          'actions holds GlassToolbarItems or lists of them, '
          'not ${entry.runtimeType}.',
        );
    }
  }
  return groups;
}

/// Several capsules of icon actions in a row, as a navigation bar's trailing
/// toolbars: one [LiquidPrismToolbarGroup] per group, [spacing] apart.
///
/// Declare every group a bar can show and let the lists carry state: an
/// empty group draws nothing and materializes in when it gains an item, so
/// the groups keep their positions.
///
/// ```dart
/// LiquidPrismToolbar(
///   size: GlassToolbarSize.navigation,
///   groups: [
///     [if (hasSuggestions) suggestionsItem],
///     [sortItem, moreItem],
///   ],
/// )
/// ```
class LiquidPrismToolbar extends StatefulWidget {
  const LiquidPrismToolbar({
    super.key,
    required this.groups,
    this.size,
    this.style,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.foregroundColor,
    this.axis,
    this.spacing,
  }) : assert(spacing == null || spacing >= 0);

  /// The capsules, leading to trailing, each a list of items.
  final List<List<GlassToolbarItem>> groups;
  final GlassToolbarSize? size;
  final GlassToolbarStyle? style;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
  final Color? foregroundColor;

  /// Row or column layout. Null inherits [LiquidPrismScaffold]'s bar axis,
  /// then defaults to [Axis.horizontal].
  final Axis? axis;

  /// Gap between capsules. Null uses [GlassToolbarStyle.groupSpacing], then 8.
  final double? spacing;

  @override
  State<LiquidPrismToolbar> createState() => _LiquidPrismToolbarState();
}

class _LiquidPrismToolbarState extends State<LiquidPrismToolbar>
    with TickerProviderStateMixin {
  final _presence = <RetargetableGlassSpring>[];
  bool _synced = false;

  GlassToolbarStyle get _appearance =>
      (LiquidPrismTheme.of(context).toolbar ?? const GlassToolbarStyle()).merge(
        widget.style,
      );

  GlassTransitionStyle get _transition =>
      (LiquidPrismTheme.of(context).transition ?? const GlassTransitionStyle())
          .merge(_appearance.itemTransitionStyle);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme rebuilds notify dependents whether or not they changed; only the
    // first sync settles without animating.
    if (!_synced) {
      _synced = true;
      _sync(animated: false);
    }
  }

  @override
  void didUpdateWidget(LiquidPrismToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(animated: true);
  }

  void _sync({required bool animated}) {
    while (_presence.length < widget.groups.length) {
      _presence.add(
        RetargetableGlassSpring(vsync: this)..addStatusListener((status) {
          if (status.isCompleted || status.isDismissed) setState(() {});
        }),
      );
    }
    while (_presence.length > widget.groups.length) {
      _presence.removeLast().dispose();
    }
    final immediate =
        !animated ||
        _appearance.itemTransition == GlassTransition.identity ||
        MediaQuery.disableAnimationsOf(context);
    final transition = _transition;
    for (var i = 0; i < widget.groups.length; i++) {
      final target = widget.groups[i].isEmpty ? 0.0 : 1.0;
      final spring = _presence[i];
      if (spring.value == target && !spring.isAnimating) continue;
      springGlass(
        spring,
        target,
        target > 0
            ? transition.enterSpring?.description ??
                  SpringDescription.withDurationAndBounce(
                    duration: const Duration(milliseconds: 450),
                  )
            : transition.exitSpring?.description ??
                  SpringDescription.withDurationAndBounce(
                    duration: const Duration(milliseconds: 300),
                  ),
        immediate: immediate,
      );
    }
  }

  @override
  void dispose() {
    for (final spring in _presence) {
      spring.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vertical =
        (widget.axis ?? LiquidPrismChrome.maybeOf(context)?.axis) ==
        Axis.vertical;
    final spacing = widget.spacing ?? _appearance.groupSpacing ?? 8.0;
    return AnimatedBuilder(
      animation: Listenable.merge(_presence),
      builder: (context, _) {
        final children = <Widget>[];
        var before = 0.0;
        for (var i = 0; i < widget.groups.length; i++) {
          final spring = _presence[i];
          final presence = spring.value.clamp(0.0, 1.0);
          if (presence <= 0 && !spring.isAnimating) continue;
          // The gap belongs between two shown groups: it follows this
          // group's own presence and that of any group before it.
          final gap = spacing * before;
          before = math.max(before, presence);
          Widget group = LiquidPrismPresence(
            progress: spring,
            child: LiquidPrismToolbarGroup(
              items: widget.groups[i],
              size: widget.size,
              style: widget.style,
              glass: widget.glass,
              optics: widget.optics,
              blur: widget.blur,
              motion: widget.motion,
              foregroundColor: widget.foregroundColor,
              axis: widget.axis,
            ),
          );
          group = Padding(
            padding: vertical
                ? EdgeInsets.only(top: gap)
                : EdgeInsetsDirectional.only(start: gap),
            child: group,
          );
          if (presence < 1) {
            group = IgnorePointer(
              child: ClipRect(
                // Shrink-wrapped across the axis too: a null factor would
                // fill the height a bar offers and centre the capsules in it.
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: vertical ? 1 : presence,
                  heightFactor: vertical ? presence : 1,
                  child: group,
                ),
              ),
            );
          }
          children.add(KeyedSubtree(key: ValueKey<int>(i), child: group));
        }
        return Flex(
          direction: vertical ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      },
    );
  }
}

/// Icon actions sharing one continuous glass capsule, with individual feedback.
/// Use [LiquidPrismToolbar] for several groups, or place groups in a Row
/// with a gap. Narrow groups scroll along their axis without shrinking their
/// icons or action regions.
///
/// Items added to or removed from [items] materialize in and out while the
/// capsule resizes; see [GlassToolbarStyle.itemTransition]. With no items the
/// capsule materializes out and draws nothing.
///
/// A vertical group stacks the same layout in a column, as in the iPhone Duo
/// side rail: [GlassToolbarItem.width] becomes each item's height.
class LiquidPrismToolbarGroup extends StatefulWidget {
  const LiquidPrismToolbarGroup({
    super.key,
    required this.items,
    GlassToolbarSize? size,
    this.style,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.foregroundColor,
    this.axis,
  }) : size = size ?? GlassToolbarSize.bottom,
       _hasSize = size != null;
  final List<GlassToolbarItem> items;
  final GlassToolbarSize size;
  final bool _hasSize;
  final GlassToolbarStyle? style;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
  final Color? foregroundColor;

  /// Row or column layout. Null inherits [LiquidPrismScaffold]'s bar axis,
  /// then defaults to [Axis.horizontal].
  final Axis? axis;

  @override
  State<LiquidPrismToolbarGroup> createState() =>
      _LiquidPrismToolbarGroupState();
}

/// One item the group shows or is still animating out.
class _ToolbarEntry {
  _ToolbarEntry(this.key, this.item, this.presence);
  final Key key;
  GlassToolbarItem item;
  final RetargetableGlassSpring presence;
  bool leaving = false;

  /// The item's resting extent, kept while it leaves.
  double width = 38;
}

class _LiquidPrismToolbarGroupState extends State<LiquidPrismToolbarGroup>
    with TickerProviderStateMixin {
  final _entries = <_ToolbarEntry>[];
  bool _synced = false;

  // Which of the group's edges its parent holds still while it resizes, as
  // observed from frame to frame: entering and leaving items pin to it, so
  // they hold their final place however the group is aligned. Null until a
  // resize has been seen; the reading direction's end is assumed until then.
  bool? _fixedRight, _fixedBottom;
  Rect? _lastRect;
  bool _observing = false;

  void _observeEdges() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _observing = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final last = _lastRect;
      _lastRect = rect;
      if (last == null) return;
      if ((rect.width - last.width).abs() > .25) {
        _fixedRight =
            (rect.right - last.right).abs() <= (rect.left - last.left).abs();
      }
      if ((rect.height - last.height).abs() > .25) {
        _fixedBottom =
            (rect.bottom - last.bottom).abs() <= (rect.top - last.top).abs();
      }
    });
  }

  /// Where an entering or leaving item sits in its growing slot.
  Alignment _itemAnchor(bool vertical) {
    if (vertical) {
      return (_fixedBottom ?? false)
          ? Alignment.bottomCenter
          : Alignment.topCenter;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return (_fixedRight ?? !rtl) ? Alignment.centerRight : Alignment.centerLeft;
  }

  GlassToolbarStyle get _appearance =>
      (LiquidPrismTheme.of(context).toolbar ?? const GlassToolbarStyle()).merge(
        widget.style,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_synced) {
      _synced = true;
      _sync(animated: false);
    }
  }

  @override
  void didUpdateWidget(LiquidPrismToolbarGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(animated: true);
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.presence.dispose();
    }
    super.dispose();
  }

  /// The key an item is tracked by: its own, else its label, made unique
  /// among [used].
  static Key _keyFor(GlassToolbarItem item, Set<Key> used) {
    var key = item.key ?? ValueKey<String>(item.label);
    for (var n = 2; used.contains(key); n++) {
      key = ValueKey<String>('${item.label}#$n');
    }
    used.add(key);
    return key;
  }

  _ToolbarEntry _entry(Key key, GlassToolbarItem item, double presence) {
    final spring = RetargetableGlassSpring(vsync: this)..value = presence;
    final entry = _ToolbarEntry(key, item, spring);
    spring.addStatusListener((status) {
      if (!mounted) return;
      if (entry.leaving && status.isDismissed) {
        // Outside the controller's own notification.
        scheduleMicrotask(() {
          if (mounted) setState(() => _entries.remove(entry));
          spring.dispose();
        });
      } else if (status.isCompleted || status.isDismissed) {
        setState(() {});
      }
    });
    return entry;
  }

  /// Whether the last items given were empty, so the group is hidden and the
  /// next items refill it at once as it materializes back in.
  bool _hidden = true;

  void _sync({required bool animated}) {
    final items = widget.items;
    // An emptied group leaves as a whole (see build), keeping its items.
    if (items.isEmpty) {
      _hidden = true;
      return;
    }
    final immediate =
        !animated ||
        _hidden ||
        _appearance.itemTransition == GlassTransition.identity ||
        MediaQuery.disableAnimationsOf(context);
    _hidden = false;
    final transition =
        (LiquidPrismTheme.of(context).transition ??
                const GlassTransitionStyle())
            .merge(_appearance.itemTransitionStyle);
    final enter =
        transition.enterSpring?.description ??
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 450),
        );
    final exit =
        transition.exitSpring?.description ??
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 300),
        );
    final used = <Key>{};
    final keys = [for (final item in items) _keyFor(item, used)];
    final byKey = {for (final entry in _entries) entry.key: entry};
    final next = <_ToolbarEntry>[];
    for (var i = 0; i < items.length; i++) {
      final existing = byKey.remove(keys[i]);
      if (existing != null) {
        existing.item = items[i];
        if (existing.leaving) {
          existing.leaving = false;
          springGlass(existing.presence, 1, enter, immediate: immediate);
        }
        next.add(existing);
      } else {
        final entry = _entry(keys[i], items[i], immediate ? 1 : 0);
        if (!immediate) springGlass(entry.presence, 1, enter);
        next.add(entry);
      }
    }
    // Unmatched entries leave in place, after their nearest kept predecessor.
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (!byKey.containsKey(entry.key)) continue;
      if (immediate) {
        entry.presence.dispose();
        continue;
      }
      if (!entry.leaving) {
        entry.leaving = true;
        springGlass(entry.presence, 0, exit);
      }
      var insertAt = 0;
      for (var j = index - 1; j >= 0; j--) {
        final at = next.indexOf(_entries[j]);
        if (at >= 0) {
          insertAt = at + 1;
          break;
        }
      }
      next.insert(insertAt, entry);
    }
    _entries
      ..clear()
      ..addAll(next);
  }

  @override
  Widget build(BuildContext context) {
    final vertical =
        (widget.axis ?? LiquidPrismChrome.maybeOf(context)?.axis) ==
        Axis.vertical;
    final theme = LiquidPrismTheme.of(context),
        colors = GlassColors.of(context);
    final appearance = _appearance;
    final placement = widget._hasSize
        ? widget.size
        : appearance.size ?? widget.size;
    final navigation = placement == GlassToolbarSize.navigation;
    final height = appearance.height ?? (navigation ? 44.0 : 48.0);
    final inset = appearance.inset ?? (navigation ? 4.0 : 5.0);
    final gap = appearance.spacing ?? (navigation ? 16.0 : 14.0);
    final foreground =
        widget.foregroundColor ??
        appearance.foregroundColor ??
        theme.foregroundColor ??
        restingGlassAccent(LiquidPrismTheme.tintOf(context), colors.brightness);
    final present = [
      for (final entry in _entries)
        if (!entry.leaving) entry,
    ];
    final widths = _itemWidths(present, height, inset);
    for (var i = 0; i < present.length; i++) {
      present[i].width = widths[i];
    }
    final presence = present.isEmpty
        ? const <RetargetableGlassSpring>[]
        : [for (final entry in _entries) entry.presence];
    return AnimatedBuilder(
      animation: Listenable.merge(presence),
      builder: (context, _) {
        _observeEdges();
        final anchor = _itemAnchor(vertical);
        // Insets follow the resting layout of the items that stay; a leaving
        // item carries its gap and collapses to nothing without a jump.
        // Items enter and leave with the shared glass content treatment.
        final contentBlur =
            (theme.transition ?? const GlassTransitionStyle())
                .merge(appearance.itemTransitionStyle)
                .contentBlur ??
            8;
        var width = 0.0;
        final cells = <Widget>[];
        final badges = <Widget>[];
        final badged = _entries.any((entry) => entry.item.badge != null);
        var position = 0;
        for (final entry in _entries) {
          final double left, right;
          if (entry.leaving) {
            left = right = gap / 2;
          } else {
            left = position == 0 ? inset : gap / 2;
            right = position == present.length - 1 ? inset : gap / 2;
            position++;
          }
          final extent = entry.width + left + right;
          final progress = entry.presence.value.clamp(0.0, 1.0);
          width += extent * progress;
          if (badged) {
            badges.add(
              _badge(
                entry,
                extent,
                left,
                right,
                progress,
                height,
                appearance,
                vertical,
                contentBlur,
                anchor,
              ),
            );
          }
          cells.add(
            _action(
              entry,
              left,
              right,
              progress,
              height,
              inset,
              colors,
              foreground,
              appearance,
              vertical,
              contentBlur,
              anchor,
            ),
          );
        }
        Widget capsule = ChromeMaterial(
          height: height,
          role: GlassRole.toolbar,
          glass: widget.glass ?? appearance.glass,
          optics: widget.optics ?? appearance.optics,
          blur: widget.blur ?? appearance.blur,
          shape: appearance.shape,
          child: ClipPath(
            clipper: GlassShapeClipper(appearance.shape ?? GlassShape.capsule),
            child: SingleChildScrollView(
              scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
              child: Flex(
                direction: vertical ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                children: cells,
              ),
            ),
          ),
        );
        if (badged) {
          // Badges overhang the capsule, as native ones do, so they paint
          // above it rather than inside its clip.
          capsule = Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: capsule),
              Positioned.fill(
                // The glass scales itself about its centre while pressed
                // (LiquidPrismPressFeedback.scaleOf), so the badges take the
                // same live scale and follow the growing capsule.
                child: Builder(
                  builder: (context) => Transform.scale(
                    scale: LiquidPrismPressFeedback.scaleOf(context),
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: OverflowBox(
                          alignment: AlignmentDirectional.topStart,
                          maxWidth: vertical ? null : double.infinity,
                          maxHeight: vertical ? double.infinity : null,
                          child: Flex(
                            direction: vertical
                                ? Axis.vertical
                                : Axis.horizontal,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: badges,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        capsule = SizedBox(
          width: vertical ? height : width,
          height: vertical ? width : height,
          child: capsule,
        );
        final body = widget.items.every((item) => !item._isEnabled)
            ? capsule
            : _withFeedback(capsule, width, appearance, theme);
        return LiquidPrismVisibility(
          visible: widget.items.isNotEmpty,
          transition: appearance.itemTransition ?? GlassTransition.materialize,
          style: appearance.itemTransitionStyle,
          child: body,
        );
      },
    );
  }

  Widget _withFeedback(
    Widget capsule,
    double width,
    GlassToolbarStyle appearance,
    LiquidPrismThemeData theme,
  ) {
    final customMotion = widget.motion ?? appearance.motion ?? theme.motion;
    return LiquidPrismPressable.feedback(
      motion: customMotion,
      child: Builder(
        builder: (context) {
          final scale = LiquidPrismPressFeedback.scaleOf(context);
          // Captured widths 159, 100 and 48 all gain 16 points while held.
          // Normalize the shared feedback spring without bounding small circles
          // to the ordinary button motion API's maximum scale.
          return LiquidPrismPressFeedback(
            progress: LiquidPrismPressFeedback.of(context),
            scale: customMotion == null && width > 0
                ? 1 + (scale - 1) * (16 / width / .1126)
                : scale,
            child: capsule,
          );
        },
      ),
    );
  }

  /// Visual item extents along the group's axis. A lone item without an
  /// explicit width fills a circle, as UIKit measured: a 36-point button in the
  /// 44-point navigation circle and a 38-point button in the 48-point bottom one.
  static List<double> _itemWidths(
    List<_ToolbarEntry> items,
    double height,
    double inset,
  ) => [
    if (items.length == 1 && !items.single.item._hasWidth)
      math.max(height - inset * 2, 0)
    else
      for (final entry in items) entry.item.width,
  ];

  /// The item's badge, in a cell the size of its slot. Measured on iOS 27:
  /// an 18-point badge whose top sits 2.8 points above the capsule and whose
  /// trailing edge overhangs the item by about 3 points.
  Widget _badge(
    _ToolbarEntry entry,
    double extent,
    double left,
    double right,
    double progress,
    double height,
    GlassToolbarStyle appearance,
    bool vertical,
    double contentBlur,
    Alignment anchor,
  ) {
    final badge = entry.item.badge;
    // The slot grows like the item's own; the badge holds its final place on
    // the group's fixed side, as the item does.
    return SizedBox(
      width: vertical ? height : extent * progress,
      height: vertical ? extent * progress : height,
      child: badge == null
          ? null
          : OverflowBox(
              alignment: anchor,
              minWidth: vertical ? null : extent,
              maxWidth: vertical ? null : extent,
              minHeight: vertical ? extent : null,
              maxHeight: vertical ? extent : null,
              child: Padding(
                padding: vertical
                    ? EdgeInsets.only(top: left, bottom: right)
                    : EdgeInsetsDirectional.only(start: left, end: right),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PositionedDirectional(
                      top: -2.8,
                      end: -3,
                      child: GlassContentPresence(
                        presence: progress,
                        blur: contentBlur,
                        child: GlassBadgeView(
                          badge: badge,
                          height: 18,
                          color: appearance.badgeColor,
                          textStyle: appearance.badgeTextStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _action(
    _ToolbarEntry entry,
    double left,
    double right,
    double progress,
    double height,
    double inset,
    GlassColors colors,
    Color foreground,
    GlassToolbarStyle appearance,
    bool vertical,
    double contentBlur,
    Alignment anchor,
  ) {
    final item = entry.item;
    final extent = entry.width + left + right;
    Widget cell = Builder(
      builder: (actionContext) => LiquidPrismPressable.glass(
        label: item.badge == null
            ? item.label
            : '${item.label}, ${item.badge!.semanticLabel}',
        selected: item.selected,
        motion: widget.motion ?? appearance.motion,
        onPressed: item.menu == null
            ? item.onPressed
            : !item._isEnabled
            ? null
            : () async {
                final result = await liquidMenus.show<Object?>(
                  context: actionContext,
                  menu: item.menu!,
                );
                if (actionContext.mounted) item.onMenuSelected?.call(result);
              },
        child: Builder(
          builder: (context) {
            final press = LiquidPrismPressFeedback.of(context);
            final color = !item._isEnabled
                ? colors.disabledLabel
                : item.foregroundColor ?? foreground;
            return SizedBox(
              width: vertical ? height : extent,
              height: vertical ? extent : height,
              child: Padding(
                padding: vertical
                    ? EdgeInsets.only(top: left, bottom: right)
                    : EdgeInsetsDirectional.only(start: left, end: right),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: vertical
                          ? EdgeInsets.symmetric(horizontal: inset)
                          : EdgeInsets.symmetric(vertical: inset),
                      child: ClipPath(
                        clipper: GlassShapeClipper(
                          appearance.itemShape ?? GlassShape.capsule,
                        ),
                        child: ColoredBox(
                          color:
                              (appearance.pressedColor ??
                                      colors.label.withValues(alpha: .12))
                                  .withValues(
                                    alpha:
                                        (appearance.pressedColor?.a ?? .12) *
                                        press,
                                  ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    IconTheme.merge(
                      // Native symbol image views enlarge their source images.
                      // 22-point Cupertino glyphs leave too much visible space
                      // between actions despite matching native item centers.
                      data: IconThemeData(
                        color: color,
                        size: appearance.iconSize ?? 25.5,
                      ),
                      child: item.icon,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (progress < 1) {
      // The slot grows or shrinks so the capsule resizes and neighbours slide
      // together, while the item itself holds its final size and place: it is
      // laid out whole against the edge of its slot on the group's fixed side
      // (see _observeEdges) and only blurs and fades,
      // as glass content does in the shared transition. The capsule's own clip
      // bounds it; nothing scales, slides or crops the glyph.
      cell = IgnorePointer(
        ignoring: entry.leaving,
        child: ExcludeSemantics(
          excluding: entry.leaving,
          child: SizedBox(
            width: vertical ? null : extent * progress,
            height: vertical ? extent * progress : null,
            child: OverflowBox(
              alignment: anchor,
              minWidth: vertical ? null : 0,
              maxWidth: vertical ? null : double.infinity,
              minHeight: vertical ? 0 : null,
              maxHeight: vertical ? double.infinity : null,
              child: GlassContentPresence(
                presence: progress,
                blur: contentBlur,
                child: cell,
              ),
            ),
          ),
        ),
      );
    }
    return KeyedSubtree(key: entry.key, child: cell);
  }
}
