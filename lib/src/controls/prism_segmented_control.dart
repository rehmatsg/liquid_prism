import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/control_interaction.dart';
import 'package:liquid_prism/src/controls/control_lens.dart';
import 'package:liquid_prism/src/controls/control_material.dart';
import 'package:liquid_prism/src/controls/prism_segmented_style.dart';
import 'package:liquid_prism/src/controls/prism_selection.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_lens_style.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';
import 'package:liquid_prism/src/rendering/tab_content_lens.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';
import 'package:liquid_prism/src/theme/typography.dart';

/// A parent-controlled segmented selection with a sliding glass lens.
class PrismSegmentedControl<T extends Object> extends StatelessWidget {
  /// Creates a controlled segmented selection.
  const new({
    super.key,
    required this.children,
    required this.selectedValue,
    required this.onValueChanged,
    this.label,
    this.onChangeStart,
    this.onChangeEnd,
    this.style,
  });

  /// Segment labels in logical insertion order.
  final Map<T, Widget> children;

  /// Parent-owned selected key.
  final T selectedValue;

  /// Proposes a selection; null disables all input.
  final ValueChanged<T>? onValueChanged;

  /// Accessible name for the segmented control.
  final String? label;

  /// Visual and motion overrides merged over the component theme.
  final PrismSegmentedStyle? style;

  /// Called when user input starts.
  final ValueChanged<T>? onChangeStart;

  /// Called when user input ends.
  final ValueChanged<T>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = PrismTheme.of(context);
    final appearance = (theme.segmentedControl ?? const PrismSegmentedStyle())
        .merge(style);
    final timing = (theme.controlMotion ?? const PrismControlMotion()).merge(
      appearance.motion,
    );
    final scale = appearance.scale ?? 1;
    final glass = appearance.variant == PrismSegmentedVariant.glass;
    final fontSize = (glass ? 15.0 : 13.0) * scale;
    final tracking = glass ? -.23 * scale : null;
    var trackHeight = (appearance.trackHeight ?? (glass ? 44 : 32)) * scale;
    var thumbHeight = (appearance.thumbHeight ?? (glass ? 36 : 28)) * scale;
    final inset = (appearance.selectionInset ?? (glass ? 4 : 2)) * scale;
    var hitHeight = math.max<double>(
      glass ? math.max(44, trackHeight) : 44,
      (appearance.hitHeight ?? 44) * scale,
    );
    final liftInset = (appearance.liftInset ?? const Size(12, 8)) * scale;
    assert(
      liftInset.width >= 0 && liftInset.height >= 0,
      'Lift inset dimensions must be non-negative.',
    );
    final lensStyle = (theme.lens ?? const PrismLensStyle()).merge(
      appearance.lens,
    );
    final colors = PrismTheme.colorsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    assert(
      children.length > 1 && children.length < 100,
      'Provide between 2 and 99 segments.',
    );
    assert(
      children.containsKey(selectedValue),
      'Selected value must identify a segment.',
    );
    final keys = children.keys.toList();
    final count = keys.length;
    final selected = keys.indexOf(selectedValue);
    var preferredWidth = (appearance.width ?? 300) * scale;
    if (appearance.sizing == PrismSegmentedSizing.fitLabels) {
      final padding =
          (appearance.labelPadding ??
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8))
              .resolve(Directionality.of(context)) *
          scale;
      var widest = 0.0;
      var tallest = 0.0;
      for (final child in children.values) {
        final base = prismTextStyle(
          context,
          TextStyle(
            fontSize: fontSize,
            fontWeight: glass ? FontWeight.w400 : FontWeight.w500,
            letterSpacing: tracking,
          ),
        ).merge(appearance.labelStyle);
        final span = switch (child) {
          Text(:final data, :final textSpan, :final style) => TextSpan(
            text: data,
            children: textSpan == null ? null : [textSpan],
            style: base.merge(style),
          ),
          RichText(:final text) => text,
          _ => null,
        };
        assert(
          span != null || appearance.width != null,
          'fitLabels needs Text/RichText labels, or an explicit width for custom widgets.',
        );
        if (span == null) continue;
        final painter = TextPainter(
          text: span,
          textDirection:
              (child is Text
                  ? child.textDirection
                  : (child as RichText).textDirection) ??
              Directionality.of(context),
          textScaler: child is Text
              ? child.textScaler ?? MediaQuery.textScalerOf(context)
              : (child as RichText).textScaler,
          locale:
              (child is Text ? child.locale : (child as RichText).locale) ??
              Localizations.maybeLocaleOf(context),
          strutStyle: child is Text
              ? child.strutStyle
              : (child as RichText).strutStyle,
          textHeightBehavior: child is Text
              ? child.textHeightBehavior
              : (child as RichText).textHeightBehavior,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        tallest = math.max(tallest, painter.height);
        painter.dispose();
      }
      if (appearance.width == null) {
        preferredWidth = (widest.ceilToDouble() + padding.horizontal) * count;
      }
      if (appearance.trackHeight == null) {
        trackHeight = math.max(
          trackHeight,
          tallest.ceilToDouble() + padding.vertical,
        );
      }
      if (appearance.thumbHeight == null) {
        thumbHeight = math.max(0, trackHeight - 2 * inset);
      }
      hitHeight = math.max(hitHeight, trackHeight);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.constrainWidth(preferredWidth);
        if (width <= 0) return const SizedBox.shrink();
        final slot = width / count;
        return SizedBox(
          width: width,
          height: hitHeight,
          child: ControlInteraction(
            key: ValueKey(Object.hashAll(keys)),
            value: selected / (count - 1),
            steps: count - 1,
            travel: slot * (count - 1),
            label: label,
            motion: timing,
            onChanged: onValueChanged == null
                ? null
                : (v) => onValueChanged!(keys[(v * (count - 1)).round()]),
            onChangeStart: onChangeStart == null
                ? null
                : (v) => onChangeStart!(
                    keys[(v * (count - 1)).round().clamp(0, count - 1)],
                  ),
            onChangeEnd: onChangeEnd == null
                ? null
                : (v) => onChangeEnd!(
                    keys[(v * (count - 1)).round().clamp(0, count - 1)],
                  ),
            positionAt: (x) =>
                ((((rtl ? width - x : x) / slot) - .5) / (count - 1)).clamp(
                  0.0,
                  1.0,
                ),
            spring: timing.travel?.description ?? NativeControl.segmentTravel,
            trackingSpring:
                timing.tracking?.description ?? NativeControl.segmentTracking,
            liftSpring: timing.lift?.description ?? NativeControl.largeLift,
            releaseSpring:
                timing.release?.description ?? NativeControl.largeLift,
            hangTime:
                timing.minimumLiftDuration ?? const Duration(milliseconds: 220),
            grabExtent: slot / 2,
            builder: (context, position, lift, stretch, activate) {
              final selectedForeground = appearance.selectedForegroundColor;
              final selectedLabel = glass
                  ? colors.label
                  : colors.controlThumbLabel;
              final selectionShape =
                  appearance.lens?.shape ?? PrismShape.capsule;
              final preview = (position * (count - 1)).round().clamp(
                0,
                count - 1,
              );
              final visualSelection = lift > .001 ? preview : selected;
              final press = ControlInteraction.pressedOf(context);
              final pressed = press == null
                  ? null
                  : (press * (count - 1)).round();
              final physical = (rtl ? 1 - position : position) * (count - 1);
              final pillWidth =
                  math.max(.001, slot - 2 * inset) + 2 * liftInset.width * lift;
              final pillHeight = thumbHeight + 2 * liftInset.height * lift;
              final pill = Rect.fromLTWH(
                slot * (physical + .5) - pillWidth / 2,
                hitHeight / 2 - pillHeight / 2,
                pillWidth,
                pillHeight,
              );
              return ControlDisabled(
                enabled: onValueChanged != null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: (hitHeight - trackHeight) / 2,
                      width: width,
                      height: trackHeight,
                      child: glass
                          ? RawPrismSurface(
                              glass: appearance.glass,
                              shape:
                                  appearance.trackShape ?? PrismShape.capsule,
                              role: PrismRole.toolbar,
                              child: const SizedBox.expand(),
                            )
                          : ControlTrack(
                              shape:
                                  appearance.trackShape ?? PrismShape.capsule,
                              color:
                                  appearance.backgroundColor ??
                                  colors.tertiarySystemFill,
                            ),
                    ),
                    if (glass)
                      Positioned.fromRect(
                        rect: pill,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 1 - lift.clamp(0.0, 1.0),
                            child: PrismSelection(
                              selected: true,
                              shape: selectionShape,
                              color: appearance.thumbColor,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    Positioned.fromRect(
                      rect: pill,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          1 + stretch,
                          1 - stretch,
                          1,
                        ),
                        child: glass
                            ? ControlLens(
                                lift: lift,
                                shape: selectionShape,
                                role: PrismRole.tabLens,
                                rim: 1,
                                style: appearance.lens,
                              )
                            : ControlThumb(
                                lift: lift,
                                small: false,
                                color: appearance.thumbColor,
                                style: appearance.lens,
                              ),
                      ),
                    ),
                    Positioned.fill(
                      child: ContentLensWindow(
                        lens: Rect.fromCenter(
                          center: pill.center,
                          width: pill.width * (1 + stretch),
                          height: pill.height * (1 - stretch),
                        ),
                        lift: lift,
                        shape: appearance.lens?.shape ?? PrismShape.capsule,
                        refraction: appearance.refractContent == false
                            ? 0
                            : appearance.contentRefraction ?? 14,
                        depth: appearance.contentDepth ?? 11.2,
                        chromaticAberration: appearance.refractContent == false
                            ? 0
                            : lensStyle.chromaticAberration ?? 3.5,
                        chromaticBand: lensStyle.chromaticBand ?? 4.8,
                        child: Row(
                          children: [
                            for (var i = 0; i < count; i++)
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: i == selected,
                                  inMutuallyExclusiveGroup: true,
                                  enabled: onValueChanged != null,
                                  onTap: onValueChanged == null
                                      ? null
                                      : () => activate(i / (count - 1)),
                                  child: AnimatedOpacity(
                                    opacity: i == pressed && i != selected
                                        ? .4
                                        : 1,
                                    duration: i == pressed
                                        ? const Duration(milliseconds: 450)
                                        : const Duration(milliseconds: 200),
                                    curve: Curves.easeOutQuad,
                                    child: Center(
                                      child: DefaultTextStyle.merge(
                                        style:
                                            prismTextStyle(
                                                  context,
                                                  TextStyle(
                                                    fontSize: fontSize,
                                                    fontWeight:
                                                        i == visualSelection &&
                                                            !glass
                                                        ? FontWeight.w500
                                                        : FontWeight.w400,
                                                    letterSpacing: tracking,
                                                  ),
                                                )
                                                .merge(appearance.labelStyle)
                                                .copyWith(
                                                  color:
                                                      appearance
                                                          .foregroundColor ??
                                                      (i == selected &&
                                                              lift < .5
                                                          ? selectedForeground
                                                          : null) ??
                                                      appearance
                                                          .labelStyle
                                                          ?.color ??
                                                      (onValueChanged == null
                                                          ? colors.label
                                                          : i == selected &&
                                                                lift < .5
                                                          ? selectedLabel
                                                          : colors.label),
                                                ),
                                        child: children[keys[i]]!,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
