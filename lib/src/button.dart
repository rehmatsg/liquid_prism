import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'appearance.dart';
import 'glass.dart';
import 'haptics.dart';
import 'material.dart';
import 'menu/menu.dart';
import 'menu/menus.dart';
import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'style.dart';
import 'theme.dart';

export 'appearance.dart' show GlassButtonVariant;

/// A glass action with generated text/icon content or an app-supplied child.
///
/// A null callback or `enabled: false` disables every activation path and
/// draws the disabled colors. While [isLoading], or while an [autoLoading]
/// action's future runs, the content is replaced by an activity indicator in
/// the same space and activation is ignored; the button keeps its colors,
/// focus and enabled semantics.
/// [destructive] draws the system red: as the foreground of a regular button
/// and as the tint of a prominent one.
class LiquidPrismButton extends StatefulWidget {
  const LiquidPrismButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.child,
    this.icon,
    this.trailingIcon,
    this.enabled = true,
    this.onLongPress,
    this.isLoading = false,
    this.autoLoading = false,
    this.loadingIndicator,
    this.destructive = false,
    this.tintColor,
    this.semanticLabel,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.variant,
    this.size,
    this.style,
    this.shape,
    this.padding,
    this.selected = false,
    this.foregroundColor,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.mouseCursor,
  }) : assert(child == null || icon == null),
       assert(child == null || trailingIcon == null),
       _iconOnly = false,
       menu = null,
       onMenuSelected = null;

  const LiquidPrismButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required this.label,
    this.enabled = true,
    this.onLongPress,
    this.isLoading = false,
    this.autoLoading = false,
    this.loadingIndicator,
    this.destructive = false,
    this.tintColor,
    this.semanticLabel,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.variant,
    this.size,
    this.style,
    this.shape,
    this.padding,
    this.selected = false,
    this.foregroundColor,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.mouseCursor,
  }) : child = null,
       trailingIcon = null,
       _iconOnly = true,
       menu = null,
       onMenuSelected = null;

  /// The button owns activation and presents the native menu through Liquid Menu.
  const LiquidPrismButton.menu({
    super.key,
    required LiquidMenu this.menu,
    required this.label,
    this.child,
    this.icon,
    this.trailingIcon,
    ValueChanged<Object?>? onSelected,
    this.enabled = true,
    this.isLoading = false,
    this.loadingIndicator,
    this.destructive = false,
    this.tintColor,
    this.semanticLabel,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.variant,
    this.size,
    this.style,
    this.shape,
    this.padding,
    this.selected = false,
    this.foregroundColor,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.mouseCursor,
  }) : assert(child == null || icon == null),
       assert(child == null || trailingIcon == null),
       _iconOnly = false,
       onPressed = null,
       onLongPress = null,
       autoLoading = false,
       onMenuSelected = onSelected;

  final FutureOr<void> Function()? onPressed;

  /// Called on a long press, after the theme's long-press haptic. Ignored
  /// while the button is disabled or loading.
  final VoidCallback? onLongPress;
  final String label;

  /// [child] replaces the generated label and icons. [icon] sits beside the
  /// label at the style's `labelPlacement`; [trailingIcon] follows both.
  final Widget? child, icon, trailingIcon;

  /// False disables the button even with a callback.
  final bool enabled;

  /// Shows the activity indicator and ignores activation.
  final bool isLoading;

  /// Also shows the activity indicator while the future [onPressed] returns
  /// is pending. A synchronous action never enters it.
  final bool autoLoading;

  /// Replaces the built-in activity indicator; it inherits the button's
  /// foreground through `IconTheme` and `DefaultTextStyle`.
  final Widget? loadingIndicator;

  /// Draws the system red; an explicit foreground or [tintColor] still wins.
  final bool destructive;

  /// Tints the glass, as a prominent button tints it with the accent.
  final Color? tintColor;

  /// The accessible name; defaults to [label].
  final String? semanticLabel;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
  final GlassButtonVariant? variant;
  final GlassControlSize? size;
  final GlassButtonStyle? style;
  final GlassShape? shape;
  final EdgeInsetsGeometry? padding;
  final bool selected;
  final Color? foregroundColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final MouseCursor? mouseCursor;
  final LiquidMenu? menu;
  final ValueChanged<Object?>? onMenuSelected;
  final bool _iconOnly;

  @override
  State<LiquidPrismButton> createState() => _LiquidPrismButtonState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null))
      ..add(EnumProperty('variant', variant))
      ..add(EnumProperty('size', size))
      ..add(DiagnosticsProperty<GlassButtonStyle>('style', style))
      ..add(DiagnosticsProperty<Glass>('glass', glass))
      ..add(DiagnosticsProperty<LiquidPrismStyle>('optics', optics))
      ..add(DoubleProperty('blur', blur))
      ..add(DiagnosticsProperty<GlassShape>('shape', shape))
      ..add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding))
      ..add(ColorProperty('foregroundColor', foregroundColor))
      ..add(ColorProperty('tintColor', tintColor, defaultValue: null))
      ..add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'))
      ..add(FlagProperty('isLoading', value: isLoading, ifTrue: 'loading'))
      ..add(
        FlagProperty('autoLoading', value: autoLoading, ifTrue: 'autoLoading'),
      )
      ..add(
        FlagProperty('destructive', value: destructive, ifTrue: 'destructive'),
      )
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(
        ObjectFlagProperty<FutureOr<void> Function()>.has(
          'onPressed',
          onPressed,
        ),
      )
      ..add(ObjectFlagProperty<VoidCallback>.has('onLongPress', onLongPress));
  }
}

class _LiquidPrismButtonState extends State<LiquidPrismButton> {
  /// Auto-loading actions still in flight.
  int _pending = 0;

  bool get _loading => widget.isLoading || _pending > 0;

  /// Activation while loading: accepted, so focus and semantics stay as they
  /// are, and ignored.
  static void _ignore() {}

  void _activate() {
    final result = widget.onPressed!();
    if (!widget.autoLoading || result is! Future<void>) return;
    setState(() => _pending++);
    // The derived future still carries an error to the zone, as the
    // unobserved action would have.
    unawaited(
      result.whenComplete(() {
        if (mounted) setState(() => _pending--);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context);
    final appearance = (theme.button ?? const GlassButtonStyle()).merge(
      widget.style,
    );
    final colors = LiquidPrismTheme.colorsOf(context);
    final tint = LiquidPrismTheme.tintOf(context);
    final prominent =
        (widget.variant ?? appearance.variant ?? GlassButtonVariant.regular) ==
        GlassButtonVariant.prominent;
    final metrics = _ButtonMetrics.resolve(
      widget.size ?? appearance.size ?? GlassControlSize.large,
    );
    final menu = widget.menu;
    final enabled =
        widget.enabled && (menu != null || widget.onPressed != null);
    final loading = _loading;
    final activate = !enabled
        ? null
        : menu == null
        ? _activate
        : () async {
            final result = await liquidMenus.show<Object?>(
              context: context,
              menu: menu,
            );
            if (context.mounted) widget.onMenuSelected?.call(result);
          };
    // A loading button stays enabled, focusable and announced as a button;
    // it only ignores activation until the work finishes.
    final action = activate == null || !loading ? activate : _ignore;
    final longPress = activate == null || loading || widget.onLongPress == null
        ? null
        : () {
            dispatchGlassHaptic(
              context,
              const GlassHapticEvent(
                GlassHapticComponent.button,
                GlassHapticKind.longPress,
              ),
            );
            widget.onLongPress!();
          };
    final explicitForeground =
        widget.foregroundColor ??
        appearance.foregroundColor ??
        appearance.textStyle?.color;
    final base =
        widget.glass ?? appearance.glass ?? theme.glass ?? Glass.regular;
    final material = widget.tintColor != null
        ? base.tint(widget.tintColor)
        : prominent && base.tintColor == null
        ? base.tint(widget.destructive ? colors.red : tint)
        : base;
    final foreground = !enabled
        ? colors.disabledLabel
        : explicitForeground ??
              (prominent
                  ? const Color(0xFFFFFFFF)
                  : widget.destructive
                  ? colors.red
                  : theme.foregroundColor ?? tint);
    final alignment = appearance.alignment ?? Alignment.center;
    final iconSize =
        appearance.iconSize ??
        (widget.child != null
            ? null
            : widget._iconOnly
            ? metrics.iconSize
            : metrics.fontSize);
    final bounds = BoxConstraints(
      minWidth:
          appearance.minimumSize?.width ??
          (widget._iconOnly ? metrics.iconExtent : 0),
      minHeight:
          appearance.minimumSize?.height ??
          (widget._iconOnly ? metrics.iconExtent : 0),
      maxWidth: appearance.maximumSize?.width ?? double.infinity,
      maxHeight: appearance.maximumSize?.height ?? double.infinity,
    );
    final content = _content(appearance);
    // The hidden content keeps the button's size while the indicator shows.
    // One stable tree: the content keeps its place (and any state) while it
    // turns invisible for the indicator, so only the indicator mounts.
    final shown = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: loading ? 0 : 1, child: content),
        if (loading)
          widget.loadingIndicator ??
              appearance.loadingIndicator ??
              _GlassActivityIndicator(
                size: widget._iconOnly ? metrics.iconSize : metrics.fontSize,
              ),
      ],
    );

    Widget button([double? fillWidth]) => LiquidPrismPressable.glass(
      label: widget.semanticLabel ?? widget.label,
      motion: widget.motion ?? appearance.motion,
      selected: widget.selected,
      onPressed: action,
      onLongPress: longPress,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: widget.onFocusChange,
      mouseCursor: widget.mouseCursor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          alignment: alignment,
          child: ConstrainedBox(
            constraints: fillWidth == null
                ? bounds
                : bounds.tighten(width: fillWidth),
            child: LiquidPrism(
              glass: material.interactive(false),
              shape:
                  widget.shape ??
                  appearance.shape ??
                  (widget._iconOnly ? GlassShape.circle : null),
              optics: widget.optics ?? appearance.optics,
              blur: widget.blur ?? appearance.blur,
              role: GlassRole.button,
              disabledProminent:
                  !enabled &&
                  prominent &&
                  widget.tintColor == null &&
                  base.tintColor == null,
              child: Padding(
                padding:
                    widget.padding ??
                    appearance.padding ??
                    metrics.padding(widget._iconOnly),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  alignment: alignment,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: metrics.fontSize,
                      fontWeight: FontWeight.w400,
                    ).merge(appearance.textStyle).copyWith(color: foreground),
                    child: IconTheme.merge(
                      data: IconThemeData(color: foreground, size: iconSize),
                      child: shown,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (appearance.sizing != GlassButtonSizing.fill) return button();
    return LayoutBuilder(
      builder: (context, constraints) =>
          button(constraints.hasBoundedWidth ? constraints.maxWidth : null),
    );
  }

  Widget _content(GlassButtonStyle appearance) {
    final main = _labelAndIcon(appearance);
    final trailing = widget.trailingIcon;
    if (trailing == null) return main;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: main),
        SizedBox(width: appearance.spacing ?? 8),
        trailing,
      ],
    );
  }

  Widget _labelAndIcon(GlassButtonStyle appearance) {
    if (widget.child case final child?) return child;
    final icon = widget.icon;
    if (widget._iconOnly) return icon!;
    final text = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (icon == null) return text;
    final placement = appearance.labelPlacement ?? GlassLabelPlacement.trailing;
    final vertical =
        placement == GlassLabelPlacement.above ||
        placement == GlassLabelPlacement.below;
    final labelFirst =
        placement == GlassLabelPlacement.leading ||
        placement == GlassLabelPlacement.above;
    final labelWidget = vertical
        ? text
        : Flexible(fit: FlexFit.loose, child: text);
    final gap = appearance.spacing ?? 8;
    final children = <Widget>[
      if (labelFirst) labelWidget else icon,
      SizedBox(width: vertical ? 0 : gap, height: vertical ? gap : 0),
      if (labelFirst) icon else labelWidget,
    ];
    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// The system activity indicator: eight spokes whose brightness steps around
/// the circle once a second, in the ambient icon color.
class _GlassActivityIndicator extends StatefulWidget {
  const _GlassActivityIndicator({required this.size});

  final double size;

  @override
  State<_GlassActivityIndicator> createState() =>
      _GlassActivityIndicatorState();
}

class _GlassActivityIndicatorState extends State<_GlassActivityIndicator>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    // The button's own label stays the accessible name.
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _SpokesPainter(
          _spin,
          IconTheme.of(context).color ?? const Color(0xFF8E8E93),
        ),
      ),
    ),
  );
}

class _SpokesPainter extends CustomPainter {
  _SpokesPainter(this.progress, this.color) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  static const _count = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..strokeWidth = radius * .22
      ..strokeCap = StrokeCap.round;
    final head = (progress.value * _count).floor();
    canvas.translate(size.width / 2, size.height / 2);
    for (var i = 0; i < _count; i++) {
      final age = (head - i) % _count;
      paint.color = color.withValues(alpha: color.a * (1 - age / _count * .8));
      canvas.save();
      canvas.rotate(i * 2 * math.pi / _count);
      canvas.drawLine(
        Offset(0, -radius * .45),
        Offset(0, -radius + paint.strokeWidth / 2),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SpokesPainter old) =>
      old.color != color || old.progress != progress;
}

// Text-button presets follow measured iOS 27 sizes in doc/button_sizes_spec.json.
class _ButtonMetrics {
  const _ButtonMetrics(
    this.fontSize,
    this.horizontal,
    this.vertical,
    this.iconSize,
    this.iconExtent,
  );
  final double fontSize, horizontal, vertical, iconSize, iconExtent;
  static _ButtonMetrics resolve(GlassControlSize size) => switch (size) {
    GlassControlSize.mini ||
    GlassControlSize.small => const _ButtonMetrics(15, 10, 5, 16, 28),
    GlassControlSize.regular => const _ButtonMetrics(17, 12, 7, 18, 32),
    GlassControlSize.large ||
    GlassControlSize.extraLarge => const _ButtonMetrics(17, 20, 15, 24, 48),
  };
  EdgeInsets padding(bool iconOnly) => iconOnly
      ? EdgeInsets.all((iconExtent - iconSize) / 2)
      : EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}
