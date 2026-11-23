part of 'prism_scaffold.dart';

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.leading,
    required this.center,
    required this.trailing,
  });

  final List<PrismToolbarContent> leading, center, trailing;

  static const double sideMargin = 24;

  @override
  Widget build(BuildContext context) {
    Widget edge(List<PrismToolbarContent> content, AlignmentDirectional at) =>
        Align(
          alignment: at,
          heightFactor: 1,
          child: PrismToolbar(content: content),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: sideMargin),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (center.isNotEmpty) PrismToolbar(content: center),
          if (leading.isNotEmpty)
            edge(leading, AlignmentDirectional.centerStart),
          if (trailing.isNotEmpty)
            edge(trailing, AlignmentDirectional.centerEnd),
        ],
      ),
    );
  }
}

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

class _ChromeLayout extends MultiChildLayoutDelegate {
  _ChromeLayout({
    required this.placement,
    required this.minimization,
    required this.onMinimizationExtent,
    required this.refreshBoundary,
    required this.bottomBarExtent,
    required this.adjustsMinimizationInsets,
    required this.slidesOff,
    required this.tabDock,
    required this.style,
    required this.viewPadding,
    required this.keyboard,
    required this.textDirection,
    required this.iOS,
    required this.topBar,
    required this.accessoryHeight,
    required this.titleRowHeight,
    required this.controlRowHeight,
    required this.contentSpacing,
    required this.titleAlignment,
    required this.contentPadding,
    required this.expandedHeight,
    required this.expandedLead,
    required this.largeTitleTop,
    required this.collapseExtent,
    required this.scrollOffset,
    required this.titleGutter,
    required this.titleGap,
    required this.actionsTop,
    required this.railBottom,
    required this.sheet,
    required this.fullEdge,
    required this.compactEdgeHeight,
    required this.compactWhenHidden,
    required this.revealed,
    required this.edgeFrame,
    required this.edgeInset,
    required this.corner,
    required this.sidebar,
    required this.reveal,
  }) : super(
         relayout: Listenable.merge([
           reveal,
           scrollOffset,
           minimization,
           revealed,
         ]),
       );

  final PrismChromePlacement placement;
  final EdgeInsets viewPadding;
  final PrismTabBarPlacement? tabDock;
  final Animation<double> minimization;
  final ValueChanged<double> onMinimizationExtent;
  final ValueNotifier<Rect> refreshBoundary;

  final ValueNotifier<double> bottomBarExtent;
  final bool adjustsMinimizationInsets;

  final bool slidesOff;
  final PrismScaffoldStyle style;
  final double keyboard, actionsTop, railBottom;
  final bool sheet;

  final double edgeFrame;

  final double edgeInset;

  final bool fullEdge;

  final double compactEdgeHeight;

  final bool compactWhenHidden;

  final ValueListenable<bool> revealed;

  final double accessoryHeight;

  final double contentSpacing;
  final PrismTitleAlignment titleAlignment;
  final EdgeInsets contentPadding;
  final double titleRowHeight,
      controlRowHeight,
      expandedHeight,
      expandedLead,
      collapseExtent,
      titleGutter,
      largeTitleTop,
      titleGap;
  final ValueListenable<double> scrollOffset;

  final Rect? corner;
  final TextDirection textDirection;
  final bool iOS, topBar;

  final AxisDirection? sidebar;

  final Animation<double> reveal;

  static EdgeInsets withRail(
    EdgeInsets viewPadding,
    PrismChromePlacement placement,
  ) => switch (placement) {
    PrismChromePlacement.leftRail => viewPadding.copyWith(
      left: math.max(viewPadding.left, _railStrip),
    ),
    PrismChromePlacement.rightRail => viewPadding.copyWith(
      right: math.max(viewPadding.right, _railStrip),
    ),
    PrismChromePlacement.bottom => viewPadding,
  };

  static double railBottomOf(
    Size size,
    EdgeInsets viewPadding,
    PrismChromePlacement placement,
    List<Rect> occlusions,
  ) {
    final column = _railColumn(size, viewPadding, placement);
    final below = [
      for (final region in occlusions)
        if (region.overlaps(column) && region.center.dy >= size.height / 2)
          region.top,
    ];
    return below.isEmpty ? size.height - _railEdge : below.reduce(math.min);
  }

  static Rect _railColumn(
    Size size,
    EdgeInsets viewPadding,
    PrismChromePlacement placement,
  ) => placement == PrismChromePlacement.rightRail
      ? Rect.fromLTRB(
          size.width - viewPadding.right,
          0,
          size.width,
          size.height,
        )
      : Rect.fromLTRB(0, 0, viewPadding.left, size.height);

  static double railActionsTop(
    Size size,
    EdgeInsets viewPadding,
    PrismChromePlacement placement,
    List<Rect> occlusions, {
    bool reported = false,
  }) {
    final column = _railColumn(size, viewPadding, placement);
    final inRail = [
      for (final region in occlusions)
        if (region.overlaps(column) && region.center.dy < size.height / 2)
          region.bottom,
    ];
    if (inRail.isNotEmpty) return inRail.reduce(math.max);
    if (reported || viewPadding.top > 0) {
      return math.max(viewPadding.top, _minimumTop);
    }
    return size.width > size.height
        ? _railActionsTopLandscape
        : _railActionsTopPortrait;
  }

  static const _edge = 16.0;

  static const _trailingGap = 8.0;
  static const _minimumTop = 24.0;
  static const _sheetTop = 16.0;
  static const _bottomBarGap = 21.0;
  static const _railGap = 12.0;
  static const _railEdge = 24.0;
  static const _railStrip = _railGap + 48 + _railEdge;
  static const _railActionsTopPortrait = 170.0;
  static const _railActionsTopLandscape = 120.0;

  @override
  void performLayout(Size size) {
    final rail = placement.isRail;
    final right = placement == PrismChromePlacement.rightRail;
    var top =
        (sheet
            ? _sheetTop
            : corner == null
            ? math.max(viewPadding.top, _minimumTop)
            : _minimumTop) +
        contentPadding.top;
    final naturalTop = top;
    final rtl = textDirection == TextDirection.rtl;
    final railLeft = viewPadding.left;
    final railRight = size.width - viewPadding.right;
    final sidebarWidth = NativeSidebar.width;
    final shown = sidebar == null ? 0.0 : reveal.value.clamp(0.0, 1.0);
    var contentLeft = sidebar == AxisDirection.left
        ? railLeft + (math.max(railLeft, sidebarWidth) - railLeft) * shown
        : railLeft;
    var contentRight = sidebar == AxisDirection.right
        ? railRight -
              (railRight - math.min(railRight, size.width - sidebarWidth)) *
                  shown
        : railRight;
    final barRow = topBar ? titleRowHeight + contentPadding.bottom : 0.0;
    final lead = expandedHeight > 0 ? expandedLead : 0.0;
    final expanded = expandedHeight + lead;
    final collapse = collapseExtent == 0
        ? (scrollOffset.value > 0 ? 1.0 : 0.0)
        : (scrollOffset.value / (collapseExtent + lead)).clamp(0.0, 1.0);
    final largeHeight = expanded * (1 - collapse);

    var covered = EdgeInsets.only(
      top: topBar || accessoryHeight > 0
          ? top +
                barRow +
                expanded +
                accessoryHeight +
                (expandedHeight > 0 && accessoryHeight == 0
                    ? 0
                    : contentSpacing)
          : top,
    );
    var topDockHeight = 0.0;
    var refreshHeaderBottom = naturalTop;
    final dockMargin = style.tabBarMargin?.resolve(textDirection);
    final dockAlignment = (style.tabBarAlignment ?? Alignment.center).resolve(
      textDirection,
    );
    final sideDock =
        tabDock == PrismTabBarPlacement.leading ||
        tabDock == PrismTabBarPlacement.trailing;
    if (hasChild(_Slot.tabBar) &&
        (sideDock || tabDock == PrismTabBarPlacement.top)) {
      final margin = dockMargin ?? const EdgeInsets.all(12);
      final dockTop = top + barRow + largeHeight + accessoryHeight;
      final availableHeight = math.max(
        0.0,
        size.height -
            math.max(keyboard, viewPadding.bottom) -
            dockTop -
            margin.vertical,
      );
      final availableWidth = math.max(
        0.0,
        contentRight - contentLeft - margin.horizontal,
      );
      final bar = layoutChild(
        _Slot.tabBar,
        BoxConstraints.loose(
          Size(
            math.min(availableWidth, style.tabBarMaxWidth ?? 440),
            availableHeight,
          ),
        ),
      );
      if (sideDock) {
        final left = (tabDock == PrismTabBarPlacement.leading) != rtl;
        final x = left
            ? contentLeft + margin.left
            : contentRight - margin.right - bar.width;
        final y =
            dockTop +
            margin.top +
            (availableHeight - bar.height) * (dockAlignment.y + 1) / 2;
        positionChild(_Slot.tabBar, Offset(x, y));
        if (left) {
          contentLeft += bar.width + margin.horizontal;
        } else {
          contentRight -= bar.width + margin.horizontal;
        }
      } else {
        positionChild(
          _Slot.tabBar,
          Offset(
            contentLeft +
                margin.left +
                (availableWidth - bar.width) * (dockAlignment.x + 1) / 2,
            dockTop +
                margin.top -
                (barRow +
                        (accessoryHeight == 0 ? contentSpacing : 0) +
                        bar.height +
                        margin.vertical +
                        (slidesOff ? naturalTop : 0)) *
                    minimization.value,
          ),
        );
        refreshHeaderBottom = dockTop + margin.top + bar.height;
        topDockHeight = bar.height + margin.vertical;
        covered = covered.copyWith(top: covered.top + topDockHeight);
      }
    }

    final minimizedExtent =
        barRow + (accessoryHeight == 0 ? contentSpacing : 0) + topDockHeight;
    final travel = minimizedExtent + (slidesOff ? naturalTop : 0);
    onMinimizationExtent(travel);
    final moved = travel * minimization.value;
    top -= moved;

    final scrollTop = covered.top;
    if (adjustsMinimizationInsets) {
      covered = covered.copyWith(
        top: math.max(
          naturalTop,
          covered.top - math.min(moved, minimizedExtent),
        ),
      );
    }
    final barLeft =
        contentPadding.left +
        (corner != null && corner!.left <= 1
            ? math.max(contentLeft, corner!.right)
            : contentLeft);
    final barRight =
        (corner != null && corner!.left > 1
            ? math.min(contentRight, corner!.left)
            : contentRight) -
        contentPadding.right;

    if (hasChild(_Slot.scrollEdge)) {
      final barBottom = top + barRow + largeHeight;
      final full = math.max(
        0.0,
        (accessoryHeight > 0 ? math.max(naturalTop, barBottom) : barBottom) +
            accessoryHeight +
            topDockHeight +
            edgeFrame -
            edgeInset -
            (accessoryHeight == 0 ? math.min(lead, largeHeight) : 0),
      );

      final double height = !fullEdge
          ? compactEdgeHeight
          : !compactWhenHidden
          ? full
          : revealed.value
          ? math.max(
              compactEdgeHeight,
              compactEdgeHeight +
                  (full - compactEdgeHeight) * (1 - minimization.value),
            )
          : compactEdgeHeight;
      layoutChild(
        _Slot.scrollEdge,
        BoxConstraints.tight(
          Size(math.max(0, contentRight - contentLeft), math.max(0, height)),
        ),
      );
      positionChild(_Slot.scrollEdge, Offset(contentLeft, 0));
    }
    if (hasChild(_Slot.accessory)) {
      refreshHeaderBottom = math.max(
        refreshHeaderBottom,
        math.max(naturalTop, top + barRow + largeHeight) + accessoryHeight,
      );
      layoutChild(
        _Slot.accessory,
        BoxConstraints.tightFor(
          width: math.max(0, contentRight - contentLeft),
          height: accessoryHeight,
        ),
      );
      positionChild(
        _Slot.accessory,
        Offset(contentLeft, math.max(naturalTop, top + barRow + largeHeight)),
      );
    }

    if (hasChild(_Slot.sidebar)) {
      layoutChild(
        _Slot.sidebar,
        BoxConstraints.tight(Size(sidebarWidth, size.height)),
      );
      final hidden = sidebarWidth * (1 - shown);
      positionChild(
        _Slot.sidebar,
        Offset(
          sidebar == AxisDirection.right
              ? size.width - sidebarWidth + hidden
              : -hidden,
          0,
        ),
      );
    }

    final controlRow = topBar ? controlRowHeight : 0.0;
    double centred(Size child) => top + (controlRow - child.height) / 2;
    var leadingOffset = _edge;
    var leadingEnd = barLeft;
    var actionsInBar = false;
    var trailingStart = barRight;
    if (hasChild(_Slot.sidebarToggle)) {
      final toggle = layoutChild(
        _Slot.sidebarToggle,
        BoxConstraints.loose(size),
      );
      const inset = NativeSidebar.toggleInset;
      positionChild(
        _Slot.sidebarToggle,
        Offset(rtl ? railRight - inset - toggle.width : railLeft + inset, top),
      );
      if (!toggle.isEmpty) leadingOffset = inset + toggle.width + 8;
      if (!toggle.isEmpty) {
        if (rtl) {
          trailingStart = barRight - leadingOffset;
        } else {
          leadingEnd = barLeft + leadingOffset;
        }
      }
    }
    double railX(double width) => right
        ? railRight + _railGap + (48 - width) / 2
        : railLeft - _railGap - 48 + (48 - width) / 2;

    var railTop = actionsTop;
    if (rail && hasChild(_Slot.leading)) {
      final child = layoutChild(
        _Slot.leading,
        BoxConstraints.loose(Size(48, size.height)),
      );
      positionChild(_Slot.leading, Offset(railX(child.width), railTop));
      if (!child.isEmpty) railTop += child.height + _railGap;
    }

    if (hasChild(_Slot.actions)) {
      final actions = layoutChild(_Slot.actions, BoxConstraints.loose(size));
      if (rail) {
        positionChild(_Slot.actions, Offset(railX(actions.width), railTop));
      } else {
        final x = rtl
            ? barLeft + (corner != null && barLeft > contentLeft ? 0 : _edge)
            : barRight -
                  (corner != null && barRight < contentRight ? 0 : _edge) -
                  actions.width;
        if (rtl) {
          leadingEnd = x + actions.width;
        } else {
          trailingStart = x;
        }
        refreshHeaderBottom = math.max(
          refreshHeaderBottom,
          top + math.max(0, (controlRow - actions.height) / 2) + actions.height,
        );
        actionsInBar = true;
        positionChild(
          _Slot.actions,
          Offset(x, top + math.max(0, (controlRow - actions.height) / 2)),
        );
      }
    }

    if (hasChild(_Slot.barActions)) {
      final child = layoutChild(_Slot.barActions, BoxConstraints.loose(size));
      final edge = rail && right != rtl ? 0.0 : _edge;
      final x = rtl
          ? (actionsInBar ? leadingEnd + _trailingGap : barLeft + edge)
          : (actionsInBar ? trailingStart - _trailingGap : barRight - edge) -
                child.width;
      if (rtl) {
        leadingEnd = x + child.width;
      } else {
        trailingStart = x;
      }
      actionsInBar = true;
      refreshHeaderBottom = math.max(
        refreshHeaderBottom,
        centred(child) + child.height,
      );
      positionChild(_Slot.barActions, Offset(x, centred(child)));
    }

    if (hasChild(_Slot.trailing)) {
      final child = layoutChild(_Slot.trailing, BoxConstraints.loose(size));
      final edge = rail && right != rtl ? 0.0 : _edge;
      final x = rtl
          ? (actionsInBar ? leadingEnd + _trailingGap : barLeft + edge)
          : (actionsInBar ? trailingStart - _trailingGap : barRight - edge) -
                child.width;
      if (rtl) {
        leadingEnd = x + child.width;
      } else {
        trailingStart = x;
      }
      actionsInBar = true;
      refreshHeaderBottom = math.max(
        refreshHeaderBottom,
        centred(child) + child.height,
      );
      positionChild(_Slot.trailing, Offset(x, centred(child)));
    }

    if (!rail && hasChild(_Slot.leading)) {
      final room = rtl
          ? barRight -
                leadingOffset -
                (actionsInBar ? leadingEnd + titleGap : barLeft + _edge)
          : (actionsInBar ? trailingStart - titleGap : barRight - _edge) -
                barLeft -
                leadingOffset;
      final child = layoutChild(
        _Slot.leading,
        BoxConstraints.loose(Size(math.max(0, room), size.height)),
      );
      if (rtl) {
        trailingStart = barRight - leadingOffset - child.width;
      } else {
        leadingEnd = barLeft + leadingOffset + child.width;
      }
      refreshHeaderBottom = math.max(
        refreshHeaderBottom,
        centred(child) + child.height,
      );
      positionChild(
        _Slot.leading,
        Offset(
          rtl
              ? barRight - leadingOffset - child.width
              : barLeft + leadingOffset,
          centred(child),
        ),
      );
    }

    if (hasChild(_Slot.barLeading)) {
      final offset = rail && right == rtl ? 0.0 : leadingOffset;
      final room = rtl
          ? barRight -
                offset -
                (actionsInBar ? leadingEnd + titleGap : barLeft + _edge)
          : (actionsInBar ? trailingStart - titleGap : barRight - _edge) -
                barLeft -
                offset;
      final child = layoutChild(
        _Slot.barLeading,
        BoxConstraints.loose(Size(math.max(0, room), size.height)),
      );
      if (rtl) {
        trailingStart = barRight - offset - child.width;
      } else {
        leadingEnd = barLeft + offset + child.width;
      }
      refreshHeaderBottom = math.max(
        refreshHeaderBottom,
        centred(child) + child.height,
      );
      positionChild(
        _Slot.barLeading,
        Offset(
          rtl ? barRight - offset - child.width : barLeft + offset,
          centred(child),
        ),
      );
    }

    if (hasChild(_Slot.title)) {
      final centre =
          (contentLeft +
              contentPadding.left +
              contentRight -
              contentPadding.right) /
          2;
      final left = math.max(
        barLeft + titleGutter,
        leadingEnd + (leadingEnd > barLeft ? titleGap : 0),
      );
      final right = math.min(
        barRight - titleGutter,
        trailingStart - (trailingStart < barRight ? titleGap : 0),
      );
      final centeredWidth = math.max(
        0.0,
        2.0 * math.min(centre - left, right - centre),
      );
      final availableWidth = math.max(0.0, right - left);

      final title = layoutChild(
        _Slot.title,
        BoxConstraints.loose(
          Size(
            titleAlignment == PrismTitleAlignment.center && centeredWidth >= 44
                ? centeredWidth
                : availableWidth,
            barRow,
          ),
        ),
      );
      final alignment = prismResolvedTitleAlignment(
        titleAlignment,
        title.width,
        centeredWidth,
      );
      final x = alignment == PrismTitleAlignment.center
          ? (centre - title.width / 2)
                .clamp(left, math.max(left, right - title.width))
                .toDouble()
          : (alignment == PrismTitleAlignment.trailing) != rtl
          ? right - title.width
          : left;
      refreshHeaderBottom = math.max(
        refreshHeaderBottom,
        top + (barRow + title.height) / 2,
      );
      positionChild(_Slot.title, Offset(x, top + (barRow - title.height) / 2));
    }
    if (hasChild(_Slot.largeTitle)) {
      layoutChild(
        _Slot.largeTitle,
        BoxConstraints.tightFor(
          width: math.max(0, barRight - barLeft - 2 * titleGutter),
        ),
      );
      positionChild(
        _Slot.largeTitle,
        Offset(
          barLeft + titleGutter,
          top +
              barRow +
              lead +
              largeTitleTop -
              math.min(scrollOffset.value, expandedHeight + lead),
        ),
      );
    }

    var railFloor = railBottom;
    if (hasChild(_Slot.tabBar) &&
        !sideDock &&
        tabDock != PrismTabBarPlacement.top) {
      if (rail && tabDock == null) {
        final bar = layoutChild(
          _Slot.tabBar,
          BoxConstraints.loose(
            Size(size.width, math.max(0, railBottom - naturalTop)),
          ),
        );
        positionChild(
          _Slot.tabBar,
          Offset(railX(bar.width), railBottom - bar.height),
        );
        if (!bar.isEmpty) railFloor = railBottom - bar.height - _railGap;
      } else {
        final margin =
            dockMargin ??
            EdgeInsets.fromLTRB(
              24,
              0,
              24,
              iOS ? _bottomBarGap : viewPadding.bottom + 10,
            );
        final width = math.max(
          0.0,
          contentRight - contentLeft - margin.horizontal,
        );
        final bar = layoutChild(
          _Slot.tabBar,
          BoxConstraints.loose(
            Size(
              math.min(width, style.tabBarMaxWidth ?? 440),
              math.max(0.0, size.height - covered.top - margin.vertical),
            ),
          ),
        );
        positionChild(
          _Slot.tabBar,
          Offset(
            contentLeft +
                margin.left +
                (width - bar.width) * (dockAlignment.x + 1) / 2,
            size.height - margin.bottom - bar.height,
          ),
        );
        covered = covered.copyWith(bottom: margin.vertical + bar.height + 3);
      }
    }

    if (hasChild(_Slot.railBottom)) {
      final group = layoutChild(
        _Slot.railBottom,
        BoxConstraints.loose(Size(48, math.max(0, railFloor - railTop))),
      );
      positionChild(
        _Slot.railBottom,
        Offset(railX(group.width), railFloor - group.height),
      );
    }

    if (hasChild(_Slot.bottomBar)) {
      final margin = style.bottomBarMargin?.resolve(textDirection);
      final floor = keyboard > 0
          ? keyboard + (margin?.bottom ?? 0)
          : covered.bottom > 0
          ? covered.bottom + (margin?.bottom ?? 8)
          : margin?.bottom ?? (iOS ? _bottomBarGap : viewPadding.bottom);
      final width = math.max(
        0.0,
        contentRight - contentLeft - (margin?.horizontal ?? 0),
      );
      final bar = layoutChild(
        _Slot.bottomBar,
        BoxConstraints.loose(
          Size(
            math.min(width, style.bottomBarMaxWidth ?? double.infinity),
            math.max(
              0.0,
              size.height - floor - covered.top - (margin?.top ?? 0),
            ),
          ),
        ),
      );
      bottomBarExtent.value = bar.height;
      final barTop = size.height - floor - bar.height;
      final alignment = (style.bottomBarAlignment ?? Alignment.center).resolve(
        textDirection,
      );
      positionChild(
        _Slot.bottomBar,
        Offset(
          contentLeft +
              (margin?.left ?? 0) +
              (width - bar.width) * (alignment.x + 1) / 2,
          barTop,
        ),
      );
      covered = covered.copyWith(
        bottom: size.height - barTop + (margin?.top ?? 0),
      );
      if (hasChild(_Slot.bottomScrollEdge)) {
        layoutChild(
          _Slot.bottomScrollEdge,
          BoxConstraints.tight(
            Size(math.max(0, contentRight - contentLeft), size.height - barTop),
          ),
        );
        positionChild(_Slot.bottomScrollEdge, Offset(contentLeft, barTop));
      }
    } else {
      bottomBarExtent.value = 0;
    }
    covered = covered.copyWith(
      bottom: math.max(covered.bottom, keyboard),
      left: contentLeft,
      right: size.width - contentRight,
    );
    refreshBoundary.value = Rect.fromLTRB(
      contentLeft,
      math.min(refreshHeaderBottom, covered.top),
      contentRight,
      covered.top,
    );
    layoutChild(_Slot.body, _BodyConstraints(size, covered, scrollTop));
    positionChild(_Slot.body, Offset.zero);
  }

  @override
  bool shouldRelayout(_ChromeLayout old) =>
      placement != old.placement ||
      fullEdge != old.fullEdge ||
      compactEdgeHeight != old.compactEdgeHeight ||
      compactWhenHidden != old.compactWhenHidden ||
      revealed != old.revealed ||
      minimization != old.minimization ||
      adjustsMinimizationInsets != old.adjustsMinimizationInsets ||
      slidesOff != old.slidesOff ||
      onMinimizationExtent != old.onMinimizationExtent ||
      tabDock != old.tabDock ||
      style != old.style ||
      viewPadding != old.viewPadding ||
      keyboard != old.keyboard ||
      textDirection != old.textDirection ||
      iOS != old.iOS ||
      topBar != old.topBar ||
      accessoryHeight != old.accessoryHeight ||
      titleRowHeight != old.titleRowHeight ||
      controlRowHeight != old.controlRowHeight ||
      contentSpacing != old.contentSpacing ||
      titleAlignment != old.titleAlignment ||
      contentPadding != old.contentPadding ||
      expandedHeight != old.expandedHeight ||
      expandedLead != old.expandedLead ||
      largeTitleTop != old.largeTitleTop ||
      collapseExtent != old.collapseExtent ||
      titleGutter != old.titleGutter ||
      titleGap != old.titleGap ||
      actionsTop != old.actionsTop ||
      railBottom != old.railBottom ||
      sheet != old.sheet ||
      edgeFrame != old.edgeFrame ||
      edgeInset != old.edgeInset ||
      corner != old.corner ||
      sidebar != old.sidebar ||
      reveal != old.reveal;
}
