import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/prism_button.dart';
import 'package:liquid_prism/src/controls/prism_button_style.dart';
import 'package:liquid_prism/src/core/prism_badge.dart';
import 'package:liquid_prism/src/core/prism_colors.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_haptics.dart';
import 'package:liquid_prism/src/navigation/prism_tab_bar.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Preferred floating dock or sidebar placement for scaffold tabs.
enum PrismTabBarPlacement {
  /// Chooses the tab placement from context.
  automatic,

  /// Places tabs in the bottom dock.
  bottom,

  /// Places tabs at the top.
  top,

  /// Places tabs along the leading edge.
  leading,

  /// Places tabs along the trailing edge.
  trailing,

  /// Places tabs in the sidebar.
  sidebar,
}

@internal
abstract final class NativeSidebar {
  static const width = 280.0;
  static const rowInset = 20.0;
  static const rowHeight = 44.0;
  static const rowGap = 9.0;
  static const labelStart = 54.0;

  static const iconCentre = 30.0;
  static const toggleSize = 48.0;

  static const toggleInset = 20.0;

  static final spring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 350),
  );

  static const toggleEntryScale = 1.2;

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

  static (Color, BlendMode) selection(Brightness brightness) =>
      brightness == Brightness.dark
      ? (const Color(0xFF151515), BlendMode.plus)
      : (const Color(0x16000000), BlendMode.srcOver);
}

/// A sidebar presentation of a controlled tab bar.
@internal
class PrismSidebar extends StatelessWidget {
  /// Creates a sidebar using the supplied tab bar's selection contract.
  const new({
    super.key,
    required this.tabBar,
    required this.top,
    required this.onHide,
  });

  /// Tab bar displayed by the scaffold or sidebar.
  final PrismTabBar tabBar;

  /// Top content inset above sidebar rows.
  final double top;

  /// Callback that hides the sidebar.
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final colors = PrismTheme.colorsOf(context);
    final accent = PrismTheme.tintOf(context);
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
    PrismColors colors,
    Color accent,
  ) {
    final tab = tabBar.tabs[index];
    final selected = index == tabBar.selectedIndex;
    final onSelected = tabBar.onSelected;
    void select() {
      if (onSelected == null) return;
      if (!selected &&
          ((PrismTheme.of(context).tabBar?.merge(tabBar.style) ?? tabBar.style)
                  ?.haptics ??
              true)) {
        dispatchPrismHaptic(
          context,
          const PrismHapticEvent(
            PrismHapticComponent.tabBar,
            PrismHapticKind.selectionChange,
          ),
        );
      }
      onSelected(index);
    }

    void longPress() {
      if (onSelected == null || tabBar.onLongPressed == null) return;
      final style =
          PrismTheme.of(context).tabBar?.merge(tabBar.style) ?? tabBar.style;
      if (style?.haptics ?? true) {
        dispatchPrismHaptic(
          context,
          const PrismHapticEvent(
            PrismHapticComponent.tabBar,
            PrismHapticKind.longPress,
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
                        child: PrismBadgedIcon(
                          badge: tab.badge,
                          color:
                              (PrismTheme.of(context).tabBar
                                          ?.merge(tabBar.style) ??
                                      tabBar.style)
                                  ?.badgeColor,
                          textStyle:
                              (PrismTheme.of(context).tabBar
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
  const new(this.fill);
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

/// A glass button that shows or hides the sidebar.
@internal
class SidebarToggle extends StatelessWidget {
  /// Creates a sidebar visibility control.
  const new({super.key, required this.label, required this.onPressed});

  /// Accessible label, also displayed when an icon is omitted.
  final String label;

  /// Activation callback; null disables the action.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: NativeSidebar.toggleSize,
    child: PrismButton(
      label: label,
      style: PrismButtonStyle(
        shape: PrismShape.circle,
        padding: EdgeInsets.zero,
        foregroundColor: PrismTheme.colorsOf(context).label,
      ),
      onPressed: onPressed,
      child: Center(
        child: Builder(
          builder: (context) => CustomPaint(
            size: const Size(22, 18),
            painter: _SidebarGlyph(
              IconTheme.of(context).color ?? PrismTheme.colorsOf(context).label,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SidebarGlyph extends CustomPainter {
  const new(this.color);
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
