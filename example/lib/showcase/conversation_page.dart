import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// A conversation with a [LiquidPrismTitle]. A one-to-one chat shows a header
/// avatar above a tappable glass name with a call action; tapping the name
/// switches to a group chat with an inline avatar in the capsule beside a
/// glass Invite text button. On iPhone Duo the icon actions move to the rail
/// while Invite stays in the top bar.
class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  var _direct = true;

  static const _directMessages = [
    (false, 'Are we still on for coffee on Saturday?'),
    (true, 'Yes! The café by the park at ten?'),
    (false, 'Perfect. I will bring the book I mentioned.'),
    (true, 'Great, I would love to hear what you thought of it.'),
    (false, 'See you then.'),
  ];

  static const _groupMessages = [
    (false, 'This month’s pick is in the shared folder.'),
    (true, 'Thanks! Three chapters in and enjoying it.'),
    (false, 'Should we ask Sam to join us next time?'),
    (true, 'Good idea, I will send an invite.'),
    (false, 'Same time next month, then.'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final dark = colors.brightness == Brightness.dark;
    final messages = _direct ? _directMessages : _groupMessages;
    return LiquidPrismScaffold(
      backgroundColor: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      title: LiquidPrismTitle(
        key: const ValueKey('conversation-title'),
        avatar: _direct ? _Avatar(color: colors.teal, initial: 'M') : null,
        leading: _direct
            ? null
            : _Avatar(color: colors.indigo, icon: CupertinoIcons.book_fill),
        onPressed: () => setState(() => _direct = !_direct),
        child: Text(_direct ? 'Maya' : 'Book Club'),
      ),
      trailing: _direct
          ? null
          : LiquidPrismButton(
              key: const ValueKey('conversation-invite'),
              label: 'Invite',
              onPressed: () {},
              child: const Text('Invite'),
            ),
      actions: [
        _direct
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Tap the name to switch the title layout',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.separated(
            itemCount: messages.length * 3,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final (mine, text) = messages[index % messages.length];
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: mine ? colors.blue : colors.tertiarySystemFill,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
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

/// A round avatar filling its square, with an initial or an icon.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, this.initial, this.icon});
  final Color color;
  final String? initial;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      const white = Color(0xFFFFFFFF);
      return DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: initial != null
                ? Text(
                    initial!,
                    style: TextStyle(
                      fontSize: size * .45,
                      fontWeight: FontWeight.w600,
                      color: white,
                    ),
                  )
                : Icon(icon, size: size * .55, color: white),
          ),
        ),
      );
    },
  );
}
