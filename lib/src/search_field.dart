import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'chrome_material.dart';
import 'material.dart';
import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'style.dart';
import 'theme.dart';
import 'toolbar.dart';

/// A native-size glass search capsule with clear and focused cancel actions.
/// Owns its controller/focus node only when they are not supplied by the caller.
class LiquidPrismSearchField extends StatefulWidget {
  const LiquidPrismSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onCancel,
    this.enabled = true,
    this.autofocus = false,
    this.showCancelButton = true,
    this.restingInset = 0,
    this.clearLabel = 'Clear search',
    this.cancelLabel = 'Cancel search',
    this.style,
    this.glass,
    this.optics,
    this.blur,
  }) : assert(restingInset >= 0);
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder, clearLabel, cancelLabel;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onCancel;
  final bool enabled, autofocus, showCancelButton;

  /// Optional inset that dissolves on focus. Native bottom search uses 20
  /// inside a parent inset by 8; standalone fields default to zero.
  final double restingInset;
  final TextStyle? style;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  @override
  State<LiquidPrismSearchField> createState() => _LiquidPrismSearchFieldState();
}

class _LiquidPrismSearchFieldState extends State<LiquidPrismSearchField>
    with SingleTickerProviderStateMixin {
  final _ownedController = TextEditingController();
  final _ownedFocus = FocusNode(debugLabel: 'Glass search');
  late final _focus = RetargetableGlassSpring(vsync: this);
  TextEditingController get _controller =>
      widget.controller ?? _ownedController;
  FocusNode get _node => widget.focusNode ?? _ownedFocus;
  @override
  void initState() {
    super.initState();
    _controller.addListener(_textChanged);
    _node.addListener(_focusChanged);
    _focus.value = _node.hasFocus ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusChanged();
  }

  @override
  void didUpdateWidget(LiquidPrismSearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      final previous = old.controller ?? _ownedController;
      previous.removeListener(_textChanged);
      if (widget.controller == null) _ownedController.value = previous.value;
      _controller.addListener(_textChanged);
    }
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownedFocus).removeListener(_focusChanged);
      _node.addListener(_focusChanged);
    }
    if (!widget.enabled) _node.unfocus();
    _focusChanged();
  }

  void _textChanged() {
    if (mounted) setState(() {});
  }

  void _focusChanged() {
    springGlass(
      _focus,
      widget.enabled && _node.hasFocus ? 1 : 0,
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 250),
      ),
      immediate: MediaQuery.disableAnimationsOf(context),
    );
  }

  void _clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    widget.onChanged?.call('');
  }

  void _cancel() {
    _clear();
    _node.unfocus();
    widget.onCancel?.call();
  }

  @override
  void dispose() {
    _controller.removeListener(_textChanged);
    _node.removeListener(_focusChanged);
    _focus.dispose();
    _ownedController.dispose();
    _ownedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final style = TextStyle(
      fontSize: 17,
      color: widget.enabled ? colors.label : colors.disabledLabel,
    ).merge(widget.style);
    final height = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(style.fontSize ?? 17) + 28,
    );
    return AnimatedBuilder(
      animation: _focus,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final progress = _focus.value.clamp(0.0, 1.0);
          // Keep the editor usable in narrow parents; cancellation remains
          // available from the keyboard/focus API when its action cannot fit.
          final cancel = widget.showCancelButton && constraints.maxWidth >= 160
              ? progress
              : 0.0;
          final inset =
              math.min(
                widget.restingInset,
                math.max(0, (constraints.maxWidth - 100) / 2),
              ) *
              (1 - progress);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.enabled ? _node.requestFocus : null,
                      child: ChromeMaterial(
                        height: height,
                        role: GlassRole.searchField,
                        glass: widget.glass,
                        optics: widget.optics,
                        blur: widget.blur,
                        child: CupertinoTextField(
                          controller: _controller,
                          focusNode: _node,
                          enabled: widget.enabled,
                          autofocus: widget.autofocus,
                          placeholder: widget.placeholder,
                          placeholderStyle: style.copyWith(
                            color: colors.secondaryLabel,
                          ),
                          style: style,
                          cursorColor: LiquidPrismTheme.tintOf(context),
                          decoration: null,
                          padding: EdgeInsets.zero,
                          textInputAction: TextInputAction.search,
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                          prefix: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 12,
                              end: 8,
                            ),
                            child: ExcludeSemantics(
                              child: Icon(
                                CupertinoIcons.search,
                                size: 20 + 1 / 3,
                                color: colors.label,
                              ),
                            ),
                          ),
                          suffix: widget.enabled && _controller.text.isNotEmpty
                              ? LiquidPrismPressable(
                                  label: widget.clearLabel,
                                  onPressed: _clear,
                                  child: SizedBox(
                                    width: 36,
                                    height: height,
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 10 + 2 / 3,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.clear_thick_circled,
                                        size: 20,
                                        color: colors.secondaryLabel,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12 * cancel),
                  if (cancel > 0)
                    SizedBox(
                      width: 48 * cancel,
                      height: height,
                      child: ClipRect(
                        clipBehavior: cancel < 1 ? Clip.hardEdge : Clip.none,
                        child: OverflowBox(
                          maxWidth: 48,
                          minWidth: 48,
                          child: ExcludeSemantics(
                            excluding: !_node.hasFocus,
                            child: IgnorePointer(
                              ignoring: !_node.hasFocus,
                              child: LiquidPrismToolbarGroup(
                                glass: widget.glass,
                                optics: widget.optics,
                                blur: widget.blur,
                                items: [
                                  GlassToolbarItem(
                                    label: widget.cancelLabel,
                                    icon: const Icon(
                                      CupertinoIcons.xmark,
                                      size: 17,
                                    ),
                                    onPressed: _cancel,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
