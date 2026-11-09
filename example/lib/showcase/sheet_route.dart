import 'package:flutter/cupertino.dart';

/// Cupertino's drag/scroll coordination with plain transforms over live glass.
class ShowcaseSheetRoute extends CupertinoSheetRoute<void> {
  ShowcaseSheetRoute({required super.scrollableBuilder});

  @override
  DelegatedTransitionBuilder get delegatedTransition => _coverPage;

  // Equal delegates let stacked routes own their secondary transition once.
  static Widget _coverPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => _CoveredPage(
    animation: secondaryAnimation,
    sheet: ModalRoute.of(context) is CupertinoSheetRoute,
    child: child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _CoveredPage(
    animation: secondaryAnimation,
    sheet: true,
    child: super.buildTransitions(
      context,
      animation,
      const AlwaysStoppedAnimation(0),
      child,
    ),
  );
}

class _CoveredPage extends StatefulWidget {
  const _CoveredPage({
    required this.animation,
    required this.sheet,
    required this.child,
  });

  final Animation<double> animation;
  final bool sheet;
  final Widget? child;

  @override
  State<_CoveredPage> createState() => _CoveredPageState();
}

class _CoveredPageState extends State<_CoveredPage> {
  late CurvedAnimation _curve;

  void _configure() {
    _curve = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
    );
  }

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(_CoveredPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curve.dispose();
      _configure();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.animation,
    child: widget.child,
    builder: (context, child) {
      final progress = Navigator.of(context).userGestureInProgress
          ? widget.animation.value
          : _curve.value;
      final deviceRadius = MediaQuery.viewPaddingOf(context).top * .9;
      final radius = widget.sheet
          ? const BorderRadius.vertical(top: Radius.circular(12))
          : BorderRadius.lerp(
              BorderRadius.vertical(
                top: Radius.circular(deviceRadius > 20 ? deviceRadius : 0),
              ),
              BorderRadius.circular(12),
              progress,
            )!;
      final clipRadius = progress == 0 ? BorderRadius.zero : radius;
      final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
      return FractionalTranslation(
        translation: Offset(0, (widget.sheet ? -.005 : .07) * progress),
        child: Transform.scale(
          scale: 1 - .0835 * progress,
          alignment: Alignment.topCenter,
          // Filtered transforms rasterize the backdrop before moving it.
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              if (child != null)
                ClipRSuperellipse(borderRadius: clipRadius, child: child),
              if (!widget.sheet && progress > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: RoundedSuperellipseBorder(
                          borderRadius: clipRadius,
                        ),
                        color:
                            (dark
                                    ? const Color(0xffc8c8c8)
                                    : CupertinoColors.black)
                                .withValues(alpha: .1 * progress),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
