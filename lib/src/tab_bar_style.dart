import 'package:flutter/widgets.dart';

import 'material.dart';

/// Labels remain available to accessibility even when visually hidden.
enum GlassTabLabelBehavior { always, selected, never }

/// Layout and colors; null fields inherit the enclosing glass theme.
@immutable
class GlassTabBarStyle {
  const GlassTabBarStyle({
    this.labelBehavior,
    this.height,
    this.padding,
    this.iconSize,
    this.labelStyle,
    this.selectedColor,
    this.unselectedColor,
    this.selectionColor,
    this.selectionBlur,
    this.shape,
    this.selectionShape,
    this.haptics,
    this.expanded,
  }) : assert(height == null || height >= 44),
       assert(iconSize == null || iconSize > 0),
       assert(
         selectionBlur == null || (selectionBlur >= 0 && selectionBlur <= 12),
       );
  final GlassTabLabelBehavior? labelBehavior;
  final double? height, iconSize;
  final EdgeInsets? padding;
  final TextStyle? labelStyle;
  final Color? selectedColor, unselectedColor, selectionColor;

  /// Extra pill blur, independent of the enclosing bar. Defaults to 2.
  /// Set to zero to disable; null inherits the enclosing theme.
  final double? selectionBlur;
  final GlassShape? shape, selectionShape;
  final bool? haptics;

  /// Fill the parent's available width. Defaults to false: the floating bar
  /// sizes to its tabs and stays compact, even inside a wide or tight parent.
  final bool? expanded;

  GlassTabBarStyle merge(GlassTabBarStyle? other) => other == null
      ? this
      : GlassTabBarStyle(
          labelBehavior: other.labelBehavior ?? labelBehavior,
          height: other.height ?? height,
          padding: other.padding ?? padding,
          iconSize: other.iconSize ?? iconSize,
          labelStyle: labelStyle?.merge(other.labelStyle) ?? other.labelStyle,
          selectedColor: other.selectedColor ?? selectedColor,
          unselectedColor: other.unselectedColor ?? unselectedColor,
          selectionColor: other.selectionColor ?? selectionColor,
          selectionBlur: other.selectionBlur ?? selectionBlur,
          shape: other.shape ?? shape,
          selectionShape: other.selectionShape ?? selectionShape,
          haptics: other.haptics ?? haptics,
          expanded: other.expanded ?? expanded,
        );
}
