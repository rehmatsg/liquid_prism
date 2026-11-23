# Native showcase reference

A standalone SwiftUI app, Prism Native, that mirrors the Flutter showcase in
`example/lib/showcase` page for page, so the two can run side by side. Wherever
the Flutter app shows a package widget, this app shows the iOS component it
stands in for. It recreates no glass, popups or animations: iOS draws them.

## What it covers

- **Tabs.** Explore, Studio and Library in a `TabView`, each with its own
  `NavigationStack`. Pushed pages hide the tab bar. Tab labels, the sidebar
  style and the iPhone Duo side bar (`toolbarVerticalBehavior`, iOS 27.1)
  follow Studio's settings. Every page has the same appearance toggle and
  artwork menu as the Flutter app, in one toolbar capsule.
- **Pages.** Each page opens with its own large title and subtitle, then
  inset-grouped sections with the same text, symbols, palette and order as
  the Flutter app. On a bent iPhone Duo the sections split into two columns
  around the fold, read from the iOS 27.1 division region.
- **Library.** All 11 components: Glass Surfaces, Buttons, Switches, Sliders,
  Segmented Controls, Tab Bars, Toolbars, Scroll Edges, Page Layouts, Popup
  Menus and Search Fields. Each has its live preview, a Disabled section where
  the Flutter page has one, and its Details rows.
- **Page demos**, opened from Page Layouts:
  - Scaffold Lab switches the heading (large title, custom header or
    inline), the scroll edge style, an accessory row, a bottom bar, one or
    two capsules, badges, pull to refresh and a subtitle. It also opens the
    same kind of page in a sheet.
  - Header Page puts its header in the bar's large-title slot, pins tabs
    below the bar, and adds a trailing pill and a bottom bar.
  - Conversation shows Maya, a one-to-one chat, with an avatar above a glass
    name capsule and a Call action. Tapping the name switches to Book Club,
    with an inline avatar, a glass Invite button and a More action.
  - Sliver App Bar has a collapsing large title, two capsules with a dot badge
    and a segmented accessory.
  - Search Page keeps a search field in the navigation bar drawer.
    Cancelling the search closes the page.

The native counterparts are `glassEffect` and `GlassEffectContainer`, buttons
with `.glass` and `.glassProminent`, and `Toggle`, `Slider` and the segmented
`Picker`. Menus are SwiftUI `Menu` and `contextMenu`, plus a `UIMenu` with a
deferred item. Chrome comes from toolbar items, `ToolbarSpacer` and `badge`,
`safeAreaBar`, `scrollEdgeEffectStyle`, `refreshable`, `searchable` and
`sheet`. Previews that sit inside page content wrap UIKit's own bars: an
inline `UINavigationBar` or `UIToolbar` with capsule groups, a `UITabBar`, a
`UISearchBar`, a `UINavigationController` showing the scroll edge styles, and
a `UITabBarController` with a large title, badges and a held-tab readout.

## Where it differs from Flutter

- Public glass has no frost or refraction parameters. Studio keeps those
  values, and the lens keeps the 8% accent tint, but they don't retune
  Apple's renderer.
- UIKit has no public vertical tab bar or toolbar outside the system rail.
  The Tab Bars and Toolbars previews keep their text, and the rail itself is
  the app's own chrome on iPhone Duo.
- iOS has no public edge fade for a scroll view without a bar. The chips
  under Scroll Edges ask for the soft scroll edge effect and show whatever
  iOS draws there.
- iOS draws no capsule for a principal toolbar item, and the bar doesn't grow
  to fit one. The Conversation title is a `.glass` button in the principal
  slot, under the avatar. Its messages start a little lower so the capsule
  doesn't cover the first line.
- The Library and Search Fields fields are inline `UISearchBar`s. The Search
  Page uses SwiftUI's navigation-bar `.searchable`, whose Cancel button shows
  only while searching.

Fonts, symbols, adaptive bar sizing and the two renderers can still produce
layout and pixel differences. This app is a native reference, not proof of
identical rendering.

## Build

Generate the project with `xcodegen generate`. The `.xcodeproj` is not
tracked. The deployment target is iOS 26, the bundle identifier is
`com.rehmat.glassshowcase.native`, and the display name is Prism Native.
Builds are unsigned by default. For a device, pass your team:

```sh
xcodegen generate
xcodebuild build -project NativeShowcase.xcodeproj -scheme NativeShowcase \
  -configuration Release -destination "id=$DEVICE" -derivedDataPath build-device \
  -allowProvisioningUpdates CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=$TEAM
xcrun devicectl device install app --device "$DEVICE" \
  build-device/Build/Products/Release-iphoneos/NativeShowcase.app
xcrun devicectl device process launch --device "$DEVICE" \
  --terminate-existing com.rehmat.glassshowcase.native
```

## Launch arguments and tests

- `--screen NAME` opens a tab (`explore`, `studio`, `library`) or a
  component (`surfaces`, `buttons`, `switches`, `sliders`, `segments`, `tabs`,
  `toolbar`, `scrollEdges`, `pages`, `menus`, `search`). It also opens a page
  demo (`scaffold-lab`, `header-page`, `conversation`, `sliver-bar`,
  `search-page`) on top of Page Layouts.
- `--dark` and `--accent NAME` set the appearance.
- `--scroll ID` scrolls to `explore-controls`, `look-feel`, `palette`,
  `optics`, `artwork` or `features-demo`.
- `--inspect` writes UIKit geometry, layer settings and SwiftUI layout frames
  to Documents. It also follows `command.json` there, so the comparison runner
  can select identical states.
- `--motion NAME` records presentation-layer lens bounds at up to 60 Hz.
- `--tab-labels "A|B|C"` opens an isolated `TabView` layout probe, and
  `--hide-labels` makes its labels icon-only.

None of these options change how the native components render, and none of
them are linked into Flutter.

`ShowcaseTests` goes through the tabs, library search and every component
route. It also exercises the native switch, segmented control and popup menu.
`LensMotionTests` performs real holds, two-second glides and fast reversals on
the switch, slider, segmented control and tab bar. `SwitchTapTests` times
quick switch taps. After building the UI test bundle,
`record_motion.py SIMULATOR OUTPUT_DIRECTORY` records the lens tests and
copies their measured presentation bounds.

The Flutter comparison entry point is `example/test_driver/showcase.dart`.
Run `native_showcase_compare.dart` with `PRISM_SIMULATOR_ID`,
`PRISM_COMPARE_OUT` and `DART_VM_SERVICE_URL` after installing this app and
launching that fixture. It captures matching light and dark states.
Recordings, generated projects and builds are ignored by Git.
