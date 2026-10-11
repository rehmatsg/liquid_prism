import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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

  /// Any Flutter widget: Icon, Image, SVG or a custom painter. Icons must not
  /// contain repaint boundaries: the selection window paints them twice.
  final Widget icon;
  final Widget? selectedIcon;
}

/// A controlled tab bar with a draggable, velocity-preserving selection pill.
///
/// Touching any tab lifts the pill into a glass lens and glides it to that
/// tab; dragging makes the lens chase the finger and stretch with its speed.
/// [onSelected] fires once on release. The parent's [selectedIndex] is
/// authoritative, including rejected selections, and the pill settles back.
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
  /// Pill centre in slot units.
  late final _position = AnimationController.unbounded(vsync: this);

  /// 0 resting pill, 1 lifted lens.
  late final _lift = AnimationController.unbounded(vsync: this);
  late final _barScale = AnimationController.unbounded(vsync: this, value: 1);
  late final _itemScale = AnimationController.unbounded(vsync: this, value: 1);
  late final _glow = AnimationController.unbounded(vsync: this);

  /// Logical pixels added along the travel axis and removed across it.
  late final _stretch = AnimationController.unbounded(vsync: this);

  /// Release ripple of the halo: 0 at release, 1 when gone.
  late final _halo = AnimationController(
    vsync: this,
    duration: NativeMotion.haloRelease,
    value: 1,
  );
  late final _vertical = AnimationController.unbounded(vsync: this);

  /// True while the selected colour must follow the pill instead of the
  /// committed tab: the icons under the lens are recoloured by position.
  final _window = ValueNotifier<bool>(false);
  bool _initialized = false, _rtl = false, _reduceMotion = false;
  bool _dragging = false, _cancelled = false, _committing = false;
  int? _pointer;
  final _contacts = <int>{};
  Offset _down = Offset.zero;
  double _slotWidth = 1, _padLeft = 0, _fingerSlot = 0;
  int _epoch = 0;
  final _focusNodes = <FocusNode>[];
  @override
  void initState() {
    super.initState();
    _syncFocus();
    _position.addListener(_followVelocity);
    _lift.addListener(_updateWindow);
    _position.addListener(_updateWindow);
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
      const GlassMotion();
  GlassTabBarStyle get _style =>
      (LiquidPrismTheme.of(context).tabBar ?? const GlassTabBarStyle()).merge(
        widget.style,
      );
  bool get _spatial => !_reduceMotion && _motion.pressScale > 1;

  /// Lift strength relative to the measured default: `pressScale` scales the
  /// lens inset, the bar scale and the item scale together; 1 disables them.
  double get _liftFactor =>
      ((_motion.pressScale - 1) / (const GlassMotion().pressScale - 1)).clamp(
        0.0,
        2.0,
      );
  double _physical(int index) =>
      (_rtl ? widget.tabs.length - 1 - index : index).toDouble();
  int _logical(double position) {
    final slot = position.round().clamp(0, widget.tabs.length - 1);
    return _rtl ? widget.tabs.length - 1 - slot : slot;
  }

  /// Finger position in slot units, resisted past the end tabs.
  double _slotAt(double dx) => _resisted(
    (dx - _padLeft) / _slotWidth - .5,
    (widget.tabs.length - 1).toDouble(),
  );

  void _updateWindow() {
    final away =
        (_position.value - _physical(widget.selectedIndex)).abs() > .001;
    final active = _pointer != null || _lift.value > .001 || away;
    if (_window.value != active) _window.value = active;
  }

  /// Stretch chases the lens speed; the short bouncy filter lets a sudden stop
  /// bulge the pill across the travel axis before it settles.
  double _stretchTarget = 0;
  void _followVelocity() {
    if (!_spatial) return;
    final speed = (_position.velocity * _slotWidth).abs();
    final target = math.min(
      NativeMotion.stretchLimit,
      NativeMotion.stretchPerSpeed * speed,
    );
    if ((target - _stretchTarget).abs() < .25 && _stretch.isAnimating) return;
    _stretchTarget = target;
    springGlass(_stretch, target, NativeMotion.stretchFilter);
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
      final held = _pointer != null && !_cancelled;
      _lift.value = 0;
      _barScale.value = 1;
      _itemScale.value = 1;
      _stretch.value = 0;
      _halo.value = 1;
      _glow.value = held ? 1 : 0;
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
    _updateWindow();
  }

  void _reset() {
    _epoch++;
    _cancelled = true;
    _dragging = false;
    _pointer = null;
    _position.value = _physical(widget.selectedIndex);
    _lift.value = 0;
    _barScale.value = 1;
    _itemScale.value = 1;
    _glow.value = 0;
    _stretch.value = 0;
    _stretchTarget = 0;
    _halo.value = 1;
    _vertical.value = 0;
    _updateWindow();
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

  void _feedback(bool held) {
    final spatial = _spatial;
    final factor = _liftFactor;
    final releasing = !held && _lift.value > .5 && spatial;
    springGlass(
      _lift,
      held && spatial ? 1 : 0,
      held ? NativeMotion.liftIn : NativeMotion.liftOut,
      immediate: _reduceMotion,
    );
    springGlass(
      _barScale,
      held && spatial ? 1 + (NativeMotion.barScale - 1) * factor : 1,
      held ? NativeMotion.barScaleIn : NativeMotion.barScaleOut,
      immediate: _reduceMotion,
    );
    springGlass(
      _itemScale,
      held && spatial ? 1 + (NativeMotion.itemScale - 1) * factor : 1,
      held ? NativeMotion.itemScaleIn : NativeMotion.itemScaleOut,
      immediate: _reduceMotion,
    );
    springGlass(
      _glow,
      held ? 1 : 0,
      held ? NativeMotion.glowIn : NativeMotion.glowOut,
      immediate: _reduceMotion,
    );
    if (releasing) {
      _halo.forward(from: 0);
    } else if (held) {
      _halo.value = 1;
    }
  }

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
    // The pill glides to the touched tab on contact, before any release.
    _fingerSlot = _slotAt(event.localPosition.dx);
    final slot = _fingerSlot.roundToDouble().clamp(
      0.0,
      (widget.tabs.length - 1).toDouble(),
    );
    springGlass(_position, slot, _motion.spring, immediate: _reduceMotion);
    _feedback(true);
    _updateWindow();
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
    _updateWindow();
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
    _fingerSlot = _slotAt(location.dx);
    if (_reduceMotion) {
      _position.value = _fingerSlot;
    } else {
      springGlass(_position, _fingerSlot, NativeMotion.tracking);
    }
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
    final projected = _fingerSlot + velocity * _motion.dragProjection;
    _commit(_logical(projected), velocity: _position.velocity);
  }

  @override
  void deactivate() {
    _cancelled = true;
    _pointer = null;
    _dragging = false;
    _contacts.clear();
    for (final controller in _controllers) {
      controller.stop();
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _reset();
  }

  List<AnimationController> get _controllers => [
    _position,
    _lift,
    _barScale,
    _itemScale,
    _glow,
    _stretch,
    _halo,
    _vertical,
  ];

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    _window.dispose();
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
    final calibrated =
        widget.onSelected != null &&
        style.selectedColor == null &&
        LiquidPrismTheme.of(context).foregroundColor == null;
    final selectedAccent = calibrated
        ? restingGlassAccent(accent, colors.brightness)
        : accent;
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
    final selectionShape = style.selectionShape ?? GlassShape.capsule;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - padding.horizontal) / widget.tabs.length;
        if (!width.isFinite || width <= 0) return const SizedBox.shrink();
        _padLeft = padding.left;
        if (width != _slotWidth) {
          _slotWidth = width;
          if (_pointer != null || _dragging) _reset();
        }
        final barSize = Size(constraints.maxWidth, height + padding.vertical);
        final content = ValueListenableBuilder<bool>(
          valueListenable: _window,
          builder: (context, window, _) => Row(
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
                    selectedAccent,
                    style,
                    window: window,
                  ),
                ),
            ],
          ),
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
                        _logical(_slotAt(details.localPosition.dx)),
                        velocity: _position.velocity,
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
              animation: Listenable.merge([
                _position,
                _lift,
                _barScale,
                _glow,
                _stretch,
                _halo,
                _vertical,
                _window,
              ]),
              child: content,
              builder: (context, child) {
                final lift = _lift.value.clamp(0.0, 1.0);
                final stretch = _stretch.value;
                final drift = _vertical.value;
                // Pill in row coordinates: slightly wider than its slot, grown
                // by the lift inset and deformed by the stretch.
                final inset = NativeMotion.lensInset * lift * _liftFactor;
                final pillWidth = width + 8 + 2 * inset;
                final pillHeight = height + 2 * inset;
                final pill = Rect.fromCenter(
                  center: Offset(
                    _position.value * width + width / 2,
                    height / 2 + drift,
                  ),
                  width: pillWidth + stretch,
                  height: math.max(pillHeight - stretch, pillHeight * .6),
                );
                final window = _window.value
                    ? selectionShape.path(pill.size).shift(pill.topLeft)
                    : null;
                final barScale = _barScale.value;
                // The lens and halo sit outside the bar glass so that their
                // backdrop filters stay untransformed; their placement follows
                // the bar's scale about its own centre.
                final centre = barSize.center(Offset.zero);
                final pillOnBar = pill.shift(
                  padding.topLeft + Offset(0, drift * .2),
                );
                final lens = Rect.fromCenter(
                  center: centre + (pillOnBar.center - centre) * barScale,
                  width: pillOnBar.width * barScale,
                  height: pillOnBar.height * barScale,
                );
                final ripple = _halo.value;
                final haloLevel = _pointer != null && !_cancelled
                    ? lift
                    : (ripple < 1 ? (1 - ripple) : 0.0);
                final haloScale =
                    1 + (NativeMotion.haloReleaseScale - 1) * ripple;
                final bar = Transform.translate(
                  offset: Offset(0, drift * .2),
                  child: LiquidPrismPressFeedback(
                    progress:
                        _glow.value.clamp(0, 1) * NativeMotion.glowOpacity,
                    scale: barScale,
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
                            Positioned.fromRect(
                              rect: pill,
                              child: Opacity(
                                opacity: 1 - lift,
                                child: LiquidPrismSelection(
                                  selected: true,
                                  shape: selectionShape,
                                  color: style.selectionColor,
                                  blur: style.selectionBlur ?? 2,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                            _SelectionWindow(
                              path: window,
                              color: selectedAccent,
                              child: child!,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    bar,
                    if (haloLevel > .001)
                      Positioned.fromRect(
                        rect: Rect.fromCenter(
                          center: lens.center,
                          width: NativeMotion.haloDiameter * haloScale,
                          height: NativeMotion.haloDiameter * haloScale,
                        ),
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color.from(
                                    alpha: NativeMotion.haloOpacity * haloLevel,
                                    red: 1,
                                    green: 1,
                                    blue: 1,
                                  ),
                                  const Color(0x00FFFFFF),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (lift > .001)
                      Positioned.fromRect(
                        rect: lens,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: lift,
                            // The native lens face is ungraded: no glow.
                            child: LiquidPrismPressFeedback(
                              progress: 0,
                              child: LiquidPrism(
                                glass: Glass.clear,
                                optics: _lensOptics,
                                blur: 0,
                                shape: selectionShape,
                                role: GlassRole.tabBar,
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
    Color selectedAccent,
    GlassTabBarStyle style, {
    required bool window,
  }) {
    final selected = widget.selectedIndex == index;
    final enabled = widget.onSelected != null;
    final tab = widget.tabs[index];
    final icon = selected ? tab.selectedIcon ?? tab.icon : tab.icon;
    // While the selection window is active the base row is uniformly
    // unselected; the window repaints whatever lies under the pill in the
    // selected colour, so the colour travels with the lens.
    final color = !enabled
        ? colors.disabledLabel
        : selected && !window
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
            child: Center(
              child: AnimatedBuilder(
                animation: _itemScale,
                child: content,
                builder: (context, child) =>
                    Transform.scale(scale: _itemScale.value, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lifted lens: a thin refracting rim, no frost and no face grading, in
/// the proportions of the native 110 x 70 pt lens (edge from -14, displacement
/// 9 on the backdrop) rather than the package's default clear optics whose
/// wide band would mirror the icons inside a lens this small.
const _lensOptics = LiquidPrismStyle(
  edgeWidth: 12,
  refraction: 14,
  frost: 0,
  dispersion: 0.08,
  brightness: 0,
  tint: Color(0x00000000),
  saturation: 1,
  reflection: 0.12,
  reflectionReach: 20,
  splay: 0.1,
  cornerRadius: 10000,
);

/// Paints its child once, then again clipped to [path] with every pixel
/// recoloured to [color]: the selected tint shows wherever the pill is.
class _SelectionWindow extends SingleChildRenderObjectWidget {
  const _SelectionWindow({
    required this.path,
    required this.color,
    required super.child,
  });
  final Path? path;
  final Color color;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSelectionWindow(path, color);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSelectionWindow renderObject,
  ) {
    renderObject
      ..path = path
      ..color = color;
  }
}

class _RenderSelectionWindow extends RenderProxyBox {
  _RenderSelectionWindow(this._path, this._color);
  Path? _path;
  Color _color;
  set path(Path? value) {
    if (identical(value, _path)) return;
    final toggled = (value == null) != (_path == null);
    _path = value;
    if (toggled) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  final _clip = LayerHandle<ClipPathLayer>();
  final _filter = LayerHandle<ColorFilterLayer>();
  @override
  bool get alwaysNeedsCompositing => _path != null;
  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(child, offset);
    final path = _path;
    if (path == null) {
      _clip.layer = null;
      _filter.layer = null;
      return;
    }
    _clip.layer = context.pushClipPath(
      needsCompositing,
      offset,
      path.getBounds(),
      path,
      (context, offset) {
        _filter.layer = context.pushColorFilter(
          offset,
          ui.ColorFilter.mode(_color, BlendMode.srcIn),
          (context, offset) => context.paintChild(child, offset),
          oldLayer: _filter.layer,
        );
      },
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    _filter.layer = null;
    super.dispose();
  }
}
