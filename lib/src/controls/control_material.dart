import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/prism_glass.dart';
import '../core/prism_lens_style.dart';
import '../rendering/recipe.dart';
import '../theme/prism_theme.dart';
import 'control_lens.dart';

/// Captured native control geometry and spring defaults.
@internal
abstract final class NativeControl {
  /// Native resting small-control thumb dimensions.
  static const thumbWidth = 37.0, thumbHeight = 24.0;

  /// Native slider thumb enlargement while held.
  static const thumbHeldScale = 1.55;

  /// Creates a spring from native duration and damping inputs.
  static SpringDescription spring(int milliseconds, double ratio) =>
      SpringDescription.withDurationAndBounce(
        duration: Duration(milliseconds: milliseconds),
        bounce: 1 - ratio,
      );

  /// Native switch travel spring.
  static final switchTravel = spring(300, 1);

  /// Native minimum switch tap-lift duration.
  static const switchHangTime = Duration(milliseconds: 220);

  /// Native slider settling spring.
  static final sliderTravel = spring(400, .8);

  /// Native slider tracking spring.
  static final sliderTracking = spring(400, 1);

  /// Native small-control lift spring.
  static final smallLift = spring(270, .625);

  /// Native small-control release spring.
  static final smallRelease = spring(500, .7);

  /// Native segmented selection travel spring.
  static final segmentTravel = spring(400, .85);

  /// Native segmented selection tracking spring.
  static final segmentTracking = spring(200, .85);

  /// Native large-selection lift spring.
  static final largeLift = spring(250, 1);
}

/// Dissolves a resting fill into the shared lifted lens.
@internal
class ControlThumb extends StatelessWidget {
  /// Creates a resting thumb that lifts into glass.
  const ControlThumb({
    super.key,
    required this.lift,
    this.small = true,
    this.restingShadow = false,
    this.minifyUnderlay = true,
    this.color,
    this.style,
  });

  /// Normalized lift progress.
  final double lift;

  /// Lens family, resting shadow, and underlying-content minification.
  final bool small, restingShadow, minifyUnderlay;

  /// Resting thumb fill override.
  final Color? color;

  /// Shared lifted-lens overrides.
  final PrismLensStyle? style;
  @override
  Widget build(BuildContext context) {
    final colors = PrismTheme.colorsOf(context);
    final fill = !small && colors.brightness == Brightness.dark
        ? colors.tertiaryLabel.withValues(alpha: .3)
        : colors.controlThumb;
    return ControlLens(
      lift: lift,
      role: !small
          ? PrismRole.segmentLens
          : minifyUnderlay
          ? PrismRole.controlThumb
          : PrismRole.sliderLens,
      restingColor: color ?? fill,
      restingShadow: restingShadow,
      style: style,
    );
  }
}

/// Clips track paint to its continuous contour.
@internal
class ControlTrack extends StatelessWidget {
  /// Creates a clipped control track.
  const ControlTrack({
    super.key,
    required this.color,
    this.child,
    this.shape = PrismShape.capsule,
  });

  /// Track fill color.
  final Color color;

  /// Optional content clipped inside the track.
  final Widget? child;

  /// Track contour.
  final PrismShape shape;
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: PrismShapeClipper(shape),
    child: ColoredBox(color: color, child: child),
  );
}

/// Applies disabled alpha while retaining backdrop sampling.
@internal
class ControlDisabled extends StatelessWidget {
  /// Creates a disabled-alpha wrapper.
  const ControlDisabled({
    super.key,
    required this.enabled,
    required this.child,
  });

  /// Whether to paint the child at full alpha.
  final bool enabled;

  /// Control content whose disabled alpha is resolved.
  final Widget child;
  @override
  Widget build(BuildContext context) => enabled
      ? child
      : ColorFiltered(
          colorFilter: const ui.ColorFilter.matrix([
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            .5,
            0,
          ]),
          child: child,
        );
}
