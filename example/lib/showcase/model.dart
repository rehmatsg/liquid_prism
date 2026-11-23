import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';

class ShowcaseModel extends ChangeNotifier {
  bool dark = false, clear = false, labels = true, verticalBar = true;
  bool sidebar = false;
  String accent = 'blue';
  int wallpaper = 0;
  double frost = 4, refraction = 24;

  bool globalOptics = false;
  bool previewOptics = false;
  bool enabled = true, favorite = false;
  double level = .62;
  int segment = 0, taps = 0;

  Brightness get brightness => dark ? Brightness.dark : Brightness.light;
  PrismGlass get glass => clear ? PrismGlass.clear : PrismGlass.regular;
  Color get tint => PrismColors(brightness).accents[accent]!;
  void change(VoidCallback update) {
    update();
    notifyListeners();
  }

  void setVerticalBar(bool value) {
    change(() => verticalBar = value);
    unawaited(
      PrismSystemChrome.setVerticalBarBehavior(
        value
            ? PrismVerticalBarBehavior.automatic
            : PrismVerticalBarBehavior.disabled,
      ),
    );
  }

  void reset() => change(() {
    dark = false;
    clear = false;
    labels = true;
    accent = 'blue';
    wallpaper = 0;
    frost = 4;
    refraction = 24;
    globalOptics = false;
    previewOptics = false;
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
  scrollEdges,
  pages,
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
      ('PrismSurface', 'Any shape, with your content on top'),
      ('PrismGlass', 'Regular, clear, tinted and identity variants'),
      ('PrismGroup', 'Nearby surfaces share one pass'),
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
      ('PrismButton', 'Glass and prominent styles'),
      ('Feedback', 'Lifts and flexes while held'),
      ('Menus', 'PrismButton.menu opens a native menu'),
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
      ('PrismSwitch', 'Controlled value with onChanged'),
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
      ('PrismSlider', 'Any range, continuous fill'),
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
      ('PrismSegmentedControl', 'Typed values, any widgets'),
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
      ('PrismTabBar', 'Compact by default, rows or columns'),
      ('PrismScaffold', 'Bottom bar on iPhone, side rail on iPhone Duo'),
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
      ('PrismToolbar.group', 'Navigation and bottom sizes'),
      ('PrismToolbar', 'Several capsules; empty groups collapse'),
      ('Items', 'Materialize in and out as the list changes'),
      ('Axis', 'Stacks vertically in the iPhone Duo rail'),
    ],
  ),
  ComponentInfo(
    ComponentKind.scrollEdges,
    'Scroll Edges',
    'Content softens under the bar.',
    CupertinoIcons.rectangle_dock,
    Color(0xFF0A84FF),
    description:
        'Scroll and the content under a bar blurs and fades, strongest at '
        'the edge. The glass controls see straight through it, as native '
        'bar buttons do.',
    details: [
      ('PrismScrollEdge', 'A bar’s effect, driven by scroll progress'),
      ('PrismScaffold', 'Draws it under the top bar by default'),
      ('PrismEdgeBlur', 'Progressive blur and fade of any edge'),
      ('PrismScrollEdge.fade', 'Edges of a scroll view, as content passes'),
      (
        'PrismGroup',
        'Glass over the effect refracts the content, not the blur',
      ),
    ],
  ),
  ComponentInfo(
    ComponentKind.pages,
    'Page Layouts',
    'Bars, headers and bottom bars.',
    CupertinoIcons.rectangle_stack,
    Color(0xFF5856D6),
    description:
        'Hand the scaffold your slivers and it builds the page: the bar, a '
        'large title or header, an accessory, a bottom bar, pull to refresh '
        'and the edge effects, with its glass grouped for you.',
    details: [
      ('PrismScaffold.slivers', 'The scaffold builds the scroll view'),
      ('header', 'Your own heading, scrolling away under the bar'),
      ('bottomBar', 'Pinned above the home indicator or keyboard'),
      ('onRefresh', 'Pull to refresh, out of the Dynamic Island'),
      ('PrismSliverAppBar', 'The same bar inside your own scroll view'),
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
      ('PrismMenu', 'Actions, sections, submenus, deferred items'),
      ('PrismMenuRegion', 'Context menus on long press'),
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
      ('PrismSearchField', 'Owned or borrowed controller'),
      ('Cancel', 'Appears while focused'),
    ],
  ),
];
