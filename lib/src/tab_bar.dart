import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'foreground.dart';
import 'material.dart';
import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'style.dart';
import 'selection.dart';
import 'tab_bar_style.dart';
import 'theme.dart';

@immutable
final class LiquidPrismTab {
  const LiquidPrismTab({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  /// Accessible name, including when visual labels are hidden.
  final String label;

  /// Any Flutter widget: Icon, Image, SVG or a custom painter.
  final Widget icon;
  final Widget? selectedIcon;
}

/// A controlled tab bar with a draggable, velocity-preserving selection pill.
/// Dragging previews a destination; [onSelected] fires once on release. The
/// parent's [selectedIndex] is authoritative, including rejected selections.
class LiquidPrismTabBar extends StatefulWidget {
  const LiquidPrismTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.style,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
  }) : assert(tabs.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < tabs.length),
       assert(blur == null || (blur >= 0 && blur <= 12));
  final List<LiquidPrismTab> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final GlassTabBarStyle? style;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
  @override
  State<LiquidPrismTabBar> createState() => _LiquidPrismTabBarState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty<LiquidPrismTab>('tabs', tabs))
      ..add(IntProperty('selectedIndex', selectedIndex))
      ..add(DiagnosticsProperty<GlassTabBarStyle>('style', style))
      ..add(DiagnosticsProperty<Glass>('glass', glass))
      ..add(DiagnosticsProperty<LiquidPrismStyle>('optics', optics))
      ..add(DoubleProperty('blur', blur))
      ..add(DiagnosticsProperty<GlassMotion>('motion', motion))
      ..add(
        ObjectFlagProperty<ValueChanged<int>>.has('onSelected', onSelected),
      );
  }
}

class _LiquidPrismTabBarState extends State<LiquidPrismTabBar>
    with TickerProviderStateMixin {
  late final _position = AnimationController.unbounded(vsync: this);
  late final _contact = AnimationController.unbounded(vsync: this);
  late final _vertical = AnimationController.unbounded(vsync: this);
  bool _initialized = false, _rtl = false, _reduceMotion = false;
  bool _dragging = false, _cancelled = false, _committing = false;
  int? _pointer;
  final _contacts = <int>{};
  Offset _down = Offset.zero;
  double _grab = 0, _slotWidth = 1, _heldVelocity = 0;
  int _epoch = 0;
  final _focusNodes = <FocusNode>[];
  @override
  void initState() {
    super.initState();
    _syncFocus();
  }

  void _syncFocus() {
    while (_focusNodes.length < widget.tabs.length) {
      _focusNodes.add(FocusNode());
    }
    while (_focusNodes.length > widget.tabs.length) {
      _focusNodes.removeLast().dispose();
    }
  }

  void _keyboardSelect(int index) {
    if (widget.onSelected == null) return;
    _focusNodes[index].requestFocus();
    _commit(index);
  }

  GlassMotion get _motion =>
      widget.motion ??
      LiquidPrismTheme.of(context).motion ??
      const GlassMotion(pressScale: 1.08);
  GlassTabBarStyle get _style =>
      (LiquidPrismTheme.of(context).tabBar ?? const GlassTabBarStyle()).merge(
        widget.style,
      );
  double _physical(int index) =>
      (_rtl ? widget.tabs.length - 1 - index : index).toDouble();
  int _logical(double position) {
    final slot = position.round().clamp(0, widget.tabs.length - 1);
    return _rtl ? widget.tabs.length - 1 - slot : slot;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!_initialized || rtl != _rtl) {
      _rtl = rtl;
      _reset();
    }
    _initialized = true;
    _reduceMotion = reduced;
    if (reduced) {
      if (!_dragging) _position.value = _physical(widget.selectedIndex);
      _contact.value = _pointer == null || _cancelled ? 0 : 1;
      _vertical.value = 0;
    }
  }

  @override
  void didUpdateWidget(LiquidPrismTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocus();
    if (widget.tabs.length != oldWidget.tabs.length ||
        widget.onSelected == null) {
      _reset();
    } else if (widget.selectedIndex != oldWidget.selectedIndex) {
      if (!_committing && _pointer != null) _cancelled = true;
      _dragging = false;
      _settle();
    }
  }

  void _reset() {
    _epoch++;
    _cancelled = true;
    _dragging = false;
    _pointer = null;
    _position.value = _physical(widget.selectedIndex);
    _contact.value = 0;
    _vertical.value = 0;
  }

  void _settle({double? velocity}) {
    springGlass(
      _position,
      _physical(widget.selectedIndex),
      _motion.spring,
      velocity: velocity,
      immediate: _reduceMotion,
    );
    springGlass(_vertical, 0, _motion.spring, immediate: _reduceMotion);
  }

  void _feedback(bool held) => springGlass(
    _contact,
    held ? 1 : 0,
    held ? _motion.pressSpring : _motion.spring,
    immediate: _reduceMotion,
  );

  void _commit(int index, {double? velocity}) {
    if (widget.onSelected == null) return;
    final epoch = _epoch;
    final settleVelocity = velocity ?? _position.velocity;
    _committing = true;
    if ((_style.haptics ?? true) && index != widget.selectedIndex) {
      unawaited(HapticFeedback.selectionClick());
    }
    widget.onSelected!(index);
    _committing = false;
    // Reconcile after the parent has had a frame to accept or reject the action.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && epoch == _epoch && _pointer == null) {
        _settle(velocity: settleVelocity);
      }
    });
    if (mounted) setState(() {});
  }

  void _pointerDown(PointerDownEvent event) {
    _contacts.add(event.pointer);
    if (_contacts.length > 1) {
      _cancelled = true;
      _dragging = false;
      _feedback(false);
      _settle();
      return;
    }
    if (widget.onSelected == null || (event.buttons & kPrimaryButton) == 0) {
      return;
    }
    _epoch++;
    _pointer = event.pointer;
    _cancelled = false;
    _down = event.localPosition;
    _grab = _position.value;
    _heldVelocity = _position.velocity;
    _position.stop();
    _feedback(true);
  }

  void _pointerUp(PointerEvent event) {
    _contacts.remove(event.pointer);
    if (_pointer != event.pointer) return;
    _pointer = null;
    _feedback(false);
    if (event is PointerCancelEvent) {
      _cancelled = true;
      _dragging = false;
      _settle();
    }
  }

  double _resisted(double value, double maximum) {
    final bound = value.clamp(0.0, maximum);
    final excess = value - bound;
    return bound + excess / (1 + excess.abs() * 8);
  }

  void _drag(Offset location) {
    if (_cancelled || _slotWidth <= 0) return;
    if (!_dragging) _feedback(true);
    _dragging = true;
    _position.value = _resisted(
      _grab + (location.dx - _down.dx) / _slotWidth,
      (widget.tabs.length - 1).toDouble(),
    );
    _vertical.value = _reduceMotion
        ? 0
        : 4 *
              ((location.dy - _down.dy) /
                  (36 + (location.dy - _down.dy).abs()));
  }

  void _dragEnd(DragEndDetails details) {
    if (_cancelled || !_dragging) {
      _settle();
      return;
    }
    _dragging = false;
    final velocity = (details.primaryVelocity ?? 0) / _slotWidth;
    final projected = _position.value + velocity * _motion.dragProjection;
    _commit(_logical(projected), velocity: velocity);
  }

  @override
  void deactivate() {
    _cancelled = true;
    _pointer = null;
    _dragging = false;
    _contacts.clear();
    _position.stop();
    _contact.stop();
    _vertical.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _reset();
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    _position.dispose();
    _contact.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = LiquidPrismTheme.colorsOf(context);
    final style = _style;
    final accent =
        style.selectedColor ??
        LiquidPrismTheme.of(context).foregroundColor ??
        LiquidPrismTheme.tintOf(context);
    final padding =
        style.padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final labels = style.labelBehavior ?? GlassTabLabelBehavior.always;
    final iconSize = style.iconSize ?? 25;
    final textStyle = const TextStyle(
      fontSize: 10,
      height: 1.2,
    ).merge(style.labelStyle);
    final textHeight =
        MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 10) *
        (textStyle.height ?? 1.2);
    final height = math.max(
      style.height ?? 54,
      iconSize +
          (labels == GlassTabLabelBehavior.never ? 0 : textHeight + 2) +
          8,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - padding.horizontal) / widget.tabs.length;
        if (!width.isFinite || width <= 0) return const SizedBox.shrink();
        if (width != _slotWidth) {
          _slotWidth = width;
          if (_pointer != null || _dragging) _reset();
        }
        final content = Row(
          children: [
            for (var index = 0; index < widget.tabs.length; index++)
              Expanded(
                child: _tab(
                  index,
                  height,
                  iconSize,
                  textStyle,
                  labels,
                  colors,
                  accent,
                  style,
                ),
              ),
          ],
        );
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _pointerDown,
          onPointerUp: _pointerUp,
          onPointerCancel: _pointerUp,
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.onSelected == null
                ? null
                : (details) {
                    if (!_cancelled) {
                      _commit(
                        _logical(
                          (details.localPosition.dx - padding.left) / width -
                              .5,
                        ),
                        velocity: _heldVelocity,
                      );
                    }
                  },
            onTapCancel: () {
              if (!_dragging) {
                _feedback(false);
                _settle();
              }
            },
            onHorizontalDragStart: widget.onSelected == null
                ? null
                : (details) => _drag(details.localPosition),
            onHorizontalDragUpdate: widget.onSelected == null
                ? null
                : (details) => _drag(details.localPosition),
            onHorizontalDragEnd: widget.onSelected == null ? null : _dragEnd,
            onHorizontalDragCancel: () {
              if (_pointer == null && !_dragging) return;
              _dragging = false;
              _cancelled = true;
              _feedback(false);
              _settle();
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_position, _contact, _vertical]),
              child: content,
              builder: (context, child) {
                final contact = _contact.value.clamp(0.0, 1.0);
                final scale = _reduceMotion
                    ? 1.0
                    : 1 + (_motion.pressScale - 1) * contact;
                return Transform.translate(
                  offset: Offset(0, _vertical.value * .2),
                  child: LiquidPrismPressFeedback(
                    progress: contact,
                    child: LiquidPrism(
                      glass: widget.glass,
                      optics: widget.optics,
                      blur: widget.blur,
                      shape: style.shape,
                      role: GlassRole.tabBar,
                      child: Padding(
                        padding: padding,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: -4,
                              top: 0,
                              width: width + 8,
                              height: height,
                              child: Transform.translate(
                                offset: Offset(
                                  _position.value * width,
                                  _vertical.value,
                                ),
                                // Grow the pill by size, not by a scale
                                // transform above its backdrop filter.
                                child: OverflowBox(
                                  maxWidth: (width + 8) * scale,
                                  maxHeight:
                                      height *
                                      (_reduceMotion ? 1 : 1 + .06 * contact),
                                  child: LiquidPrismSelection(
                                    selected: true,
                                    shape:
                                        style.selectionShape ??
                                        GlassShape.capsule,
                                    color: style.selectionColor,
                                    blur: style.selectionBlur ?? 2,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                            child!,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _tab(
    int index,
    double height,
    double iconSize,
    TextStyle labelStyle,
    GlassTabLabelBehavior labels,
    GlassColors colors,
    Color accent,
    GlassTabBarStyle style,
  ) {
    final selected = widget.selectedIndex == index;
    final enabled = widget.onSelected != null;
    final tab = widget.tabs[index];
    final icon = selected ? tab.selectedIcon ?? tab.icon : tab.icon;
    final calibrated =
        selected &&
        enabled &&
        style.selectedColor == null &&
        LiquidPrismTheme.of(context).foregroundColor == null;
    final selectedAccent = calibrated
        ? restingGlassAccent(accent, colors.brightness)
        : accent;
    final color = !enabled
        ? colors.disabledLabel
        : selected
        ? selectedAccent
        : style.unselectedColor ?? colors.label;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme.merge(
          data: IconThemeData(size: iconSize, color: color),
          child: icon,
        ),
        if (labels != GlassTabLabelBehavior.never &&
            (labels != GlassTabLabelBehavior.selected || selected)) ...[
          const SizedBox(height: 2),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle.copyWith(
              color: labelStyle.color ?? color,
              fontWeight:
                  labelStyle.fontWeight ??
                  (selected ? FontWeight.w600 : FontWeight.w500),
            ),
          ),
        ],
      ],
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: tab.label,
      excludeSemantics: true,
      onTap: enabled ? () => _commit(index) : null,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (enabled) {
              _keyboardSelect(
                (index + (_rtl ? -1 : 1)).clamp(0, widget.tabs.length - 1),
              );
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (enabled) {
              _keyboardSelect(
                (index + (_rtl ? 1 : -1)).clamp(0, widget.tabs.length - 1),
              );
            }
          },
        },
        child: FocusableActionDetector(
          focusNode: _focusNodes[index],
          enabled: enabled,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _commit(index);
                return null;
              },
            ),
          },
          child: SizedBox(
            height: height,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
