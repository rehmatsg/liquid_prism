import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'material.dart';
import 'motion.dart';
import 'theme.dart';
import 'style.dart';
import 'recipe.dart';

/// Native phone sheet resting positions.
enum GlassSheetDetent { medium, large }

/// The body must attach this controller to its primary ListView/ScrollView,
/// including for short content, to coordinate scrolling and sheet resizing.
typedef LiquidPrismSheetBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
);

/// Present a modal sheet. Dismiss with Navigator.pop(context, result).
///
/// Themes are captured from the caller, including across a root Navigator.
/// The builder's scroll controller coordinates scroll/resize gestures. The sheet
/// accounts for safe areas and keyboards and uses continuous corners throughout.
/// By default the glass background becomes opaque at the large detent. An
/// explicit [backgroundColor] overrides that fill at every detent.
Future<T?> showLiquidPrismSheet<T>({
  required BuildContext context,
  required LiquidPrismSheetBuilder builder,
  List<GlassSheetDetent> detents = const [
    GlassSheetDetent.medium,
    GlassSheetDetent.large,
  ],
  GlassSheetDetent? initialDetent,
  ValueChanged<GlassSheetDetent>? onDetentChanged,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragIndicator = true,
  bool useRootNavigator = true,
  String semanticLabel = 'Sheet',
  String barrierLabel = 'Dismiss sheet',
  Glass? glass,
  Color? backgroundColor,
  RouteSettings? routeSettings,
}) {
  assert(detents.isNotEmpty && detents.toSet().length == detents.length);
  assert(initialDetent == null || detents.contains(initialDetent));
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final theme = LiquidPrismTheme.of(context).merge(
    LiquidPrismThemeData(brightness: LiquidPrismTheme.brightnessOf(context)),
  );
  return navigator.push<T>(
    _LiquidPrismSheetRoute<T>(
      builder: builder,
      detents: List.unmodifiable(detents),
      initialDetent: initialDetent ?? detents.first,
      onDetentChanged: onDetentChanged,
      dismissible: isDismissible,
      enableDrag: enableDrag,
      showDragIndicator: showDragIndicator,
      semanticLabel: semanticLabel,
      dismissLabel: barrierLabel,
      glass: glass,
      backgroundColor: backgroundColor,
      theme: theme,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      settings: routeSettings,
    ),
  );
}

class _LiquidPrismSheetRoute<T> extends PopupRoute<T> {
  _LiquidPrismSheetRoute({
    required this.builder,
    required this.detents,
    required this.initialDetent,
    required this.onDetentChanged,
    required this.dismissible,
    required this.enableDrag,
    required this.showDragIndicator,
    required this.semanticLabel,
    required this.dismissLabel,
    required this.glass,
    required this.backgroundColor,
    required this.theme,
    required this.capturedThemes,
    super.settings,
  });
  final LiquidPrismSheetBuilder builder;
  final List<GlassSheetDetent> detents;
  final GlassSheetDetent initialDetent;
  final ValueChanged<GlassSheetDetent>? onDetentChanged;
  final bool dismissible, enableDrag, showDragIndicator;
  final String semanticLabel, dismissLabel;
  final Glass? glass;
  final Color? backgroundColor;
  final LiquidPrismThemeData theme;
  final CapturedThemes capturedThemes;
  @override
  bool get barrierDismissible => dismissible;
  @override
  Color get barrierColor =>
      GlassColors(theme.brightness ?? Brightness.light).sheetBarrier;
  @override
  String get barrierLabel => dismissLabel;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => capturedThemes.wrap(
    LiquidPrismTheme(
      data: theme,
      inherit: false,
      child: _SheetBody<T>(route: this),
    ),
  );
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .chain(
            CurveTween(
              curve: animation.status == AnimationStatus.reverse
                  ? Curves.easeInCubic
                  : Curves.easeOutCubic,
            ),
          )
          .animate(animation),
      child: child,
    );
  }
}

class _SheetBody<T> extends StatefulWidget {
  const _SheetBody({required this.route});
  final _LiquidPrismSheetRoute<T> route;
  @override
  State<_SheetBody<T>> createState() => _SheetBodyState<T>();
}

class _SheetBodyState<T> extends State<_SheetBody<T>>
    with SingleTickerProviderStateMixin {
  final _controller = DraggableScrollableController();
  final _staticScroll = ScrollController();
  late final _spring = RetargetableGlassSpring(vsync: this);
  double _availableHeight = 1, _medium = .5, _large = .9, _extent = .5;
  bool _dismissScheduled = false, _keyboardVisible = false;
  GlassSheetDetent? _lastDetent;
  _LiquidPrismSheetRoute<T> get route => widget.route;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  List<double> get _targets => [
    for (final detent in route.detents)
      detent == GlassSheetDetent.medium ? _medium : _large,
  ]..sort();
  @override
  void initState() {
    super.initState();
    _spring.addListener(() {
      if (_controller.isAttached) {
        _controller.jumpTo(_spring.value.clamp(0.0, _targets.last));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (visible &&
        !_keyboardVisible &&
        route.enableDrag &&
        route.detents.contains(GlassSheetDetent.large)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _settle(_large);
      });
    }
    _keyboardVisible = visible;
  }

  void _settle(double target) {
    if (!_controller.isAttached) return;
    _spring.value = _controller.size;
    springGlass(_spring, target, NativeSheetMotion.snap, immediate: _reduced);
  }

  void _dismiss() {
    if (_dismissScheduled || !route.dismissible || !route.isCurrent) return;
    _dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route.isCurrent) Navigator.of(context).pop();
    });
  }

  bool _notification(DraggableScrollableNotification notification) {
    if (_extent != notification.extent) {
      setState(() => _extent = notification.extent);
    }
    if (_extent < _targets.first * .35) _dismiss();
    for (final detent in route.detents) {
      final target = detent == GlassSheetDetent.medium ? _medium : _large;
      if ((_extent - target).abs() < .001 && _lastDetent != detent) {
        _lastDetent = detent;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_dismissScheduled) {
            route.onDetentChanged?.call(detent);
          }
        });
      }
    }
    return false;
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_controller.isAttached) return;
    _spring.stop();
    _controller.jumpTo(
      (_controller.size - details.delta.dy / _availableHeight).clamp(
        route.dismissible ? 0.0 : _targets.first,
        _targets.last,
      ),
    );
  }

  void _dragEnd(DragEndDetails details) {
    if (!_controller.isAttached) return;
    final velocity = details.primaryVelocity ?? 0;
    final size = _controller.size;
    if (route.dismissible &&
        (size < _targets.first * .75 ||
            (size <= _targets.first + .02 && velocity > 700))) {
      _dismiss();
      return;
    }
    final projected = size - velocity * .12 / _availableHeight;
    final target = _targets.reduce(
      (a, b) => (a - projected).abs() < (b - projected).abs() ? a : b,
    );
    _settle(target);
  }

  @override
  void dispose() {
    _spring.dispose();
    _controller.dispose();
    _staticScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context), colors = GlassColors.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (route.dismissible) Navigator.of(context).maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: route.dismissible,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: route.semanticLabel,
            explicitChildNodes: true,
            onDismiss: route.dismissible ? _dismiss : null,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _availableHeight = math.max(1, constraints.maxHeight);
                _large =
                    ((_availableHeight - media.padding.top) / _availableHeight)
                        .clamp(.1, 1);
                _medium = math.min(
                  .5 +
                      (math.max(
                                media.padding.bottom,
                                media.viewPadding.bottom,
                              ) -
                              4 / media.devicePixelRatio) /
                          _availableHeight,
                  _large,
                );
                final initial = route.initialDetent == GlassSheetDetent.medium
                    ? _medium
                    : _large;
                Widget surface(
                  BuildContext context,
                  ScrollController scroll,
                  double extent,
                ) {
                  final expansion =
                      (_large <= _medium
                              ? 1.0
                              : (extent - _medium) / (_large - _medium))
                          .clamp(0.0, 1.0);
                  final inset = NativeSheetMotion.sideInset * (1 - expansion);
                  final corners = BorderRadius.vertical(
                    top: const Radius.circular(38),
                    bottom: Radius.circular(54 + 8 * expansion),
                  );
                  if (constraints.maxWidth <= 0 ||
                      extent * _availableHeight <=
                          28 +
                              math.max(
                                media.viewInsets.bottom,
                                media.padding.bottom,
                              )) {
                    return const SizedBox.shrink();
                  }
                  return Transform.translate(
                    offset: Offset(0, -inset),
                    child: Transform.scale(
                      scale: math.max(
                        .1,
                        (constraints.maxWidth - inset * 2) /
                            constraints.maxWidth,
                      ),
                      alignment: Alignment.bottomCenter,
                      child: CustomPaint(
                        painter: _SheetShadow(corners),
                        child: ClipPath(
                          clipper: _SheetClipper(corners),
                          child: LiquidPrism(
                            key: const ValueKey('liquid-prism-sheet-surface'),
                            glass: route.glass ?? Glass.regular,
                            role: GlassRole.sheet,
                            optics: const LiquidPrismStyle(
                              edgeWidth: 20,
                              refraction: 60,
                              frost: 4,
                              dispersion: 0,
                              reflection: .08,
                              light: .4,
                              brightness: 0,
                              saturation: 1,
                              tint: Color(0x00000000),
                            ),
                            blur: 4,
                            shape: const GlassShape.rect(
                              cornerRadius: NativeSheetMotion.cornerRadius,
                            ),
                            child: ColoredBox(
                              color:
                                  route.backgroundColor ??
                                  colors.sheetBackground.withValues(
                                    alpha: expansion,
                                  ),
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  fontSize: 17,
                                  color: colors.label,
                                ),
                                child: IconTheme(
                                  data: IconThemeData(color: colors.label),
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        dragStartBehavior:
                                            DragStartBehavior.down,
                                        onVerticalDragUpdate: route.enableDrag
                                            ? _dragUpdate
                                            : null,
                                        onVerticalDragEnd: route.enableDrag
                                            ? _dragEnd
                                            : null,
                                        onVerticalDragCancel: () => _settle(
                                          _targets.reduce(
                                            (a, b) =>
                                                (a - _extent).abs() <
                                                    (b - _extent).abs()
                                                ? a
                                                : b,
                                          ),
                                        ),
                                        child: Semantics(
                                          label: 'Resize sheet',
                                          increasedValue: 'Large',
                                          decreasedValue: 'Medium',
                                          value: expansion > .5
                                              ? 'Large'
                                              : 'Medium',
                                          onIncrease:
                                              route.enableDrag &&
                                                  route.detents.contains(
                                                    GlassSheetDetent.large,
                                                  )
                                              ? () => _settle(_large)
                                              : null,
                                          onDecrease:
                                              route.enableDrag &&
                                                  route.detents.contains(
                                                    GlassSheetDetent.medium,
                                                  )
                                              ? () => _settle(_medium)
                                              : null,
                                          child: SizedBox(
                                            height: 16,
                                            width: double.infinity,
                                            child: route.showDragIndicator
                                                ? Center(
                                                    child: SizedBox(
                                                      width: 60,
                                                      height: 4,
                                                      child: ClipPath(
                                                        clipper:
                                                            const GlassShapeClipper(
                                                              GlassShape
                                                                  .capsule,
                                                            ),
                                                        child: ColoredBox(
                                                          color: colors
                                                              .tertiaryLabel,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: math.max(
                                              media.viewInsets.bottom,
                                              media.padding.bottom,
                                            ),
                                          ),
                                          child: MediaQuery.removePadding(
                                            context: context,
                                            removeTop: true,
                                            removeBottom: true,
                                            child: MediaQuery.removeViewInsets(
                                              context: context,
                                              removeBottom: true,
                                              child: Builder(
                                                builder: (context) => route
                                                    .builder(context, scroll),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (!route.enableDrag) {
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: initial * _availableHeight,
                      child: surface(context, _staticScroll, initial),
                    ),
                  );
                }
                return NotificationListener<DraggableScrollableNotification>(
                  onNotification: _notification,
                  child: DraggableScrollableSheet(
                    controller: _controller,
                    initialChildSize: initial,
                    minChildSize: route.dismissible ? 0 : _targets.first,
                    maxChildSize: _targets.last,
                    expand: true,
                    snap: true,
                    snapSizes: _targets
                        .where(
                          (v) =>
                              v > (route.dismissible ? 0 : _targets.first) &&
                              v < _targets.last,
                        )
                        .toList(),
                    snapAnimationDuration: _reduced
                        ? const Duration(milliseconds: 1)
                        : const Duration(milliseconds: 500),
                    shouldCloseOnMinExtent: false,
                    builder: (context, scroll) => AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => surface(
                        context,
                        scroll,
                        _controller.isAttached ? _controller.size : initial,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetClipper extends CustomClipper<Path> {
  const _SheetClipper(this.corners);
  final BorderRadius corners;
  @override
  Path getClip(Size size) =>
      RoundedSuperellipseBorder(borderRadius: corners)
          .getOuterPath(Offset.zero & size);
  @override
  bool shouldReclip(_SheetClipper old) => old.corners != corners;
}

class _SheetShadow extends CustomPainter {
  const _SheetShadow(this.corners);
  final BorderRadius corners;
  @override
  void paint(Canvas canvas, Size size) {
    final outline = _SheetClipper(corners).getClip(size);
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(60))
        ..addPath(outline, Offset.zero),
    );
    canvas.drawPath(
      outline.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0x24000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheetShadow old) => old.corners != corners;
}

/// Calibrated phone defaults; see doc/native_sheet_spec.md for provenance.
abstract final class NativeSheetMotion {
  static const sideInset = 8.0, cornerRadius = 38.0;
  static final snap = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 500),
    bounce: 0,
  );
}
