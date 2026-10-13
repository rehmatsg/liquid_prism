import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'button.dart';
import 'material.dart';
import 'tab_bar.dart';
import 'theme.dart';
import 'haptics.dart';
import 'badge.dart';

/// Where [LiquidPrismScaffold] shows its tabs when the window has regular
/// width, such as the unfolded iPhone Duo.
enum GlassTabBarPlacement {
  /// The tab bar, as on every other window.
  automatic,

  /// A sidebar along the leading edge, as `defaultTabBarPlacement(.sidebar)`
  /// does natively. Apple suggests it for information-dense apps.
  sidebar,
}

/// Measured on the unfolded iPhone Duo (iOS 27.1); see
/// doc/native_adaptive_layout.md.
abstract final class NativeSidebar {
  static const width = 280.0;
  static const rowInset = 20.0;
  static const rowHeight = 44.0;
  static const rowGap = 9.0;
  static const labelStart = 54.0;

  /// Native icons centre 30 pt into the row.
  static const iconCentre = 30.0;
  static const toggleSize = 48.0;

  /// The shown-sidebar toggle's inset when the sidebar is hidden.
  static const toggleInset = 20.0;

  /// Both the panel's slide and the content's reflow: a critically damped
  /// spring with a .35 s response (fitted to presentation frames).
  static final spring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 350),
  );

  /// The hidden-sidebar toggle materializes from 1.2 times its size.
  static const toggleEntryScale = 1.2;

  /// The panel is a `UIGlassEffect` over full-width content. Fitted from
  /// pixels against the uncovered backdrop: a Gaussian blur, then a matrix
  /// that keeps `luma` of the luminance and `chroma` of the color around it,
  /// then adds `offset`. RMS error 2.6/255 in light, 0.9/255 in dark.
  static ui.ImageFilter material(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final sigma = dark ? 12.0 : 13.0;
    final (luma, chroma) = dark ? (.374, .558) : (.403, .911);
    final offset = dark
        ? const [25.0, 29.4, 32.5]
        : const [131.4, 136.2, 139.4];
    const weights = [.2126, .7152, .0722];
    return ui.ImageFilter.compose(
      outer: ui.ColorFilter.matrix([
        for (var row = 0; row < 3; row++) ...[
          for (var column = 0; column < 3; column++)
            (luma - chroma) * weights[column] + (row == column ? chroma : 0),
          0,
          offset[row],
        ],
        0,
        0,
        0,
        1,
        0,
      ]),
      inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
  }

  /// The selected row's capsule: light darkens what is beneath by 8.6%,
  /// dark adds 21 to each channel.
  static (Color, BlendMode) selection(Brightness brightness) =>
      brightness == Brightness.dark
      ? (const Color(0xFF151515), BlendMode.plus)
      : (const Color(0x16000000), BlendMode.srcOver);
}

/// The tabs of a [LiquidPrismTabBar] as a sidebar list. The parent's
/// selection stays authoritative, as with the tab bar.
class GlassSidebar extends StatelessWidget {
  const GlassSidebar({
    super.key,
    required this.tabBar,
    required this.top,
    required this.onHide,
  });

  final LiquidPrismTabBar tabBar;

  /// The top of the window's content area: rows start below the toggle.
  final double top;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidPrismTheme.colorsOf(context);
    final accent = LiquidPrismTheme.tintOf(context);
    return ClipRect(
      child: BackdropFilter(
        filter: NativeSidebar.material(colors.brightness),
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: NativeSidebar.rowInset,
                  ),
                  child: SidebarToggle(
                    label: 'Hide sidebar',
                    onPressed: onHide,
                  ),
                ),
              ),
              const SizedBox(height: NativeSidebar.rowGap),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NativeSidebar.rowInset,
                  ),
                  children: [
                    for (var i = 0; i < tabBar.tabs.length; i++)
                      _row(context, i, colors, accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    int index,
    GlassColors colors,
    Color accent,
  ) {
    final tab = tabBar.tabs[index];
    final selected = index == tabBar.selectedIndex;
    final onSelected = tabBar.onSelected;
    void select() {
      if (onSelected == null) return;
      if (!selected &&
          ((LiquidPrismTheme.of(context).tabBar?.merge(tabBar.style) ??
                      tabBar.style)
                  ?.haptics ??
              true)) {
        dispatchGlassHaptic(
          context,
          const GlassHapticEvent(
            GlassHapticComponent.tabBar,
            GlassHapticKind.selectionChange,
          ),
        );
      }
      onSelected(index);
    }

    void longPress() {
      if (onSelected == null || tabBar.onLongPressed == null) return;
      final style =
          LiquidPrismTheme.of(context).tabBar?.merge(tabBar.style) ??
          tabBar.style;
      if (style?.haptics ?? true) {
        dispatchGlassHaptic(
          context,
          const GlassHapticEvent(
            GlassHapticComponent.tabBar,
            GlassHapticKind.longPress,
          ),
        );
      }
      tabBar.onLongPressed!(index);
    }

    final hold = onSelected != null && tabBar.onLongPressed != null
        ? longPress
        : null;
    return Semantics(
      onLongPress: hold,
      container: true,
      button: true,
      selected: selected,
      enabled: onSelected != null,
      label: tab.label,
      value: tab.badge?.semanticLabel,
      excludeSemantics: true,
      onTap: onSelected == null ? null : select,
      child: FocusableActionDetector(
        enabled: onSelected != null,
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              select();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSelected == null ? null : select,
          onLongPress: hold,
          child: CustomPaint(
            painter: selected
                ? _SelectionPainter(NativeSidebar.selection(colors.brightness))
                : null,
            child: SizedBox(
              height: NativeSidebar.rowHeight,
              child: Stack(
                children: [
                  PositionedDirectional(
                    start:
                        NativeSidebar.iconCentre - NativeSidebar.rowHeight / 2,
                    width: NativeSidebar.rowHeight,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconTheme.merge(
                        data: IconThemeData(
                          size: 22,
                          color: onSelected == null
                              ? colors.disabledLabel
                              : accent,
                        ),
                        child: GlassBadgedIcon(
                          badge: tab.badge,
                          color:
                              (LiquidPrismTheme.of(context).tabBar
                                          ?.merge(tabBar.style) ??
                                      tabBar.style)
                                  ?.badgeColor,
                          textStyle:
                              (LiquidPrismTheme.of(context).tabBar
                                          ?.merge(tabBar.style) ??
                                      tabBar.style)
                                  ?.badgeTextStyle,
                          child: selected
                              ? tab.selectedIcon ?? tab.icon
                              : tab.icon,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: NativeSidebar.labelStart,
                    end: 12,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          // Native: medium when selected, regular otherwise.
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: onSelected == null
                              ? colors.disabledLabel
                              : colors.label,
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
    );
  }
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter(this.fill);
  final (Color, BlendMode) fill;

  @override
  void paint(Canvas canvas, Size size) {
    final (color, mode) = fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.height / 2),
      ),
      Paint()
        ..color = color
        ..blendMode = mode,
    );
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) => fill != oldDelegate.fill;
}

/// The 48 pt glass circle that hides or shows the sidebar.
class SidebarToggle extends StatelessWidget {
  const SidebarToggle({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: NativeSidebar.toggleSize,
    child: LiquidPrismButton(
      label: label,
      shape: GlassShape.circle,
      padding: EdgeInsets.zero,
      foregroundColor: LiquidPrismTheme.colorsOf(context).label,
      onPressed: onPressed,
      child: Center(
        child: Builder(
          builder: (context) => CustomPaint(
            size: const Size(22, 18),
            painter: _SidebarGlyph(
              IconTheme.of(context).color ??
                  LiquidPrismTheme.colorsOf(context).label,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The sidebar symbol: a rounded window with a narrow leading column.
class _SidebarGlyph extends CustomPainter {
  const _SidebarGlyph(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color;
    final frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(.8),
      const Radius.circular(4),
    );
    canvas.drawRRect(frame, paint);
    final column = size.width * .36;
    canvas.drawLine(Offset(column, 1), Offset(column, size.height - 1), paint);
    for (final y in [.32, .5]) {
      canvas.drawLine(
        Offset(size.width * .14, size.height * y),
        Offset(column - size.width * .1, size.height * y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SidebarGlyph oldDelegate) => color != oldDelegate.color;
}
