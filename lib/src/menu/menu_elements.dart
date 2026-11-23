import 'dart:async' show FutureOr;

import 'package:flutter/foundation.dart' show immutable, listEquals;

import 'package:liquid_prism/src/menu/menu_icon.dart';

/// The checkmark state of a menu row.
enum PrismMenuElementState {
  /// The off setting.
  off,

  /// The on setting.
  on,

  /// The mixed setting.
  mixed,
}

/// The preferred native menu row density.
enum PrismMenuElementSize {
  /// The automatic setting.
  automatic,

  /// The small setting.
  small,

  /// The medium setting.
  medium,

  /// The large setting.
  large,
}

/// An action, separator, section, submenu, or deferred menu element.
sealed class PrismMenuElement {
  /// Creates a PrismMenuElement.
  const new();

  /// Serializes native wire fields.
  Map<String, Object?> toMap();
}

/// A selectable menu row with an optional result and callback.
@immutable
final class PrismMenuAction<T> extends PrismMenuElement {
  /// Creates a PrismMenuAction.
  const new({
    required this.title,
    this.id,
    this.value,
    this.icon,
    this.state = .off,
    this.destructive = false,
    this.enabled = true,
    this.hidden = false,
    this.keepsMenuPresented = false,
    this.discoverabilityTitle,
    this.onSelected,
  });

  /// The stable wire identifier, minted automatically when omitted.
  final String? id;

  /// The result returned after this action is selected and the menu closes.
  final T? value;

  /// The row or menu header text.
  final String title;

  /// The leading menu image.
  final PrismMenuIcon? icon;

  /// The row checkmark state.
  final PrismMenuElementState state;

  /// Whether the system uses its destructive appearance.
  final bool destructive;

  /// Whether the row accepts selection.
  final bool enabled;

  /// Whether the native menu omits the row.
  final bool hidden;

  /// Whether the menu remains open for repeated selections.
  final bool keepsMenuPresented;

  /// The optional keyboard shortcut discovery text.
  final String? discoverabilityTitle;

  /// Called for each selection, including repeated row selections.
  final void Function()? onSelected;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuAction<T> &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          value == other.value &&
          title == other.title &&
          icon == other.icon &&
          state == other.state &&
          destructive == other.destructive &&
          enabled == other.enabled &&
          hidden == other.hidden &&
          keepsMenuPresented == other.keepsMenuPresented &&
          discoverabilityTitle == other.discoverabilityTitle &&
          onSelected == other.onSelected);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    value,
    title,
    icon,
    state,
    destructive,
    enabled,
    hidden,
    keepsMenuPresented,
    discoverabilityTitle,
    onSelected,
  );

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => {
    'type': 'action',
    if (id != null) 'id': id,
    'title': title,
    if (icon != null) 'icon': icon!.toMap(),
    if (state != .off) 'state': state.name,
    if (destructive) 'destructive': true,
    if (!enabled) 'disabled': true,
    if (hidden) 'hidden': true,
    if (keepsMenuPresented) 'keepsMenuPresented': true,
    if (discoverabilityTitle != null)
      'discoverabilityTitle': discoverabilityTitle,
  };
}

/// A separator between adjacent menu groups.
@immutable
final class PrismMenuDivider extends PrismMenuElement {
  /// Creates a PrismMenuDivider.
  const new();

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuDivider && runtimeType == other.runtimeType);

  /// The hash of this value and its fields.
  @override
  int get hashCode => runtimeType.hashCode;

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => const {'type': 'divider'};
}

/// An inline group of menu elements with an optional header.
@immutable
final class PrismMenuSection extends PrismMenuElement {
  /// Creates a PrismMenuSection.
  const new({
    this.title = '',
    this.icon,
    this.children = const [],
    this.singleSelection = false,
    this.palette = false,
    this.preferredElementSize = .automatic,
  });

  /// The row or menu header text.
  final String title;

  /// The leading menu image.
  final PrismMenuIcon? icon;

  /// The ordered child elements.
  final List<PrismMenuElement> children;

  /// Whether the group uses single-selection semantics.
  final bool singleSelection;

  /// Whether the section renders as an icon palette.
  final bool palette;

  /// The preferred native row density.
  final PrismMenuElementSize preferredElementSize;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuSection &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          icon == other.icon &&
          listEquals(children, other.children) &&
          singleSelection == other.singleSelection &&
          palette == other.palette &&
          preferredElementSize == other.preferredElementSize);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(
    runtimeType,
    title,
    icon,
    Object.hashAll(children),
    singleSelection,
    palette,
    preferredElementSize,
  );

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => {
    'type': 'section',
    'menu': {
      'title': title,
      if (icon != null) 'image': icon!.toMap(),
      'elementSize': preferredElementSize.name,
      'options': {
        if (singleSelection) 'singleSelection': true,
        if (palette) 'palette': true,
      },
    },
  };
}

/// A nested menu presented as a navigable row.
@immutable
final class PrismSubmenu extends PrismMenuElement {
  /// Creates a PrismSubmenu.
  const new({
    required this.title,
    this.icon,
    this.children = const [],
    this.destructive = false,
    this.singleSelection = false,
    this.preferredElementSize = .automatic,
  });

  /// The row or menu header text.
  final String title;

  /// The leading menu image.
  final PrismMenuIcon? icon;

  /// The ordered child elements.
  final List<PrismMenuElement> children;

  /// Whether the system uses its destructive appearance.
  final bool destructive;

  /// Whether the group uses single-selection semantics.
  final bool singleSelection;

  /// The preferred native row density.
  final PrismMenuElementSize preferredElementSize;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismSubmenu &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          icon == other.icon &&
          listEquals(children, other.children) &&
          destructive == other.destructive &&
          singleSelection == other.singleSelection &&
          preferredElementSize == other.preferredElementSize);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(
    runtimeType,
    title,
    icon,
    Object.hashAll(children),
    destructive,
    singleSelection,
    preferredElementSize,
  );

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => {
    'type': 'submenu',
    'menu': {
      'title': title,
      if (icon != null) 'image': icon!.toMap(),
      'elementSize': preferredElementSize.name,
      'options': {
        if (destructive) 'destructive': true,
        if (singleSelection) 'singleSelection': true,
      },
    },
  };
}

/// Menu elements loaded when the native menu requests them.
@immutable
final class PrismMenuDeferred extends PrismMenuElement {
  /// Creates a PrismMenuDeferred.
  const new({required this.loader, this.id});

  /// The stable wire identifier, minted automatically when omitted.
  final String? id;

  /// Loads child elements when requested at display time.
  final FutureOr<List<PrismMenuElement>> Function() loader;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuDeferred &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          loader == other.loader);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(runtimeType, id, loader);

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => {
    'type': 'deferred',
    if (id != null) 'id': id,
  };
}
