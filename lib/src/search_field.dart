import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'chrome_material.dart';
import 'material.dart';
import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'style.dart';
import 'theme.dart';
import 'toolbar.dart';
import 'appearance.dart';

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
    bool? showCancelButton,
    double? restingInset,
    this.appearance,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.search,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.readOnly = false,
    this.textAlign = TextAlign.start,
    this.onTap,
    this.onEditingComplete,
    this.onCleared,
    this.prefix,
    this.suffix,
    this.clearLabel = 'Clear search',
    this.cancelLabel = 'Cancel search',
    this.style,
    this.glass,
    this.optics,
    this.blur,
  }) : showCancelButton = showCancelButton ?? true,
       _hasCancel = showCancelButton != null,
       restingInset = restingInset ?? 0,
       _hasInset = restingInset != null,
       assert(restingInset == null || restingInset >= 0);
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder, clearLabel, cancelLabel;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onCancel;
  final bool enabled, autofocus, showCancelButton;
  final bool _hasCancel, _hasInset;
  final GlassSearchStyle? appearance;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autocorrect, enableSuggestions, readOnly;
  final TextAlign textAlign;
  final VoidCallback? onTap, onEditingComplete, onCleared;
  final Widget? prefix, suffix;

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

  GlassSearchStyle get _appearance =>
      (LiquidPrismTheme.of(context).search ?? const GlassSearchStyle()).merge(
        widget.appearance,
      );

  void _focusChanged() {
    springGlass(
      _focus,
      widget.enabled && _node.hasFocus ? 1 : 0,
      _appearance.focusSpring?.description ??
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
    widget.onCleared?.call();
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
    final appearance = _appearance;
    final style = TextStyle(
      fontSize: 17,
      color: widget.enabled ? colors.label : colors.disabledLabel,
    ).merge(appearance.textStyle).merge(widget.style);
    final height = math.max(
      appearance.height ?? 48.0,
      MediaQuery.textScalerOf(context).scale(style.fontSize ?? 17) + 28,
    );
    return AnimatedBuilder(
      animation: _focus,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final progress = _focus.value.clamp(0.0, 1.0);
          // Keep the editor usable in narrow parents; cancellation remains
          // available from the keyboard/focus API when its action cannot fit.
          final showCancel = widget._hasCancel
              ? widget.showCancelButton
              : appearance.showCancelButton ?? widget.showCancelButton;
          final cancelWidth = appearance.cancelWidth ?? 48;
          final cancelGap = appearance.cancelSpacing ?? 12;
          final cancel =
              showCancel &&
                  constraints.maxWidth >=
                      math.max(160, cancelWidth + cancelGap + 100)
              ? progress
              : 0.0;
          final inset =
              math.min(
                widget._hasInset
                    ? widget.restingInset
                    : appearance.restingInset ?? widget.restingInset,
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
                        glass: widget.glass ?? appearance.glass,
                        optics: widget.optics ?? appearance.optics,
                        blur: widget.blur ?? appearance.blur,
                        shape: appearance.shape,
                        child: CupertinoTextField(
                          controller: _controller,
                          focusNode: _node,
                          enabled: widget.enabled,
                          autofocus: widget.autofocus,
                          keyboardType: widget.keyboardType,
                          inputFormatters: widget.inputFormatters,
                          textCapitalization: widget.textCapitalization,
                          autocorrect: widget.autocorrect,
                          enableSuggestions: widget.enableSuggestions,
                          readOnly: widget.readOnly,
                          textAlign: widget.textAlign,
                          onTap: widget.onTap,
                          onEditingComplete: widget.onEditingComplete,
                          placeholder: widget.placeholder,
                          placeholderStyle: style
                              .copyWith(color: colors.secondaryLabel)
                              .merge(appearance.placeholderStyle),
                          style: style,
                          cursorColor:
                              appearance.cursorColor ??
                              LiquidPrismTheme.tintOf(context),
                          decoration: null,
                          padding: EdgeInsets.zero,
                          textInputAction: widget.textInputAction,
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                          prefix:
                              widget.prefix ??
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 12,
                                  end: 8,
                                ),
                                child: ExcludeSemantics(
                                  child: Icon(
                                    CupertinoIcons.search,
                                    size: appearance.iconSize ?? 20 + 1 / 3,
                                    color: appearance.iconColor ?? colors.label,
                                  ),
                                ),
                              ),
                          suffix:
                              widget.suffix ??
                              (widget.enabled &&
                                      appearance.showClearButton != false &&
                                      _controller.text.isNotEmpty
                                  ? LiquidPrismPressable(
                                      label: widget.clearLabel,
                                      onPressed: _clear,
                                      child: SizedBox(
                                        width: appearance.clearWidth ?? 36,
                                        height: height,
                                        child: Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                end: 10 + 2 / 3,
                                              ),
                                          child: Icon(
                                            CupertinoIcons.clear_thick_circled,
                                            size: 20,
                                            color:
                                                appearance.clearColor ??
                                                colors.secondaryLabel,
                                          ),
                                        ),
                                      ),
                                    )
                                  : null),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: cancelGap * cancel),
                  if (cancel > 0)
                    SizedBox(
                      width: cancelWidth * cancel,
                      height: height,
                      child: ClipRect(
                        clipBehavior: cancel < 1 ? Clip.hardEdge : Clip.none,
                        child: OverflowBox(
                          maxWidth: cancelWidth,
                          minWidth: cancelWidth,
                          child: ExcludeSemantics(
                            excluding: !_node.hasFocus,
                            child: IgnorePointer(
                              ignoring: !_node.hasFocus,
                              child: LiquidPrismToolbarGroup(
                                glass: widget.glass ?? appearance.glass,
                                optics: widget.optics ?? appearance.optics,
                                blur: widget.blur ?? appearance.blur,
                                style: GlassToolbarStyle(
                                  height: height,
                                  inset: (cancelWidth - 38) / 2,
                                ),
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
