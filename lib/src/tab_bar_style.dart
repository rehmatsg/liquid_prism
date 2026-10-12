import 'package:flutter/widgets.dart';

import 'material.dart';
import 'appearance.dart';
import 'motion.dart';
import 'style.dart';

/// Labels remain available to accessibility even when visually hidden.
enum GlassTabLabelBehavior { always, selected, never }

/// Layout and colors; null fields inherit the enclosing glass theme.
@immutable
class GlassTabBarStyle {
  const GlassTabBarStyle({
    this.glass,
    this.optics,
    this.blur,
    this.motion,
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
    this.minimumTabWidth,
    this.labelPadding,
    this.lens,
    this.refractContent,
    this.contentRefraction,
    this.contentDepth,
  }) : assert(blur == null || (blur >= 0 && blur <= 12)),
       assert(height == null || height >= 44),
       assert(iconSize == null || iconSize > 0),
       assert(
         selectionBlur == null || (selectionBlur >= 0 && selectionBlur <= 12),
       ),
       assert(minimumTabWidth == null || minimumTabWidth > 0),
       assert(labelPadding == null || labelPadding >= 0),
       assert(
         contentRefraction == null ||
             (contentRefraction >= 0 && contentRefraction <= 64),
       ),
       assert(contentDepth == null || contentDepth > 0);

  /// Housing material overrides. Lifted lenses use [lens] independently.
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
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

  /// Minimum tab center spacing before label measurement. Defaults to 86.
  final double? minimumTabWidth;

  /// Extra width around the widest label. Defaults to 32.
  final double? labelPadding;
  final GlassLensStyle? lens;

  /// Refract icon/label strokes near the held pill's rim. Defaults true.
  final bool? refractContent;

  /// Foreground displacement magnitude and rim depth; defaults 14 and 11.2.
  final double? contentRefraction, contentDepth;

  GlassTabBarStyle copyWith({
    Glass? glass,
    LiquidPrismStyle? optics,
    double? blur,
    GlassMotion? motion,
    GlassTabLabelBehavior? labelBehavior,
    double? height,
    EdgeInsets? padding,
    double? iconSize,
    TextStyle? labelStyle,
    Color? selectedColor,
    Color? unselectedColor,
    Color? selectionColor,
    double? selectionBlur,
    GlassShape? shape,
    GlassShape? selectionShape,
    bool? haptics,
    bool? expanded,
    double? minimumTabWidth,
    double? labelPadding,
    GlassLensStyle? lens,
    bool? refractContent,
    double? contentRefraction,
    double? contentDepth,
  }) => GlassTabBarStyle(
    glass: glass ?? this.glass,
    optics: optics ?? this.optics,
    blur: blur ?? this.blur,
    motion: motion ?? this.motion,
    labelBehavior: labelBehavior ?? this.labelBehavior,
    height: height ?? this.height,
    padding: padding ?? this.padding,
    iconSize: iconSize ?? this.iconSize,
    labelStyle: labelStyle ?? this.labelStyle,
    selectedColor: selectedColor ?? this.selectedColor,
    unselectedColor: unselectedColor ?? this.unselectedColor,
    selectionColor: selectionColor ?? this.selectionColor,
    selectionBlur: selectionBlur ?? this.selectionBlur,
    shape: shape ?? this.shape,
    selectionShape: selectionShape ?? this.selectionShape,
    haptics: haptics ?? this.haptics,
    expanded: expanded ?? this.expanded,
    minimumTabWidth: minimumTabWidth ?? this.minimumTabWidth,
    labelPadding: labelPadding ?? this.labelPadding,
    lens: lens ?? this.lens,
    refractContent: refractContent ?? this.refractContent,
    contentRefraction: contentRefraction ?? this.contentRefraction,
    contentDepth: contentDepth ?? this.contentDepth,
  );

  GlassTabBarStyle merge(GlassTabBarStyle? other) => other == null
      ? this
      : GlassTabBarStyle(
          glass: other.glass ?? glass,
          optics: other.optics ?? optics,
          blur: other.blur ?? blur,
          motion: other.motion ?? motion,
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
          minimumTabWidth: other.minimumTabWidth ?? minimumTabWidth,
          labelPadding: other.labelPadding ?? labelPadding,
          lens: (lens ?? const GlassLensStyle()).merge(other.lens),
          refractContent: other.refractContent ?? refractContent,
          contentRefraction: other.contentRefraction ?? contentRefraction,
          contentDepth: other.contentDepth ?? contentDepth,
        );
}
