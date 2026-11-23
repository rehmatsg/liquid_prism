import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism_example/showcase/component_page.dart';
import 'package:liquid_prism_example/showcase/model.dart';
import 'package:liquid_prism_example/showcase/pages.dart';
import 'package:liquid_prism_example/showcase/widgets.dart';
import 'package:material_ui/material_ui.dart' show DefaultMaterialLocalizations;

/// The interactive Liquid Prism component showcase.
class PrismExample extends StatefulWidget {
  /// Creates a [PrismExample].
  const new({super.key});
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

/// The top-level destinations in the showcase.
enum ShowcaseTab {
  /// Featured demonstrations and entry points.
  explore,

  /// Appearance and optics customization controls.
  studio,

  /// The searchable collection of component demonstrations.
  library,
}

/// The showcase shell with shared controls and tab navigation.
class ShowcaseHome extends StatefulWidget {
  /// Creates a [ShowcaseHome].
  const new({super.key, required this.model});

  /// Shared showcase appearance and interaction state.
  final ShowcaseModel model;
  @override
  State<ShowcaseHome> createState() => _ShowcaseHomeState();
}

class _ShowcaseHomeState extends State<ShowcaseHome> {
  ShowcaseTab tab = ShowcaseTab.explore;
  final Map<ShowcaseTab, ScrollController> scroll = {
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

/// Builds toolbar actions for appearance and artwork selection.
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
