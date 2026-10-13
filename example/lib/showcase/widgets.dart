import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureState;

import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// System grouped-list colors the package palette doesn't carry.
extension ShowcaseColors on GlassColors {
  bool get _dark => brightness == Brightness.dark;
  Color get groupedBackground =>
      _dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get cell => _dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get separator =>
      _dark ? const Color(0x99545458) : const Color(0x4A3C3C43);
}

Color ink(BuildContext context) => GlassColors.of(context).label;
Color muted(BuildContext context) => GlassColors.of(context).secondaryLabel;

/// Widest readable column on iPad and the unfolded iPhone Duo.
const double readableWidth = 720;

/// A scrolling page with an iOS large title. Chrome from the enclosing
/// [LiquidPrismScaffold] floats over it; its padding keeps content clear.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.controller,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final colors = GlassColors.of(context);
    final titleStyle = CupertinoTheme.of(context)
        .textTheme
        .navLargeTitleTextStyle
        .copyWith(color: colors.label);
    final header = [
      Text(title, key: ValueKey('page-title:$title'), style: titleStyle),
      if (subtitle case final subtitle?) ...[
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: colors.secondaryLabel,
          ),
        ),
      ],
      const SizedBox(height: 20),
    ];
    // A bent iPhone Duo reports its fold as a display feature. Interactive
    // content moves off the crease: the sections reflow into two columns.
    final fold = MediaQuery.displayFeaturesOf(context)
        .where(
          (feature) =>
              feature.state == DisplayFeatureState.postureHalfOpened &&
              feature.bounds.height > feature.bounds.width,
        )
        .firstOrNull;
    ListView column(
      List<Widget> items, {
      required EdgeInsets insets,
      ScrollController? controller,
    }) => ListView(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: insets,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: readableWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
          ),
        ),
      ],
    );
    final content = switch (fold) {
      null => column(
        [...header, ...children],
        controller: controller,
        insets: EdgeInsets.fromLTRB(
          padding.left + 20,
          padding.top + 4,
          padding.right + 20,
          padding.bottom + 32,
        ),
      ),
      final fold => () {
        final split = (children.length + 1) ~/ 2;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: fold.bounds.left,
              child: column(
                [...header, ...children.take(split)],
                controller: controller,
                insets: EdgeInsets.fromLTRB(
                  padding.left + 20,
                  padding.top + 4,
                  20,
                  padding.bottom + 32,
                ),
              ),
            ),
            Positioned(
              left: fold.bounds.right,
              top: 0,
              bottom: 0,
              right: 0,
              child: column(
                children.skip(split).toList(),
                insets: EdgeInsets.fromLTRB(
                  20,
                  padding.top + 4,
                  padding.right + 20,
                  padding.bottom + 32,
                ),
              ),
            ),
          ],
        );
      }(),
    };
    // The scaffold's scroll edge effect softens content under the bar; the
    // page paints no fade of its own.
    return content;
  }
}

/// A titled inset-grouped list section.
class InsetSection extends StatelessWidget {
  const InsetSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });
  final String? header, footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header case final header?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                header,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
          GroupedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 16),
                      child: Container(height: .5, color: colors.separator),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer case final footer?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                footer,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A grouped-list cell background with continuous corners.
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: GlassColors.of(context).cell,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(26)),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// One list row: optional icon, title and subtitle, and a trailing control.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onPressed,
    this.label,
  });
  final String title;
  final String? subtitle, label;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (icon case final icon?) ...[
              SymbolTile(icon: icon, color: iconColor ?? colors.blue),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17)),
                  if (subtitle case final subtitle?) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.secondaryLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing case final trailing?) ...[
              const SizedBox(width: 12),
              trailing,
            ] else if (onPressed != null) ...[
              const SizedBox(width: 12),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 17,
                color: colors.tertiaryLabel,
              ),
            ],
          ],
        ),
      ),
    );
    if (onPressed == null) return row;
    return LiquidPrismPressable(
      label: label ?? title,
      onPressed: onPressed,
      child: row,
    );
  }
}

/// A Settings-style rounded square with a white symbol.
class SymbolTile extends StatelessWidget {
  const SymbolTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: ShapeDecoration(
      color: color,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(size * .24),
      ),
    ),
    child: Icon(icon, size: size * .6, color: const Color(0xFFFFFFFF)),
  );
}

/// A section heading above free-form content.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: .35,
          ),
        ),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(fontSize: 15, color: muted(context))),
        ],
      ],
    ),
  );
}

/// A circular glass back button, 44 pt like the native one.
/// Columns of at least [minimumWidth], filling the available width.
class FlowGrid extends StatelessWidget {
  const FlowGrid({
    super.key,
    required this.children,
    this.minimumWidth = 300,
    this.spacing = 14,
  });
  final List<Widget> children;
  final double minimumWidth, spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(
        1,
        ((constraints.maxWidth + spacing) / (minimumWidth + spacing)).floor(),
      );
      final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Original abstract artwork for glass to refract.
class Art extends StatelessWidget {
  const Art({super.key, this.variant = 0, this.child});
  final int variant;
  final Widget? child;

  static const names = ['Meadow', 'Dusk', 'Apricot'];

  /// Legible ink on each artwork.
  static const inks = [Color(0xFF233B36), Color(0xFF1F1D3D), Color(0xFF4A3029)];

  /// Each artwork's base color, for fades toward it.
  static const backgrounds = [
    Color(0xFF8EBEB5),
    Color(0xFF495D96),
    Color(0xFFB57248),
  ];

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

/// Artwork clipped to a continuous rounded rectangle.
class ArtCanvas extends StatelessWidget {
  const ArtCanvas({
    super.key,
    required this.variant,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  final int variant;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const CanvasClip(),
    child: Art(
      variant: variant,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: Art.inks[variant]),
        child: IconTheme.merge(
          data: IconThemeData(color: Art.inks[variant]),
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}

class CanvasClip extends CustomClipper<Path> {
  const CanvasClip();
  @override
  Path getClip(Size size) => const GlassShape.rect(cornerRadius: 26).path(size);
  @override
  bool shouldReclip(CanvasClip old) => false;
}
