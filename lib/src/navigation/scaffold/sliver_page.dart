part of 'prism_scaffold.dart';

class _BodyConstraints extends BoxConstraints {
  _BodyConstraints(super.size, this.covered, this.scrollTop) : super.tight();
  final EdgeInsets covered;
  final double scrollTop;

  @override
  bool operator ==(Object other) =>
      other is _BodyConstraints &&
      covered == other.covered &&
      scrollTop == other.scrollTop &&
      super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, covered, scrollTop);
}

class _InsetBody extends StatelessWidget {
  const _InsetBody({
    required this.media,
    required this.child,
    required this.consumeKeyboard,
    required this.ownsScrollView,
  });
  final bool consumeKeyboard, ownsScrollView;
  final MediaQueryData media;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final covered = constraints is _BodyConstraints
          ? constraints.covered
          : EdgeInsets.zero;
      final scrollTop = constraints is _BodyConstraints
          ? math.max(media.padding.top, constraints.scrollTop)
          : media.padding.top;
      return MediaQuery(
        data: media.copyWith(
          viewInsets: consumeKeyboard
              ? media.viewInsets.copyWith(bottom: 0)
              : media.viewInsets,
          padding: EdgeInsets.fromLTRB(
            math.max(media.padding.left, covered.left),
            ownsScrollView
                ? math.max(media.padding.top, covered.top)
                : scrollTop,
            math.max(media.padding.right, covered.right),
            math.max(media.padding.bottom, covered.bottom),
          ),
        ),
        child: ownsScrollView
            ? _ScaffoldScrollInset(extent: scrollTop, child: child)
            : child,
      );
    },
  );
}

class _ScaffoldScrollInset extends InheritedWidget {
  const _ScaffoldScrollInset({required this.extent, required super.child});
  final double extent;

  static double of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ScaffoldScrollInset>()!
      .extent;

  @override
  bool updateShouldNotify(_ScaffoldScrollInset old) => extent != old.extent;
}

class _SliverPage extends StatefulWidget {
  const _SliverPage({
    required this.slivers,
    required this.header,
    required this.controller,
    required this.onHeaderExtent,
  });
  final List<Widget> slivers;
  final Widget? header;
  final ScrollController? controller;
  final ValueChanged<double> onHeaderExtent;

  @override
  State<_SliverPage> createState() => _SliverPageState();
}

class _SliverPageState extends State<_SliverPage> {
  PrismTabReselection? _reselection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reselection = PrismTabReselection.maybeOf(context);
    if (reselection != _reselection) {
      _reselection?.removeListener(_toTop);
      _reselection = reselection?..addListener(_toTop);
    }
  }

  @override
  void dispose() {
    _reselection?.removeListener(_toTop);
    super.dispose();
  }

  void _toTop() {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final controller =
        widget.controller ?? PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(0);
    } else {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final header = widget.header;
    return CustomScrollView(
      controller: widget.controller,
      primary: widget.controller == null ? true : null,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _TopInset(padding.top, _ScaffoldScrollInset.of(context)),
        ),
        SliverPadding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (header != null)
                SliverToBoxAdapter(
                  child: _SizeReporter(
                    onHeight: widget.onHeaderExtent,
                    child: header,
                  ),
                ),
              ...widget.slivers,
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: padding.bottom)),
      ],
    );
  }
}

class _TopInset extends SliverPersistentHeaderDelegate {
  _TopInset(this.minExtent, this.maxExtent);
  @override
  final double minExtent, maxExtent;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      const SizedBox.expand();
  @override
  bool shouldRebuild(_TopInset old) =>
      old.minExtent != minExtent || old.maxExtent != maxExtent;
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reported;
  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
