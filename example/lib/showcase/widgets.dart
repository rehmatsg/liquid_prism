import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureState;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';

/// Additional semantic colors used by the showcase.
extension ShowcaseColors on PrismColors {
  bool get _dark => brightness == Brightness.dark;

  /// The background color behind grouped sections.
  Color get groupedBackground =>
      _dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  /// The background color of a grouped cell.
  Color get cell => _dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);

  /// The divider color between grouped rows.
  Color get separator => _dark
      ? const Color.from(
          alpha: .5,
          red: 84 / 255,
          green: 84 / 255,
          blue: 88 / 255,
        )
      : const Color.from(
          alpha: .12,
          red: 60 / 255,
          green: 60 / 255,
          blue: 67 / 255,
        );
}

/// Returns the primary label color for the current appearance.
Color ink(BuildContext context) => PrismColors.of(context).label;

/// Returns the secondary label color for the current appearance.
Color muted(BuildContext context) => PrismColors.of(context).secondaryLabel;

/// The maximum content width used by showcase pages.
const double readableWidth = 720;

/// A scrollable page with a large title and fold-aware layout.
class LargeTitlePage extends StatelessWidget {
  /// Creates a [LargeTitlePage].
  const new({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.controller,
  });

  /// The primary text displayed by this widget.
  final String title;

  /// Supporting text displayed below the title.
  final String? subtitle;

  /// The widgets displayed in this container.
  final List<Widget> children;

  /// The optional controller for the page scroll view.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final colors = PrismColors.of(context);
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

    return content;
  }
}

/// A grouped section with optional header and footer text.
class InsetSection extends StatelessWidget {
  /// Creates an [InsetSection].
  const new({super.key, required this.children, this.header, this.footer});

  /// The optional heading above the grouped rows.
  final String? header;

  /// The optional explanatory text below the grouped rows.
  final String? footer;

  /// The widgets displayed in this container.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = PrismColors.of(context);
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

/// A rounded card using the current grouped-cell background.
class GroupedCard extends StatelessWidget {
  /// Creates a [GroupedCard].
  const new({super.key, required this.child, this.padding = EdgeInsets.zero});

  /// The content displayed inside this widget.
  final Widget child;

  /// The space between the container edge and its content.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: PrismColors.of(context).cell,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(26)),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// A settings row with optional icon, subtitle, and action.
class ListRow extends StatelessWidget {
  /// Creates a [ListRow].
  const new({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onPressed,
    this.label,
  });

  /// The primary text displayed by this widget.
  final String title;

  /// Supporting text displayed below the title.
  final String? subtitle;

  /// The optional accessibility label for the row action.
  final String? label;

  /// The icon displayed by this widget.
  final IconData? icon;

  /// The optional background color of the row icon tile.
  final Color? iconColor;

  /// The optional widget displayed at the end of the row.
  final Widget? trailing;

  /// Called when the user activates this widget.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PrismColors.of(context);
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
    return PrismPressable(
      label: label ?? title,
      onPressed: onPressed,
      child: row,
    );
  }
}

/// A colored tile containing a contrasting icon.
class SymbolTile extends StatelessWidget {
  /// Creates a [SymbolTile].
  const new({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
  });

  /// The icon displayed by this widget.
  final IconData icon;

  /// The background color of the icon tile.
  final Color color;

  /// The width and height of the icon tile.
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

/// A section heading with an optional subtitle.
class SectionTitle extends StatelessWidget {
  /// Creates a [SectionTitle].
  const new(this.title, {super.key, this.subtitle});

  /// The primary text displayed by this widget.
  final String title;

  /// Supporting text displayed below the title.
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

/// A responsive grid that wraps children into equally sized columns.
class FlowGrid extends StatelessWidget {
  /// Creates a [FlowGrid].
  const new({
    super.key,
    required this.children,
    this.minimumWidth = 300,
    this.spacing = 14,
  });

  /// The widgets displayed in this container.
  final List<Widget> children;

  /// The target minimum width of each grid column.
  final double minimumWidth;

  /// The horizontal and vertical space between grid items.
  final double spacing;

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

/// Procedural background artwork in one of the showcase palettes.
class Art extends StatelessWidget {
  /// Creates an [Art].
  const new({super.key, this.variant = 0, this.child});

  /// The index of the artwork palette to display.
  final int variant;

  /// The content displayed inside this widget.
  final Widget? child;

  /// The display names of the available artwork palettes.
  static const names = ['Meadow', 'Dusk', 'Apricot'];

  /// Foreground colors matched to each artwork palette.
  static const inks = [Color(0xFF233B36), Color(0xFF1F1D3D), Color(0xFF4A3029)];

  /// Base background colors for each artwork palette.
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
  new(this.variant);
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
    c
      ..drawRect(
        Offset.zero & s,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.take(2).toList(),
          ).createShader(Offset.zero & s),
      )
      ..save()
      ..translate(s.width * .5, s.height * .48)
      ..rotate(-.48);
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
    c
      ..drawOval(
        ring,
        Paint()
          ..color = colors[3].withValues(alpha: .2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * .18,
      )
      ..restore();
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

/// A clipped artwork panel with matching foreground colors.
class ArtCanvas extends StatelessWidget {
  /// Creates an [ArtCanvas].
  const new({
    super.key,
    required this.variant,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  /// The index of the artwork palette to display.
  final int variant;

  /// The content displayed inside this widget.
  final Widget child;

  /// The space between the container edge and its content.
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

/// The rounded clipping path used by artwork panels.
class CanvasClip extends CustomClipper<Path> {
  /// Creates a [CanvasClip].
  const new();
  @override
  Path getClip(Size size) => const PrismShape.rect(cornerRadius: 26).path(size);
  @override
  bool shouldReclip(CanvasClip old) => false;
}
