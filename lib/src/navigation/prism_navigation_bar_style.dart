import 'package:flutter/widgets.dart';

import '../core/prism_motion.dart';
import 'prism_title_style.dart';

/// Placement and typography mode for a navigation bar title.
enum PrismTitleDisplayMode { automatic, inline, inlineLarge, large }

/// Horizontal alignment for a navigation bar title.
enum PrismTitleAlignment { automatic, leading, center, trailing }

/// Scroll-driven minimization behavior for a navigation bar.
enum PrismMinimizationBehavior { automatic, never, onScrollDown, onScrollUp }

/// Restoration policy for a minimized navigation bar.
enum PrismMinimizationRestoration { automatic, atScrollEdge }

/// Safe-area inset behavior while a navigation bar minimizes.
enum PrismMinimizationSafeArea { automatic, enabled, disabled }

/// Typography, layout, and minimization overrides for navigation bars.
@immutable
class PrismNavigationBarStyle {
  /// Creates a partial navigation bar style override.
  const PrismNavigationBarStyle({
    this.titleStyle,
    this.titleDisplayMode,
    this.titleAlignment,
    this.largeTitleAlignment,
    this.minimizationBehavior,
    this.minimizationThreshold,
    this.minimizationRestoration,
    this.minimizationSafeArea,
    this.controlRowHeight,
    this.contentPadding,
    this.largeTitleExtent,
    this.largeTitleStyle,
    this.subtitleStyle,
    this.largeSubtitleStyle,
    this.gutter,
    this.controlGap,
    this.contentSpacing,
    this.revealExtent,
    this.revealSpring,
    this.hideSpring,
    this.inlineTitleDelay,
    this.largeTitleFadeDuration,
    this.largeTitleFadeCurve,
    this.titleCapsule,
  }) : assert(gutter == null || gutter >= 0),
       assert(controlGap == null || controlGap >= 0),
       assert(contentSpacing == null || contentSpacing >= 0),
       assert(revealExtent == null || revealExtent >= 0),
       assert(controlRowHeight == null || controlRowHeight >= 44),
       assert(largeTitleExtent == null || largeTitleExtent >= 0),
       assert(minimizationThreshold == null || minimizationThreshold >= 0);

  /// Default reveal spring for inline titles.
  static const PrismSpring titleSpring = PrismSpring.physical(
    SpringDescription(mass: 1, stiffness: 225, damping: 28.3),
  );

  /// Default hide spring for inline titles.
  static const PrismSpring titleHideSpring = PrismSpring.physical(
    SpringDescription(mass: 1, stiffness: 93.3, damping: 18.22),
  );

  /// Inline title text style override.
  final TextStyle? titleStyle;

  /// Expanded large title text style override.
  final TextStyle? largeTitleStyle;

  /// Title display mode override.
  final PrismTitleDisplayMode? titleDisplayMode;

  /// Inline subtitle text style override.
  final TextStyle? subtitleStyle;

  /// Expanded large subtitle text style override.
  final TextStyle? largeSubtitleStyle;

  /// Horizontal outer gutter for bar controls.
  final double? gutter;

  /// Spacing between leading/trailing controls and the title.
  final double? controlGap;

  /// Clearance below navigation chrome before body content.
  final double? contentSpacing;

  /// Inline title alignment override.
  final PrismTitleAlignment? titleAlignment;

  /// Expanded large title alignment override.
  final PrismTitleAlignment? largeTitleAlignment;

  /// Scroll-driven minimization behavior.
  final PrismMinimizationBehavior? minimizationBehavior;

  /// Scroll threshold before minimization begins.
  final double? minimizationThreshold;

  /// Policy for restoring a minimized bar.
  final PrismMinimizationRestoration? minimizationRestoration;

  /// Policy for adjusting pinned safe-area clearance during minimization.
  final PrismMinimizationSafeArea? minimizationSafeArea;

  /// Minimum height of the control row before text scaling.
  final double? controlRowHeight;

  /// Additional padding inside the safe area.
  final EdgeInsetsGeometry? contentPadding;

  /// Explicit expanded large-title row height.
  final double? largeTitleExtent;

  /// Scroll distance at which the large title transitions to inline.
  final double? revealExtent;

  /// Spring animating inline title reveal.
  final PrismSpring? revealSpring;

  /// Spring animating inline title hide.
  final PrismSpring? hideSpring;

  /// Delay before the inline title starts revealing from rest.
  final Duration? inlineTitleDelay;

  /// Duration of the large title fade transition.
  final Duration? largeTitleFadeDuration;

  /// Curve of the large title fade transition.
  final Curve? largeTitleFadeCurve;

  /// Geometry and glass overrides for [PrismTitle] capsules in this bar.
  final PrismTitleStyle? titleCapsule;

  /// Returns a copy with specified fields replaced.
  PrismNavigationBarStyle copyWith({
    TextStyle? titleStyle,
    PrismTitleDisplayMode? titleDisplayMode,
    PrismTitleAlignment? titleAlignment,
    PrismTitleAlignment? largeTitleAlignment,
    PrismMinimizationBehavior? minimizationBehavior,
    double? minimizationThreshold,
    PrismMinimizationRestoration? minimizationRestoration,
    PrismMinimizationSafeArea? minimizationSafeArea,
    double? controlRowHeight,
    EdgeInsetsGeometry? contentPadding,
    double? largeTitleExtent,
    TextStyle? largeTitleStyle,
    TextStyle? subtitleStyle,
    TextStyle? largeSubtitleStyle,
    double? gutter,
    double? controlGap,
    double? contentSpacing,
    double? revealExtent,
    PrismSpring? revealSpring,
    PrismSpring? hideSpring,
    Duration? inlineTitleDelay,
    Duration? largeTitleFadeDuration,
    Curve? largeTitleFadeCurve,
    PrismTitleStyle? titleCapsule,
  }) => PrismNavigationBarStyle(
    titleStyle: titleStyle ?? this.titleStyle,
    titleDisplayMode: titleDisplayMode ?? this.titleDisplayMode,
    titleAlignment: titleAlignment ?? this.titleAlignment,
    largeTitleAlignment: largeTitleAlignment ?? this.largeTitleAlignment,
    minimizationBehavior: minimizationBehavior ?? this.minimizationBehavior,
    minimizationThreshold: minimizationThreshold ?? this.minimizationThreshold,
    minimizationRestoration:
        minimizationRestoration ?? this.minimizationRestoration,
    minimizationSafeArea: minimizationSafeArea ?? this.minimizationSafeArea,
    controlRowHeight: controlRowHeight ?? this.controlRowHeight,
    contentPadding: contentPadding ?? this.contentPadding,
    largeTitleExtent: largeTitleExtent ?? this.largeTitleExtent,
    largeTitleStyle: largeTitleStyle ?? this.largeTitleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    largeSubtitleStyle: largeSubtitleStyle ?? this.largeSubtitleStyle,
    gutter: gutter ?? this.gutter,
    controlGap: controlGap ?? this.controlGap,
    contentSpacing: contentSpacing ?? this.contentSpacing,
    revealExtent: revealExtent ?? this.revealExtent,
    revealSpring: revealSpring ?? this.revealSpring,
    hideSpring: hideSpring ?? this.hideSpring,
    inlineTitleDelay: inlineTitleDelay ?? this.inlineTitleDelay,
    largeTitleFadeDuration:
        largeTitleFadeDuration ?? this.largeTitleFadeDuration,
    largeTitleFadeCurve: largeTitleFadeCurve ?? this.largeTitleFadeCurve,
    titleCapsule: titleCapsule ?? this.titleCapsule,
  );

  /// Merges non-null fields from [other] over this style.
  PrismNavigationBarStyle merge(PrismNavigationBarStyle? other) => other == null
      ? this
      : PrismNavigationBarStyle(
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          titleDisplayMode: other.titleDisplayMode ?? titleDisplayMode,
          titleAlignment: other.titleAlignment ?? titleAlignment,
          largeTitleAlignment: other.largeTitleAlignment ?? largeTitleAlignment,
          minimizationBehavior:
              other.minimizationBehavior ?? minimizationBehavior,
          minimizationThreshold:
              other.minimizationThreshold ?? minimizationThreshold,
          minimizationRestoration:
              other.minimizationRestoration ?? minimizationRestoration,
          minimizationSafeArea:
              other.minimizationSafeArea ?? minimizationSafeArea,
          controlRowHeight: other.controlRowHeight ?? controlRowHeight,
          contentPadding: other.contentPadding ?? contentPadding,
          largeTitleExtent: other.largeTitleExtent ?? largeTitleExtent,
          largeTitleStyle:
              largeTitleStyle?.merge(other.largeTitleStyle) ??
              other.largeTitleStyle,
          subtitleStyle:
              subtitleStyle?.merge(other.subtitleStyle) ?? other.subtitleStyle,
          largeSubtitleStyle:
              largeSubtitleStyle?.merge(other.largeSubtitleStyle) ??
              other.largeSubtitleStyle,
          gutter: other.gutter ?? gutter,
          controlGap: other.controlGap ?? controlGap,
          contentSpacing: other.contentSpacing ?? contentSpacing,
          revealExtent: other.revealExtent ?? revealExtent,
          revealSpring: other.revealSpring ?? revealSpring,
          hideSpring: other.hideSpring ?? hideSpring,
          inlineTitleDelay: other.inlineTitleDelay ?? inlineTitleDelay,
          largeTitleFadeDuration:
              other.largeTitleFadeDuration ?? largeTitleFadeDuration,
          largeTitleFadeCurve: other.largeTitleFadeCurve ?? largeTitleFadeCurve,
          titleCapsule:
              titleCapsule?.merge(other.titleCapsule) ?? other.titleCapsule,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismNavigationBarStyle &&
          other.titleStyle == titleStyle &&
          other.titleDisplayMode == titleDisplayMode &&
          other.titleAlignment == titleAlignment &&
          other.largeTitleAlignment == largeTitleAlignment &&
          other.minimizationBehavior == minimizationBehavior &&
          other.minimizationThreshold == minimizationThreshold &&
          other.minimizationRestoration == minimizationRestoration &&
          other.minimizationSafeArea == minimizationSafeArea &&
          other.controlRowHeight == controlRowHeight &&
          other.contentPadding == contentPadding &&
          other.largeTitleExtent == largeTitleExtent &&
          other.largeTitleStyle == largeTitleStyle &&
          other.subtitleStyle == subtitleStyle &&
          other.largeSubtitleStyle == largeSubtitleStyle &&
          other.gutter == gutter &&
          other.controlGap == controlGap &&
          other.contentSpacing == contentSpacing &&
          other.revealExtent == revealExtent &&
          other.revealSpring == revealSpring &&
          other.hideSpring == hideSpring &&
          other.inlineTitleDelay == inlineTitleDelay &&
          other.largeTitleFadeDuration == largeTitleFadeDuration &&
          other.largeTitleFadeCurve == largeTitleFadeCurve &&
          other.titleCapsule == titleCapsule;

  @override
  int get hashCode => Object.hashAll([
    titleStyle,
    titleDisplayMode,
    titleAlignment,
    largeTitleAlignment,
    minimizationBehavior,
    minimizationThreshold,
    minimizationRestoration,
    minimizationSafeArea,
    controlRowHeight,
    contentPadding,
    largeTitleExtent,
    largeTitleStyle,
    subtitleStyle,
    largeSubtitleStyle,
    gutter,
    controlGap,
    contentSpacing,
    revealExtent,
    revealSpring,
    hideSpring,
    inlineTitleDelay,
    largeTitleFadeDuration,
    largeTitleFadeCurve,
    titleCapsule,
  ]);
}
