import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'appearance.dart';
import 'glass.dart';
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
/// Null callbacks disable touch, keyboard and accessibility activation.
class LiquidPrismButton extends StatelessWidget {
  const LiquidPrismButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.child,
    this.icon,
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
       _iconOnly = false,
       menu = null,
       onMenuSelected = null,
       _menuEnabled = false;

  const LiquidPrismButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required this.label,
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
       _iconOnly = true,
       menu = null,
       onMenuSelected = null,
       _menuEnabled = false;

  /// The button owns activation and presents the native menu through Liquid Menu.
  const LiquidPrismButton.menu({
    super.key,
    required LiquidMenu this.menu,
    required this.label,
    this.child,
    this.icon,
    ValueChanged<Object?>? onSelected,
    bool enabled = true,
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
       _iconOnly = false,
       onPressed = null,
       onMenuSelected = onSelected,
       _menuEnabled = enabled;

  final FutureOr<void> Function()? onPressed;
  final String label;
  final Widget? child, icon;
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
  final bool _iconOnly, _menuEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context);
    final appearance = (theme.button ?? const GlassButtonStyle()).merge(style);
    final colors = LiquidPrismTheme.colorsOf(context);
    final tint = LiquidPrismTheme.tintOf(context);
    final prominent =
        (variant ?? appearance.variant ?? GlassButtonVariant.regular) ==
        GlassButtonVariant.prominent;
    final metrics = _ButtonMetrics.resolve(
      size ?? appearance.size ?? GlassControlSize.large,
    );
    final enabled = menu == null ? onPressed != null : _menuEnabled;
    final action = menu == null
        ? onPressed
        : !enabled
        ? null
        : () async {
            final result = await liquidMenus.show<Object?>(
              context: context,
              menu: menu!,
            );
            if (context.mounted) onMenuSelected?.call(result);
          };
    final explicitForeground =
        foregroundColor ??
        appearance.foregroundColor ??
        appearance.textStyle?.color ??
        (prominent ? null : theme.foregroundColor);
    final base = glass ?? appearance.glass ?? theme.glass ?? Glass.regular;
    final material = prominent && base.tintColor == null
        ? base.tint(tint)
        : base;
    final foreground = !enabled
        ? colors.disabledLabel
        : explicitForeground ?? (prominent ? const Color(0xFFFFFFFF) : tint);
    final alignment = appearance.alignment ?? Alignment.center;
    final bounds = BoxConstraints(
      minWidth:
          appearance.minimumSize?.width ?? (_iconOnly ? metrics.iconExtent : 0),
      minHeight:
          appearance.minimumSize?.height ??
          (_iconOnly ? metrics.iconExtent : 0),
      maxWidth: appearance.maximumSize?.width ?? double.infinity,
      maxHeight: appearance.maximumSize?.height ?? double.infinity,
    );

    Widget button([double? fillWidth]) => LiquidPrismPressable.glass(
      label: label,
      motion: motion ?? appearance.motion,
      selected: selected,
      onPressed: action,
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      mouseCursor: mouseCursor,
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
                  shape ??
                  appearance.shape ??
                  (_iconOnly ? GlassShape.circle : null),
              optics: optics ?? appearance.optics,
              blur: blur ?? appearance.blur,
              role: GlassRole.button,
              disabledProminent:
                  !enabled && prominent && base.tintColor == null,
              child: Padding(
                padding:
                    padding ?? appearance.padding ?? metrics.padding(_iconOnly),
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
                      data: IconThemeData(
                        color: foreground,
                        size:
                            appearance.iconSize ??
                            (_iconOnly ? metrics.iconSize : metrics.fontSize),
                      ),
                      child: _content(appearance),
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
    if (child != null) return child!;
    if (_iconOnly) return icon!;
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
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
      if (labelFirst) labelWidget else icon!,
      SizedBox(width: vertical ? 0 : gap, height: vertical ? gap : 0),
      if (labelFirst) icon! else labelWidget,
    ];
    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(EnumProperty('variant', variant))
      ..add(EnumProperty('size', size))
      ..add(DiagnosticsProperty<GlassButtonStyle>('style', style))
      ..add(DiagnosticsProperty<Glass>('glass', glass))
      ..add(DiagnosticsProperty<LiquidPrismStyle>('optics', optics))
      ..add(DoubleProperty('blur', blur))
      ..add(DiagnosticsProperty<GlassShape>('shape', shape))
      ..add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding))
      ..add(ColorProperty('foregroundColor', foregroundColor))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(
        ObjectFlagProperty<FutureOr<void> Function()>.has(
          'onPressed',
          onPressed,
        ),
      );
  }
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
