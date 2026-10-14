import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'theme.dart';

/// How glass enters and leaves. Mirrors SwiftUI's `GlassEffectTransition`.
enum GlassTransition {
  /// Appear and disappear without animating the material.
  identity,

  /// Grow the lens, frost, light and shadow in from the live backdrop, while
  /// foreground content fades and sharpens. Exit runs the same path in reverse.
  materialize,
}

/// Timing and content treatment for [LiquidPrismVisibility].
///
/// Unspecified fields inherit the theme, then the fitted defaults: a 450 ms
/// zero-bounce entry, a 300 ms exit and an 8-point content blur. These are
/// fitted by eye, not measured from native.
@immutable
class GlassTransitionStyle {
  const GlassTransitionStyle({
    this.enterSpring,
    this.exitSpring,
    this.contentBlur,
  }) : assert(contentBlur == null || contentBlur >= 0);
  final GlassSpring? enterSpring;
  final GlassSpring? exitSpring;

  /// Gaussian blur, in logical pixels, of foreground content while absent.
  /// Zero fades content without blurring it.
  final double? contentBlur;

  GlassTransitionStyle copyWith({
    GlassSpring? enterSpring,
    GlassSpring? exitSpring,
    double? contentBlur,
  }) => GlassTransitionStyle(
    enterSpring: enterSpring ?? this.enterSpring,
    exitSpring: exitSpring ?? this.exitSpring,
    contentBlur: contentBlur ?? this.contentBlur,
  );

  GlassTransitionStyle merge(GlassTransitionStyle? other) => other == null
      ? this
      : GlassTransitionStyle(
          enterSpring: other.enterSpring ?? enterSpring,
          exitSpring: other.exitSpring ?? exitSpring,
          contentBlur: other.contentBlur ?? contentBlur,
        );
}

/// Drives how present every glass surface below it is, from 0 (absent) to 1.
///
/// The material fades through its own optical inputs, so the backdrop stays
/// live; never fade glass with an ancestor Opacity. Nested presences multiply.
/// Use [LiquidPrismVisibility] for an ordinary show/hide.
class LiquidPrismPresence extends StatefulWidget {
  const LiquidPrismPresence({
    super.key,
    required this.progress,
    required this.child,
    this.contentBlur = 8,
    this.materialize = true,
  }) : assert(contentBlur >= 0);

  /// Values outside 0–1 (for example a spring's overshoot) are clamped.
  final Animation<double> progress;

  /// Blur of foreground content at zero presence.
  final double contentBlur;

  /// False keeps the lens at full size: the material fades through its
  /// optics without growing in. Content blurs and fades either way.
  final bool materialize;
  final Widget child;

  /// The combined presence for glass at [context]; 1 outside any presence.
  static double of(BuildContext context) =>
      maybeData(context)?.progress.value.clamp(0.0, 1.0) ?? 1;

  @internal
  static GlassPresenceScope? maybeData(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassPresenceScope>();

  @override
  State<LiquidPrismPresence> createState() => _LiquidPrismPresenceState();
}

class _LiquidPrismPresenceState extends State<LiquidPrismPresence> {
  Animation<double>? _parent;
  Animation<double>? _combined;

  Animation<double> _resolve(Animation<double>? parent) {
    if (_combined == null ||
        parent != _parent ||
        (_combined is _PresenceProduct
            ? (_combined! as _PresenceProduct).next != widget.progress
            : _combined != widget.progress)) {
      _parent = parent;
      _combined = parent == null
          ? widget.progress
          : _PresenceProduct(parent, widget.progress);
    }
    return _combined!;
  }

  @override
  Widget build(BuildContext context) {
    final parent = LiquidPrismPresence.maybeData(context);
    return GlassPresenceScope(
      progress: _resolve(parent?.progress),
      contentBlur: widget.contentBlur,
      materialize: widget.materialize && (parent?.materialize ?? true),
      child: widget.child,
    );
  }
}

class _PresenceProduct extends CompoundAnimation<double> {
  _PresenceProduct(Animation<double> first, Animation<double> next)
    : super(first: first, next: next);
  @override
  double get value => first.value.clamp(0.0, 1.0) * next.value.clamp(0.0, 1.0);
}

@internal
class GlassPresenceScope extends InheritedNotifier<Animation<double>> {
  const GlassPresenceScope({
    super.key,
    required Animation<double> progress,
    required this.contentBlur,
    required this.materialize,
    required super.child,
  }) : super(notifier: progress);
  Animation<double> get progress => notifier!;
  final double contentBlur;
  final bool materialize;

  @override
  bool updateShouldNotify(GlassPresenceScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      contentBlur != oldWidget.contentBlur ||
      materialize != oldWidget.materialize;
}

/// Shows or hides glass with the native-style materialize transition.
///
/// The child stays mounted while it animates out and is then removed. It stops
/// receiving pointers and leaves the semantics tree as soon as it is hidden.
/// Reduce Motion replaces materializing with a short fade.
class LiquidPrismVisibility extends StatefulWidget {
  const LiquidPrismVisibility({
    super.key,
    required this.visible,
    required this.child,
    this.transition = GlassTransition.materialize,
    this.style,
    this.onEnd,
  });
  final bool visible;
  final Widget child;
  final GlassTransition transition;

  /// Overrides the theme's transition style field by field.
  final GlassTransitionStyle? style;

  /// Called when an entry or exit settles.
  final VoidCallback? onEnd;

  @override
  State<LiquidPrismVisibility> createState() => _LiquidPrismVisibilityState();
}

class _LiquidPrismVisibilityState extends State<LiquidPrismVisibility>
    with SingleTickerProviderStateMixin {
  late final _presence = RetargetableGlassSpring(vsync: this)
    ..value = widget.visible ? 1 : 0
    ..addStatusListener(_status);

  GlassTransitionStyle get _style =>
      (LiquidPrismTheme.of(context).transition ?? const GlassTransitionStyle())
          .merge(widget.style);

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      if (mounted) setState(() {});
      widget.onEnd?.call();
    }
  }

  @override
  void didUpdateWidget(LiquidPrismVisibility old) {
    super.didUpdateWidget(old);
    if (old.visible == widget.visible) return;
    final target = widget.visible ? 1.0 : 0.0;
    if (widget.transition == GlassTransition.identity) {
      _presence.value = target;
      widget.onEnd?.call();
      return;
    }
    final style = _style;
    springGlass(
      _presence,
      target,
      _reduceMotion
          ? SpringDescription.withDurationAndBounce(
              duration: const Duration(milliseconds: 200),
            )
          : widget.visible
          ? style.enterSpring?.description ??
                SpringDescription.withDurationAndBounce(
                  duration: const Duration(milliseconds: 450),
                )
          : style.exitSpring?.description ??
                SpringDescription.withDurationAndBounce(
                  duration: const Duration(milliseconds: 300),
                ),
    );
  }

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && !_presence.isAnimating && _presence.value <= 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      ignoring: !widget.visible,
      child: ExcludeSemantics(
        excluding: !widget.visible,
        child: LiquidPrismPresence(
          progress: _presence,
          contentBlur: _style.contentBlur ?? 8,
          materialize: !_reduceMotion,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Content entering or leaving with glass, as iOS does: it blurs and fades
/// out as [presence] falls to 0 and sharpens in as it returns, without
/// moving or scaling. At full presence it adds no layers, so child state and
/// paint are untouched.
class GlassContentPresence extends StatelessWidget {
  const GlassContentPresence({
    super.key,
    required this.presence,
    required this.blur,
    required this.child,
  });

  /// 0 (absent) to 1; clamped.
  final double presence;

  /// Gaussian blur, in logical pixels, at zero presence.
  final double blur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = presence.clamp(0.0, 1.0);
    final sigma = (1 - p) * blur;
    return Opacity(
      opacity: p,
      child: ImageFiltered(
        enabled: sigma > .05,
        imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.decal,
        ),
        child: child,
      ),
    );
  }
}
