import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'chrome_material.dart';
import 'glass_transition.dart';
import 'material.dart';
import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'style.dart';
import 'theme.dart';
import 'toolbar.dart';
import 'appearance.dart';

/// Wraps the search field's glass capsule; see
/// [LiquidPrismSearchField.fieldBuilder].
typedef GlassSearchFieldBuilder = Widget Function(
  BuildContext context,
  Widget field,
);

/// Builds the editor's trailing widget; see
/// [LiquidPrismSearchField.suffixBuilder].
typedef GlassSearchSuffixBuilder = Widget? Function(
  BuildContext context,
  Widget? clearButton,
);

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
    this.cancelVisibility,
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
    this.suffixBuilder,
    this.fieldBuilder,
    this.onFocusChange,
    this.onTapOutside,
    this.groupId = EditableText,
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

  /// When the cancel action shows. Overrides
  /// [GlassSearchStyle.cancelVisibility]; defaults to
  /// [GlassSearchCancelVisibility.focused]. Use
  /// [GlassSearchCancelVisibility.always] for a dedicated search screen whose
  /// cancel closes it: it then shows, and works, while the field is unfocused.
  final GlassSearchCancelVisibility? cancelVisibility;
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

  /// Builds the trailing widget from the field's own clear action, which is
  /// null while clearing is unavailable (empty, disabled or hidden by style).
  /// Return [clearButton] to keep it, another widget such as a progress
  /// indicator to replace it, or null for none. A non-null [suffix] wins.
  final GlassSearchSuffixBuilder? suffixBuilder;

  /// Wraps the glass capsule that holds the editor, excluding the resting
  /// inset and the cancel action. Its rect is the field's anchor: wrap it in a
  /// [CompositedTransformTarget], [OverlayPortal], [TapRegion] or [Focus] to
  /// attach a dropdown or handle keys. Keep the returned structure stable
  /// across builds; replacing ancestors of the field remounts the editor and
  /// drops the keyboard.
  final GlassSearchFieldBuilder? fieldBuilder;

  /// Called when the editor gains or loses focus, after the change. Swapping
  /// in a focus node with a different state does not call it.
  final ValueChanged<bool>? onFocusChange;

  /// Called for a pointer down outside the editor and outside every
  /// [TapRegion] sharing [groupId]. Null keeps the platform behavior.
  final TapRegionCallback? onTapOutside;

  /// Tap region group of the editor. Give a field-anchored overlay's
  /// [TapRegion] the same group so taps inside it are not outside the field.
  final Object groupId;

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

Widget? _defaultSuffix(BuildContext context, Widget? clearButton) =>
    clearButton;

Widget _plainField(BuildContext context, Widget field) => field;

class _LiquidPrismSearchFieldState extends State<LiquidPrismSearchField>
    with TickerProviderStateMixin {
  final _ownedController = TextEditingController();
  final _ownedFocus = FocusNode(debugLabel: 'Glass search');
  late final _focus = RetargetableGlassSpring(vsync: this);
  // The cancel action materializes on its own spring so it can settle with a
  // little overshoot after the field has made room for it.
  late final _reveal = RetargetableGlassSpring(vsync: this);
  TextEditingController get _controller =>
      widget.controller ?? _ownedController;
  FocusNode get _node => widget.focusNode ?? _ownedFocus;
  @override
  void initState() {
    super.initState();
    _controller.addListener(_textChanged);
    _node.addListener(_nodeChanged);
    _reportedFocus = _node.hasFocus;
    _focus.value = _reveal.value = _node.hasFocus ? 1 : 0;
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
      (old.focusNode ?? _ownedFocus).removeListener(_nodeChanged);
      _node.addListener(_nodeChanged);
      _reportedFocus = _node.hasFocus;
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

  late bool _reportedFocus;

  void _nodeChanged() {
    _focusChanged();
    final focused = _node.hasFocus;
    if (focused == _reportedFocus) return;
    _reportedFocus = focused;
    widget.onFocusChange?.call(focused);
  }

  void _focusChanged() {
    final focused = widget.enabled && _node.hasFocus;
    final immediate = MediaQuery.disableAnimationsOf(context);
    final focusSpring =
        _appearance.focusSpring?.description ??
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 380),
        );
    springGlass(_focus, focused ? 1 : 0, focusSpring, immediate: immediate);
    springGlass(
      _reveal,
      focused ? 1 : 0,
      focused
          ? _appearance.cancelSpring?.description ??
                SpringDescription.withDurationAndBounce(
                  duration: const Duration(milliseconds: 520),
                  bounce: .22,
                )
          : focusSpring,
      immediate: immediate,
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
    _node.removeListener(_nodeChanged);
    _focus.dispose();
    _reveal.dispose();
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
    final clearButton =
        widget.enabled &&
            appearance.showClearButton != false &&
            _controller.text.isNotEmpty
        ? LiquidPrismPressable(
            label: widget.clearLabel,
            onPressed: _clear,
            child: SizedBox(
              width: appearance.clearWidth ?? 36,
              height: height,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 10 + 2 / 3),
                child: Icon(
                  CupertinoIcons.clear_thick_circled,
                  size: 20,
                  color: appearance.clearColor ?? colors.secondaryLabel,
                ),
              ),
            ),
          )
        : null;
    // Built outside the focus animation: the capsule's width animates through
    // layout, so neither the editor nor `fieldBuilder` rebuilds per frame.
    final capsule = (widget.fieldBuilder ?? _plainField)(
      context,
      GestureDetector(
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
            onTapOutside: widget.onTapOutside,
            groupId: widget.groupId,
            placeholder: widget.placeholder,
            placeholderStyle: style
                .copyWith(color: colors.secondaryLabel)
                .merge(appearance.placeholderStyle),
            style: style,
            cursorColor:
                appearance.cursorColor ?? LiquidPrismTheme.tintOf(context),
            decoration: null,
            padding: appearance.padding ?? EdgeInsets.zero,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            prefix:
                widget.prefix ??
                Padding(
                  padding:
                      appearance.prefixPadding ??
                      const EdgeInsetsDirectional.only(start: 12, end: 8),
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
                (widget.suffixBuilder ?? _defaultSuffix)(context, clearButton),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_focus, _reveal]),
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
          final fits =
              showCancel &&
              constraints.maxWidth >=
                  math.max(160, cancelWidth + cancelGap + 100);
          final pinned =
              (widget.cancelVisibility ?? appearance.cancelVisibility) ==
              GlassSearchCancelVisibility.always;
          final cancel = fits ? (pinned ? 1.0 : progress) : 0.0;
          // Unclamped so the action's bounce carries through its slide/scale.
          final reveal = fits ? (pinned ? 1.0 : _reveal.value) : 0.0;
          final active = pinned || _node.hasFocus;
          final inset =
              math.min(
                widget._hasInset
                    ? widget.restingInset
                    : appearance.restingInset ?? widget.restingInset,
                math.max(0, (constraints.maxWidth - 100) / 2),
              ) *
              (1 - progress);
          final field = SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: capsule),
                SizedBox(width: (cancelGap + cancelWidth) * cancel),
              ],
            ),
          );
          final rtl = Directionality.of(context) == TextDirection.rtl;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                field,
                if (reveal > .001)
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    width: cancelWidth,
                    height: height,
                    // Fades through the glass's own optics, keeping its full
                    // lens while it slides; an Opacity or scale here would
                    // cut the lens off from its backdrop.
                    child: LiquidPrismPresence(
                      progress: pinned ? kAlwaysCompleteAnimation : _reveal,
                      materialize: false,
                      child: Transform.translate(
                        // Slides in from the trailing edge, toward the field.
                        offset: Offset(
                          (1 - reveal) * cancelWidth * .6 * (rtl ? -1 : 1),
                          0,
                        ),
                        child: ExcludeSemantics(
                          excluding: !active,
                          // Cancel belongs to the field: tapping it is never
                          // a tap outside the editor's group.
                          child: TapRegion(
                            groupId: widget.groupId,
                            child: IgnorePointer(
                              ignoring: !active,
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
                                    // The inset sizes this to cancelWidth,
                                    // which need not equal the field height.
                                    width: 38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
