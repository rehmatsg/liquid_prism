import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'button.dart';
import 'material.dart';
import 'tab_bar.dart';
import 'theme.dart';

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
  static const toggleSize = 48.0;
  static Color background(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF181D20)
      : const Color(0xFFEAEFF2);
  static Color selection(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF2C3134)
      : const Color(0xFFD6DBDE);
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
    return ColoredBox(
      color: NativeSidebar.background(colors.brightness),
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
                child: SidebarToggle(label: 'Hide sidebar', onPressed: onHide),
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
      if (!selected && (tabBar.style?.haptics ?? true)) {
        unawaited(HapticFeedback.selectionClick());
      }
      onSelected(index);
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: onSelected != null,
      label: tab.label,
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
          child: SizedBox(
            height: NativeSidebar.rowHeight,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: selected
                    ? NativeSidebar.selection(colors.brightness)
                    : const Color(0x00000000),
                shape: const StadiumBorder(),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: NativeSidebar.labelStart,
                    child: Center(
                      child: IconTheme.merge(
                        data: IconThemeData(
                          size: 22,
                          color: onSelected == null
                              ? colors.disabledLabel
                              : accent,
                        ),
                        child: selected
                            ? tab.selectedIcon ?? tab.icon
                            : tab.icon,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        color: onSelected == null
                            ? colors.disabledLabel
                            : colors.label,
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
