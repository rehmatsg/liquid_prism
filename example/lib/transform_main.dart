import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// Glass under an animated ancestor translate + scale, as an app's covered
/// page sits beneath a modal sheet. The red outlines are ordinary content
/// drawn at each surface's bounds; the glass rim must coincide with them.
///
/// Run with `--dart-define=PRISM_TRANSFORM_MODE=filter|transform|none` and
/// `--dart-define=PRISM_TRANSFORM_T=0.0..1.0`, or `PRISM_TRANSFORM_T=-1` to
/// animate continuously. `PRISM_TRANSFORM_HOLD=true` holds the first tab
/// down, lifting its pill so the tab foreground lens runs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(const TransformFixtureApp());
}

/// How the covered page applies its scale.
enum TransformFixtureMode {
  /// No ancestor scale: the reference geometry.
  none,

  /// `Transform.scale` without a filter quality: a [TransformLayer].
  transform,

  /// `Transform.scale` with a filter quality: an `ImageFilter.matrix` layer.
  filter,
}

class TransformFixtureApp extends StatelessWidget {
  const TransformFixtureApp({super.key, this.mode, this.t});

  final TransformFixtureMode? mode;
  final double? t;

  static TransformFixtureMode get _defaultMode =>
      TransformFixtureMode.values.byName(
        const String.fromEnvironment(
          'PRISM_TRANSFORM_MODE',
          defaultValue: 'filter',
        ),
      );

  static double get _defaultT => double.parse(
    const String.fromEnvironment('PRISM_TRANSFORM_T', defaultValue: '1'),
  );

  @override
  Widget build(BuildContext context) => CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: TransformFixture(mode: mode ?? _defaultMode, t: t ?? _defaultT),
  );
}

class TransformFixture extends StatefulWidget {
  const TransformFixture({super.key, required this.mode, required this.t});

  final TransformFixtureMode mode;

  /// Sheet progress; negative animates between 0 and 1.
  final double t;

  @override
  State<TransformFixture> createState() => _TransformFixtureState();
}

class _TransformFixtureState extends State<TransformFixture>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  final _tabBar = GlobalKey();
  int _tab = 0;

  static const _hold = bool.fromEnvironment('PRISM_TRANSFORM_HOLD');

  @override
  void initState() {
    super.initState();
    _sync();
    if (_hold) {
      Future<void>.delayed(const Duration(seconds: 1), _holdFirstTab);
    }
  }

  /// A pointer that never lifts keeps the first tab's pill raised.
  void _holdFirstTab() {
    final box = _tabBar.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final point = box.localToGlobal(
      Offset(box.size.width / 6, box.size.height / 2),
    );
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: 9999, position: point),
    );
  }

  @override
  void didUpdateWidget(TransformFixture oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.t < 0) {
      if (!_progress.isAnimating) _progress.repeat(reverse: true);
    } else {
      _progress
        ..stop()
        ..value = widget.t;
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = RepaintBoundary(child: _page());
    return ColoredBox(
      color: const Color(0xFF000000),
      child: AnimatedBuilder(
        animation: _progress,
        child: page,
        builder: (context, child) {
          final t = _progress.value;
          final topFraction =
              (MediaQuery.paddingOf(context).top + 10) /
              MediaQuery.sizeOf(context).height;
          final clipped = ClipRSuperellipse(
            borderRadius: BorderRadius.circular(38 * t),
            child: child,
          );
          return switch (widget.mode) {
            TransformFixtureMode.none => child!,
            TransformFixtureMode.transform => FractionalTranslation(
              translation: Offset(0, topFraction * t),
              child: Transform.scale(
                scale: 1 - 0.0835 * t,
                alignment: Alignment.topCenter,
                child: clipped,
              ),
            ),
            TransformFixtureMode.filter => FractionalTranslation(
              translation: Offset(0, topFraction * t),
              child: Transform.scale(
                scale: 1 - 0.0835 * t,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                child: clipped,
              ),
            ),
          };
        },
      ),
    );
  }

  Widget _page() => Stack(
    fit: StackFit.expand,
    children: [
      const _Stripes(),
      SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Covered',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const Spacer(),
                  _Outlined(
                    child: LiquidPrismToolbarGroup(
                      size: GlassToolbarSize.navigation,
                      items: [
                        GlassToolbarItem(
                          label: 'Favorite',
                          icon: const Icon(CupertinoIcons.star),
                          onPressed: () {},
                        ),
                        GlassToolbarItem(
                          label: 'More',
                          icon: const Icon(CupertinoIcons.ellipsis),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const _Outlined(
              child: LiquidPrism(
                shape: GlassShape.capsule,
                child: SizedBox(
                  width: 220,
                  height: 64,
                  child: Center(child: Text('Surface')),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _Outlined(
              child: LiquidPrism(
                shape: GlassShape.rect(cornerRadius: 24),
                child: SizedBox(
                  width: 260,
                  height: 90,
                  child: Center(child: Text('Smooth rect')),
                ),
              ),
            ),
            const Spacer(),
            _Outlined(
              child: LiquidPrismTabBar(
                key: _tabBar,
                selectedIndex: _tab,
                onSelected: (index) => setState(() => _tab = index),
                tabs: const [
                  LiquidPrismTab(
                    label: 'Explore',
                    icon: Icon(CupertinoIcons.sparkles),
                  ),
                  LiquidPrismTab(
                    label: 'Studio',
                    icon: Icon(CupertinoIcons.slider_horizontal_3),
                  ),
                  LiquidPrismTab(
                    label: 'Library',
                    icon: Icon(CupertinoIcons.square_grid_2x2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ],
  );
}

/// Draws a hairline at the child's layout bounds, above its glass.
class _Outlined extends StatelessWidget {
  const _Outlined({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: const _OutlinePainter(), child: child);
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      (Offset.zero & size).deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFF0000),
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) => false;
}

/// High-contrast background so refraction and rim placement are visible.
class _Stripes extends StatelessWidget {
  const _Stripes();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _StripePainter());
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    const colors = [Color(0xFF2F6BFF), Color(0xFFFFB020), Color(0xFF16A34A)];
    var i = 0;
    for (var y = 0.0; y < size.height; y += 24, i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 8),
        Paint()..color = colors[i % colors.length],
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => false;
}
