import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'menu/menu.dart';
import 'menu/menu_elements.dart';
import 'system_chrome.dart';
import 'tab_bar.dart';
import 'toolbar.dart';

/// Where [LiquidPrismScaffold] floats its tab bar and actions.
///
/// iOS moves bar chrome into a vertical rail when the window has a deep safe
/// area on one side only, as beside the sensor bar of iPhone Duo. An iPhone in
/// landscape has equal side insets and keeps the bottom tab bar.
enum GlassChromePlacement {
  /// Actions in the top bar, tab bar floating above the bottom edge.
  bottom,

  /// Actions and tab bar stacked in a rail inside the left safe area.
  leftRail,

  /// Actions and tab bar stacked in a rail inside the right safe area.
  rightRail;

  bool get isRail => this != bottom;

  /// Chooses a placement from window safe-area insets ([MediaQueryData.viewPadding]).
  ///
  /// [LiquidPrismScaffold] prefers the system's answer: on iOS 27.1 and later
  /// the plugin reports `UITraitCollection.verticalBarEdge`. This fallback is
  /// for earlier systems and tests: a rail needs one side to be at least
  /// [railInset] deeper than the other, fitted to measured iOS 27.1 layouts.
  static GlassChromePlacement resolve(
    EdgeInsets viewPadding, {
    double railInset = 48,
  }) {
    final difference = viewPadding.right - viewPadding.left;
    if (difference >= railInset) return rightRail;
    if (-difference >= railInset) return leftRail;
    return bottom;
  }
}

/// Placement and bar axis published below a [LiquidPrismScaffold].
@immutable
class LiquidPrismChrome extends InheritedWidget {
  const LiquidPrismChrome({
    super.key,
    required this.placement,
    this.axis,
    required super.child,
  });

  final GlassChromePlacement placement;

  /// The axis bar components adopt; null where content should keep its own.
  final Axis? axis;

  static LiquidPrismChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidPrismChrome>();

  @override
  bool updateShouldNotify(LiquidPrismChrome oldWidget) =>
      placement != oldWidget.placement || axis != oldWidget.axis;
}

/// A full-window layout that floats glass chrome over scrolling content and
/// puts it where iOS would for the current window.
///
/// On iPhone the [actions] sit at the top trailing edge and the [tabBar] floats
/// above the bottom edge. Wherever iOS uses a vertical bar, as on iPhone Duo,
/// both move into a rail on that edge, below the status bar, and the tab bar
/// turns icon-only. When the rail is too short, the actions collapse into one
/// overflow menu before the tab bar compresses, as native bars do. The layout
/// follows the window as it resizes, folds or rotates.
///
/// On iOS 27.1 and later the placement, the status bar's position in the rail
/// and any partial fold come from UIKit (`verticalBarEdge` and reserved
/// regions). The fold reaches the body as a [MediaQueryData.displayFeatures]
/// entry, so `DisplayFeatureSubScreen` can keep content out of it.
///
/// [body] fills the whole window, so content stays visible through the glass.
/// Its [MediaQueryData.padding] includes the space the chrome covers, which
/// scroll views apply automatically. Use [SafeArea] or read the padding for
/// anything else that must stay clear.
class LiquidPrismScaffold extends StatelessWidget {
  const LiquidPrismScaffold({
    super.key,
    required this.body,
    this.leading,
    this.actions = const [],
    this.tabBar,
    this.placement,
    this.backgroundColor,
  });

  /// Full-window content. Usually a scroll view.
  final Widget body;

  /// A top-leading control, such as a back button. It stays in the top bar in
  /// every placement.
  final Widget? leading;

  /// Actions sharing one glass capsule: top trailing, or atop the rail.
  final List<GlassToolbarItem> actions;

  /// Usually a [LiquidPrismTabBar]. It adopts the placement's axis unless it
  /// sets its own.
  final Widget? tabBar;

  /// Forces a placement. Null follows the system's vertical bar edge, or
  /// [GlassChromePlacement.resolve] where the system doesn't report one.
  final GlassChromePlacement? placement;

  /// Painted behind [body]. Null leaves the window transparent.
  final Color? backgroundColor;

  /// The placement of the nearest scaffold, or null outside one.
  static GlassChromePlacement? placementOf(BuildContext context) =>
      LiquidPrismChrome.maybeOf(context)?.placement;

  /// The top bar's measured height: 44 pt navigation capsules.
  static const double topBarHeight = 44;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<SystemChrome?>(
    valueListenable: SystemChromeListener.instance.value,
    builder: (context, system, _) => _build(context, system),
  );

  Widget _build(BuildContext context, SystemChrome? system) {
    final media = MediaQuery.of(context);
    final resolved =
        placement ??
        switch (system) {
          null => GlassChromePlacement.resolve(media.viewPadding),
          SystemChrome(verticalBarEdge: AxisDirection.left) =>
            GlassChromePlacement.leftRail,
          SystemChrome(verticalBarEdge: AxisDirection.right) =>
            GlassChromePlacement.rightRail,
          _ => GlassChromePlacement.bottom,
        };
    final rail = resolved.isRail;
    final keyboard = media.viewInsets.bottom > 0;
    final occlusions = system?.occlusions ?? const <Rect>[];
    final actionsTop = _ChromeLayout.railActionsTop(
      media.size,
      media.viewPadding,
      resolved,
      occlusions,
    );
    final items = rail && !_fitsRail(media.size.height - actionsTop)
        ? [_overflow(actions)]
        : actions;
    final features = system?.displayFeatures ?? const [];
    final layout = CustomMultiChildLayout(
      delegate: _ChromeLayout(
        placement: resolved,
        viewPadding: media.viewPadding,
        keyboard: media.viewInsets.bottom,
        textDirection: Directionality.of(context),
        iOS: defaultTargetPlatform == TargetPlatform.iOS,
        topBar: leading != null || (!rail && actions.isNotEmpty),
        actionsTop: actionsTop,
      ),
      children: [
        LayoutId(
          id: _Slot.body,
          child: LiquidPrismChrome(
            placement: resolved,
            child: _InsetBody(
              media: features.isEmpty
                  ? media
                  : media.copyWith(
                      displayFeatures: [...media.displayFeatures, ...features],
                    ),
              child: body,
            ),
          ),
        ),
        if (leading case final leading?)
          LayoutId(id: _Slot.leading, child: leading),
        if (items.isNotEmpty)
          LayoutId(
            id: _Slot.actions,
            child: LiquidPrismToolbarGroup(
              items: items,
              // Measured: a 44 pt navigation capsule in the top bar, a 48 pt
              // wide column in the rail.
              size: rail
                  ? GlassToolbarSize.bottom
                  : GlassToolbarSize.navigation,
              axis: rail ? Axis.vertical : Axis.horizontal,
            ),
          ),
        // A bottom tab bar would sit under the keyboard; native hides it too.
        if (tabBar case final tabBar? when rail || !keyboard)
          LayoutId(
            id: _Slot.tabBar,
            child: LiquidPrismChrome(
              placement: resolved,
              axis: rail ? Axis.vertical : Axis.horizontal,
              child: tabBar,
            ),
          ),
      ],
    );
    return switch (backgroundColor) {
      final color? => ColoredBox(color: color, child: layout),
      null => layout,
    };
  }

  /// Whether the actions and tab bar both fit a rail of [height] below the
  /// actions' top, with the measured gaps.
  bool _fitsRail(double height) {
    if (actions.length < 2) return true;
    final actionsLength =
        actions.fold<double>(0, (sum, item) => sum + item.width) +
        14 * (actions.length - 1) +
        10;
    final tabs = switch (tabBar) {
      LiquidPrismTabBar(:final tabs) => 50.0 * tabs.length + 12,
      null => 0.0,
      _ => 0.0,
    };
    return actionsLength + _ChromeLayout._railGap + tabs + 24 <= height;
  }

  /// One "More" item whose native menu holds every action.
  static GlassToolbarItem _overflow(List<GlassToolbarItem> actions) =>
      GlassToolbarItem.menu(
        icon: const _Ellipsis(),
        label: 'More',
        menu: LiquidMenu(
          children: [
            for (final item in actions)
              if (item.menu case final menu?)
                LiquidSubmenu(title: item.label, children: menu.children)
              else
                LiquidMenuAction<void>(
                  title: item.label,
                  enabled: item.onPressed != null,
                  onSelected: () => item.onPressed?.call(),
                ),
          ],
        ),
      );
}

/// Three dots in the icon theme's size and color: the overflow symbol,
/// without depending on an icon font.
class _Ellipsis extends StatelessWidget {
  const _Ellipsis();

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    final dot = size * .16;
    return Semantics(
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: theme.color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Slot { body, leading, actions, tabBar }

/// Body constraints that also carry the chrome's coverage, the technique
/// Flutter's own Scaffold uses to hand layout-time sizes to its body.
class _BodyConstraints extends BoxConstraints {
  _BodyConstraints(super.size, this.covered) : super.tight();
  final EdgeInsets covered;

  @override
  bool operator ==(Object other) =>
      other is _BodyConstraints && covered == other.covered && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, covered);
}

class _InsetBody extends StatelessWidget {
  const _InsetBody({required this.media, required this.child});
  final MediaQueryData media;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final covered = constraints is _BodyConstraints
          ? constraints.covered
          : EdgeInsets.zero;
      return MediaQuery(
        data: media.copyWith(
          padding: EdgeInsets.fromLTRB(
            math.max(media.padding.left, covered.left),
            math.max(media.padding.top, covered.top),
            math.max(media.padding.right, covered.right),
            math.max(media.padding.bottom, covered.bottom),
          ),
        ),
        child: child,
      );
    },
  );
}

class _ChromeLayout extends MultiChildLayoutDelegate {
  _ChromeLayout({
    required this.placement,
    required this.viewPadding,
    required this.keyboard,
    required this.textDirection,
    required this.iOS,
    required this.topBar,
    required this.actionsTop,
  });

  final GlassChromePlacement placement;
  final EdgeInsets viewPadding;
  final double keyboard, actionsTop;
  final TextDirection textDirection;
  final bool iOS, topBar;

  /// Where rail actions start: below the system UI that UIKit reports in the
  /// rail (the status bar), else below the top safe area, else the measured
  /// Duo offsets for systems without reserved regions.
  static double railActionsTop(
    Size size,
    EdgeInsets viewPadding,
    GlassChromePlacement placement,
    List<Rect> occlusions,
  ) {
    final right = placement == GlassChromePlacement.rightRail;
    final column = right
        ? Rect.fromLTRB(
            size.width - viewPadding.right,
            0,
            size.width,
            size.height,
          )
        : Rect.fromLTRB(0, 0, viewPadding.left, size.height);
    final inRail = [
      for (final region in occlusions)
        if (region.overlaps(column) && region.center.dy < size.height / 2)
          region.bottom,
    ];
    if (inRail.isNotEmpty) return inRail.reduce(math.max);
    if (viewPadding.top > 0) return math.max(viewPadding.top, _minimumTop);
    return size.width > size.height
        ? _railActionsTopLandscape
        : _railActionsTopPortrait;
  }

  // Measured on iOS 27 simulators; see doc/native_adaptive_layout.md.
  static const _edge = 16.0;
  static const _minimumTop = 24.0;
  static const _bottomBarGap = 21.0;
  static const _railGap = 12.0;
  static const _railEdge = 24.0;
  // Without reserved regions: measured at y 170 in the folded (portrait)
  // window and y 120 in the unfolded (landscape) one, where the status bar's
  // occlusion region ends.
  static const _railActionsTopPortrait = 170.0;
  static const _railActionsTopLandscape = 120.0;

  @override
  void performLayout(Size size) {
    final rail = placement.isRail;
    final right = placement == GlassChromePlacement.rightRail;
    // The top bar starts at the status bar's bottom; with the status bar in
    // the rail it keeps a 24 pt margin.
    final top = math.max(viewPadding.top, _minimumTop);
    final rtl = textDirection == TextDirection.rtl;
    final contentLeft = viewPadding.left;
    final contentRight = size.width - viewPadding.right;
    var covered = EdgeInsets.only(
      top: topBar ? top + LiquidPrismScaffold.topBarHeight : top,
    );

    if (hasChild(_Slot.leading)) {
      final leading = layoutChild(_Slot.leading, BoxConstraints.loose(size));
      final x = rtl
          ? contentRight - _edge - leading.width
          : contentLeft + _edge;
      positionChild(
        _Slot.leading,
        Offset(
          x,
          top + (LiquidPrismScaffold.topBarHeight - leading.height) / 2,
        ),
      );
    }

    // Rail column: 48 pt wide, 12 pt outside the content edge.
    double railX(double width) => right
        ? contentRight + _railGap + (48 - width) / 2
        : contentLeft - _railGap - 48 + (48 - width) / 2;

    if (hasChild(_Slot.actions)) {
      final actions = layoutChild(_Slot.actions, BoxConstraints.loose(size));
      if (rail) {
        positionChild(_Slot.actions, Offset(railX(actions.width), actionsTop));
      } else {
        final x = rtl
            ? contentLeft + _edge
            : contentRight - _edge - actions.width;
        positionChild(
          _Slot.actions,
          Offset(
            x,
            top + (LiquidPrismScaffold.topBarHeight - actions.height) / 2,
          ),
        );
      }
    }

    if (hasChild(_Slot.tabBar)) {
      if (rail) {
        final bar = layoutChild(
          _Slot.tabBar,
          BoxConstraints.loose(
            Size(size.width, math.max(0, size.height - top - _railEdge)),
          ),
        );
        positionChild(
          _Slot.tabBar,
          Offset(railX(bar.width), size.height - _railEdge - bar.height),
        );
      } else {
        // Native floating housing sits 21 pt from the screen edge on iOS
        // (doc/native_tab_bar_spec.md), within the gesture inset.
        final gap = iOS ? _bottomBarGap : viewPadding.bottom + 10;
        final width = math.max(0.0, contentRight - contentLeft - 2 * 24);
        final bar = layoutChild(
          _Slot.tabBar,
          BoxConstraints.loose(Size(math.min(width, 440), size.height)),
        );
        positionChild(
          _Slot.tabBar,
          Offset(
            contentLeft + (contentRight - contentLeft - bar.width) / 2,
            size.height - gap - bar.height,
          ),
        );
        // Measured: content clears the bar by 3 pt (safe area 86 for a 62 pt bar).
        covered = covered.copyWith(bottom: gap + bar.height + 3);
      }
    }

    covered = covered.copyWith(
      bottom: math.max(covered.bottom, keyboard),
      left: viewPadding.left,
      right: viewPadding.right,
    );
    layoutChild(_Slot.body, _BodyConstraints(size, covered));
    positionChild(_Slot.body, Offset.zero);
  }

  @override
  bool shouldRelayout(_ChromeLayout old) =>
      placement != old.placement ||
      viewPadding != old.viewPadding ||
      keyboard != old.keyboard ||
      textDirection != old.textDirection ||
      iOS != old.iOS ||
      topBar != old.topBar ||
      actionsTop != old.actionsTop;
}
