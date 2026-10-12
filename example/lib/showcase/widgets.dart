import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'model.dart';

Color ink(BuildContext context) => GlassColors.of(context).label;
Color muted(BuildContext context) => GlassColors.of(context).secondaryLabel;

class ShowcaseBackdrop extends StatelessWidget {
  const ShowcaseBackdrop({super.key, required this.model, required this.child});
  final ShowcaseModel model;
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: model.dark ? const Color(0xFF151B20) : const Color(0xFFF5F3ED),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _Atmosphere(model.dark)),
          ),
        ),
        child,
      ],
    ),
  );
}

class _Atmosphere extends CustomPainter {
  _Atmosphere(this.dark);
  final bool dark;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..shader =
          RadialGradient(
            colors: [
              (dark ? const Color(0xFF315652) : const Color(0xFFC9DED1))
                  .withValues(alpha: .45),
              const Color(0x00000000),
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(s.width, 80), radius: s.width * .95),
          );
    c.drawRect(Offset.zero & s, p);
  }

  @override
  bool shouldRepaint(_Atmosphere old) => old.dark != dark;
}

class Art extends StatelessWidget {
  const Art({super.key, this.variant = 0, this.child});
  final int variant;
  final Widget? child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ArtPainter(variant), child: child);
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.variant);
  final int variant;
  static const palettes = [
    [
      Color(0xFF8EBEB5),
      Color(0xFFDAE5C8),
      Color(0xFFF0AF86),
      Color(0xFF476862),
    ],
    [
      Color(0xFF495D96),
      Color(0xFFB2BDD8),
      Color(0xFFEEABBB),
      Color(0xFF3E3C71),
    ],
    [
      Color(0xFFB57248),
      Color(0xFFF2CD82),
      Color(0xFFFAE5BF),
      Color(0xFF6D4E45),
    ],
  ];
  @override
  void paint(Canvas c, Size s) {
    final colors = palettes[variant];
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.take(2).toList(),
        ).createShader(Offset.zero & s),
    );
    c.save();
    c.translate(s.width * .5, s.height * .48);
    c.rotate(-.48);
    final oval = Rect.fromCenter(
      center: Offset(s.width * .06, s.height * .45),
      width: s.width * 1.45,
      height: s.height * .84,
    );
    c.drawOval(
      oval,
      Paint()
        ..shader = LinearGradient(colors: [colors[2], colors[2], colors[3]])
            .createShader(oval),
    );
    final ring = Rect.fromCenter(
      center: Offset(-s.width * .2, -s.height * .19),
      width: s.width * 1.12,
      height: s.height * .95,
    );
    c.drawOval(
      ring,
      Paint()
        ..color = colors[3].withValues(alpha: .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * .18,
    );
    c.restore();
    final glow = Rect.fromCircle(
      center: Offset(s.width * .8, s.height * .05),
      radius: s.width * .75,
    );
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        ).createShader(glow),
    );
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.variant != variant;
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: GlassColors.of(context).brightness == Brightness.dark
          ? const Color(0xFF20292C)
          : const Color(0xFFFCFBF7),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: ink(context).withValues(alpha: .055)),
      ),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 1.8,
      fontWeight: FontWeight.w700,
      color: color ?? muted(context),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -.6,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

class Note extends StatelessWidget {
  const Note(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 13, height: 1.45, color: muted(context)),
  );
}

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.text, {
    super.key,
    required this.onPressed,
    this.icon,
    this.prominent = false,
    this.label,
  });
  final String text;
  final String? label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool prominent;
  @override
  Widget build(BuildContext context) => LiquidPrismButton(
    label: label ?? text,
    buttonStyle: prominent
        ? GlassButtonStyle.glassProminent
        : GlassButtonStyle.glass,
    onPressed: onPressed,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(text, style: const TextStyle(fontSize: 14))),
        if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 16)],
      ],
    ),
  );
}

class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => LiquidPrismButton(
    label: label,
    shape: GlassShape.circle,
    padding: const EdgeInsets.all(13),
    foregroundColor: ink(context),
    onPressed: onPressed,
    child: Icon(icon, size: 19),
  );
}

class ComponentRow extends StatelessWidget {
  const ComponentRow({super.key, required this.info, required this.onPressed});
  final ComponentInfo info;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => LiquidPrismPressable(
    label: 'Explore ${info.title}',
    onPressed: onPressed,
    child: Panel(
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: info.color.withValues(alpha: .12),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Icon(info.icon, size: 23, color: info.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Note(info.subtitle),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(CupertinoIcons.arrow_up_right, size: 16, color: muted(context)),
        ],
      ),
    ),
  );
}

class FlowGrid extends StatelessWidget {
  const FlowGrid({super.key, required this.children, this.minimumWidth = 300});
  final List<Widget> children;
  final double minimumWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(
        1,
        ((constraints.maxWidth + 14) / (minimumWidth + 14)).floor(),
      );
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
