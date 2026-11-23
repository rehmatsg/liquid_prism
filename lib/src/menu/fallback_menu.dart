import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'menu.dart';
import 'menu_anchor.dart';
import 'menu_elements.dart';
import 'menu_icon.dart';

/// Presents menu models with Flutter when native menus are unavailable.
final class FallbackMenu {
  FallbackMenu._();

  /// Presents a menu and completes with the first selected value on dismissal.
  static Future<Object?> show(
    BuildContext context,
    PrismMenu menu,
    PrismMenuAnchor anchor,
  ) {
    return _present(context, menu, _position(context, anchor));
  }

  static RelativeRect _position(BuildContext context, PrismMenuAnchor anchor) {
    final overlay = Overlay.of(context).context.findRenderObject();
    final overlaySize = overlay is RenderBox
        ? overlay.size
        : MediaQuery.sizeOf(context);
    final rect = switch (anchor) {
      PrismMenuPointAnchor(:final position) => Rect.fromLTWH(
        position.dx,
        position.dy,
        0,
        0,
      ),
      PrismMenuRectAnchor(:final rect) => rect,
    };
    return RelativeRect.fromRect(rect, Offset.zero & overlaySize);
  }

  static Future<Object?> _present(
    BuildContext context,
    PrismMenu menu,
    RelativeRect position,
  ) async {
    final items = await _entries(context, menu.children);
    if (items.isEmpty) return null;
    if (!context.mounted) return null;
    final selected = await showMenu<Object?>(
      context: context,
      position: position,
      items: items,
    );
    switch (selected) {
      case _SubmenuJump(:final submenu):
        if (!context.mounted) return null;
        return _present(
          context,
          PrismMenu(children: submenu.children),
          position,
        );
      case PrismMenuAction<Object?> action:
        action.onSelected?.call();
        return action.value;
      default:
        return null;
    }
  }

  static Future<List<PopupMenuEntry<Object?>>> _entries(
    BuildContext context,
    List<PrismMenuElement> children,
  ) {
    return _entriesWithTheme(Theme.of(context), children);
  }

  static Future<List<PopupMenuEntry<Object?>>> _entriesWithTheme(
    ThemeData theme,
    List<PrismMenuElement> children,
  ) async {
    final entries = <PopupMenuEntry<Object?>>[];
    for (final element in children) {
      switch (element) {
        case PrismMenuAction<Object?> action:
          if (action.hidden) break;
          entries.add(_actionEntry(theme, action));
        case PrismMenuDivider():
          if (entries.isNotEmpty) entries.add(const PopupMenuDivider());
        case PrismMenuSection section:
          if (entries.isNotEmpty) entries.add(const PopupMenuDivider());
          if (section.title.isNotEmpty) {
            entries.add(_headerEntry(theme, section.title));
          }
          entries.addAll(await _entriesWithTheme(theme, section.children));
        case PrismSubmenu submenu:
          entries.add(_submenuEntry(theme, submenu));
        case PrismMenuDeferred deferred:
          try {
            final resolved = await deferred.loader();
            entries.addAll(await _entriesWithTheme(theme, resolved));
          } catch (_) {}
      }
    }
    return entries;
  }

  static PopupMenuEntry<Object?> _actionEntry(
    ThemeData theme,
    PrismMenuAction<Object?> action,
  ) {
    final color = action.destructive ? theme.colorScheme.error : null;
    return PopupMenuItem<Object?>(
      value: action,
      enabled: action.enabled,
      child: Row(
        children: [
          if (action.icon != null) ...[
            _FallbackIcon(icon: action.icon!, color: color),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(action.title, style: TextStyle(color: color)),
          ),
          if (action.state != .off) ...[
            const SizedBox(width: 12),
            Icon(Icons.check, size: 18, color: color),
          ],
        ],
      ),
    );
  }

  static PopupMenuEntry<Object?> _headerEntry(ThemeData theme, String title) {
    return PopupMenuItem<Object?>(
      enabled: false,
      height: 28,
      child: Text(title, style: theme.textTheme.labelSmall),
    );
  }

  static PopupMenuEntry<Object?> _submenuEntry(
    ThemeData theme,
    PrismSubmenu submenu,
  ) {
    return PopupMenuItem<Object?>(
      value: _SubmenuJump(submenu),
      child: Row(
        children: [
          if (submenu.icon != null) ...[
            _FallbackIcon(icon: submenu.icon!),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(submenu.title)),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

final class _SubmenuJump {
  const _SubmenuJump(this.submenu);
  final PrismSubmenu submenu;
}

final class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.icon, this.color});

  final PrismMenuIcon icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return switch (icon) {
      PrismMenuSfSymbol() => Icon(Icons.circle, size: 14, color: color),
      PrismMenuImage(:final bytes) => Image.memory(
        bytes,
        width: 18,
        height: 18,
        color: color,
      ),
    };
  }
}
