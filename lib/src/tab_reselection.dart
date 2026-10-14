import 'package:flutter/widgets.dart';

/// Taps on the selected tab of a [LiquidPrismScaffold]'s tab bar.
///
/// The scaffold shares one with its tab bar and every page in its body. A
/// page built from `LiquidPrismScaffold.slivers` scrolls back to the top on
/// a reselection while it is the visible, current route; listen with
/// [maybeOf] for anything else, such as focusing a search field.
class LiquidPrismTabReselection extends ChangeNotifier {
  /// Reports a tap on the already selected tab.
  void reselect() => notifyListeners();

  /// The nearest scaffold's reselections, or null outside a scaffold with a
  /// tab bar.
  static LiquidPrismTabReselection? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ReselectionScope>()
      ?.reselection;

  /// Provides [reselection] to [child].
  static Widget scope({
    required LiquidPrismTabReselection reselection,
    required Widget child,
  }) => _ReselectionScope(reselection: reselection, child: child);
}

class _ReselectionScope extends InheritedWidget {
  const _ReselectionScope({required this.reselection, required super.child});
  final LiquidPrismTabReselection reselection;
  @override
  bool updateShouldNotify(_ReselectionScope old) =>
      reselection != old.reselection;
}
