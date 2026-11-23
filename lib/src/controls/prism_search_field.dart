import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../core/prism_motion.dart';
import '../navigation/prism_toolbar.dart';
import '../navigation/prism_toolbar_content.dart';
import '../navigation/prism_toolbar_style.dart';
import '../rendering/chrome_material.dart';
import '../rendering/prism_transition.dart';
import '../rendering/recipe.dart';
import '../theme/prism_theme.dart';
import 'prism_pressable.dart';
import 'prism_search_style.dart';

/// Wraps the search capsule without remounting the editor.
typedef PrismSearchFieldBuilder = Widget Function(
  BuildContext context,
  Widget field,
);

/// Builds trailing content from the available clear action.
typedef PrismSearchSuffixBuilder = Widget? Function(
  BuildContext context,
  Widget? clearButton,
);

/// A glass search editor that preserves borrowed controller ownership.
class PrismSearchField extends StatefulWidget {
  /// Creates a search field with optional borrowed editing resources.
  const PrismSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onCancel,
    this.enabled = true,
    this.autofocus = false,
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
  });

  /// Borrowed editor controller; null uses an owned controller.
  final TextEditingController? controller;

  /// Borrowed focus node; null uses an owned node.
  final FocusNode? focusNode;

  /// Placeholder and accessible names for clear and cancel actions.
  final String placeholder, clearLabel, cancelLabel;

  /// Callbacks for user edits and submitted text.
  final ValueChanged<String>? onChanged, onSubmitted;

  /// Called after clearing text and dismissing keyboard focus.
  final VoidCallback? onCancel;

  /// Whether editing is enabled and initial focus is requested.
  final bool enabled, autofocus;

  /// Visual overrides merged over the search theme.
  final PrismSearchStyle? style;

  /// Keyboard layout requested by the editor.
  final TextInputType keyboardType;

  /// Action displayed by the software keyboard.
  final TextInputAction textInputAction;

  /// Formatters applied to user edits.
  final List<TextInputFormatter>? inputFormatters;

  /// Keyboard capitalization behavior.
  final TextCapitalization textCapitalization;

  /// Correction, suggestion, and editing behavior.
  final bool autocorrect, enableSuggestions, readOnly;

  /// Alignment of editor text.
  final TextAlign textAlign;

  /// Callbacks for taps, editing completion, and the clear action.
  final VoidCallback? onTap, onEditingComplete, onCleared;

  /// Custom leading and trailing editor widgets.
  final Widget? prefix, suffix;

  /// Builds trailing content unless an explicit suffix is supplied.
  final PrismSearchSuffixBuilder? suffixBuilder;

  /// Wraps the capsule; keep its structure stable to preserve editor state.
  final PrismSearchFieldBuilder? fieldBuilder;

  /// Reports editor focus changes after they occur.
  final ValueChanged<bool>? onFocusChange;

  /// Handles pointer contact outside the editor tap region group.
  final TapRegionCallback? onTapOutside;

  /// Tap region group shared by the editor and its overlays.
  final Object groupId;

  @override
  State<PrismSearchField> createState() => _PrismSearchFieldState();
}

Widget? _defaultSuffix(BuildContext context, Widget? clearButton) =>
    clearButton;

Widget _plainField(BuildContext context, Widget field) => field;

class _PrismSearchFieldState extends State<PrismSearchField>
    with TickerProviderStateMixin {
  final _ownedController = TextEditingController();
  final _ownedFocus = FocusNode(debugLabel: 'Prism search');
  late final _focus = RetargetablePrismSpring(vsync: this);
  late final _reveal = RetargetablePrismSpring(vsync: this);
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
  void didUpdateWidget(PrismSearchField old) {
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

  PrismSearchStyle get _appearance =>
      (PrismTheme.of(context).search ?? const PrismSearchStyle()).merge(
        widget.style,
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
    springPrism(_focus, focused ? 1 : 0, focusSpring, immediate: immediate);
    springPrism(
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
    final colors = PrismTheme.colorsOf(context);
    final appearance = _appearance;
    final style = TextStyle(
      fontSize: 17,
      color: widget.enabled ? colors.label : colors.disabledLabel,
    ).merge(appearance.textStyle);
    final height = math.max(
      appearance.height ?? 48.0,
      MediaQuery.textScalerOf(context).scale(style.fontSize ?? 17) + 28,
    );
    final clearButton =
        widget.enabled &&
            appearance.showClearButton != false &&
            _controller.text.isNotEmpty
        ? PrismPressable(
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
    final capsule = (widget.fieldBuilder ?? _plainField)(
      context,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _node.requestFocus : null,
        child: ChromeMaterial(
          height: height,
          role: PrismRole.searchField,
          glass: appearance.glass,
          optics: appearance.optics,
          blur: appearance.blur,
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
            cursorColor: appearance.cursorColor ?? PrismTheme.tintOf(context),
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
          final showCancel = appearance.showCancelButton ?? true;
          final cancelWidth = appearance.cancelWidth ?? 48;
          final cancelGap = appearance.cancelSpacing ?? 12;
          final fits =
              showCancel &&
              constraints.maxWidth >=
                  math.max(160, cancelWidth + cancelGap + 100);
          final pinned =
              (appearance.cancelVisibility) ==
              PrismSearchCancelVisibility.always;
          final cancel = fits ? (pinned ? 1.0 : progress) : 0.0;
          final reveal = fits ? (pinned ? 1.0 : _reveal.value) : 0.0;
          final active = pinned || _node.hasFocus;
          final inset =
              math.min(
                appearance.restingInset ?? 0,
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
                    child: PrismPresence(
                      progress: pinned ? kAlwaysCompleteAnimation : _reveal,
                      materialize: false,
                      child: Transform.translate(
                        offset: Offset(
                          (1 - reveal) * cancelWidth * .6 * (rtl ? -1 : 1),
                          0,
                        ),
                        child: ExcludeSemantics(
                          excluding: !active,
                          child: TapRegion(
                            groupId: widget.groupId,
                            child: IgnorePointer(
                              ignoring: !active,
                              child: PrismToolbar.group(
                                style: PrismToolbarStyle(
                                  glass: appearance.glass,
                                  optics: appearance.optics,
                                  blur: appearance.blur,
                                  height: height,
                                  inset: (cancelWidth - 38) / 2,
                                ),
                                items: [
                                  PrismToolbarItem(
                                    label: widget.cancelLabel,
                                    icon: const Icon(
                                      CupertinoIcons.xmark,
                                      size: 17,
                                    ),
                                    onPressed: _cancel,
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
