import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/prism_pressable.dart';
import 'package:liquid_prism/src/core/prism_badge.dart';
import 'package:liquid_prism/src/core/prism_colors.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/menu/menus.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar_content.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar_style.dart';
import 'package:liquid_prism/src/navigation/scaffold/chrome_placement.dart';
import 'package:liquid_prism/src/rendering/chrome_material.dart';
import 'package:liquid_prism/src/rendering/prism_transition.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/theme/foreground.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// A navigation capsule that pops the current route by default.
class PrismBackButton extends StatelessWidget {
  /// Creates a back or close navigation button.
  const new({
    super.key,
    this.close = false,
    this.icon,
    this.label,
    this.onPressed,
    this.size = PrismToolbarSize.navigation,
    this.style,
  });

  /// Whether to display a close glyph instead of a back chevron.
  final bool close;

  /// Icon widget displayed for this action or destination.
  final Widget? icon;

  /// Accessible name; defaults to Back or Close.
  final String? label;

  /// Callback override; null pops the nearest navigator.
  final VoidCallback? onPressed;

  /// Toolbar sizing preset.
  final PrismToolbarSize size;

  /// Local appearance overrides merged over the component theme.
  final PrismToolbarStyle? style;

  @override
  Widget build(BuildContext context) {
    final appearance =
        (PrismTheme.of(context).toolbar ?? const PrismToolbarStyle()).merge(
          style,
        );
    final Widget glyph;
    if (close) {
      glyph = icon ?? appearance.closeIcon ?? const Icon(CupertinoIcons.xmark);
    } else {
      final shift = appearance.backIconShift ?? .5;
      final mirrors = appearance.backIconMirrors ?? true;
      final rtl = Directionality.of(context) == TextDirection.rtl;
      glyph = Transform.translate(
        offset: Offset(mirrors && rtl ? shift : -shift, 0),
        child:
            icon ??
            appearance.backIcon ??
            const Icon(CupertinoIcons.chevron_back),
      );
    }
    return PrismToolbar.group(
      size: size,
      style: style,

      items: [
        PrismToolbarItem(
          icon: glyph,
          label: label ?? (close ? 'Close' : 'Back'),
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

/// Typed toolbar content arranged in animated glass capsules.
class PrismToolbar extends StatefulWidget {
  /// Creates a toolbar from typed content.
  const new({
    super.key,
    required this.content,
    this.axis,
    this.size,
    this.style,
  }) : items = null;

  /// Creates a single capsule with animated item insertion and removal.
  const new group({
    super.key,
    required List<PrismToolbarItem> this.items,
    this.axis,
    this.size,
    this.style,
  }) : content = const [];

  /// Items displayed in a capsule when using [PrismToolbar.group].
  final List<PrismToolbarItem>? items;

  /// Ordered toolbar content.
  final List<PrismToolbarContent> content;

  /// Toolbar sizing preset.
  final PrismToolbarSize? size;

  /// Local appearance overrides merged over the component theme.
  final PrismToolbarStyle? style;

  /// Bar axis; null inherits the scaffold axis, then horizontal.
  final Axis? axis;

  @override
  State<PrismToolbar> createState() => _PrismToolbarState();
}

class _ToolbarGroupPresenceOwner extends InheritedWidget {
  const new({required this.group, required super.child});
  final Widget group;
  @override
  bool updateShouldNotify(_ToolbarGroupPresenceOwner oldWidget) =>
      group != oldWidget.group;
}

class _PrismToolbarState extends State<PrismToolbar>
    with TickerProviderStateMixin {
  final _presence = <RetargetablePrismSpring>[];
  bool _synced = false;
  bool _regrouping = false;

  PrismToolbarStyle get _appearance =>
      (PrismTheme.of(context).toolbar ?? const PrismToolbarStyle()).merge(
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
  void didUpdateWidget(PrismToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _regrouping = _regroups(oldWidget.content);
    _sync(animated: !_regrouping);
  }

  List<PrismToolbarContent> get _content =>
      prismToolbarSegments(widget.content);

  bool _regroups(List<PrismToolbarContent> previous) {
    final before = prismToolbarSegments(previous);
    final after = _content;
    if ([...before, ...after].any((entry) => entry is! PrismToolbarGroup)) {
      return false;
    }
    final oldGroups = before.cast<PrismToolbarGroup>();
    final newGroups = after.cast<PrismToolbarGroup>();
    if ([...oldGroups, ...newGroups].any(
      (group) => group.items.any(
        (item) =>
            item.key == null && (item.child != null || item.label.isEmpty),
      ),
    )) {
      return false;
    }
    List<Key> identities(List<PrismToolbarGroup> groups) => [
      for (final group in groups)
        for (final item in group.items) item.key ?? ValueKey(item.label),
    ];
    return listEquals(identities(oldGroups), identities(newGroups)) &&
        !listEquals(
          [for (final group in oldGroups) (group.key, group.items.length)],
          [for (final group in newGroups) (group.key, group.items.length)],
        );
  }

  void _sync({required bool animated}) {
    final content = _content;
    while (_presence.length < content.length) {
      _presence.add(
        RetargetablePrismSpring(vsync: this)..addStatusListener((status) {
          if (status.isCompleted || status.isDismissed) setState(() {});
        }),
      );
    }
    while (_presence.length > content.length) {
      _presence.removeLast().dispose();
    }
    for (var i = 0; i < content.length; i++) {
      final entry = content[i];
      final appearance = _appearance.merge(
        entry is PrismToolbarGroup ? entry.style : null,
      );
      final immediate =
          !animated ||
          appearance.itemTransition == PrismTransition.identity ||
          MediaQuery.disableAnimationsOf(context);
      final transition =
          (PrismTheme.of(context).transition ?? const PrismTransitionStyle())
              .merge(appearance.itemTransitionStyle);
      final target =
          (content[i] is PrismToolbarGroup &&
              (content[i] as PrismToolbarGroup).items.isEmpty)
          ? 0.0
          : 1.0;
      final spring = _presence[i];
      if (spring.value == target && !spring.isAnimating) continue;
      springPrism(
        spring,
        target,
        target > 0
            ? transition.enterSpring?.description ??
                  SpringDescription.withDurationAndBounce(
                    duration: const Duration(milliseconds: 280),
                  )
            : transition.exitSpring?.description ??
                  SpringDescription.withDurationAndBounce(
                    duration: const Duration(milliseconds: 280),
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
    final items = widget.items;
    if (items != null) {
      return _ToolbarCapsule(
        items: items,
        axis: widget.axis,
        size: widget.size,
        style: widget.style,
      );
    }
    final vertical =
        (widget.axis ?? PrismChrome.maybeOf(context)?.axis) == Axis.vertical;
    final spacing = _appearance.groupSpacing ?? 8.0;
    final content = _content;
    return AnimatedBuilder(
      animation: Listenable.merge(_presence),
      builder: (context, _) {
        final children = <Widget>[];
        var before = 0.0;
        for (var i = 0; i < content.length; i++) {
          final spring = _presence[i];
          final presence = spring.value.clamp(0.0, 1.0);
          if (presence <= 0 && !spring.isAnimating) continue;
          final gap = spacing * before;
          before = math.max(before, presence);
          final entry = content[i];
          if (entry case PrismToolbarSpacer(:final extent, :final flex)) {
            children.add(
              extent != null
                  ? SizedBox(
                      width: vertical ? 0 : extent,
                      height: vertical ? extent : 0,
                    )
                  : Spacer(flex: flex),
            );
            before = 0;
            continue;
          }
          var group = switch (entry) {
            PrismToolbarGroup(:final items, :final style) => _ToolbarCapsule(
              key: entry.key,
              items: items,
              size: widget.size,
              style: (widget.style ?? const PrismToolbarStyle())
                  .merge(style)
                  .copyWith(
                    itemTransition: _regrouping
                        ? PrismTransition.identity
                        : null,
                  ),
              axis: widget.axis,
            ),
            PrismToolbarItem(:final child, :final width) => SizedBox(
              key: entry.key,
              width: vertical ? null : width,
              height: vertical ? width : null,
              child: child,
            ),
            PrismToolbarSpacer() => const SizedBox.shrink(),
          };
          final appearance = _appearance.merge(
            entry is PrismToolbarGroup ? entry.style : null,
          );
          final transition =
              (PrismTheme.of(context).transition ??
                      const PrismTransitionStyle())
                  .merge(appearance.itemTransitionStyle);
          group = PrismPresence(
            progress: spring,
            contentBlur: transition.contentBlur ?? 4,
            materialize: !MediaQuery.disableAnimationsOf(context),
            child: _ToolbarGroupPresenceOwner(group: group, child: group),
          );
          group = Padding(
            padding: vertical
                ? EdgeInsets.only(top: gap)
                : EdgeInsetsDirectional.only(start: gap),
            child: group,
          );
          if (presence < 1) {
            group = IgnorePointer(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: vertical ? 1 : presence,
                heightFactor: vertical ? presence : 1,
                child: group,
              ),
            );
          }
          children.add(
            KeyedSubtree(key: entry.key ?? ValueKey<int>(i), child: group),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final bounded = vertical
                ? constraints.hasBoundedHeight
                : constraints.hasBoundedWidth;
            if (children.length == 1 && children.single is! Spacer) {
              return children.single;
            }
            final flexible = children.any((child) => child is Spacer);
            final layout = Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              mainAxisSize: flexible && bounded
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                for (final child in children)
                  if (child is Spacer)
                    if (bounded)
                      Spacer(flex: child.flex)
                    else
                      const SizedBox.shrink()
                  else
                    child,
              ],
            );
            return flexible
                ? layout
                : SingleChildScrollView(
                    clipBehavior: Clip.none,
                    scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
                    child: layout,
                  );
          },
        );
      },
    );
  }
}

class _ToolbarCapsule extends StatefulWidget {
  const new({super.key, required this.items, this.size, this.style, this.axis});
  final List<PrismToolbarItem> items;
  final PrismToolbarSize? size;
  final PrismToolbarStyle? style;

  final Axis? axis;

  @override
  State<_ToolbarCapsule> createState() => _PrismToolbarGroupState();
}

class _ToolbarEntry {
  new(this.key, this.item, this.presence);
  final Key key;
  PrismToolbarItem item;
  final RetargetablePrismSpring presence;
  bool leaving = false;

  double width = 38;
}

class _PrismToolbarGroupState extends State<_ToolbarCapsule>
    with TickerProviderStateMixin {
  final _entries = <_ToolbarEntry>[];
  bool _synced = false;

  bool? _fixedRight;
  bool? _fixedBottom;
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

  Alignment _itemAnchor(bool vertical) {
    if (vertical) {
      return (_fixedBottom ?? false)
          ? Alignment.bottomCenter
          : Alignment.topCenter;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return (_fixedRight ?? !rtl) ? Alignment.centerRight : Alignment.centerLeft;
  }

  PrismToolbarStyle get _appearance =>
      (PrismTheme.of(context).toolbar ?? const PrismToolbarStyle()).merge(
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
  void didUpdateWidget(_ToolbarCapsule oldWidget) {
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

  static Key _keyFor(PrismToolbarItem item, Set<Key> used) {
    var key = item.key ?? ValueKey<String>(item.label);
    for (var n = 2; used.contains(key); n++) {
      key = ValueKey<String>('${item.label}#$n');
    }
    used.add(key);
    return key;
  }

  _ToolbarEntry _entry(Key key, PrismToolbarItem item, double presence) {
    final spring = RetargetablePrismSpring(vsync: this)..value = presence;
    final entry = _ToolbarEntry(key, item, spring);
    spring.addStatusListener((status) {
      if (!mounted) return;
      if (entry.leaving && status.isDismissed) {
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

  bool _hidden = true;

  void _sync({required bool animated}) {
    final items = widget.items;
    if (items.isEmpty) {
      _hidden = true;
      return;
    }
    final immediate =
        !animated ||
        _hidden ||
        _appearance.itemTransition == PrismTransition.identity ||
        MediaQuery.disableAnimationsOf(context);
    _hidden = false;
    final transition =
        (PrismTheme.of(context).transition ?? const PrismTransitionStyle())
            .merge(_appearance.itemTransitionStyle);
    final enter =
        transition.enterSpring?.description ??
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 280),
        );
    final exit =
        transition.exitSpring?.description ??
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 280),
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
          springPrism(existing.presence, 1, enter, immediate: immediate);
        }
        next.add(existing);
      } else {
        final entry = _entry(keys[i], items[i], immediate ? 1 : 0);
        if (!immediate) springPrism(entry.presence, 1, enter);
        next.add(entry);
      }
    }
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (!byKey.containsKey(entry.key)) continue;
      if (immediate) {
        entry.presence.dispose();
        continue;
      }
      if (!entry.leaving) {
        entry.leaving = true;
        springPrism(entry.presence, 0, exit);
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
        (widget.axis ?? PrismChrome.maybeOf(context)?.axis) == Axis.vertical;
    final theme = PrismTheme.of(context);
    final colors = PrismColors.of(context);
    final appearance = _appearance;
    final placement = widget.size ?? appearance.size ?? PrismToolbarSize.bottom;
    final navigation = placement == PrismToolbarSize.navigation;
    final height = appearance.height ?? (navigation ? 44.0 : 48.0);
    final inset = appearance.inset ?? (navigation ? 4.0 : 5.0);
    final gap = appearance.spacing ?? (navigation ? 16.0 : 14.0);
    final foreground =
        appearance.foregroundColor ??
        theme.foregroundColor ??
        prismAccent(PrismTheme.tintOf(context), colors.brightness);
    final present = [
      for (final entry in _entries)
        if (!entry.leaving) entry,
    ];
    final widths = [
      for (final entry in present)
        prismToolbarItemExtent(
          context,
          entry.item,
          appearance,
          lone: present.length == 1,
          height: height,
          inset: inset,
          vertical: vertical,
        ),
    ];
    for (var i = 0; i < present.length; i++) {
      present[i].width = widths[i];
    }
    final presence = present.isEmpty
        ? const <RetargetablePrismSpring>[]
        : [for (final entry in _entries) entry.presence];
    return AnimatedBuilder(
      animation: Listenable.merge(presence),
      builder: (context, _) {
        _observeEdges();
        final anchor = _itemAnchor(vertical);
        final contentBlur =
            (theme.transition ?? const PrismTransitionStyle())
                .merge(appearance.itemTransitionStyle)
                .contentBlur ??
            4;
        var width = 0.0;
        final cells = <Widget>[];
        final badges = <Widget>[];
        final badged = _entries.any((entry) => entry.item.badge != null);
        var position = 0;
        for (final entry in _entries) {
          final double left;
          final double right;
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
                inset,
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
          role: PrismRole.toolbar,
          glass: appearance.glass,
          optics: appearance.optics,
          blur: appearance.blur,
          shape: appearance.shape,
          child: ClipPath(
            clipper: PrismShapeClipper(appearance.shape ?? PrismShape.capsule),
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
          capsule = Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: capsule),
              Positioned.fill(
                child: Builder(
                  builder: (context) => Transform.scale(
                    scale: PrismPressFeedback.scaleOf(context),
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
        final body = widget.items.every((item) => !item.isEnabled)
            ? capsule
            : _withFeedback(capsule, width, appearance, theme);
        final owner = context
            .dependOnInheritedWidgetOfExactType<_ToolbarGroupPresenceOwner>();
        if (identical(owner?.group, widget)) {
          final hidden = widget.items.isEmpty;
          return IgnorePointer(
            ignoring: hidden,
            child: ExcludeSemantics(
              excluding: hidden,
              child: ExcludeFocus(excluding: hidden, child: body),
            ),
          );
        }
        return PrismVisibility(
          visible: widget.items.isNotEmpty,
          transition: appearance.itemTransition ?? PrismTransition.materialize,
          style: appearance.itemTransitionStyle,
          child: body,
        );
      },
    );
  }

  Widget _withFeedback(
    Widget capsule,
    double width,
    PrismToolbarStyle appearance,
    PrismThemeData theme,
  ) {
    final customMotion = appearance.motion ?? theme.motion;
    return PrismPressable.feedback(
      motion: customMotion,
      child: Builder(
        builder: (context) {
          final scale = PrismPressFeedback.scaleOf(context);
          return PrismPressFeedback(
            progress: PrismPressFeedback.of(context),
            scale: customMotion == null && width > 0
                ? 1 + (scale - 1) * (16 / width / .1126)
                : scale,
            child: capsule,
          );
        },
      ),
    );
  }

  Widget _badge(
    _ToolbarEntry entry,
    double extent,
    double left,
    double right,
    double progress,
    double height,
    PrismToolbarStyle appearance,
    bool vertical,
    double contentBlur,
    Alignment anchor,
    double inset,
  ) {
    final badge = entry.item.badge;
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
                      top: -2.8 - (vertical ? left : 0),
                      end: vertical ? inset - 3 : -3,
                      child: Builder(
                        builder: (context) => PrismContentPresence(
                          presence: progress * PrismPresence.of(context),
                          blur:
                              PrismPresence.maybeData(context)?.contentBlur ??
                              contentBlur,
                          child: PrismBadgeView(
                            badge: badge,
                            height: 18,
                            color: appearance.badgeColor,
                            textStyle: appearance.badgeTextStyle,
                          ),
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
    PrismColors colors,
    Color foreground,
    PrismToolbarStyle appearance,
    bool vertical,
    double contentBlur,
    Alignment anchor,
  ) {
    final item = entry.item;
    final extent = entry.width + left + right;
    var cell = item.child != null
        ? SizedBox(
            width: vertical ? height : extent,
            height: vertical ? extent : height,
            child: Padding(
              padding: vertical
                  ? EdgeInsets.only(top: left, bottom: right)
                  : EdgeInsetsDirectional.only(start: left, end: right),
              child: Center(child: item.child),
            ),
          )
        : Builder(
            builder: (actionContext) => PrismPressable.glass(
              label: item.badge == null
                  ? item.label
                  : '${item.label}, ${item.badge!.semanticLabel}',
              selected: item.selected,
              motion: appearance.motion,
              onPressed: item.menu == null
                  ? item.onPressed
                  : !item.isEnabled
                  ? null
                  : () async {
                      final result = await prismMenus.show<Object?>(
                        context: actionContext,
                        menu: item.menu!,
                      );
                      if (actionContext.mounted) {
                        item.onMenuSelected?.call(result);
                      }
                    },
              child: Builder(
                builder: (context) {
                  final press = PrismPressFeedback.of(context);
                  final color = !item.isEnabled
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
                          if (appearance.pressedColor case final pressedColor?)
                            Padding(
                              padding: vertical
                                  ? EdgeInsets.symmetric(horizontal: inset)
                                  : EdgeInsets.symmetric(vertical: inset),
                              child: ClipPath(
                                clipper: PrismShapeClipper(
                                  appearance.itemShape ?? PrismShape.capsule,
                                ),
                                child: ColoredBox(
                                  color: pressedColor.withValues(
                                    alpha: pressedColor.a * press,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          IconTheme.merge(
                            data: IconThemeData(
                              color: color,
                              size: appearance.iconSize ?? 25.5,
                            ),
                            child:
                                item.icon ??
                                DefaultTextStyle(
                                  style: prismToolbarTextStyle(
                                    context,
                                    appearance,
                                  ).copyWith(color: color),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  child: Text(item.label),
                                ),
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
              child: PrismContentPresence(
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
