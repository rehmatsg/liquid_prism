import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/control_gesture.dart';
import 'package:liquid_prism/src/controls/control_lens.dart';
import 'package:liquid_prism/src/controls/prism_pressable.dart';
import 'package:liquid_prism/src/controls/prism_selection.dart';
import 'package:liquid_prism/src/core/prism_badge.dart';
import 'package:liquid_prism/src/core/prism_colors.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_haptics.dart';
import 'package:liquid_prism/src/core/prism_lens_style.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';
import 'package:liquid_prism/src/navigation/prism_system_chrome.dart';
import 'package:liquid_prism/src/navigation/prism_tab_bar_style.dart';
import 'package:liquid_prism/src/navigation/prism_tab_reselection.dart';
import 'package:liquid_prism/src/navigation/scaffold/chrome_placement.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';
import 'package:liquid_prism/src/rendering/tab_content_lens.dart';
import 'package:liquid_prism/src/theme/foreground.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// A destination with a label, icons, and optional badge.
@immutable
final class PrismTab {
  /// Creates a destination descriptor.
  const new({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badge,
  });

  /// Accessible label, also displayed when an icon is omitted.
  final String label;

  /// Icon widget displayed for this action or destination.
  final Widget icon;

  /// Icon displayed for the selected destination; defaults to [icon].
  final Widget? selectedIcon;

  /// Optional status or count badge.
  final PrismBadge? badge;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismTab &&
          other.label == label &&
          other.icon == icon &&
          other.selectedIcon == selectedIcon &&
          other.badge == badge;

  @override
  int get hashCode => Object.hash(label, icon, selectedIcon, badge);
}

/// A controlled tab bar with a draggable glass selection lens.
class PrismTabBar extends StatefulWidget {
  /// Creates a controlled tab bar with component-style appearance.
  const new({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.onLongPressed,
    this.axis,
    this.style,
  }) : assert(tabs.length > 1, 'At least two tabs are required.'),
       assert(
         selectedIndex >= 0 && selectedIndex < tabs.length,
         'selectedIndex must be within the tabs.',
       );

  /// Ordered tab destinations.
  final List<PrismTab> tabs;

  /// Parent-owned index of the selected destination.
  final int selectedIndex;

  /// Selection proposal callback; null disables interaction.
  final ValueChanged<int>? onSelected;

  /// Long-press callback, enabled only when selection is enabled.
  final ValueChanged<int>? onLongPressed;

  /// Local appearance overrides merged over the component theme.
  final PrismTabBarStyle? style;

  /// Bar axis; null inherits the scaffold axis, then horizontal.
  final Axis? axis;
  @override
  State<PrismTabBar> createState() => _PrismTabBarState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty<PrismTab>('tabs', tabs))
      ..add(IntProperty('selectedIndex', selectedIndex))
      ..add(DiagnosticsProperty<PrismTabBarStyle>('style', style))
      ..add(EnumProperty<Axis>('axis', axis, defaultValue: null))
      ..add(
        ObjectFlagProperty<ValueChanged<int>>.has('onSelected', onSelected),
      );
  }
}

class _PrismTabBarState extends State<PrismTabBar>
    with TickerProviderStateMixin {
  late final _position = RetargetablePrismSpring(vsync: this);

  late final _lift = AnimationController.unbounded(vsync: this);
  late final _lensScale = AnimationController.unbounded(vsync: this, value: 1);
  late final _glow = AnimationController.unbounded(vsync: this);

  late final _stretch = RetargetablePrismSpring(vsync: this);
  late final _crossStretch = RetargetablePrismSpring(vsync: this);
  bool _trackingDeformation = false;
  double? _deformationTarget;

  late final _halo = AnimationController(
    vsync: this,
    duration: NativeMotion.haloRelease,
    value: 1,
  );
  Timer? _lensDwell;
  bool _releaseLensPending = false;

  final _window = ValueNotifier<bool>(false);
  bool _initialized = false;
  bool _rtl = false;
  bool _reduceMotion = false;
  bool _vertical = false;
  bool _dragging = false;
  bool _cancelled = false;
  bool _committing = false;
  int? _pointer;
  final _contacts = <int>{};

  double _slotWidth = 1;
  double _barWidth = 274;
  double _padLeft = 0;
  double _fingerSlot = 0;
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

  PrismMotion get _motion =>
      _style.motion ?? PrismTheme.of(context).motion ?? const PrismMotion();
  PrismTabBarStyle get _style =>
      (PrismTheme.of(context).tabBar ?? const PrismTabBarStyle()).merge(
        widget.style,
      );
  bool get _spatial => !_reduceMotion && _motion.pressScale > 1;

  double get _liftFactor =>
      ((_motion.pressScale - 1) / (const PrismMotion().pressScale - 1)).clamp(
        0.0,
        2.0,
      );

  bool get _mirrored => _rtl && !_vertical;
  double _physical(int index) =>
      (_mirrored ? widget.tabs.length - 1 - index : index).toDouble();
  int _logical(double position) {
    final slot = position.round().clamp(0, widget.tabs.length - 1);
    return _mirrored ? widget.tabs.length - 1 - slot : slot;
  }

  double _main(Offset point) => _vertical ? point.dy : point.dx;

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
    springPrism(
      _stretch,
      target,
      NativeMotion.stretchFilter,
      precision: _barPrecision,
    );
    springPrism(
      _crossStretch,
      -target * 110 / 70,
      NativeMotion.stretchFilter,
      precision: _barPrecision,
    );
  }

  double _pixelRatio = 1;

  double? get _barPrecision =>
      PrismSettle.precision(pixelsPerUnit: _barWidth * .6 * _pixelRatio);

  double? get _positionPrecision =>
      PrismSettle.precision(pixelsPerUnit: _slotWidth * 1.2 * _pixelRatio);

  double? get _liftPrecision => PrismSettle.precision(
    alphaPerUnit: 1,
    pixelsPerUnit: _liftReach * _pixelRatio,
  );
  static const _liftReach = 32.0;

  static final double? _glowPrecision = PrismSettle.precision(
    alphaPerUnit: NativeMotion.glowOpacity * .9 * .2,
  );

  void _travelShape(double target, {bool contact = false}) {
    if (_trackingDeformation ||
        (!_spatial) ||
        (!contact && target == _deformationTarget)) {
      return;
    }
    _deformationTarget = target;
    final distance = (target - _position.value).abs().clamp(0.0, 1.0);
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
    _pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
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
      (widget.axis ?? PrismChrome.maybeOf(context)?.axis) == Axis.vertical;

  @override
  void didUpdateWidget(PrismTabBar oldWidget) {
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
    springPrism(
      _position,
      _physical(widget.selectedIndex),
      _motion.spring,
      velocity: velocity,
      immediate: _reduceMotion,
      precision: _positionPrecision,
    );
  }

  void _cancelLensDwell() {
    _lensDwell?.cancel();
    _lensDwell = null;
    _releaseLensPending = false;
  }

  void _dropLens() {
    springPrism(
      _lift,
      0,
      NativeMotion.liftOut,
      immediate: _reduceMotion,
      precision: _liftPrecision,
    );
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
      springPrism(
        _lift,
        held && spatial ? 1 : 0,
        held ? NativeMotion.liftIn : NativeMotion.liftOut,
        immediate: _reduceMotion,
        precision: _liftPrecision,
      );
    }
    springPrism(
      _lensScale,
      held && spatial ? 1 + NativeMotion.barExpansion / _barWidth * factor : 1,
      held ? NativeMotion.barScaleIn : NativeMotion.barScaleOut,
      immediate: _reduceMotion,
      precision: _barPrecision,
    );
    springPrism(
      _glow,
      held ? 1 : 0,
      held ? NativeMotion.glowIn : NativeMotion.glowOut,
      immediate: _reduceMotion,
      precision: _glowPrecision,
    );
    if (releasing) {
      _halo.forward(from: 0);
    } else if (held) {
      _halo.value = 1;
    }
  }

  void _commit(int index, {double? velocity, bool fromDrag = false}) {
    if (widget.onSelected == null) return;
    if (index == widget.selectedIndex && !fromDrag) {
      PrismTabReselection.maybeOf(context)?.reselect();
    }
    if (!fromDrag) _trackingDeformation = false;
    final epoch = _epoch;
    final settleVelocity = velocity ?? _position.velocity;
    _committing = true;
    if ((_style.haptics ?? true) && index != widget.selectedIndex) {
      dispatchPrismHaptic(
        context,
        const PrismHapticEvent(
          PrismHapticComponent.tabBar,
          PrismHapticKind.selectionChange,
        ),
      );
    }
    widget.onSelected!(index);
    _committing = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && epoch == _epoch && _pointer == null) {
        _settle(velocity: settleVelocity);
      }
    });
    if (mounted) setState(() {});
  }

  void _longPress(int index) {
    if (_cancelled ||
        widget.onSelected == null ||
        widget.onLongPressed == null) {
      return;
    }
    _cancelled = true;
    _dragging = false;
    _feedback(false);
    _settle();
    if (_style.haptics ?? true) {
      dispatchPrismHaptic(
        context,
        const PrismHapticEvent(
          PrismHapticComponent.tabBar,
          PrismHapticKind.longPress,
        ),
      );
    }
    widget.onLongPressed!(index);
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
    _fingerSlot = _slotAt(event.localPosition);
    final slot = _fingerSlot.roundToDouble().clamp(
      0.0,
      (widget.tabs.length - 1).toDouble(),
    );
    _trackingDeformation = false;
    _travelShape(slot, contact: true);
    springPrism(
      _position,
      slot,
      _motion.spring,
      immediate: _reduceMotion,
      precision: _positionPrecision,
    );
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
      springPrism(
        _position,
        _fingerSlot,
        NativeMotion.tracking,
        precision: _positionPrecision,
      );
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
    final colors = PrismTheme.colorsOf(context);
    final style = _style;
    final accent =
        style.selectedColor ??
        PrismTheme.of(context).foregroundColor ??
        PrismTheme.tintOf(context);
    final calibrated =
        widget.onSelected != null &&
        style.selectedColor == null &&
        PrismTheme.of(context).foregroundColor == null;
    final selectedAccent = calibrated
        ? prismAccent(accent, colors.brightness)
        : accent;
    final vertical = _vertical;
    final padding =
        (style.padding ??
                (vertical
                    ? const EdgeInsets.symmetric(horizontal: 2, vertical: 6)
                    : const EdgeInsets.symmetric(horizontal: 8, vertical: 4)))
            .resolve(Directionality.of(context));
    final labels =
        style.labelBehavior ??
        (vertical ? PrismTabLabelBehavior.never : PrismTabLabelBehavior.always);
    final iconSize = style.iconSize ?? 25;
    final textStyle = const TextStyle(
      fontSize: 10,
      height: 1.2,
    ).merge(style.labelStyle);
    final textHeight =
        MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 10) *
        (textStyle.height ?? 1.2);
    var height = vertical
        ? math.max<double>(44, iconSize + 8)
        : math.max(
            style.height ?? 54,
            iconSize +
                (labels == PrismTabLabelBehavior.never ? 0 : textHeight + 2) +
                8,
          );
    final lensStyle = (PrismTheme.of(context).lens ?? const PrismLensStyle())
        .merge(style.lens);
    final selectionShape =
        style.selectionShape ?? lensStyle.shape ?? PrismShape.capsule;
    var contentWidth = iconSize;
    if (labels != PrismTabLabelBehavior.never) {
      final effectiveStyle = DefaultTextStyle.of(context).style.merge(
        textStyle.copyWith(fontWeight: textStyle.fontWeight ?? FontWeight.w500),
      );
      final painter = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      );
      for (final tab in widget.tabs) {
        painter
          ..text = TextSpan(text: tab.label, style: effectiveStyle)
          ..layout();
        contentWidth = math.max(contentWidth, painter.width);
      }
      painter.dispose();
    }
    if (vertical && labels != PrismTabLabelBehavior.never) {
      height = math.max(height, contentWidth + 16);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final slot = vertical
        ? math.max<double>(
            50,
            iconSize +
                25 +
                (labels == PrismTabLabelBehavior.never ? 0 : textHeight + 2),
          )
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
            style.sizing == PrismTabBarSizing.fill && available.isFinite
            ? available
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
        final heldAccent = calibrated
            ? prismAccent(accent, colors.brightness, held: true)
            : selectedAccent;
        Widget selectedContent(double lift) => Flex(
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
                  Color.lerp(selectedAccent, heldAccent, lift)!,
                  style,
                  window: true,
                  vertical: vertical,
                  selectedCopy: true,
                  magnify: 1 + (NativeMotion.heldSelectedScale - 1) * lift,
                ),
              ),
          ],
        );
        final badges = widget.tabs.any((tab) => tab.badge != null)
            ? ExcludeSemantics(
                child: IgnorePointer(
                  child: ValueListenableBuilder<bool>(
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
                              badgeLayer: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            : null;
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
            onLongPress: widget.onLongPressed == null
                ? null
                : (details) =>
                      _longPress(_logical(_slotAt(details.localPosition))),
            onTapUp: (details) {
              if (!_cancelled) {
                _commit(
                  _logical(_slotAt(details.localPosition)),
                  velocity: _position.velocity,
                );
              }
            },
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
                      PrismPressFeedback(
                        progress:
                            _glow.value.clamp(0, 1) * NativeMotion.glowOpacity,
                        scale: barScale,
                        child: RawPrismSurface(
                          glass: style.glass,
                          optics: style.optics,
                          blur: style.blur,
                          shape: style.shape,
                          role: PrismRole.tabBar,
                          child: SizedBox.fromSize(size: barSize),
                        ),
                      ),
                      if (haloLevel > .001)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _LensHalo(
                                lens.center,
                                NativeMotion.haloDiameter * haloScale,
                                NativeMotion.haloOpacity * haloLevel,
                                NativeMotion.haloBlurRadius * haloScale,
                                housing: style.shape ?? PrismShape.capsule,
                                housingScale: barScale,
                              ),
                            ),
                          ),
                        ),

                      if (lift > .001)
                        Positioned.fromRect(
                          rect: lens,
                          child: IgnorePointer(
                            child: PrismPressFeedback(
                              progress: 0,
                              child: ControlLens(
                                lift: lift,
                                shape: selectionShape,
                                role: PrismRole.tabLens,
                                rim: style.rimRefraction ?? 1,
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
                            child: PrismSelection(
                              selected: true,
                              shape: selectionShape,
                              color: style.selectionColor,
                              blur:
                                  style.selectionBlur ??
                                  _selectionBlur(
                                    context,
                                    blur: style.blur,
                                    optics: style.optics,
                                    glass: style.glass,
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
                          child: ContentLensWindow.selection(
                            scale: barScale,
                            origin: centre - padding.topLeft,
                            path: window,
                            selected: window == null
                                ? null
                                : selectedContent(lift),
                            lens: foregroundPill,
                            lift: lift,
                            shape: selectionShape,
                            refraction: style.refractContent == false
                                ? 0
                                : style.contentRefraction ?? 6.5,
                            depth: style.contentDepth ?? 11.2,
                            wrapper: style.refractContent == false ? 0 : 3.0,
                            chromaticAberration: style.refractContent == false
                                ? 0
                                : (lensStyle.chromaticAberration ?? 3.5) *
                                      (style.rimRefraction ?? 1),
                            chromaticBand: lensStyle.chromaticBand ?? 4.8,
                            child: child!,
                          ),
                        ),
                      ),
                      if (badges != null)
                        Positioned.fill(
                          key: const ValueKey('tab-badges'),
                          child: Padding(
                            padding: padding,
                            child: Transform(
                              transform:
                                  Matrix4.translationValues(
                                      centre.dx - padding.left,
                                      centre.dy - padding.top,
                                      0,
                                    )
                                    ..scaleByDouble(barScale, barScale, 1, 1)
                                    ..translateByDouble(
                                      -(centre.dx - padding.left),
                                      -(centre.dy - padding.top),
                                      0,
                                      1,
                                    ),
                              child: badges,
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
    PrismTabLabelBehavior labels,
    PrismColors colors,
    Color selectedAccent,
    PrismTabBarStyle style, {
    required bool window,
    required bool vertical,
    bool badgeLayer = false,
    bool selectedCopy = false,
    double magnify = 1,
  }) {
    final committed = widget.selectedIndex == index;
    final selected = selectedCopy || (committed && !window);
    final enabled = widget.onSelected != null;
    final tab = widget.tabs[index];
    final icon = selected ? tab.selectedIcon ?? tab.icon : tab.icon;
    final color = !enabled
        ? colors.disabledLabel
        : selected
        ? selectedAccent
        : style.unselectedColor ?? colors.label;

    Widget hidden(Widget child) => badgeLayer
        ? Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: child,
          )
        : child;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme.merge(
          data: IconThemeData(size: iconSize, color: color),
          child: PrismBadgedIcon(
            badge: badgeLayer ? tab.badge : null,
            color: style.badgeColor,
            textStyle: style.badgeTextStyle,
            child: hidden(icon),
          ),
        ),
        if (labels != PrismTabLabelBehavior.never &&
            (labels != PrismTabLabelBehavior.selected || selected)) ...[
          const SizedBox(height: 2),
          if (badgeLayer)
            hidden(
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle.copyWith(
                  fontWeight:
                      labelStyle.fontWeight ??
                      (selected ? FontWeight.w600 : FontWeight.w500),
                ),
              ),
            )
          else
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
    if (badgeLayer || selectedCopy) {
      return SizedBox(
        width: vertical ? height : null,
        height: vertical ? null : height,
        child: Center(
          child: magnify == 1
              ? content
              : Transform.scale(scale: magnify, child: content),
        ),
      );
    }
    return Semantics(
      container: true,
      button: true,
      selected: committed,
      enabled: enabled,
      label: tab.label,
      value: tab.badge?.semanticLabel,
      excludeSemantics: true,
      onTap: enabled ? () => _commit(index) : null,
      onLongPress: enabled && widget.onLongPressed != null
          ? () {
              _cancelled = false;
              _longPress(index);
            }
          : null,
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

class _LensHalo extends CustomPainter {
  const new(
    this.centre,
    this.diameter,
    this.opacity,
    this.blurRadius, {
    required this.housing,
    required this.housingScale,
  });
  final Offset centre;
  final double diameter;
  final double opacity;
  final double blurRadius;

  final PrismShape housing;
  final double housingScale;

  @override
  void paint(Canvas canvas, Size size) {
    final centreOfBar = size.center(Offset.zero);
    final expand = Matrix4.translationValues(centreOfBar.dx, centreOfBar.dy, 0)
      ..scaleByDouble(housingScale, housingScale, 1, 1)
      ..translateByDouble(-centreOfBar.dx, -centreOfBar.dy, 0, 1);
    canvas
      ..save()
      ..clipPath(housing.path(size).transform(expand.storage))
      ..drawCircle(
        centre,
        diameter / 2,
        Paint()
          ..color = Color.from(alpha: opacity, red: 1, green: 1, blue: 1)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LensHalo old) =>
      centre != old.centre ||
      diameter != old.diameter ||
      opacity != old.opacity ||
      blurRadius != old.blurRadius ||
      housing != old.housing ||
      housingScale != old.housingScale;
}

const double _nativeSelectionBlur = 2 * FrostPass.engineSigmaScale;

double _selectionBlur(
  BuildContext context, {
  required double? blur,
  required PrismOptics? optics,
  required PrismGlass? glass,
}) {
  final theme = PrismTheme.of(context);
  final explicit = blur ?? (optics != null ? optics.frost : theme.blur);
  if (explicit != null) return explicit >= 3 ? 0 : _nativeSelectionBlur;
  final recipe = PrismRecipe.resolve(
    glass ?? theme.glass ?? PrismGlass.regular,
    PrismTheme.materialBrightnessOf(context),
    PrismRole.tabBar,
    customOptics: false,
  );
  final covering = FrostPass.effectiveSigma(
    FrostPass.resolve(
      kind: recipe.kind,
      dark: recipe.dark,
      frost: recipe.optics(0).frost,
      fillFrost: PrismRecipe.blurFillFrost,
      tint: GlassTint.resolve(
        theme.glassTint,
        PrismSystemChrome.deviceGlassTintAmount.value,
      ),
    ),
  );
  return covering >= 3 ? 0 : _nativeSelectionBlur;
}
