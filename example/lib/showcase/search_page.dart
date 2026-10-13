import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'component_page.dart';
import 'model.dart';
import 'widgets.dart';

/// A page that only searches: the field stays fixed under the bar as the
/// scaffold's accessory while the results scroll beneath the edge effect.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.model});
  final ShowcaseModel model;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  static const _ideas = [
    ('Morning light', 'Warm glass over a sunrise wallpaper'),
    ('Night mode', 'Dark glass with a deeper rim'),
    ('A fresh start', 'Reset every control to its default'),
    ('Frosted panel', 'Heavy blur behind a toolbar'),
    ('Clear lens', 'Unfrosted glass that only refracts'),
    ('Tinted capsule', 'Accent colour through the glass'),
    ('Floating tabs', 'A compact bar over scrolling content'),
    ('Side rail', 'Tabs in a column on wide windows'),
    ('Soft edge', 'Content blurs and fades under the bar'),
    ('Hard edge', 'A flat backdrop with a hairline'),
    ('Held slider', 'The knob lifts and grows on touch'),
    ('Quiet switch', 'Toggles with no haptics'),
    ('Segment pill', 'Labels bend under the lifted lens'),
    ('Native menu', 'A UIKit menu from a glass button'),
    ('Badged inbox', 'Counts and dots on tabs and actions'),
    ('Large title', 'Scrolls away into the inline title'),
    ('Keyboard once', 'Padding that counts the keyboard once'),
    ('Reduce motion', 'Springs settle without travel'),
    ('Right to left', 'Every control mirrored'),
    ('Big text', 'Controls grow with the text size'),
  ];

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    bool matches(String title, String subtitle) =>
        '$title $subtitle'.toLowerCase().contains(query);
    final found = [
      for (final c in components)
        if (matches(c.title, c.subtitle)) c,
    ];
    final ideas = [
      for (final idea in _ideas)
        if (matches(idea.$1, idea.$2)) idea,
    ];
    return LiquidPrismScaffold(
      backgroundColor: GlassColors.of(context).groupedBackground,
      title: const Text('Search'),
      accessory: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: LiquidPrismSearchField(
            key: const ValueKey('search-page-field'),
            controller: _query,
            focusNode: _focus,
            placeholder: 'Components and ideas',
            onChanged: (_) => setState(() {}),
            onCancel: () => setState(() {}),
          ),
        ),
      ),
      // The scaffold's padding clears the bar and the field, so read it from
      // a context below the scaffold.
      body: Builder(
        builder: (context) => ListView(
          // Dragging the results dismisses the keyboard, as in iOS search.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            if (found.isEmpty && ideas.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 44,
                      color: muted(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No results for “${_query.text.trim()}”',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check the spelling or try a new search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: muted(context)),
                    ),
                  ],
                ),
              ),
            if (found.isNotEmpty)
              InsetSection(
                header: 'Components',
                children: [
                  for (final c in found)
                    ListRow(
                      title: c.title,
                      subtitle: c.subtitle,
                      icon: c.icon,
                      iconColor: c.color,
                      onPressed: () {
                        _focus.unfocus();
                        Navigator.of(context).push<void>(
                          CupertinoPageRoute(
                            builder: (_) =>
                                ComponentPage(info: c, model: widget.model),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (ideas.isNotEmpty)
              InsetSection(
                header: query.isEmpty ? 'Suggestions' : 'Ideas',
                children: [
                  for (final idea in ideas)
                    ListRow(title: idea.$1, subtitle: idea.$2),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
