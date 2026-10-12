import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

class ShowcaseModel extends ChangeNotifier {
  bool dark = false, clear = false, labels = true;
  String accent = 'blue';
  int wallpaper = 0;
  double frost = 4, refraction = 24;
  bool enabled = true, favorite = false;
  double level = .62;
  int segment = 0, taps = 0;

  Brightness get brightness => dark ? Brightness.dark : Brightness.light;
  Glass get glass => clear ? Glass.clear : Glass.regular;
  Color get tint => GlassColors(brightness).accents[accent]!;
  void change(VoidCallback update) {
    update();
    notifyListeners();
  }

  void reset() => change(() {
    dark = false;
    clear = false;
    labels = true;
    accent = 'blue';
    wallpaper = 0;
    frost = 4;
    refraction = 24;
  });
}

enum ComponentKind {
  surfaces,
  buttons,
  switches,
  sliders,
  segments,
  tabs,
  toolbar,
  search,
  sheets,
}

class ComponentInfo {
  const ComponentInfo(
    this.kind,
    this.title,
    this.subtitle,
    this.icon,
    this.color,
  );
  final ComponentKind kind;
  final String title, subtitle;
  final IconData icon;
  final Color color;
  String get id => kind.name;
}

const components = [
  ComponentInfo(
    ComponentKind.surfaces,
    'Glass surfaces',
    'A window into what’s underneath.',
    CupertinoIcons.layers,
    Color(0xFF467C73),
  ),
  ComponentInfo(
    ComponentKind.buttons,
    'Buttons',
    'Small actions. Satisfying feedback.',
    CupertinoIcons.hand_point_right,
    Color(0xFFBE674B),
  ),
  ComponentInfo(
    ComponentKind.switches,
    'Switches',
    'A familiar feel, down to the spring.',
    CupertinoIcons.switch_camera,
    Color(0xFF587A4B),
  ),
  ComponentInfo(
    ComponentKind.sliders,
    'Sliders',
    'Find the sweet spot.',
    CupertinoIcons.slider_horizontal_3,
    Color(0xFF927137),
  ),
  ComponentInfo(
    ComponentKind.segments,
    'Segmented controls',
    'Slide into a different perspective.',
    CupertinoIcons.rectangle_split_3x1,
    Color(0xFF827497),
  ),
  ComponentInfo(
    ComponentKind.tabs,
    'Tab bars',
    'Navigation with a little lift.',
    CupertinoIcons.square_grid_2x2,
    Color(0xFF546EA2),
  ),
  ComponentInfo(
    ComponentKind.toolbar,
    'Toolbars',
    'A shared home for your actions.',
    CupertinoIcons.ellipsis,
    Color(0xFF8D6956),
  ),
  ComponentInfo(
    ComponentKind.search,
    'Search fields',
    'Clear your mind. Find your thing.',
    CupertinoIcons.search,
    Color(0xFF56828B),
  ),
  ComponentInfo(
    ComponentKind.sheets,
    'Sheets',
    'Room for the next idea.',
    CupertinoIcons.rectangle_on_rectangle,
    Color(0xFF8B6F87),
  ),
];
