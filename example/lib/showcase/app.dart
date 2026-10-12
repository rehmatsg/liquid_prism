import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'package:liquid_prism/liquid_prism.dart';

import 'model.dart';
import 'pages.dart';
import 'component_page.dart';
import 'widgets.dart';

class LiquidPrismExample extends StatefulWidget {
  const LiquidPrismExample({super.key});
  @override
  State<LiquidPrismExample> createState() => _LiquidPrismExampleState();
}

class _LiquidPrismExampleState extends State<LiquidPrismExample> {
  final model = ShowcaseModel();
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => CupertinoApp(
      title: 'Liquid Prism',
      localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: model.brightness,
        primaryColor: model.tint,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 16,
            color: GlassColors(model.brightness).label,
          ),
        ),
      ),
      builder: (context, child) => LiquidPrismTheme(
        data: LiquidPrismThemeData(
          brightness: model.brightness,
          tint: model.tint,
          glass: model.glass,
          tabBar: GlassTabBarStyle(
            labelBehavior: model.labels
                ? GlassTabLabelBehavior.always
                : GlassTabLabelBehavior.never,
          ),
        ),
        child: child!,
      ),
      home: ShowcaseHome(model: model),
    ),
  );
}

class ShowcaseHome extends StatefulWidget {
  const ShowcaseHome({super.key, required this.model});
  final ShowcaseModel model;
  @override
  State<ShowcaseHome> createState() => _ShowcaseHomeState();
}

class _ShowcaseHomeState extends State<ShowcaseHome> {
  int tab = 0;
  final scroll = List.generate(3, (_) => ScrollController());
  final search = TextEditingController();
  final searchFocus = FocusNode();
  @override
  void dispose() {
    for (final c in scroll) {
      c.dispose();
    }
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void select(int value) {
    searchFocus.unfocus();
    setState(() => tab = value);
  }

  void open(ComponentInfo info) => Navigator.of(context).push<void>(
    CupertinoPageRoute(
      builder: (_) => ComponentPage(info: info, model: widget.model),
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(color: ink(context)),
    child: ShowcaseBackdrop(
      model: widget.model,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
                child: Row(
                  children: [
                    Container(
                      width: 33,
                      height: 33,
                      decoration: ShapeDecoration(
                        color: ink(context),
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.cube,
                        color: widget.model.dark
                            ? const Color(0xFF151B20)
                            : const Color(0xFFF5F3ED),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'liquid prism',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                    IconAction(
                      icon: widget.model.dark
                          ? CupertinoIcons.sun_max
                          : CupertinoIcons.moon,
                      label: 'Toggle appearance',
                      onPressed: () => widget.model.change(
                        () => widget.model.dark = !widget.model.dark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(tab),
                  controller: scroll[tab],
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 26),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 940),
                      child: switch (tab) {
                        0 => ExplorePage(
                          model: widget.model,
                          open: open,
                          onStudio: () => select(1),
                          onLibrary: () => select(2),
                        ),
                        1 => StudioPage(model: widget.model),
                        _ => LibraryPage(
                          model: widget.model,
                          controller: search,
                          focus: searchFocus,
                          open: open,
                        ),
                      },
                    ),
                  ),
                ),
              ),
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    10,
                    24,
                    // Native floating housing sits 21 pt from the screen edge
                    // (doc/native_tab_bar_spec.md), within the gesture inset.
                    defaultTargetPlatform == TargetPlatform.iOS
                        ? 21
                        : MediaQuery.viewPaddingOf(context).bottom + 10,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: LiquidPrismTabBar(
                        key: const ValueKey('showcase-navigation'),
                        selectedIndex: tab,
                        onSelected: select,
                        tabs: const [
                          LiquidPrismTab(
                            label: 'Explore',
                            icon: Icon(CupertinoIcons.sparkles),
                          ),
                          LiquidPrismTab(
                            label: 'Studio',
                            icon: Icon(CupertinoIcons.slider_horizontal_3),
                          ),
                          LiquidPrismTab(
                            label: 'Library',
                            icon: Icon(CupertinoIcons.square_grid_2x2),
                            selectedIcon: Icon(
                              CupertinoIcons.square_grid_2x2_fill,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
            ],
          ),
        ),
      ),
    ),
  );
}
