import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// The scroll edge's blur fill, switched on and off over content that shows
/// it: dense text on the page, 2-point stripes like the native probe's, text
/// on the opposite tone, and fine strokes over color. The page opens scrolled
/// so content already sits under the bar, and both bars carry the effect.
class BlurFillPage extends StatefulWidget {
  const BlurFillPage({super.key});

  @override
  State<BlurFillPage> createState() => _BlurFillPageState();
}

class _BlurFillPageState extends State<BlurFillPage> {
  var _fill = true;
  var _fade = true;
  final _scroll = ScrollController(initialScrollOffset: 72);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return PrimaryScrollController(
      controller: _scroll,
      child: LiquidPrismScaffold(
        backgroundColor: _page(colors),
        title: const Text('Blur Fill'),
        scrollEdgeStyle: GlassScrollEdgeStyle(
          fill: _fill ? null : 0,
          fadeOpacity: _fade ? null : 0,
        ),
        toolbar: [
          GlassToolbarGroup(
            placement: GlassToolbarPlacement.bottom,
            items: [
              GlassToolbarItem(
                key: const ValueKey('blur-fill-toggle'),
                label: _fill ? 'Blur Fill On' : 'Blur Fill Off',
                onPressed: () => setState(() => _fill = !_fill),
              ),
            ],
          ),
          GlassToolbarGroup(
            placement: GlassToolbarPlacement.bottom,
            items: [
              GlassToolbarItem(
                key: const ValueKey('blur-fill-fade-toggle'),
                label: _fade ? 'Fade On' : 'Fade Off',
                onPressed: () => setState(() => _fade = !_fade),
              ),
            ],
          ),
        ],
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Leave content under a bar and switch the blur fill. With it '
                'on, detail darker than its surroundings lifts toward them '
                '(in dark appearance, brighter detail dims), so text under the '
                'bar loses contrast instead of only softening. The fade toward '
                'the page stood in for this blend, so also try the fill with '
                'the fade off. Dark appearance is in Studio.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: 24,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: switch (i % 4) {
                  0 => const _Prose(),
                  1 => const _Stripes(),
                  2 => const _Prose(inverted: true),
                  _ => const _Swatches(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plain page: white in light appearance, black in dark.
Color _page(GlassColors colors) => colors.brightness == Brightness.dark
    ? const Color(0xFF000000)
    : const Color(0xFFFFFFFF);

const _prose =
    'The quick brown fox jumps over the lazy dog. Pack my box with five dozen '
    'liquor jugs. How vexingly quick daft zebras jump! Sphinx of black '
    'quartz, judge my vow. 0123456789. Small type, thin strokes and fine '
    'rules show how much contrast survives under the bar.';

/// A paragraph on the page, or on a card of the opposite tone.
class _Prose extends StatelessWidget {
  const _Prose({this.inverted = false});
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final text = Text(
      _prose,
      style: TextStyle(
        fontSize: 15,
        height: 1.3,
        color: inverted ? _page(colors) : colors.label,
      ),
    );
    if (!inverted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: text,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.label,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: text),
    );
  }
}

/// 2-point black and white stripes, across on the left and down on the
/// right, the pattern the native scroll edge was measured over.
class _Stripes extends StatelessWidget {
  const _Stripes();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: const SizedBox(
      height: 96,
      width: double.infinity,
      child: CustomPaint(painter: _StripePainter()),
    ),
  );
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final black = Paint()..color = const Color(0xFF000000);
    final half = size.width / 2;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, half, 2), black);
    }
    for (var x = half; x < size.width; x += 4) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), black);
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => false;
}

/// Saturated tiles with white type and hairline borders.
class _Swatches extends StatelessWidget {
  const _Swatches();

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return Row(
      children: [
        for (final color in [
          colors.red,
          colors.orange,
          colors.yellow,
          colors.green,
          colors.blue,
          colors.purple,
        ])
          Expanded(
            child: Container(
              height: 72,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFFFFF)),
              ),
              child: const Text(
                'Aa',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
