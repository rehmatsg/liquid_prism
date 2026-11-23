import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Enter and exit animation mode for [PrismVisibility].
enum PrismTransition {
  /// Shows or hides content immediately.
  identity,

  /// Animates glass presence and lens geometry.
  materialize,
}

/// Timing and content blur overrides for [PrismVisibility].
@immutable
class PrismTransitionStyle {
  /// Creates a partial transition style override.
  const new({this.enterSpring, this.exitSpring, this.contentBlur})
    : assert(
        contentBlur == null || contentBlur >= 0,
        'contentBlur must be null or nonnegative',
      );

  /// Spring animating material entry.
  final PrismSpring? enterSpring;

  /// Spring animating material exit.
  final PrismSpring? exitSpring;

  /// Foreground content blur sigma when presence is zero.
  final double? contentBlur;

  /// Returns a copy with specified fields replaced.
  PrismTransitionStyle copyWith({
    PrismSpring? enterSpring,
    PrismSpring? exitSpring,
    double? contentBlur,
  }) => PrismTransitionStyle(
    enterSpring: enterSpring ?? this.enterSpring,
    exitSpring: exitSpring ?? this.exitSpring,
    contentBlur: contentBlur ?? this.contentBlur,
  );

  /// Merges non-null fields from [other] over this style.
  PrismTransitionStyle merge(PrismTransitionStyle? other) => other == null
      ? this
      : PrismTransitionStyle(
          enterSpring: other.enterSpring ?? enterSpring,
          exitSpring: other.exitSpring ?? exitSpring,
          contentBlur: other.contentBlur ?? contentBlur,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismTransitionStyle &&
          other.enterSpring == enterSpring &&
          other.exitSpring == exitSpring &&
          other.contentBlur == contentBlur;

  @override
  int get hashCode => Object.hash(enterSpring, exitSpring, contentBlur);
}

/// Drives glass surface presence from an external [Animation].
class PrismPresence extends StatefulWidget {
  /// Creates a presence scope driven by [progress] in `[0, 1]`.
  const new({
    super.key,
    required this.progress,
    required this.child,
    this.contentBlur = 4,
    this.materialize = true,
  }) : assert(contentBlur >= 0, 'contentBlur must be nonnegative');

  /// Presence progress animation clamped to `[0, 1]`.
  final Animation<double> progress;

  /// Foreground content blur sigma at zero presence.
  final double contentBlur;

  /// Whether lens geometry grows with presence in addition to fading.
  final bool materialize;

  /// Subtree whose glass surfaces observe this presence.
  final Widget child;

  /// Combined presence value for [context], or `1` outside any scope.
  static double of(BuildContext context) =>
      maybeData(context)?.progress.value.clamp(0.0, 1.0) ?? 1;

  /// Returns the nearest inherited presence scope, if any.
  @internal
  static PrismPresenceScope? maybeData(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrismPresenceScope>();

  @override
  State<PrismPresence> createState() => _PrismPresenceState();
}

class _PrismPresenceState extends State<PrismPresence> {
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
    final parent = PrismPresence.maybeData(context);
    return PrismPresenceScope(
      progress: _resolve(parent?.progress),
      contentBlur: widget.contentBlur,
      materialize: widget.materialize && (parent?.materialize ?? true),
      child: widget.child,
    );
  }
}

class _PresenceProduct extends CompoundAnimation<double> {
  new(Animation<double> first, Animation<double> next)
    : super(first: first, next: next);

  @override
  double get value => first.value.clamp(0.0, 1.0) * next.value.clamp(0.0, 1.0);
}

@internal
class PrismPresenceScope extends InheritedNotifier<Animation<double>> {
  const new({
    required Animation<double> progress,
    required this.contentBlur,
    required this.materialize,
    required super.child,
    super.key,
  }) : super(notifier: progress);

  Animation<double> get progress => notifier!;
  final double contentBlur;
  final bool materialize;

  @override
  bool updateShouldNotify(PrismPresenceScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      contentBlur != oldWidget.contentBlur ||
      materialize != oldWidget.materialize;
}

/// Shows or hides glass content using a live materialize transition.
class PrismVisibility extends StatefulWidget {
  /// Creates a visibility transition driven by [visible].
  const new({
    super.key,
    required this.visible,
    required this.child,
    this.transition = PrismTransition.materialize,
    this.style,
    this.onEnd,
  }) : progress = null,
       contentBlur = 4,
       materialize = true;

  /// Creates a visibility transition driven directly by [progress] in `[0, 1]`.
  const new driven({
    super.key,
    required Animation<double> this.progress,
    required this.child,
    this.contentBlur = 4,
    this.materialize = true,
  }) : assert(contentBlur >= 0, 'contentBlur must be nonnegative'),
       visible = true,
       transition = PrismTransition.materialize,
       style = null,
       onEnd = null;

  /// Whether [child] is shown.
  final bool visible;

  /// Subtree to materialize in and out.
  final Widget child;

  /// Transition mode for visibility changes.
  final PrismTransition transition;

  /// Optional timing and content blur overrides.
  final PrismTransitionStyle? style;

  /// Called when an enter or exit transition settles.
  final VoidCallback? onEnd;

  /// External presence animation for the driven constructor.
  final Animation<double>? progress;

  /// Foreground content blur sigma for the driven constructor.
  final double contentBlur;

  /// Whether lens geometry grows for the driven constructor.
  final bool materialize;

  @override
  State<PrismVisibility> createState() => _PrismVisibilityState();
}

class _PrismVisibilityState extends State<PrismVisibility>
    with SingleTickerProviderStateMixin {
  RetargetablePrismSpring? _presence;

  RetargetablePrismSpring _ensurePresence() =>
      _presence ??= RetargetablePrismSpring(vsync: this)
        ..value = widget.visible ? 1 : 0
        ..addStatusListener(_status);

  PrismTransitionStyle get _style =>
      (PrismTheme.of(context).transition ?? const PrismTransitionStyle()).merge(
        widget.style,
      );

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      if (mounted) setState(() {});
      widget.onEnd?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) {
      _ensurePresence();
    }
  }

  @override
  void didUpdateWidget(PrismVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != null) return;
    final presence = _ensurePresence();
    if (oldWidget.visible == widget.visible && oldWidget.progress == null) {
      return;
    }
    final target = widget.visible ? 1.0 : 0.0;
    if (widget.transition == PrismTransition.identity) {
      presence.value = target;
      widget.onEnd?.call();
      return;
    }
    final style = _style;
    springPrism(
      presence,
      target,
      _reduceMotion
          ? SpringDescription.withDurationAndBounce(
              duration: const Duration(milliseconds: 200),
            )
          : widget.visible
          ? style.enterSpring?.description ??
                SpringDescription.withDurationAndBounce(
                  duration: const Duration(milliseconds: 280),
                )
          : style.exitSpring?.description ??
                SpringDescription.withDurationAndBounce(
                  duration: const Duration(milliseconds: 280),
                ),
      precision: _precision(style),
    );
  }

  double? _precision(PrismTransitionStyle style) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
    final reach = math.max(style.contentBlur ?? 4, box.size.shortestSide * .55);
    return PrismSettle.precision(
      alphaPerUnit: 1,
      pixelsPerUnit: reach * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1),
    );
  }

  @override
  void dispose() {
    _presence?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.progress case final progress?) {
      return PrismPresence(
        progress: progress,
        contentBlur: widget.contentBlur,
        materialize: widget.materialize,
        child: widget.child,
      );
    }
    final presence = _ensurePresence();
    if (!widget.visible && !presence.isAnimating && presence.value <= 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      ignoring: !widget.visible,
      child: ExcludeSemantics(
        excluding: !widget.visible,
        child: PrismPresence(
          progress: presence,
          contentBlur: _style.contentBlur ?? 4,
          materialize: !_reduceMotion,
          child: widget.child,
        ),
      ),
    );
  }
}

@internal
class PrismContentPresence extends StatelessWidget {
  const new({
    super.key,
    required this.presence,
    required this.blur,
    required this.child,
  });

  final double presence;
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
