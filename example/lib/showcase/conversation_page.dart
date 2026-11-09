import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// A conversation cycling through an above-avatar, inline-avatar and plain
/// glass title. Repeated taps retarget the transition without resetting the conversation.
class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  var _layout = 0;

  static const _directMessages = [
    (false, 'Are we still on for coffee on Saturday?'),
    (true, 'Yes! The café by the park at ten?'),
    (false, 'Perfect. I will bring the book I mentioned.'),
    (true, 'Great, I would love to hear what you thought of it.'),
    (false, 'See you then.'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final dark = colors.brightness == Brightness.dark;
    const messages = _directMessages;
    return LiquidPrismScaffold(
      backgroundColor: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      title: LiquidPrismTitle(
        key: const ValueKey('conversation-title'),
        avatar: _layout == 0 ? _Avatar(color: colors.teal, initial: 'M') : null,
        leading: _layout == 1
            ? _Avatar(color: colors.teal, initial: 'M')
            : null,
        onPressed: () => setState(() => _layout = (_layout + 1) % 3),
        child: const Text('Maya'),
      ),
      toolbar: [
        GlassToolbarItem(
          icon: const Icon(CupertinoIcons.phone),
          label: 'Call',
          onPressed: () {},
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Tap the name: avatar above → inline avatar → title only',
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

/// A round avatar filling its square.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.initial});
  final Color color;
  final String initial;

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
            child: Text(
              initial,
              style: TextStyle(
                fontSize: size * .45,
                fontWeight: FontWeight.w600,
                color: white,
              ),
            ),
          ),
        ),
      );
    },
  );
}
