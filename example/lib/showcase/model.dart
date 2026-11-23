import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';

/// Shared appearance settings and interaction state for the showcase.
class ShowcaseModel extends ChangeNotifier {
  /// Whether the showcase uses a dark appearance.
  bool dark = false;

  /// Whether controls use the clear glass material.
  bool clear = false;

  /// Whether tab labels follow the default visibility behavior.
  bool labels = true;

  /// Whether automatic vertical system-bar behavior is enabled.
  bool verticalBar = true;

  /// Whether navigation uses the sidebar placement.
  bool sidebar = false;

  /// The name of the selected accent color.
  String accent = 'blue';

  /// The index of the selected background artwork.
  int wallpaper = 0;

  /// The customized glass blur amount.
  double frost = 4;

  /// The customized glass refraction strength.
  double refraction = 24;

  /// Whether customized optics apply throughout the showcase.
  bool globalOptics = false;

  /// Whether the studio preview uses customized optics.
  bool previewOptics = false;

  /// The current switch value in component previews.
  bool enabled = true;

  /// Whether the favorite action is selected.
  bool favorite = false;

  /// The current slider value in component previews.
  double level = .62;

  /// The selected segment in component previews.
  int segment = 0;

  /// The number of button activations in component previews.
  int taps = 0;

  /// The brightness derived from the selected appearance.
  Brightness get brightness => dark ? Brightness.dark : Brightness.light;

  /// The glass material derived from the clear-material setting.
  PrismGlass get glass => clear ? PrismGlass.clear : PrismGlass.regular;

  /// The selected accent color for the current brightness.
  Color get tint => PrismColors(brightness).accents[accent]!;

  /// Applies a state update and notifies showcase listeners.
  void change(VoidCallback update) {
    update();
    notifyListeners();
  }

  /// Updates vertical system-bar behavior and notifies listeners.
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

  /// Restores default appearance and optics without resetting interactions.
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

/// The component categories available in the showcase.
enum ComponentKind {
  /// Glass surfaces and materials.
  surfaces,

  /// Buttons and press feedback.
  buttons,

  /// Switch controls and haptic feedback.
  switches,

  /// Sliders and lifted thumbs.
  sliders,

  /// Segmented selection controls.
  segments,

  /// Tab bars and navigation selection.
  tabs,

  /// Grouped toolbar actions.
  toolbar,

  /// Scroll-edge blur and fade effects.
  scrollEdges,

  /// Scaffold layouts, headers, and navigation bars.
  pages,

  /// Native popup and context menus.
  menus,

  /// Search fields and suggestions.
  search,
}

/// Display metadata for a showcase component category.
class ComponentInfo {
  /// Creates a [ComponentInfo].
  const new(
    this.kind,
    this.title,
    this.subtitle,
    this.icon,
    this.color, {
    required this.description,
    required this.details,
  });

  /// The category represented by this entry.
  final ComponentKind kind;

  /// The display name of the component category.
  final String title;

  /// A short summary shown in the component library.
  final String subtitle;

  /// The introductory text shown on the component detail page.
  final String description;

  /// The symbol identifying the component category.
  final IconData icon;

  /// The accent color identifying the component category.
  final Color color;

  /// Feature names and descriptions shown on the detail page.
  final List<(String, String)> details;

  /// The stable identifier derived from the component category.
  String get id => kind.name;
}

/// The component categories and metadata shown in the library.
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
