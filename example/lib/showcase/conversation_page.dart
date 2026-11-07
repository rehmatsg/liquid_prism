import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// A conversation with a [LiquidPrismTitle]: a header avatar above a tappable
/// glass name (as in a chat app), or, after tapping the name, an inline avatar
/// in the capsule beside a glass Invite text button. On iPhone Duo the icon
/// actions move to the rail while Invite stays in the top bar.
class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  var _header = true;

  static const _messages = [
    (true, 'Can you get the pull request updated and ready to merge?'),
    (
      false,
      'I will resolve the conflicts, run the checks and flag anything that needs your decision.',
    ),
    (true, 'GitHub seems to be blocking CI. Can you take a look?'),
    (false, 'Checking what is blocking it now.'),
    (true, 'Thanks. Tap the name above to see the other title style.'),
    (
      false,
      'The capsule can hold an avatar inside it, with a text button beside it.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final name = _header ? 'Friday' : 'Spacy';
    return LiquidPrismScaffold(
      title: LiquidPrismTitle(
        key: const ValueKey('conversation-title'),
        avatar: _header ? _Avatar(color: colors.orange) : null,
        leading: _header ? null : _Avatar(color: colors.orange, online: true),
        onPressed: () => setState(() => _header = !_header),
        child: Text(name),
      ),
      trailing: _header
          ? null
          : LiquidPrismButton(
              key: const ValueKey('conversation-invite'),
              label: 'Invite',
              onPressed: () {},
              child: const Text('Invite'),
            ),
      actions: [
        _header
            ? GlassToolbarItem(
                icon: const Icon(CupertinoIcons.phone),
                label: 'Call',
                onPressed: () {},
              )
            : GlassToolbarItem(
                icon: const Icon(CupertinoIcons.ellipsis),
                label: 'More',
                onPressed: () {},
              ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList.separated(
            itemCount: _messages.length * 3,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final (mine, text) = _messages[index % _messages.length];
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: mine
                          ? colors.orange.withValues(alpha: .85)
                          : colors.tertiarySystemFill,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 17,
                          color: mine ? const Color(0xFFFFFFFF) : colors.label,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A round avatar filling its square; [online] adds a presence dot.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, this.online = false});
  final Color color;
  final bool online;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: Icon(
                  CupertinoIcons.sparkles,
                  size: size * .5,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GlassColors.of(context).green,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
                ),
                child: SizedBox.square(dimension: size * .38),
              ),
            ),
        ],
      );
    },
  );
}
