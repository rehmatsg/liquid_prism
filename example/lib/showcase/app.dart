import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'package:liquid_prism/liquid_prism.dart';

import 'component_page.dart';
import 'model.dart';
import 'pages.dart';
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
    builder: (context, _) {
      final colors = GlassColors(model.brightness);
      return CupertinoApp(
        title: 'Liquid Prism',
        localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(
          brightness: model.brightness,
          primaryColor: model.tint,
          scaffoldBackgroundColor: colors.groupedBackground,
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 17,
              letterSpacing: -.41,
              color: colors.label,
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
          // Publishes iPhone Duo bar placement and keeps dialogs out of the
          // fold, for every route.
          child: LiquidPrismSystemChrome(
            child: DefaultTextStyle(
              style: CupertinoTheme.of(context).textTheme.textStyle,
              child: child!,
            ),
          ),
        ),
        home: ShowcaseHome(model: model),
      );
    },
  );
}

enum ShowcaseTab { explore, studio, library }

class ShowcaseHome extends StatefulWidget {
  const ShowcaseHome({super.key, required this.model});
  final ShowcaseModel model;
  @override
  State<ShowcaseHome> createState() => _ShowcaseHomeState();
}

class _ShowcaseHomeState extends State<ShowcaseHome> {
  var tab = ShowcaseTab.explore;
  final scroll = {
    for (final tab in ShowcaseTab.values) tab: ScrollController(),
  };
  final search = TextEditingController();
  final searchFocus = FocusNode();

  ShowcaseModel get model => widget.model;

  @override
  void dispose() {
    for (final controller in scroll.values) {
      controller.dispose();
    }
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void select(ShowcaseTab value) {
    searchFocus.unfocus();
    if (value == tab && scroll[value]!.hasClients) {
      // Tapping the current tab scrolls back to the top, as on iOS.
      scroll[value]!.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() => tab = value);
  }

  void open(ComponentInfo info) {
    searchFocus.unfocus();
    Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => ComponentPage(info: info, model: model),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LiquidPrismScaffold(
    backgroundColor: GlassColors.of(context).groupedBackground,
    actions: appearanceActions(model),
    tabBar: LiquidPrismTabBar(
      key: const ValueKey('showcase-navigation'),
      selectedIndex: tab.index,
      onSelected: (index) => select(ShowcaseTab.values[index]),
      tabs: const [
        LiquidPrismTab(label: 'Explore', icon: Icon(CupertinoIcons.sparkles)),
        LiquidPrismTab(
          label: 'Studio',
          icon: Icon(CupertinoIcons.slider_horizontal_3),
        ),
        LiquidPrismTab(
          label: 'Library',
          icon: Icon(CupertinoIcons.square_grid_2x2),
          selectedIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
        ),
      ],
    ),
    body: KeyedSubtree(
      key: ValueKey(tab),
      child: switch (tab) {
        ShowcaseTab.explore => ExplorePage(
          model: model,
          controller: scroll[tab],
          open: open,
          onStudio: () => select(ShowcaseTab.studio),
        ),
        ShowcaseTab.studio => StudioPage(model: model, controller: scroll[tab]),
        ShowcaseTab.library => LibraryPage(
          model: model,
          controller: scroll[tab],
          search: search,
          focus: searchFocus,
          open: open,
        ),
      },
    ),
  );
}

/// The appearance toggle and artwork menu shared by every screen.
List<GlassToolbarItem> appearanceActions(ShowcaseModel model) => [
  GlassToolbarItem(
    icon: Icon(model.dark ? CupertinoIcons.sun_max : CupertinoIcons.moon),
    label: 'Toggle appearance',
    onPressed: () => model.change(() => model.dark = !model.dark),
  ),
  GlassToolbarItem.menu(
    icon: const Icon(CupertinoIcons.photo),
    label: 'Choose artwork',
    menu: LiquidMenu(
      title: 'Artwork',
      children: [
        for (var i = 0; i < Art.names.length; i++)
          LiquidMenuAction<int>(
            id: 'artwork-$i',
            title: Art.names[i],
            value: i,
            state: model.wallpaper == i
                ? MenuElementState.on
                : MenuElementState.off,
            onSelected: () => model.change(() => model.wallpaper = i),
          ),
      ],
    ),
  ),
];
