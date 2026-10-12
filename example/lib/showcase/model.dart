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
  menus,
  search,
}

class ComponentInfo {
  const ComponentInfo(
    this.kind,
    this.title,
    this.subtitle,
    this.icon,
    this.color, {
    required this.description,
    required this.details,
  });
  final ComponentKind kind;
  final String title, subtitle, description;
  final IconData icon;
  final Color color;

  /// Public API and behavior notes, as (title, detail) rows.
  final List<(String, String)> details;
  String get id => kind.name;
}

const components = [
  ComponentInfo(
    ComponentKind.surfaces,
    'Glass Surfaces',
    'A window into what’s underneath.',
    CupertinoIcons.square_stack_3d_up_fill,
    Color(0xFF30B0C7),
    description:
        'Glass bends the scene behind it while keeping your content crisp. '
        'Move the lens, then try regular, clear and tinted materials.',
    details: [
      ('LiquidPrism', 'Any shape, with your content on top'),
      ('Glass', 'Regular, clear, tinted and identity variants'),
      ('LiquidPrismGroup', 'Nearby surfaces share one pass'),
    ],
  ),
  ComponentInfo(
    ComponentKind.buttons,
    'Buttons',
    'Small actions. Satisfying feedback.',
    CupertinoIcons.hand_point_right_fill,
    Color(0xFFFF9500),
    description:
        'An everyday action with a tactile response. Try a quiet glass '
        'button, a prominent action, or a circular favorite.',
    details: [
      ('LiquidPrismButton', 'Glass and prominent styles'),
      ('Feedback', 'Lifts and flexes while held'),
      ('Menus', 'LiquidPrismButton.menu opens a native menu'),
    ],
  ),
  ComponentInfo(
    ComponentKind.switches,
    'Switches',
    'A familiar feel, down to the spring.',
    CupertinoIcons.switch_camera_solid,
    Color(0xFF34C759),
    description:
        'Tap to change your outlook. Hold and drag the thumb to feel its '
        'lift and the spring that brings it home.',
    details: [
      ('LiquidPrismSwitch', 'Controlled value with onChanged'),
      ('Haptics', 'A light tap when the value changes'),
    ],
  ),
  ComponentInfo(
    ComponentKind.sliders,
    'Sliders',
    'Find the sweet spot.',
    CupertinoIcons.slider_horizontal_3,
    Color(0xFF5856D6),
    description:
        'A little precision, a little play. Drag the thumb to change the '
        'value and watch it lift under your finger.',
    details: [
      ('LiquidPrismSlider', 'Any range, continuous fill'),
      ('Thumb', 'Grows into a lens while held'),
    ],
  ),
  ComponentInfo(
    ComponentKind.segments,
    'Segmented Controls',
    'Slide into a different perspective.',
    CupertinoIcons.rectangle_split_3x1_fill,
    Color(0xFFAF52DE),
    description:
        'A shared track with a gliding selection. Tap a perspective or hold '
        'the pill and slide to a new one.',
    details: [
      ('LiquidPrismSegmentedControl', 'Typed values, any widgets'),
      ('Gesture', 'Tap, or hold and slide'),
    ],
  ),
  ComponentInfo(
    ComponentKind.tabs,
    'Tab Bars',
    'Navigation with a little lift.',
    CupertinoIcons.square_grid_2x2_fill,
    Color(0xFF007AFF),
    description:
        'A floating home for navigation. The selection lifts, follows your '
        'finger and settles into its next destination.',
    details: [
      ('LiquidPrismTabBar', 'Compact by default, rows or columns'),
      ('LiquidPrismScaffold', 'Bottom bar on iPhone, side rail on iPhone Duo'),
    ],
  ),
  ComponentInfo(
    ComponentKind.toolbar,
    'Toolbars',
    'A shared home for your actions.',
    CupertinoIcons.ellipsis_circle_fill,
    Color(0xFFA2845E),
    description:
        'Related actions share a single glass capsule. Each icon responds '
        'individually while the whole group lifts together.',
    details: [
      ('LiquidPrismToolbarGroup', 'Navigation and bottom sizes'),
      ('Axis', 'Stacks vertically in the iPhone Duo rail'),
    ],
  ),
  ComponentInfo(
    ComponentKind.menus,
    'Popup Menus',
    'Real native menus, right where you tap.',
    CupertinoIcons.list_bullet_below_rectangle,
    Color(0xFFFF2D55),
    description:
        'A glass button, a real native popup. Try sections, checkmarks, SF '
        'Symbols, submenus and items loaded when the menu opens. UIKit '
        'handles the presentation.',
    details: [
      ('LiquidMenu', 'Actions, sections, submenus, deferred items'),
      ('LiquidMenuRegion', 'Context menus on long press'),
    ],
  ),
  ComponentInfo(
    ComponentKind.search,
    'Search Fields',
    'Clear your mind. Find your thing.',
    CupertinoIcons.search,
    Color(0xFF8E8E93),
    description:
        'A field that makes space when you need it. Type a thought, clear '
        'it, or cancel to return to the moment.',
    details: [
      ('LiquidPrismSearchField', 'Owned or borrowed controller'),
      ('Cancel', 'Appears while focused'),
    ],
  ),
];
