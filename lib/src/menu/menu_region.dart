import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/menu/menu.dart';
import 'package:liquid_prism/src/menu/menu_anchor.dart';
import 'package:liquid_prism/src/menu/menu_engine.dart';

/// The gesture that opens a menu region.
enum PrismMenuTrigger {
  /// Opens the menu on a tap.
  tap,

  /// Opens the menu on a long press.
  longPress,
}

/// The attachment geometry used by a menu region.
enum PrismMenuAnchorMode {
  /// Anchors the menu at the last pointer position.
  tapPoint,

  /// Anchors the menu to the trigger bounds.
  triggerRect,
}

/// Opens a menu using a region gesture or an existing child handler.
final class PrismMenuRegion extends StatefulWidget {
  /// Creates a PrismMenuRegion.
  const new({
    super.key,
    required this.menu,
    required this.child,
    this.trigger = .tap,
    this.anchor = .triggerRect,
    this.onSelected,
  }) : builder = null;

  /// Creates a region using the child’s existing activation handler.
  const new builder({
    super.key,
    required this.menu,
    required this.builder,
    this.anchor = .tapPoint,
    this.onSelected,
  }) : trigger = null,
       child = null;

  /// The menu presented by this region.
  final PrismMenu menu;

  /// The visual trigger used with the region gesture.
  final Widget? child;

  /// Builds a child that calls the supplied show callback itself.
  final Widget Function(BuildContext context, VoidCallback show)? builder;

  /// The opening gesture, or null when the builder owns activation.
  final PrismMenuTrigger? trigger;

  /// The attachment mode for the presented menu.
  final PrismMenuAnchorMode anchor;

  /// Called after dismissal with the first selected value, or null.
  final void Function(Object? selected)? onSelected;

  /// Creates the menu region state.
  @override
  State<PrismMenuRegion> createState() => _PrismMenuRegionState();
}

class _PrismMenuRegionState extends State<PrismMenuRegion> {
  Offset? _lastPointer;

  void _recordPointer(PointerDownEvent event) {
    _lastPointer = event.position;
  }

  Future<void> _show() async {
    final anchor = switch (widget.anchor) {
      .tapPoint =>
        _lastPointer != null
            ? PrismMenuAnchor.point(_lastPointer!)
            : _rectAnchor(),
      .triggerRect => _rectAnchor(),
    };
    final selected = await PrismMenuEngine.instance.show(
      context: context,
      menu: widget.menu,
      anchor: anchor,
    );
    if (mounted) widget.onSelected?.call(selected);
  }

  PrismMenuAnchor _rectAnchor() {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return .rect(
        Rect.fromPoints(
          box.localToGlobal(.zero),
          box.localToGlobal(box.size.bottomRight(.zero)),
        ),
      );
    }
    return .point(_lastPointer ?? .zero);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? widget.builder!(context, _show);
    final trigger = widget.trigger;
    return Listener(
      onPointerDown: _recordPointer,
      child: trigger == null
          ? child
          : GestureDetector(
              behavior: .translucent,
              onTap: trigger == .tap ? _show : null,
              onLongPress: trigger == .longPress ? _show : null,
              child: child,
            ),
    );
  }
}
