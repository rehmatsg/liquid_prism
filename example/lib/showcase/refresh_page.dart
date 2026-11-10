import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'widgets.dart';

const _subjects = [
  ('Maya Chen', 'Coffee on Saturday?', 'The café by the park at ten works.'),
  ('Design Weekly', 'Glass that moves', 'Five details that make it feel real.'),
  ('Jonas Weber', 'Build 412 is ready', 'TestFlight has the new scaffold.'),
  ('Priya Nair', 'Trip photos', 'I put the album where you can find it.'),
  ('App Store', 'Your receipt', 'Thanks for your purchase this week.'),
  ('Sam Ortiz', 'Re: launch notes', 'Two small edits, then it is good to go.'),
  ('Calendar', 'Tomorrow at a glance', 'Three events and one reminder.'),
  ('Lena Fischer', 'Thank you!', 'The book arrived, and it is wonderful.'),
];

const _tints = [
  Color(0xFF30B0C7),
  Color(0xFF5856D6),
  Color(0xFFFF9500),
  Color(0xFF34C759),
  Color(0xFFFF2D55),
  Color(0xFF007AFF),
];

/// Where a pull's drop comes from on this device, for the pages' captions.
String _anchorLabel(Rect? island) => island == null
    ? 'This window has no Dynamic Island, so the drop comes out of its notch '
          'or top edge.'
    : 'The drop comes out of the Dynamic Island '
          '(${island.width.round()}×${island.height.round()} at '
          '${island.left.round()}, ${island.top.round()}).';

/// Pull to refresh on [LiquidPrismScaffold.slivers]: one callback. Each
/// refresh delivers new messages to the top of the inbox.
class RefreshFeedPage extends StatefulWidget {
  const RefreshFeedPage({super.key});

  @override
  State<RefreshFeedPage> createState() => _RefreshFeedPageState();
}

class _RefreshFeedPageState extends State<RefreshFeedPage> {
  /// Message ids, newest first.
  final _messages = [for (var i = 11; i >= 0; i--) i];
  var _unread = 0;
  var _slow = false;
  var _fail = false;
  final _controller = LiquidPrismRefreshController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Completes with false when the refresh fails, which skips the check.
  Future<bool> _refresh() async {
    await Future<void>.delayed(Duration(milliseconds: _slow ? 3500 : 1200));
    if (!mounted || _fail) return false;
    setState(() {
      final next = _messages.first + 1;
      _messages.insertAll(0, [next + 1, next]);
      _unread += 2;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return LiquidPrismScaffold(
      backgroundColor: colors.groupedBackground,
      title: const Text('Inbox'),
      largeTitle: const Text('Inbox'),
      refreshController: _controller,
      toolbar: [
        GlassToolbarItem(
          key: const ValueKey('refresh-now'),
          icon: const Icon(CupertinoIcons.arrow_clockwise),
          label: 'Refresh now',
          onPressed: _controller.refresh,
        ),
        GlassToolbarItem(
          key: const ValueKey('refresh-fail'),
          icon: Icon(_fail ? CupertinoIcons.wifi_slash : CupertinoIcons.wifi),
          label: _fail ? 'Let refreshes succeed' : 'Make refreshes fail',
          onPressed: () => setState(() => _fail = !_fail),
        ),
        GlassToolbarItem(
          key: const ValueKey('refresh-slow'),
          icon: Icon(
            _slow ? CupertinoIcons.tortoise_fill : CupertinoIcons.hare,
          ),
          label: _slow ? 'Use a fast refresh' : 'Use a slow refresh',
          onPressed: () => setState(() => _slow = !_slow),
        ),
      ],
      onRefresh: _refresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          sliver: SliverToBoxAdapter(
            child: ValueListenableBuilder<Rect?>(
              valueListenable: LiquidPrismSystemChrome.dynamicIsland,
              builder: (context, island, _) => Text(
                'Pull down to check for mail. ${_anchorLabel(island)} '
                '${_unread == 0 ? '' : '$_unread new since you arrived.'}',
                key: const ValueKey('refresh-caption'),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final id = _messages[index];
              final (sender, subject, preview) =
                  _subjects[id % _subjects.length];
              return _MessageRow(
                key: ValueKey('message-$id'),
                sender: sender,
                subject: subject,
                preview: preview,
                tint: _tints[id % _tints.length],
                unread: index < _unread,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.tint,
    required this.unread,
  });
  final String sender, subject, preview;
  final Color tint;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Text(
              sender.substring(0, 1),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sender,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subject, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: colors.secondaryLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pull to refresh on a [LiquidPrismScaffold.body]: the page owns its scroll
/// view, here a short dark grid that still pulls, and the scaffold follows it.
/// Dark content shows how the drop reads without a light page behind it.
class RefreshGalleryPage extends StatefulWidget {
  const RefreshGalleryPage({super.key});

  @override
  State<RefreshGalleryPage> createState() => _RefreshGalleryPageState();
}

class _RefreshGalleryPageState extends State<RefreshGalleryPage> {
  var _seed = 0;

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _seed++);
  }

  @override
  Widget build(BuildContext context) => LiquidPrismTheme(
    data: const LiquidPrismThemeData(brightness: Brightness.dark),
    child: Builder(
      builder: (context) => LiquidPrismScaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        title: const Text('Gallery'),
        onRefresh: _refresh,
        body: Builder(
          builder: (context) {
            final padding = MediaQuery.paddingOf(context);
            return GridView.builder(
              key: const ValueKey('refresh-gallery'),
              // Six tiles don't fill the window; this keeps them pullable.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                padding.left + 16,
                padding.top + 8,
                padding.right + 16,
                padding.bottom + 16,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                final hue = ((index + _seed) * 47 + _seed * 113) % 360;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        HSLColor.fromAHSL(1, hue.toDouble(), .7, .55).toColor(),
                        HSLColor.fromAHSL(
                          1,
                          (hue + 60) % 360,
                          .8,
                          .3,
                        ).toColor(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
