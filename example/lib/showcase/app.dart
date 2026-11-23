import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:material_ui/material_ui.dart' show DefaultMaterialLocalizations;

import 'component_page.dart';
import 'model.dart';
import 'pages.dart';
import 'widgets.dart';

class PrismExample extends StatefulWidget {
  const PrismExample({super.key});
  @override
  State<PrismExample> createState() => _PrismExampleState();
}

class _PrismExampleState extends State<PrismExample> {
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
      final colors = PrismColors(model.brightness);
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
        builder: (context, child) => PrismTheme(
          data: PrismThemeData(
            brightness: model.brightness,
            tint: model.tint,
            glass: model.glass,

            blur: model.globalOptics ? model.frost : null,
            refraction: model.globalOptics ? model.refraction : null,
            tabBar: PrismTabBarStyle(
              labelBehavior: model.labels ? null : PrismTabLabelBehavior.never,
            ),
          ),

          child: PrismSystemChrome(
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
  Widget build(BuildContext context) => PrismScaffold(
    backgroundColor: PrismColors.of(context).groupedBackground,
    tabBarPlacement: model.sidebar
        ? PrismTabBarPlacement.sidebar
        : PrismTabBarPlacement.automatic,
    toolbar: appearanceActions(model),

    onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 1400)),
    tabBar: PrismTabBar(
      key: const ValueKey('showcase-navigation'),
      selectedIndex: tab.index,
      onSelected: (index) => select(ShowcaseTab.values[index]),
      tabs: const [
        PrismTab(label: 'Explore', icon: Icon(CupertinoIcons.sparkles)),
        PrismTab(
          label: 'Studio',
          icon: Icon(CupertinoIcons.slider_horizontal_3),
        ),

        PrismTab(
          label: 'Library',
          icon: Icon(CupertinoIcons.square_grid_2x2_fill),
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

List<PrismToolbarItem> appearanceActions(ShowcaseModel model) => [
  PrismToolbarItem(
    icon: Icon(model.dark ? CupertinoIcons.sun_max : CupertinoIcons.moon),
    label: 'Toggle appearance',
    onPressed: () => model.change(() => model.dark = !model.dark),
  ),
  PrismToolbarItem.menu(
    icon: const Icon(CupertinoIcons.photo),
    label: 'Choose artwork',
    menu: PrismMenu(
      title: 'Artwork',
      children: [
        for (var i = 0; i < Art.names.length; i++)
          PrismMenuAction<int>(
            id: 'artwork-$i',
            title: Art.names[i],
            value: i,
            state: model.wallpaper == i
                ? PrismMenuElementState.on
                : PrismMenuElementState.off,
            onSelected: () => model.change(() => model.wallpaper = i),
          ),
      ],
    ),
  ),
];
