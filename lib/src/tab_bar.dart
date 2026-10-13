import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'control_gesture.dart';
import 'control_lens.dart';
import 'appearance.dart';
import 'chrome_layout.dart';
import 'superellipse.dart';
import 'glass.dart';
import 'layer_transform.dart';
import 'foreground.dart';
import 'material.dart';
import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'style.dart';
import 'selection.dart';
import 'tab_bar_style.dart';
import 'theme.dart';

part 'tab_content_lens.dart';

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
///
/// [axis] lays the tabs out in a row (the default) or a column. A vertical bar
/// is the icon-only side rail that iOS uses beside a sensor bar on iPhone Duo;
/// labels stay available to accessibility. Inside a [LiquidPrismScaffold] the
/// axis follows the scaffold's resolved placement unless set here.
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
    this.axis,
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

  /// Row or column layout. Null inherits [LiquidPrismScaffold]'s placement,
  /// then defaults to [Axis.horizontal].
  final Axis? axis;
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
      ..add(EnumProperty<Axis>('axis', axis, defaultValue: null))
      ..add(
        ObjectFlagProperty<ValueChanged<int>>.has('onSelected', onSelected),
      );
  }
}

class _LiquidPrismTabBarState extends State<LiquidPrismTabBar>
    with TickerProviderStateMixin {
  /// Pill centre in slot units.
  late final _position = RetargetableGlassSpring(vsync: this);

  /// 0 resting pill, 1 lifted lens.
  late final _lift = AnimationController.unbounded(vsync: this);
  late final _lensScale = AnimationController.unbounded(vsync: this, value: 1);
  late final _glow = AnimationController.unbounded(vsync: this);

  /// Independent width and height deformation, relative to lens bounds.
  late final _stretch = RetargetableGlassSpring(vsync: this);
  late final _crossStretch = RetargetableGlassSpring(vsync: this);
  bool _trackingDeformation = false;
  double? _deformationTarget;

  /// Release ripple of the halo: 0 at release, 1 when gone.
  late final _halo = AnimationController(
    vsync: this,
    duration: NativeMotion.haloRelease,
    value: 1,
  );
  Timer? _lensDwell;
  bool _releaseLensPending = false;

  /// True while the selected colour must follow the pill instead of the
  /// committed tab: the icons under the lens are recoloured by position.
  final _window = ValueNotifier<bool>(false);
  bool _initialized = false, _rtl = false, _reduceMotion = false;
  bool _vertical = false;
  bool _dragging = false, _cancelled = false, _committing = false;
  int? _pointer;
  final _contacts = <int>{};

  /// Slot extent, bar extent and leading padding along the main axis.
  double _slotWidth = 1, _barWidth = 274, _padLeft = 0, _fingerSlot = 0;
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
      _style.motion ??
      LiquidPrismTheme.of(context).motion ??
      const GlassMotion();
  GlassTabBarStyle get _style =>
      (LiquidPrismTheme.of(context).tabBar ?? const GlassTabBarStyle()).merge(
        widget.style,
      );
  bool get _spatial => !_reduceMotion && _motion.pressScale > 1;

  /// Lift strength relative to the measured default: `pressScale` scales the
  /// lens inset and housing expansion together; 1 disables them.
  double get _liftFactor =>
      ((_motion.pressScale - 1) / (const GlassMotion().pressScale - 1)).clamp(
        0.0,
        2.0,
      );

  /// Columns run top to bottom in either text direction.
  bool get _mirrored => _rtl && !_vertical;
  double _physical(int index) =>
      (_mirrored ? widget.tabs.length - 1 - index : index).toDouble();
  int _logical(double position) {
    final slot = position.round().clamp(0, widget.tabs.length - 1);
    return _mirrored ? widget.tabs.length - 1 - slot : slot;
  }

  double _main(Offset point) => _vertical ? point.dy : point.dx;

  /// Finger position in slot units, resisted past the end tabs.
  double _slotAt(Offset point) {
    final centre = _padLeft + _slotWidth * widget.tabs.length / 2;
    final local = centre + (_main(point) - centre) / _lensScale.value;
    return _resisted(
      (local - _padLeft) / _slotWidth - .5,
      (widget.tabs.length - 1).toDouble(),
    );
  }

  void _updateWindow() {
    final away =
        (_position.value - _physical(widget.selectedIndex)).abs() > .001;
    final active = _pointer != null || _lift.value > .001 || away;
    if (_window.value != active) _window.value = active;
  }

  double _stretchTarget = 0;
  void _followVelocity() {
    if (!_spatial || !_trackingDeformation) return;
    final speed = (_position.velocity * _slotWidth).abs();
    final target =
        math.min(
          NativeMotion.stretchLimit,
          NativeMotion.stretchPerSpeed * speed,
        ) /
        110 *
        _liftFactor;
    if ((target - _stretchTarget).abs() < .0001 && _stretch.isAnimating) return;
    _stretchTarget = target;
    springGlass(_stretch, target, NativeMotion.stretchFilter);
    springGlass(_crossStretch, -target * 110 / 70, NativeMotion.stretchFilter);
  }

  void _travelShape(double target, {bool contact = false}) {
    if (_trackingDeformation ||
        (!_spatial) ||
        (!contact && target == _deformationTarget)) {
      return;
    }
    _deformationTarget = target;
    final distance = ((target - _position.value).abs()).clamp(0.0, 1.0);
    final travel = distance * _liftFactor;
    final timeScale = _motion.response.inMicroseconds / 400000;
    for (final axis in [(_stretch, false), (_crossStretch, true)]) {
      unawaited(
        axis.$1.animateWith(
          NativeLensDeformation(
            vertical: axis.$2,
            travel: travel,
            timeScale: timeScale,
            value: axis.$1.value,
            velocity: axis.$1.velocity,
          ),
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final vertical = _resolveVertical();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!_initialized || rtl != _rtl || vertical != _vertical) {
      _rtl = rtl;
      _vertical = vertical;
      _reset();
    }
    _initialized = true;
    _reduceMotion = reduced;
    if (reduced) {
      if (!_dragging) _position.value = _physical(widget.selectedIndex);
      final held = _pointer != null && !_cancelled;
      _lift.value = 0;
      _lensScale.value = 1;
      _stretch.value = 0;
      _crossStretch.value = 0;
      _halo.value = 1;
      _glow.value = held ? 1 : 0;
      _cancelLensDwell();
    }
  }

  bool _resolveVertical() =>
      (widget.axis ?? LiquidPrismChrome.maybeOf(context)?.axis) ==
      Axis.vertical;

  @override
  void didUpdateWidget(LiquidPrismTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocus();
    final vertical = _resolveVertical();
    if (widget.tabs.length != oldWidget.tabs.length ||
        widget.onSelected == null ||
        vertical != _vertical) {
      _vertical = vertical;
      _reset();
    } else if (widget.selectedIndex != oldWidget.selectedIndex) {
      if (!_committing && _pointer != null) {
        _cancelled = true;
        _feedback(false);
      }
      _dragging = false;
      _settle();
    }
    _updateWindow();
  }

  void _reset() {
    _cancelLensDwell();
    _epoch++;
    _cancelled = true;
    _dragging = false;
    _pointer = null;
    _position.value = _physical(widget.selectedIndex);
    _lift.value = 0;
    _lensScale.value = 1;
    _glow.value = 0;
    _stretch.value = 0;
    _crossStretch.value = 0;
    _trackingDeformation = false;
    _deformationTarget = null;
    _stretchTarget = 0;
    _halo.value = 1;

    _updateWindow();
  }

  void _settle({double? velocity}) {
    _travelShape(_physical(widget.selectedIndex));
    springGlass(
      _position,
      _physical(widget.selectedIndex),
      _motion.spring,
      velocity: velocity,
      immediate: _reduceMotion,
    );
  }

  void _cancelLensDwell() {
    _lensDwell?.cancel();
    _lensDwell = null;
    _releaseLensPending = false;
  }

  void _dropLens() {
    springGlass(_lift, 0, NativeMotion.liftOut, immediate: _reduceMotion);
  }

  void _feedback(bool held, {bool finishLift = false}) {
    final spatial = _spatial;
    final factor = _liftFactor;
    final releasing = !held && _glow.value > .001 && spatial;
    final keepLens = finishLift && _lensDwell != null && spatial;
    if (keepLens) {
      _releaseLensPending = true;
    } else {
      if (!held) _cancelLensDwell();
      springGlass(
        _lift,
        held && spatial ? 1 : 0,
        held ? NativeMotion.liftIn : NativeMotion.liftOut,
        immediate: _reduceMotion,
      );
    }
    springGlass(
      _lensScale,
      held && spatial ? 1 + NativeMotion.barExpansion / _barWidth * factor : 1,
      held ? NativeMotion.barScaleIn : NativeMotion.barScaleOut,
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

  void _commit(int index, {double? velocity, bool fromDrag = false}) {
    if (widget.onSelected == null) return;
    if (!fromDrag) _trackingDeformation = false;
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
    _cancelLensDwell();
    if (_spatial) {
      _lensDwell = Timer(NativeMotion.lensDwell, () {
        _lensDwell = null;
        if (_releaseLensPending) {
          _releaseLensPending = false;
          _dropLens();
        }
      });
    }
    // The pill glides to the touched tab on contact, before any release.
    _fingerSlot = _slotAt(event.localPosition);
    final slot = _fingerSlot.roundToDouble().clamp(
      0.0,
      (widget.tabs.length - 1).toDouble(),
    );
    _trackingDeformation = false;
    _travelShape(slot, contact: true);
    springGlass(_position, slot, _motion.spring, immediate: _reduceMotion);
    _feedback(true);
    _updateWindow();
  }

  void _pointerUp(PointerEvent event) {
    _contacts.remove(event.pointer);
    if (_pointer != event.pointer) return;
    _pointer = null;
    _feedback(false, finishLift: event is PointerUpEvent && !_cancelled);
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
    _trackingDeformation = true;
    _fingerSlot = _slotAt(location);
    if (_reduceMotion) {
      _position.value = _fingerSlot;
    } else {
      springGlass(_position, _fingerSlot, NativeMotion.tracking);
    }
  }

  void _dragEnd(DragEndDetails details) {
    if (_cancelled || !_dragging) {
      _settle();
      return;
    }
    _dragging = false;
    final velocity = (details.primaryVelocity ?? 0) / _slotWidth;
    final projected = _fingerSlot + velocity * _motion.dragProjection;
    _commit(_logical(projected), velocity: _position.velocity, fromDrag: true);
  }

  @override
  void deactivate() {
    _cancelled = true;
    _pointer = null;
    _dragging = false;
    _contacts.clear();
    _cancelLensDwell();
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
    _lensScale,
    _glow,
    _stretch,
    _crossStretch,
    _halo,
  ];

  @override
  void dispose() {
    _cancelLensDwell();
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
    final vertical = _vertical;
    // The native iPhone Duo rail: 44 x 58 pt buttons at a 50 pt pitch inside
    // a 48 pt wide capsule, 2 pt across and 6 pt along the rail.
    final padding =
        style.padding ??
        (vertical
            ? const EdgeInsets.symmetric(horizontal: 2, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4));
    // The rail is icon-only. Labels remain the accessible names.
    final labels = vertical
        ? GlassTabLabelBehavior.never
        : style.labelBehavior ?? GlassTabLabelBehavior.always;
    final iconSize = style.iconSize ?? 25;
    final textStyle = const TextStyle(
      fontSize: 10,
      height: 1.2,
    ).merge(style.labelStyle);
    final textHeight =
        MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 10) *
        (textStyle.height ?? 1.2);
    // Cross-axis extent of one tab: its height in a row, width in a column.
    final height = vertical
        ? math.max(44.0, iconSize + 8)
        : math.max(
            style.height ?? 54,
            iconSize +
                (labels == GlassTabLabelBehavior.never ? 0 : textHeight + 2) +
                8,
          );
    final lensStyle =
        (LiquidPrismTheme.of(context).lens ?? const GlassLensStyle()).merge(
          style.lens,
        );
    final selectionShape =
        style.selectionShape ?? lensStyle.shape ?? GlassShape.capsule;
    var contentWidth = iconSize;
    if (labels != GlassTabLabelBehavior.never) {
      final effectiveStyle = DefaultTextStyle.of(context).style.merge(
        textStyle.copyWith(fontWeight: textStyle.fontWeight ?? FontWeight.w500),
      );
      final painter = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      );
      for (final tab in widget.tabs) {
        painter.text = TextSpan(text: tab.label, style: effectiveStyle);
        painter.layout();
        contentWidth = math.max(contentWidth, painter.width);
      }
      painter.dispose();
    }
    // Native items have an 86-point minimum centre spacing. Wider labels add
    // 32 points of horizontal breathing room; measure in device pixels as UIKit
    // does. The housing keeps its outer padding, instead of consuming all space.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final slot = vertical
        ? math.max(50.0, iconSize + 25)
        : math.max(
            style.minimumTabWidth ?? 86.0,
            (contentWidth * dpr).ceil() / dpr + (style.labelPadding ?? 32),
          );
    final mainPadding = vertical ? padding.vertical : padding.horizontal;
    final preferredWidth = slot * widget.tabs.length + mainPadding;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = vertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        final barWidth =
            !vertical && style.expanded == true && constraints.hasBoundedWidth
            ? constraints.maxWidth
            : math.min(preferredWidth, available);
        final width = (barWidth - mainPadding) / widget.tabs.length;
        if (!width.isFinite || width <= 0) return const SizedBox.shrink();
        _padLeft = vertical ? padding.top : padding.left;
        _barWidth = barWidth;
        if (width != _slotWidth) {
          _slotWidth = width;
          if (_pointer != null || _dragging) _reset();
        }
        final barSize = vertical
            ? Size(height + padding.horizontal, barWidth)
            : Size(barWidth, height + padding.vertical);
        final content = ValueListenableBuilder<bool>(
          valueListenable: _window,
          builder: (context, window, _) => Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
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
                    vertical: vertical,
                  ),
                ),
            ],
          ),
        );
        final selects = widget.onSelected != null;
        void cancelDrag() {
          if (_pointer == null && !_dragging) return;
          _dragging = false;
          _cancelled = true;
          _feedback(false);
          _settle();
        }

        final surface = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _pointerDown,
          onPointerUp: _pointerUp,
          onPointerCancel: _pointerUp,
          child: ControlGestureDetector(
            enabled: selects,
            axis: vertical ? Axis.vertical : Axis.horizontal,
            onTapUp: (details) {
              if (!_cancelled) {
                _commit(
                  _logical(_slotAt(details.localPosition)),
                  velocity: _position.velocity,
                );
              }
            },
            // Any direction past the touch slop drags; the pill reads only the
            // bar's own axis, so diagonal drags and flicks still select.
            onStart: (details) => _drag(details.localPosition),
            onUpdate: (details) => _drag(details.localPosition),
            onEnd: _dragEnd,
            onCancel: cancelDrag,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _position,
                _lift,
                _lensScale,
                _glow,
                _stretch,
                _crossStretch,
                _halo,

                _window,
              ]),
              child: content,
              builder: (context, child) {
                final lift = _lift.value.clamp(0.0, 1.0);
                final deformation = _stretch.value.clamp(-.24, .24);
                final inset = NativeMotion.lensInset * lift * _liftFactor;
                final along = (width + 8 + 2 * inset) * (1 + deformation);
                final across =
                    (height + 2 * inset) *
                    (1 + _crossStretch.value.clamp(-.3, .3));
                final travel = _position.value * width + width / 2;
                final pill = Rect.fromCenter(
                  center: vertical
                      ? Offset(height / 2, travel)
                      : Offset(travel, height / 2),
                  width: vertical ? across : along,
                  height: vertical ? along : across,
                );
                final lensScale = _lensScale.value;
                final barScale = lensScale;
                // UIKit applies the flex transform to the housing and its
                // foreground, with an additional lift on the lens bounds.
                final foregroundPill = pill;
                final window = _window.value
                    ? selectionShape
                          .path(foregroundPill.size)
                          .shift(foregroundPill.topLeft)
                    : null;
                final centre = barSize.center(Offset.zero);
                final pillOnBar = pill.shift(padding.topLeft);
                final lens = Rect.fromCenter(
                  center: centre + (pillOnBar.center - centre) * barScale,
                  width: pillOnBar.width * lensScale,
                  height: pillOnBar.height * lensScale,
                );
                final ripple = _halo.value;
                final held = _pointer != null && !_cancelled;
                final haloLevel = held ? 1.0 : (ripple < 1 ? 1 - ripple : 0.0);
                final haloScale = held
                    ? 1.0
                    : 1 + (NativeMotion.haloReleaseScale - 1) * ripple;
                return SizedBox.fromSize(
                  size: barSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      LiquidPrismPressFeedback(
                        progress:
                            _glow.value.clamp(0, 1) * NativeMotion.glowOpacity,
                        scale: barScale,
                        child: LiquidPrism(
                          glass: widget.glass ?? style.glass,
                          optics: widget.optics ?? style.optics,
                          blur: widget.blur ?? style.blur,
                          shape: style.shape,
                          role: GlassRole.tabBar,
                          child: SizedBox.fromSize(size: barSize),
                        ),
                      ),
                      if (haloLevel > .001)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ClipPath(
                              clipper: GlassShapeClipper(
                                style.shape ?? GlassShape.capsule,
                              ),
                              child: CustomPaint(
                                painter: _LensHalo(
                                  lens.center,
                                  NativeMotion.haloDiameter * haloScale,
                                  NativeMotion.haloOpacity * haloLevel,
                                  NativeMotion.haloBlurRadius * haloScale,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Capture only the bar and its backdrop, then paint the
                      // rest selection and separately refracted foreground.
                      if (lift > .001)
                        Positioned.fromRect(
                          rect: lens,
                          child: IgnorePointer(
                            child: LiquidPrismPressFeedback(
                              progress: 0,
                              child: ControlLens(
                                lift: lift,
                                shape: selectionShape,
                                role: GlassRole.tabLens,
                                style: lensStyle.copyWith(
                                  shape: selectionShape,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fromRect(
                        key: const ValueKey('tab-selection'),
                        rect: lens,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 1 - lift,
                            child: LiquidPrismSelection(
                              selected: true,
                              shape: selectionShape,
                              color: style.selectionColor,
                              blur:
                                  style.selectionBlur ??
                                  _selectionBlur(
                                    context,
                                    blur: widget.blur ?? style.blur,
                                    optics: widget.optics ?? style.optics,
                                    glass: widget.glass ?? style.glass,
                                  ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        key: const ValueKey('tab-foreground'),
                        child: Padding(
                          padding: padding,
                          child: _SelectionWindow(
                            scale: barScale,
                            // The housing scales about the bar's centre.
                            origin: centre - padding.topLeft,
                            path: window,
                            color: selectedAccent,
                            lens: foregroundPill,
                            lift: lift,
                            shape: selectionShape,
                            refraction: style.refractContent == false
                                ? 0
                                : style.contentRefraction ?? 14,
                            depth: style.contentDepth ?? 11.2,
                            child: child!,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        return Align(
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox.fromSize(size: barSize, child: surface),
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
    required bool vertical,
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
          SingleActivator(
            vertical
                ? LogicalKeyboardKey.arrowDown
                : LogicalKeyboardKey.arrowRight,
          ): () {
            if (enabled) {
              _keyboardSelect(
                (index + (_mirrored ? -1 : 1)).clamp(0, widget.tabs.length - 1),
              );
            }
          },
          SingleActivator(
            vertical
                ? LogicalKeyboardKey.arrowUp
                : LogicalKeyboardKey.arrowLeft,
          ): () {
            if (enabled) {
              _keyboardSelect(
                (index + (_mirrored ? 1 : -1)).clamp(0, widget.tabs.length - 1),
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
            width: vertical ? height : null,
            height: vertical ? null : height,
            child: Center(child: content),
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

/// Paints its child once, then again clipped to [path] with every pixel
/// recoloured to [color]: the selected tint shows wherever the pill is.
///
/// The housing's flex [scale] is applied here, beneath the refraction filter,
/// rather than by an ancestor transform. A filter layer under an animating
/// scale is placed on whole device pixels each frame, so while the pill lifted
/// the selected copy popped between pixels against the smoothly scaling rest.
class _SelectionWindowPaint extends SingleChildRenderObjectWidget {
  const _SelectionWindowPaint({
    required this.path,
    required this.color,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.shader,
    required this.refraction,
    required this.depth,
    required this.scale,
    required this.origin,
    required super.child,
  });
  final Path? path;
  final Color color;
  final Rect lens;
  final double lift, refraction, depth, scale;
  final Offset origin;
  final GlassShape shape;
  final ui.FragmentShader? shader;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSelectionWindow(path, color)
        ..configure(shader, lens, lift, shape, refraction, depth)
        ..setScale(scale, origin);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSelectionWindow renderObject,
  ) {
    renderObject
      ..path = path
      ..color = color
      ..configure(shader, lens, lift, shape, refraction, depth)
      ..setScale(scale, origin);
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

  double _scale = 1;
  Offset _origin = Offset.zero;
  void setScale(double scale, Offset origin) {
    if (scale == _scale && origin == _origin) return;
    _scale = scale;
    _origin = origin;
    markNeedsPaint();
  }

  /// The flex scale about [_origin], or null at rest.
  Matrix4? get _transform => _scale == 1
      ? null
      : (Matrix4.translationValues(_origin.dx, _origin.dy, 0)
          ..scaleByDouble(_scale, _scale, 1, 1)
          ..translateByDouble(-_origin.dx, -_origin.dy, 0, 1));

  ui.FragmentShader? _shader;
  Rect _lens = Rect.zero;
  double _lift = 0, _refraction = 14, _depth = 11.2;
  GlassShape _shape = GlassShape.capsule;
  void configure(
    ui.FragmentShader? shader,
    Rect lens,
    double lift,
    GlassShape shape,
    double refraction,
    double depth,
  ) {
    if (shader == _shader &&
        lens == _lens &&
        lift == _lift &&
        shape == _shape &&
        refraction == _refraction &&
        depth == _depth) {
      return;
    }
    _shader = shader;
    _lens = lens;
    _lift = lift;
    _shape = shape;
    _refraction = refraction;
    _depth = depth;
    markNeedsPaint();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final local = _transform;
    if (local != null) transform.multiply(local);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _transform,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );

  Size? _contourSize;
  double? _contourRadius;
  List<double> _contour = [];

  /// Whether the selected foreground is refracted by the content lens.
  bool get _refractsContent =>
      _shader != null && _lift >= .001 && _refraction != 0;

  /// The content lens for a raster at [deviceScale] physical pixels per point.
  ui.ImageFilter _contentFilter(double deviceScale) {
    final shader = _shader!;
    // The filter sits outside the flex scale, so its lens is the scaled
    // contour; lengths in points scale with it.
    final local = _shape.rect(_lens.size).shift(_lens.topLeft);
    final contour = Rect.fromCenter(
      center: _origin + (local.center - _origin) * _scale,
      width: local.width * _scale,
      height: local.height * _scale,
    );
    final radius = _shape.radius * _scale;
    if (_contourSize != contour.size || _contourRadius != radius) {
      _contourSize = contour.size;
      _contourRadius = radius;
      _contour = superellipseUniforms(contour.size, radius);
    }
    // The filter reads the whole foreground row, which stays put while the
    // pill moves; the lens is expressed relative to that row.
    final values = [
      contour.left,
      contour.top,
      contour.width,
      contour.height,
      deviceScale,
      _lift,
      radius,
      _shape.isSmooth ? 1.0 : 0.0,
      ..._contour,
      _refraction * _scale,
      _depth * _scale,
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i + 2, values[i]);
    }
    return ui.ImageFilter.shader(shader);
  }

  final _warp = LayerHandle<_ContentLensLayer>();
  final _clip = LayerHandle<ClipPathLayer>();
  final _outsideClip = LayerHandle<ClipPathLayer>();
  final _filter = LayerHandle<ColorFilterLayer>();
  final _scaled = LayerHandle<TransformLayer>();
  final _outsideScaled = LayerHandle<TransformLayer>();

  /// Paints [painter] under the flex scale, reusing [handle]'s layer.
  void _underScale(
    PaintingContext context,
    Offset offset,
    LayerHandle<TransformLayer> handle,
    PaintingContextCallback painter,
  ) {
    final local = _transform;
    if (local == null) {
      handle.layer = null;
      painter(context, offset);
    } else {
      handle.layer = context.pushTransform(
        needsCompositing,
        offset,
        local,
        painter,
        oldLayer: handle.layer,
      );
    }
  }

  @override
  bool get alwaysNeedsCompositing => _path != null;
  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final path = _path;
    if (path == null) {
      _clip.layer = null;
      _outsideClip.layer = null;
      _filter.layer = null;
      _warp.layer = null;
      _scaled.layer = null;
      _underScale(
        context,
        offset,
        _outsideScaled,
        (context, offset) => context.paintChild(child, offset),
      );
      return;
    }
    // The selected and unselected copies occupy complementary regions.
    // Painting both at the same pixel leaves unselected fringes around glyphs.
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      path,
    );
    _underScale(
      context,
      offset,
      _outsideScaled,
      (context, offset) => _outsideClip.layer = context.pushClipPath(
        needsCompositing,
        offset,
        Offset.zero & size,
        outside,
        (context, offset) => context.paintChild(child, offset),
        oldLayer: _outsideClip.layer,
      ),
    );
    void selected(PaintingContext context, Offset offset) {
      _filter.layer = context.pushColorFilter(
        offset,
        ui.ColorFilter.mode(_color, BlendMode.srcIn),
        (context, offset) => context.paintChild(child, offset),
        oldLayer: _filter.layer,
      );
    }

    void clipped(PaintingContext context, Offset offset) => _underScale(
      context,
      offset,
      _scaled,
      (context, offset) => _clip.layer = context.pushClipPath(
        needsCompositing,
        offset,
        path.getBounds(),
        path,
        selected,
        oldLayer: _clip.layer,
      ),
    );

    if (!_refractsContent) {
      _warp.layer = null;
      clipped(context, offset);
      return;
    }
    // Clip inside the filter, not around it. Impeller sizes a filter's input
    // to its clip; a clip that follows the pill moves that input by fractions
    // of a pixel each frame, so the shader resampled the glyphs at a shifting
    // phase and they shook in place. The shader only pulls samples inward from
    // the contour, so clipping first leaves its output unchanged.
    final lens = _warp.layer ??= _ContentLensLayer(this);
    lens.invalidate();
    final layer = lens.filter..offset = offset;
    context.pushLayer(
      lens,
      (context, _) => context.pushLayer(layer, (context, _) {
        // Establish the full foreground source extent. Glyph-only ink bounds
        // otherwise shift the shader's lens coordinate system.
        context.canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = const Color(0x00000000)
            ..blendMode = BlendMode.src,
        );
        clipped(context, Offset.zero);
      }, offset),
      offset,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    _outsideClip.layer = null;
    _filter.layer = null;
    _warp.layer = null;
    _scaled.layer = null;
    _outsideScaled.layer = null;
    super.dispose();
  }
}

/// Configures the content lens filter at composition. The filter maps its
/// raster with the composited device scale, which an animating ancestor
/// transform changes without repainting the tab bar beneath a repaint
/// boundary. The composited scale, unlike the laid-out one, also excludes an
/// ancestor `ImageFilter.matrix`, which scales this raster only afterwards.
class _ContentLensLayer extends ContainerLayer {
  _ContentLensLayer(this.window);
  final _RenderSelectionWindow window;
  // The handle keeps the child alive while it is detached between repaints.
  final _filter = LayerHandle<ImageFilterLayer>(ImageFilterLayer());
  ImageFilterLayer get filter => _filter.layer!;
  double? _deviceScale;

  /// Rebuilds the filter at the next composition; the window repainted.
  void invalidate() => _deviceScale = null;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final scale = compositedTransform(this).getMaxScaleOnAxis();
    if (scale != _deviceScale || filter.imageFilter == null) {
      _deviceScale = scale;
      filter.imageFilter = window._contentFilter(scale);
    }
    addChildrenToScene(builder);
  }

  @override
  void dispose() {
    _filter.layer = null;
    super.dispose();
  }
}

class _LensHalo extends CustomPainter {
  const _LensHalo(this.centre, this.diameter, this.opacity, this.blurRadius);
  final Offset centre;
  final double diameter, opacity, blurRadius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      centre,
      diameter / 2,
      Paint()
        // Native LittleGlow is a circle's broad Gaussian shadow, rather than
        // a gradient that concentrates all its brightness at the touch point.
        // Its blur grows with the release ripple's contour.
        ..color = Color.from(alpha: opacity, red: 1, green: 1, blue: 1)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius),
    );
  }

  @override
  bool shouldRepaint(_LensHalo old) =>
      centre != old.centre ||
      diameter != old.diameter ||
      opacity != old.opacity ||
      blurRadius != old.blurRadius;
}

/// The selection's own blur. Native adds a 2-point blur under the pill, which
/// a housing frosted at 3 points or more already exceeds: the extra pass would
/// widen a 3.3-point kernel to 3.9 and cost a full backdrop capture per frame,
/// so it only runs when the housing is clear or lightly frosted.
double _selectionBlur(
  BuildContext context, {
  required double? blur,
  required LiquidPrismStyle? optics,
  required Glass? glass,
}) {
  final theme = LiquidPrismTheme.of(context);
  final frost =
      blur ??
      (optics != null ? optics.frost : theme.blur) ??
      GlassRecipe.resolve(
        glass ?? theme.glass ?? Glass.regular,
        LiquidPrismTheme.materialBrightnessOf(context),
        GlassRole.tabBar,
        customOptics: false,
      ).optics(0).frost;
  return frost >= 3 ? 0 : 2;
}
