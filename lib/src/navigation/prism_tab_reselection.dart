import 'package:flutter/widgets.dart';

/// Notifies descendants when the selected tab is activated again.
class PrismTabReselection extends ChangeNotifier {
  /// Notifies listeners that the active tab was selected again.
  void reselect() => notifyListeners();

  /// Returns the nearest tab reselection notifier, if present.
  static PrismTabReselection? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ReselectionScope>()
      ?.reselection;

  /// Publishes a reselection notifier to descendants.
  static Widget scope({
    required PrismTabReselection reselection,
    required Widget child,
  }) => _ReselectionScope(reselection: reselection, child: child);
}

class _ReselectionScope extends InheritedWidget {
  const new({required this.reselection, required super.child});
  final PrismTabReselection reselection;
  @override
  bool updateShouldNotify(_ReselectionScope old) =>
      reselection != old.reselection;
}
