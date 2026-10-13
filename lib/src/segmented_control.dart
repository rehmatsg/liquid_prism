import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'control_interaction.dart';
import 'control_material.dart';
import 'theme.dart';
import 'appearance.dart';
import 'motion.dart';
import 'tab_content_lens.dart';
import 'material.dart';

/// Equal-width segmented tabs, with a free-sliding glass selection lens.
/// Values follow the map's insertion order. The parent's [selectedValue] is
/// authoritative. Touch commits on release; keys and accessibility commit at once.
class LiquidPrismSegmentedControl<T extends Object> extends StatelessWidget {
  const LiquidPrismSegmentedControl({
    super.key,
    required this.children,
    required this.selectedValue,
    required this.onValueChanged,
    this.label,
    this.backgroundColor,
    this.thumbColor,
    this.foregroundColor,
    this.style,
    this.motion,
    this.onChangeStart,
    this.onChangeEnd,
  });
  final Map<T, Widget> children;
  final T selectedValue;
  final ValueChanged<T>? onValueChanged;
  final String? label;
  final Color? backgroundColor, thumbColor, foregroundColor;
  final GlassSegmentedStyle? style;
  final GlassControlMotion? motion;
  final ValueChanged<T>? onChangeStart, onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context);
    final appearance = (theme.segmentedControl ?? const GlassSegmentedStyle())
        .merge(style);
    final timing = (theme.controlMotion ?? const GlassControlMotion()).merge(
      motion,
    );
    final scale = appearance.scale ?? 1;
    var hitHeight = math.max(44.0, (appearance.hitHeight ?? 44) * scale);
    var trackHeight = (appearance.trackHeight ?? 32) * scale;
    var thumbHeight = (appearance.thumbHeight ?? 28) * scale;
    final inset = (appearance.selectionInset ?? 2) * scale;
    final liftInset = (appearance.liftInset ?? const Size(12, 8)) * scale;
    assert(liftInset.width >= 0 && liftInset.height >= 0);
    final lensStyle = (theme.lens ?? const GlassLensStyle()).merge(
      appearance.lens,
    );
    final colors = GlassColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    assert(children.length > 1 && children.length < 100);
    assert(children.containsKey(selectedValue));
    final keys = children.keys.toList();
    final count = keys.length, selected = keys.indexOf(selectedValue);
    var preferredWidth = (appearance.width ?? 300) * scale;
    if (appearance.sizing == GlassSegmentedSizing.fitLabels) {
      final padding =
          (appearance.labelPadding ??
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8))
              .resolve(Directionality.of(context)) *
          scale;
      var widest = 0.0, tallest = 0.0;
      for (final child in children.values) {
        final base = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.w500,
          ).merge(appearance.labelStyle),
        );
        final InlineSpan? span = switch (child) {
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
            // Replacing/reordering keys cancels an obsolete in-flight gesture.
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
            // Only the selected segment grabs the selection.
            grabExtent: slot / 2,
            builder: (context, position, lift, stretch, activate) {
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
                      math.max(.001, slot - 2 * inset) +
                      2 * liftInset.width * lift,
                  pillHeight = thumbHeight + 2 * liftInset.height * lift;
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
                      child: ControlTrack(
                        shape: appearance.trackShape ?? GlassShape.capsule,
                        color:
                            backgroundColor ??
                            appearance.backgroundColor ??
                            colors.tertiarySystemFill,
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
                        child: ControlThumb(
                          lift: lift,
                          small: false,
                          color: thumbColor ?? appearance.thumbColor,
                          style: appearance.lens,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      // Native labels bend near the held selection's rim.
                      child: ContentLensWindow(
                        lens: Rect.fromCenter(
                          center: pill.center,
                          width: pill.width * (1 + stretch),
                          height: pill.height * (1 - stretch),
                        ),
                        lift: lift,
                        shape: appearance.lens?.shape ?? GlassShape.capsule,
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
                                  // Native press on another segment: its label
                                  // fades to .4 (~.45 s) and back (~.2 s).
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
                                            TextStyle(
                                                  fontSize: 13 * scale,
                                                  fontWeight:
                                                      i == visualSelection
                                                      ? FontWeight.w500
                                                      : FontWeight.w400,
                                                )
                                                .merge(appearance.labelStyle)
                                                .copyWith(
                                                  color:
                                                      foregroundColor ??
                                                      appearance
                                                          .foregroundColor ??
                                                      (i == selected &&
                                                              lift < .5
                                                          ? appearance
                                                                .selectedForegroundColor
                                                          : null) ??
                                                      appearance
                                                          .labelStyle
                                                          ?.color ??
                                                      (i == selected &&
                                                              lift < .5
                                                          ? colors
                                                                .controlThumbLabel
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
