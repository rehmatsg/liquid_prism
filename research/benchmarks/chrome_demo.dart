import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

class ChromeDemo extends StatefulWidget {
  const ChromeDemo({super.key, this.standalone = false});
  final bool standalone;
  @override
  State<ChromeDemo> createState() => _ChromeDemoState();
}

class _ChromeDemoState extends State<ChromeDemo> {
  final _query = TextEditingController();
  var _actions = 0;
  var _dark = true;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _action() => setState(() => _actions++);
  @override
  Widget build(BuildContext context) => CupertinoTheme(
    data: CupertinoThemeData(
      brightness: _dark ? Brightness.dark : Brightness.light,
    ),
    child: PrismTheme(
      brightness: _dark ? Brightness.dark : Brightness.light,
      child: Builder(
        builder: (context) {
          final colors = PrismColors.of(context);
          return DefaultTextStyle(
            style: TextStyle(color: colors.label, fontSize: 17),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0D8C8C),
                        Color(0xFF0A1F54),
                        Color(0xFFBFB30D),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 383),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.fromLTRB(
                        8,
                        0,
                        8,
                        MediaQuery.viewInsetsOf(context).bottom > 0 ? 10 : 28,
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                if (!widget.standalone)
                                  PrismButton(
                                    label: 'Back',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: const PrismButtonStyle(
                                      padding: EdgeInsets.all(12),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.chevron_back,
                                      size: 20,
                                    ),
                                  ),
                                const Expanded(
                                  child: Text(
                                    'Toolbar',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                PrismToolbar.group(
                                  key: const ValueKey('navigation-toolbar'),
                                  size: PrismToolbarSize.navigation,
                                  items: [
                                    PrismToolbarItem(
                                      key: const ValueKey('favorite'),
                                      label: 'Favorite',
                                      icon: const Icon(CupertinoIcons.star),
                                      width: 42 + 1 / 3,
                                      onPressed: _action,
                                    ),
                                    PrismToolbarItem(
                                      key: const ValueKey('share'),
                                      label: 'Share',
                                      icon: const Icon(CupertinoIcons.share),
                                      width: 38 + 2 / 3,
                                      onPressed: _action,
                                    ),
                                    PrismToolbarItem(
                                      key: const ValueKey('more'),
                                      label: 'More',
                                      icon: const Icon(CupertinoIcons.ellipsis),
                                      onPressed: _action,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 36),
                                    const Text(
                                      'Toolbar & search',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Hold an icon to lift its group. Search, clear, or cancel below.',
                                    ),
                                    const SizedBox(height: 24),
                                    Text('Actions: $_actions'),
                                    const SizedBox(height: 24),
                                    PrismButton(
                                      key: const ValueKey('appearance'),
                                      label: 'Switch appearance',
                                      onPressed: () =>
                                          setState(() => _dark = !_dark),
                                      child: Text(
                                        _dark
                                            ? 'Light appearance'
                                            : 'Dark appearance',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                PrismToolbar.group(
                                  key: const ValueKey('bottom-toolbar'),
                                  items: [
                                    PrismToolbarItem(
                                      key: const ValueKey('previous'),
                                      label: 'Previous',
                                      icon: const Icon(
                                        CupertinoIcons.chevron_left,
                                      ),
                                      onPressed: _action,
                                    ),
                                    PrismToolbarItem(
                                      key: const ValueKey('next'),
                                      label: 'Next',
                                      icon: const Icon(
                                        CupertinoIcons.chevron_right,
                                      ),
                                      onPressed: _action,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                PrismToolbar.group(
                                  key: const ValueKey('compose-toolbar'),
                                  items: [
                                    PrismToolbarItem(
                                      key: const ValueKey('compose'),
                                      label: 'Compose',
                                      icon: const Icon(
                                        CupertinoIcons.square_pencil,
                                      ),
                                      onPressed: _action,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          PrismSearchField(
                            key: const ValueKey('search-field'),
                            controller: _query,
                            style: const PrismSearchStyle(restingInset: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
