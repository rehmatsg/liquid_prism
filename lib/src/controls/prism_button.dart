import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/prism_button_style.dart';
import 'package:liquid_prism/src/controls/prism_pressable.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_haptics.dart';
import 'package:liquid_prism/src/menu/menu.dart';
import 'package:liquid_prism/src/menu/menus.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';
import 'package:liquid_prism/src/theme/typography.dart';

export 'prism_button_style.dart' show PrismButtonVariant;

/// A glass action with text, icons, loading, and native menus.
class PrismButton extends StatefulWidget {
  /// Creates a glass action with generated or custom content.
  const new({
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
    this.destructive = false,
    this.selected = false,
    this.semanticLabel,
    this.variant,
    this.size,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.mouseCursor,
  }) : assert(
         child == null || icon == null,
         'Child and icon are mutually exclusive.',
       ),
       assert(
         child == null || trailingIcon == null,
         'Child and trailingIcon are mutually exclusive.',
       ),
       _iconOnly = false,
       menu = null,
       onMenuSelected = null;

  /// Creates an icon-only action with an accessible label.
  const new icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required this.label,
    this.enabled = true,
    this.onLongPress,
    this.isLoading = false,
    this.autoLoading = false,
    this.destructive = false,
    this.selected = false,
    this.semanticLabel,
    this.variant,
    this.size,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.mouseCursor,
  }) : child = null,
       trailingIcon = null,
       _iconOnly = true,
       menu = null,
       onMenuSelected = null;

  /// Creates a button that owns native menu activation.
  const new menu({
    super.key,
    required PrismMenu this.menu,
    required this.label,
    this.child,
    this.icon,
    this.trailingIcon,
    ValueChanged<Object?>? onSelected,
    this.enabled = true,
    this.isLoading = false,
    this.destructive = false,
    this.selected = false,
    this.semanticLabel,
    this.variant,
    this.size,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.mouseCursor,
  }) : assert(
         child == null || icon == null,
         'Child and icon are mutually exclusive.',
       ),
       assert(
         child == null || trailingIcon == null,
         'Child and trailingIcon are mutually exclusive.',
       ),
       _iconOnly = false,
       onPressed = null,
       onLongPress = null,
       autoLoading = false,
       onMenuSelected = onSelected;

  /// Action callback; null disables activation unless a menu is supplied.
  final FutureOr<void> Function()? onPressed;

  /// Long-press action, ignored while disabled or loading.
  final VoidCallback? onLongPress;

  /// Visible label and default accessible name.
  final String label;

  /// Custom content replacing the generated label and icons.
  final Widget? child;

  /// Leading icon for generated content.
  final Widget? icon;

  /// Trailing icon for generated content.
  final Widget? trailingIcon;

  /// Whether the button can activate.
  final bool enabled;

  /// Whether to show progress and ignore activation.
  final bool isLoading;

  /// Whether to show progress while the returned future is pending.
  final bool autoLoading;

  /// Whether to use the destructive native foreground or prominent tint.
  final bool destructive;

  /// Accessible name overriding the visible label.
  final String? semanticLabel;

  /// Material treatment overriding the resolved style.
  final PrismButtonVariant? variant;

  /// Size preset overriding the resolved style.
  final PrismControlSize? size;

  /// Visual overrides merged over the component theme.
  final PrismButtonStyle? style;

  /// Whether accessibility reports this button as selected.
  final bool selected;

  /// Borrowed focus node; the caller retains ownership.
  final FocusNode? focusNode;

  /// Whether to request focus when mounted.
  final bool autofocus;

  /// Callback for changes to keyboard focus.
  final ValueChanged<bool>? onFocusChange;

  /// Cursor shown while hovering over the button.
  final MouseCursor? mouseCursor;

  /// Native menu presented by the menu constructor.
  final PrismMenu? menu;

  /// Callback with the native menu result after dismissal.
  final ValueChanged<Object?>? onMenuSelected;
  final bool _iconOnly;

  @override
  State<PrismButton> createState() => _PrismButtonState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null))
      ..add(EnumProperty('variant', variant))
      ..add(EnumProperty('size', size))
      ..add(DiagnosticsProperty<PrismButtonStyle>('style', style))
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

class _PrismButtonState extends State<PrismButton> {
  int _pending = 0;

  bool get _loading => widget.isLoading || _pending > 0;

  static void _ignore() {}

  void _activate() {
    final result = widget.onPressed!();
    if (!widget.autoLoading || result is! Future<void>) return;
    setState(() => _pending++);
    unawaited(
      result.whenComplete(() {
        if (mounted) setState(() => _pending--);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = PrismTheme.of(context);
    final appearance = (theme.button ?? const PrismButtonStyle()).merge(
      widget.style,
    );
    final colors = PrismTheme.colorsOf(context);
    final tint = PrismTheme.tintOf(context);
    final prominent =
        (widget.variant ?? appearance.variant ?? PrismButtonVariant.regular) ==
        PrismButtonVariant.prominent;
    final metrics = _ButtonMetrics.resolve(
      widget.size ?? appearance.size ?? PrismControlSize.large,
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
            final result = await prismMenus.show<Object?>(
              context: context,
              menu: menu,
            );
            if (context.mounted) widget.onMenuSelected?.call(result);
          };
    final action = activate == null || !loading ? activate : _ignore;
    final longPress = activate == null || loading || widget.onLongPress == null
        ? null
        : () {
            dispatchPrismHaptic(
              context,
              const PrismHapticEvent(
                PrismHapticComponent.button,
                PrismHapticKind.longPress,
              ),
            );
            widget.onLongPress!();
          };
    final local = widget.style;
    final directForeground = local?.foregroundColor ?? local?.textStyle?.color;
    final themedForeground =
        theme.button?.foregroundColor ?? theme.button?.textStyle?.color;
    final base = appearance.glass ?? theme.glass ?? PrismGlass.regular;
    final themedTint = widget.destructive ? null : theme.button?.tintColor;
    final tintColor = local?.tintColor ?? themedTint;
    final material = tintColor != null
        ? base.tint(tintColor)
        : prominent && base.tintColor == null
        ? base.tint(widget.destructive ? colors.red : tint)
        : base;
    final foreground = !enabled
        ? colors.disabledLabel
        : directForeground ??
              (prominent
                  ? themedForeground ?? const Color(0xFFFFFFFF)
                  : widget.destructive
                  ? colors.red
                  : themedForeground ?? theme.foregroundColor ?? tint);
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
    final shown = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: loading ? 0 : 1, child: content),
        if (loading)
          appearance.loadingIndicator ??
              _PrismActivityIndicator(
                size: widget._iconOnly ? metrics.iconSize : metrics.fontSize,
              ),
      ],
    );

    Widget button([double? fillWidth]) => PrismPressable.glass(
      label: widget.semanticLabel ?? widget.label,
      motion: appearance.motion,
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
            child: RawPrismSurface(
              glass: material.interactive(false),
              shape:
                  appearance.shape ??
                  (widget._iconOnly ? PrismShape.circle : null),
              optics: appearance.optics,
              blur: appearance.blur,
              role: PrismRole.button,
              disabledProminent:
                  !enabled &&
                  prominent &&
                  tintColor == null &&
                  base.tintColor == null,
              child: Padding(
                padding:
                    appearance.padding ?? metrics.padding(widget._iconOnly),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  alignment: alignment,
                  child: DefaultTextStyle.merge(
                    style: prismTextStyle(
                      context,
                      TextStyle(
                        fontSize: metrics.fontSize,
                        fontWeight: FontWeight.w400,
                      ),
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
    if (appearance.sizing != PrismButtonSizing.fill) return button();
    return LayoutBuilder(
      builder: (context, constraints) =>
          button(constraints.hasBoundedWidth ? constraints.maxWidth : null),
    );
  }

  Widget _content(PrismButtonStyle appearance) {
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

  Widget _labelAndIcon(PrismButtonStyle appearance) {
    if (widget.child case final child?) return child;
    final icon = widget.icon;
    if (widget._iconOnly) return icon!;
    final text = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (icon == null) return text;
    final placement = appearance.labelPlacement ?? PrismLabelPlacement.trailing;
    final vertical =
        placement == PrismLabelPlacement.above ||
        placement == PrismLabelPlacement.below;
    final labelFirst =
        placement == PrismLabelPlacement.leading ||
        placement == PrismLabelPlacement.above;
    final labelWidget = vertical ? text : Flexible(child: text);
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

class _PrismActivityIndicator extends StatefulWidget {
  const new({required this.size});

  final double size;

  @override
  State<_PrismActivityIndicator> createState() =>
      _PrismActivityIndicatorState();
}

class _PrismActivityIndicatorState extends State<_PrismActivityIndicator>
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
  new(this.progress, this.color) : super(repaint: progress);

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
      canvas
        ..save()
        ..rotate(i * 2 * math.pi / _count)
        ..drawLine(
          Offset(0, -radius * .45),
          Offset(0, -radius + paint.strokeWidth / 2),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_SpokesPainter old) =>
      old.color != color || old.progress != progress;
}

class _ButtonMetrics {
  const new(
    this.fontSize,
    this.horizontal,
    this.vertical,
    this.iconSize,
    this.iconExtent,
  );
  factory resolve(PrismControlSize size) => switch (size) {
    PrismControlSize.mini ||
    PrismControlSize.small => const _ButtonMetrics(15, 10, 5, 16, 28),
    PrismControlSize.regular => const _ButtonMetrics(17, 12, 7, 18, 32),
    PrismControlSize.large ||
    PrismControlSize.extraLarge => const _ButtonMetrics(17, 20, 15, 24, 48),
  };

  final double fontSize;
  final double horizontal;
  final double vertical;
  final double iconSize;
  final double iconExtent;
  EdgeInsets padding(bool iconOnly) => iconOnly
      ? EdgeInsets.all((iconExtent - iconSize) / 2)
      : EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}
