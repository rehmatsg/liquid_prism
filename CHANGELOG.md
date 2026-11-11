# Changelog

## Unreleased

- On vertical-rail layouts (iPhone Duo), an automatic scaffold bar with a plain title, no large title or header, and outside a sheet now hides on scroll down and returns at the top. Bars that reveal a title on scroll keep it; an explicit `minimizationBehavior` still wins.
- Add `enabled`, `onLongPress`, `isLoading`, `autoLoading`, `loadingIndicator`, `destructive`, `tintColor`, `trailingIcon` and `semanticLabel` to `LiquidPrismButton`, with a built-in activity indicator and `GlassButtonStyle.loadingIndicator`. `LiquidPrismPressable` takes `onLongPress`, and `GlassHapticComponent.button` reports a button's long press.
- Fade a scaffold's bottom scroll edge with its bottom bar's height, so a bar kept mounted while collapsed draws no edge at zero height.
- Center automatic inline titles on vertical-rail layouts when the page has no trailing actions; titles keep leading alignment beside them.

## 0.13.0

- Add HDR lighting for light glass on supported iOS displays. `LiquidPrism.preload()` enables it automatically and `preload(enableHDR: false)` keeps the SDR path. Regular glass lifts its face to about 1.07× white with a rim reaching about 1.3× at the poles and along flat edges; clear glass lifts its face to about 1.19×. Measured against native Liquid Glass in the same HDR capture on device. The rim stays lit under Control Center, as native's does.
- Add `shadow: false` to `LiquidPrism` and `LiquidPrismThemeData` to remove a surface's exterior and inset material shadows while keeping its rims.
- Plain clear surfaces no longer cast a material shadow, matching native's captured inputs. Clear buttons and tab bars keep theirs.
- Keep the rim lens on small plain regular surfaces. It now fades out only below 16 points, to none at 10, where 0.11.0 removed it at 48 points; native 44-point circles and capsules bend their backdrop.
- Stop the native regular and clear recipes from drawing a broad reflection of nearby content, which showed labels above a surface as streaks.
- Restore activity badges to the full native badge height while preserving their corner placement and materialization.

- Lay out title logos at their declared slot size, preserving their corner geometry while moving between avatar and inline positions.
- Match inline glass-title capsules to bar icon-button heights, fitting default text/leading insets around subtitles and honoring custom control heights and larger text.

## 0.12.0

- Compose scaffold and sliver subtitles inside glass title capsules, with inline avatar support through the existing leading slot and full text-scaled height.
- Retain toolbar refraction on compact title pills. Keep title glass, borders, logos and text coordinated during reveals without isolating their live backdrop. Omit the top edge blur for glass titles and action-only bars; lead ordinary titles on vertical rails.
- Materialize toolbar groups once with an unclipped contour while their layout extent changes, and use a restrained 280 ms entry/exit with a 4-point content blur.
- Fade toolbar badges with their group and item materialization. Draw smaller activity dots with consistent corner placement across RTL and vertical toolbars. Keep long toolbar counts inside their trailing safe edge and tab/sidebar badge centers stable at larger text sizes.

## 0.11.0

0.10.0 was never tagged; its changes ship in this release.

- Match regular glass to native Liquid Glass measured on device at every Liquid Glass setting: a sharp backdrop under a lighten/darken-blended blur fill, size-dependent base blur and dark bleed on surfaces taller than 64 points, the native white rim highlight and dark edge line, and rims that mirror nearby content. Plain regular surfaces shorter than 64 points fade their default rim lens out, to none at 48 points, as measured; bars, buttons and fields keep their lens, and an explicit `refraction` is used as given. The selected tab pill keeps its 2-point blur over regular bars. Explicit blur and optics still override the device curve.

- Cut the GPU cost of regular and clear glass. The wide blur fill is now blurred once per frame for all the glass that shares a backdrop and blended inside each surface's own pass, replacing three or four backdrop layers per surface; dark glass takes its bleed from the same blur. Glass painted one after another shares that blur without a `LiquidPrismGroup`. Measured on an M5 Mac, seven free-standing regular surfaces cost about 1.6 ms of GPU time per frame, down from 6.2 ms, and scaffold chrome 1.3 ms, down from 2.8 ms. Off-screen glass skips its backdrop passes. Glass now fades in by the fill's opacity where its blur radius grew before.

- Let Studio use device-derived regular glass until optics are explicitly adjusted; material selector controls inherit the app material.

- Show refresh below compact and accessory-only headers: the circle scales and fades into the opened gap, which stays clear while refreshing. Keep balanced clearance above and below the resting circle, independent of the pull threshold. Expanded headings and action-only chrome retain the island/top-edge effect.

- Let automatic inline titles use the leading edge when trailing controls crowd the centered position, in both scaffold and sliver bars. Preserve explicit alignment, RTL and centered glass title capsules.

- Draw the detached refresh drop with native circle antialiasing and add a thin translucent white contour around the emerging drop and detached circle in dark appearance.
- Preserve the full blended contour during early pulls from the top edge on devices without a Dynamic Island.
- Add a light release haptic when an armed pull starts refreshing, routed through `GlassHaptics` as `refreshReleased`. Programmatic refreshes do not emit it. Exhaustive `GlassHapticKind` switches must handle the new event.

- Add `tool/gpu_bench/`, a GPU benchmark that runs on a Mac without a device.

## 0.9.0

- Add `LiquidPrismRefreshController` and `LiquidPrismScaffold.refreshController`: `refresh()` starts the scaffold's refresh from code with the same indicator as a released pull, joins one that is already running, and `isRefreshing` reports it.

- Route pull-to-refresh haptics through the theme's `GlassHaptics` hook, as `GlassHapticComponent.refresh` events of kind `refreshPulled`, `refreshArmed`, `refreshSucceeded` and `refreshFailed`. An app can now silence or reroute them. These are new enum values: an exhaustive `switch` over either enum needs the new cases.

- Let a refresh report failure: an `onRefresh` future that completes with `false`, or throws, now ends without the check and success haptic. A callback that returns a `Future<bool>` meaning something else should stop returning it.

- Keep the page's state when `onRefresh` switches between null and a callback. The scaffold now always builds its scroll listeners and refresh layer, so scroll position, focus and the bar survive the change.

## 0.8.0

- Replace the scaffold's stock refresh control with a Liquid Prism one. `onRefresh` now draws a black drop out of the Dynamic Island, out of the notch on iPhones that have one, or out of the top edge elsewhere. It holds a ring that fills from the top, pinches off into a circle once a release will refresh, spins level with the bar's controls, and merges back after a check. Haptics mark the drop leaving, the pinch-off and the completion.

- `onRefresh` now works with `body` as well as `slivers`, and no longer holds the content down while refreshing.

- Move the scaffold's large title down with the content when the page is pulled past its top, as a native large title does.

- Add `LiquidPrismSystemChrome.dynamicIsland`, the island's frame in the Flutter view (private UIKit API where available, estimated from the safe area otherwise).

- Add pull to refresh to the consumer agent skill and the component guide.

## 0.7.4

- Remove the default grey fill behind held toolbar actions; retain glass press motion and explicit `pressedColor` overrides.

- Ignore duplicate status-bar notifications during app touches so iPhone Duo title/action taps do not also scroll the page to the top. Genuine system taps keep working.

- Improve light regular-glass rim contrast over bright backgrounds by matching the slightly darker native face while preserving white highlights.

## 0.7.3

- Add a portable consumer agent skill and integration guide for adaptive scaffolds, scroll edges, component defaults and verification.

- Match native large-title exit behavior: fade without the compact title’s blur, in both scaffold and sliver app bars.

- Expand Scaffold Lab with navigation and scaffold style overrides, title compositions, dock placement, standalone app-bar and body previews, and reset controls.
- Animate title avatar compositions and scaffold header height with spring motion, respecting Reduce Motion and interrupted transitions.
- Let the Conversation showcase cycle through above-avatar, inline-avatar, and title-only layouts.

## 0.7.2

- Add `LiquidPrismScaffold.contentInsetsOf` so external overlays can align with
  the same safe area and side rail as scaffold titles and content.
- Keep Scaffold Lab glass aligned while sheets cover or reveal the page, using
  plain covered-page transforms with Cupertino drag and scroll coordination.

## 0.7.1

- Suppress the outgoing header edge on initial downward scroll. Reveal the
  compact title and its edge during actual upward restoration; scroll-away
  expanded headings do not build a compact title. Accessories retain their edge.
- Keep scaffold bottom-bar edges soft, or off when scroll edges are disabled,
  even when the top edge uses the hard variant.

- Regroup action-only toolbars without replaying entry/exit animations;
  genuinely added and removed actions retain their transitions.

- Keep side-rail controls fixed when the navigation title minimizes, and retain
  stable content insets by default so header hide/reveal does not double scroll.
  Explicit enabled safe-area adjustment still follows the bar.

- Keep centered navigation titles aligned with the content area beside corner
  status regions, and keep crowded interactive titles usable. Sheets no longer
  reserve horizontal space for the window status bar above them.
- Preserve rounded ancestor clips around scroll-edge blur, haze and fade when
  backdrop filters restore their clip state, including moving sheet surfaces.
- Keep accessory rows visible and interactive while scaffold and sliver titles
  and controls minimize. Retain the accessory's scroll edge and content clearance.
- Add sticky, scroll-away and reveal-on-scroll-up modes to Scaffold Lab, including
  the full set of lab controls when presented in a sheet.

## 0.7.0

- Breaking: replace untyped scaffold/sliver `actions` and nested toolbar `groups`
  with typed `toolbar`/`content`: text or icon actions, native menus, custom
  widgets, explicit groups, fixed/flexible spacers and positional placements.
- Keep visible title widgets interactive. Add independent inline/expanded title
  alignment and SwiftUI-style whole-bar minimization/restoration and inset control.
  Match measured large-title fade timing and separate inline reveal/hide profiles.
  Center inline titles by default, use Cupertino title fonts, and match standard
  navigation content clearance to 10 points.
- Add navigation control-row height, directional content padding
  and expanded-title extent. Add scaffold dock margins, alignment and maximum
  widths, plus top, bottom, leading and trailing tab docks.
- Breaking: rename `GlassButtonAppearance` to `GlassButtonStyle`, button variants
  to `GlassButtonVariant.regular`/`.prominent` and `buttonStyle` to `variant`.
  Text buttons generate their label; add icon/label arrangements, native control
  sizes, intrinsic/fill sizing, visual bounds and borrowed focus/cursor control.
- Breaking: standardize search styling on `style: GlassSearchStyle(...)` and
  direct typography on `textStyle:`.
- Breaking: replace tab `expanded` with `GlassTabBarSizing.compact`/`.fill` and
  remove obsolete navigation `revealCurve` (use `revealSpring`). Vertical tabs
  honor explicit label behavior. Compact sizing remains the default.
- Avoid rebuilding scroll edges during viewport layout when the keyboard or
  dock geometry changes.
- Add a runnable composition example and [0.7 migration guide](doc/releases/0.7.md).
  Native rendering, shader packets and controlled-input contracts are preserved.

- Match native Liquid Glass defaults more closely: setting-dependent regular
  frost, dark face grading and gray fill, regular rim lighting and standalone
  shadow strength. Explicit blur and optical overrides retain precedence.
- Match native large-button typography and spacing, semantic button tint,
  grouped-background tab accents, disabled prominent buttons and dark disabled
  segmented selections. Dark resting selections use a translucent gray fill and
  white text that adapt to the backdrop. Correct showcase separator alpha.
- Add reproducible SwiftUI/Flutter material and control-state comparisons, with
  captured native inputs documented separately from renderer fits.

## 0.6.0

- The held slider's shadow in light appearance matches native over white:
  it was about twice as dark and darkest right at the lens. The light held
  slider drops the contact shadow and uses fainter layers fitted to a native
  capture; dark appearance is unchanged.

- The iOS plugin reports the device's Liquid Glass setting (iOS 27's
  Settings > Appearance > Liquid Glass slider, UIKit's glass tint amount) as
  `LiquidPrismSystemChrome.deviceGlassTintAmount`, and Reduce Transparency as
  `LiquidPrismSystemChrome.reduceTransparency`, updating when either changes.
  The tint amount uses private UIKit API looked up at runtime under names
  assembled from fragments; it is null where iOS has no such setting, so
  earlier versions are unaffected. Reduce Transparency is public on every
  version.

- Regular and clear glass follow the device's Liquid Glass setting, live:
  below iOS's default the frost becomes the native blur fill (the blurred
  backdrop over the sharp one with normal and lighten blends at the measured
  opacities) and the white face fill thins, so glass shows more of the
  backdrop; above it the face whitens and clear glass frosts. At the default
  glass looks as before. `LiquidPrismThemeData.glassTint` fixes the amount;
  an explicit `blur` or `optics` keeps a plain frost. Reduce Transparency is
  not applied to glass yet: no capture shows what it changes.

- Regular glass rims read on white as native ones do: a full-white band
  inside the dark line at the top and bottom. Regular glass now draws the
  vertical key/fill highlight with the matrix iOS 27.2 uses for it, instead of
  a diagonal top-left lobe, and the inner ring shadow is drawn in the optical
  pass under that highlight. Clear glass's dark line is lighter, matching the
  measured −0.3 bias.

- Light regular glass keeps its face off-white, as native does. Its face now
  follows native glass measured over flat greys: over a light backdrop it is
  slightly off-white (254 over white, 249 over the grouped background), so the
  rim's white band shows, and over mid and dark greys it is up to 3 levels
  brighter than before. This replaces an earlier brightness cap that made
  glass over white too dark.

- `LiquidPrismThemeData.refraction` sets the rim refraction of every glass
  surface that uses its material's optics, as `blur` sets their frost, keeping
  the rest of each recipe. The showcase's Studio gains a Whole app switch that
  applies its Frost and Refraction to every screen.

- On iOS, a scaffold `bottomBar` without a tab bar sits on the tab bar's line,
  21 points above the screen's edge, inside the home indicator's inset as
  native bottom glass does (a bottom search field rests 28 points up), instead
  of above the 34-point inset. Above a tab bar or the keyboard it is unchanged.

- In the iPhone Duo rail layout the scaffold's top bar row is 48 points, the
  height of the rail's circles, so top bar controls and titles sit on native's
  line (a SwiftUI text button there is 48.3 points from the 24-point margin).

- `LiquidPrismButton`'s standard and menu text buttons default to 14 points of
  vertical padding instead of 15, so a 17-point label is 48 points tall, the
  height of a SwiftUI bar text button (Invite measured 48.3 on iPhone Duo) and
  of the package's icon buttons. Pass `padding` to keep the old size.

- `LiquidPrismTitle` puts a navigation title in a glass capsule, with an
  optional `leading` inside it (a small avatar) and an optional `avatar`
  above it that the capsule tucks under, as SwiftUI chat screens do;
  `onPressed` makes it a button. The scaffold grows its bar to fit while the
  leading control and actions keep their row. Geometry is configurable with
  `GlassTitleStyle`, locally or in `GlassNavigationBarStyle.titleCapsule`.
- On iPhone Duo, a `trailing` widget such as a glass text button ends at the
  content's edge beside the rail, as measured, instead of 16 points in.

- On iPhone Duo, `LiquidPrismScaffold` moves `leading` (the back button)
  into the vertical rail with the actions: at the top of the column, under
  the status bar, the actions 12 points below it, as native apps do. It no
  longer keeps a top bar row to itself there. With horizontal bars nothing
  changes.

- In dark appearance the held tab pill's selected copy keeps the lighter
  resting tint (native measured 48, 192, 248 for system blue) instead of the
  plain accent, and the glyph fringe fills missed channels with the dark
  housing's grey rather than black, so icons no longer turn dark blue with
  navy fringes.

- Icons and labels under the held tab pill's rim bend like native: the
  lens's −17.5 content-wrapper displacement now runs before the −14
  ContentLensing pass over the same 11.2-point field, so glyphs near the rim
  stretch smoothly into it instead of folding back as mirrored copies.

- Glass inside a `LiquidPrismGroup` or `LiquidPrismScaffold` now sits on top of
  scroll edge effects and edge blurs, refracting the blurred, faded content as
  SwiftUI glass does. The effects are no longer cut out of the glass, which
  had made it read more see-through over blurred content; each effect takes its
  own two backdrop captures again.

- The held tab pill magnifies its selected icons and labels 1.16× about each
  item, native's held selected item source transform, scaled with the lift.

- The held tab pill tints its selected icons and labels with the plain accent,
  as native does (system blue 0, 136, 255), instead of the darker resting
  selection color; the color follows the lift.

- Icons and labels under the held tab pill's rim fringe like native: red and
  blue sit about 2.7 points apart (they were under 0.9) in amber and azure
  bands, and the fringe reaches about 14 points in, where it stopped at 4.8.
  The fringe scales with the pill's height, so the segmented selection's
  labels fringe at about 0.6 of the tab's. Where a shifted channel misses the
  glyph it now shows the bar's tone instead of painting the other channels
  near black.

- Lifted switch, segmented and tab lenses bend the backdrop at their rim as
  strongly as native: each takes its own native rim refraction (switch 11.5
  over 6.9 points, segmented 8.8 over 7.04, tab pill 10.5 over 7, like the
  slider's 11.1 over 6.66), where they reused the underlay's 9-point
  displacement over a fitted 12-point band. The broad underlay minification
  is now a separate shader input, at native strength (9 points for every
  minifying lens, where small lenses used less), and is read after the rim
  refracts, so it no longer cancels the rim's bend at the edge. A custom
  `rimRefraction` no longer changes it; explicit `optics` still drive both.

- Tabs seen through the held or moving tab pill now show their selected icon
  and semibold label, as native does, instead of their unselected icon
  recolored. Outside the pill every tab, including the committed one, shows its
  unselected state until release.

## 0.5.4

- Cheaper optical glass shader: a moment-matched footprint pair replaces most
  four-tap integrations of compressed rim samples, reflection taps are placed
  in backdrop pixels once, and the highlight and absorption arithmetic is
  simplified. Output stays within 2/255 of 0.5.3.
- Cheaper scroll-edge blur pass (about 15% less fragment time on the default
  strips) and tab foreground lens (about half, skipping the contour search
  outside the pill's box), with no visible change.
- The scroll edge haze no longer blurs the whole screen every frame. It was a
  blur composed under a mask shader, and Impeller limits only the outermost
  backdrop filter to its clip, so the inner blur ran over the full capture.
  The haze is now a plain blur clipped to the strips, weighted by a `dstIn`
  gradient child; captures match the previous output within 1/255. The
  `edge_haze.frag` shader asset is removed.
- Resting switch, slider and segmented-control thumbs no longer add a
  backdrop pass: at lift 0 every optic is zero and the white fill covers the
  lens, so the thumb paints only its fill until it is held. Custom lens
  optics or frost, a presence fade and the tab pill keep the glass.
- Scrolling under `LiquidPrismScaffold` and a pinned `LiquidPrismSliverAppBar`
  no longer repaints the bars every frame once the title has settled and the
  scroll edge is at full strength.
- Glass springs stop once their remaining motion is under a quarter of a
  physical pixel and half an 8-bit color step, instead of ticking for another
  0.3-0.4 s.

## 0.5.3

- The `leading` slot of `LiquidPrismScaffold` and `LiquidPrismSliverAppBar`
  is now bounded by the actions and `trailing` (12 points before them), so a
  wide leading widget, such as a menu trigger with a long label, ellipsizes
  instead of running under them.
- An inline title taller than the bar's row (two lines at a large text size,
  say) now scales down to fit the row instead of overflowing it.

## 0.5.2

- Fix the action capsules jumping to the middle of the screen while a new
  capsule grew in (an empty group gaining an item): the entering group now
  keeps the bar's height instead of filling the height the bar offers.

## 0.5.1

- Content now starts 16 points below the bar's controls, matching the
  16-point side margins (`LiquidPrismScaffold.topBarClearance`; native keeps
  14). Under a large title it still starts at the end of the title's row.

## 0.5.0

- Pinned `SliverPersistentHeader`s in `LiquidPrismScaffold.slivers` now pin
  below the bar, as documented, instead of behind it: the bar's inset is a
  pinned sliver, so a page's sticky tabs stack beneath the controls while
  content still scrolls under the bar.
- Add `trailing` to `LiquidPrismScaffold` and `LiquidPrismSliverAppBar`: a
  widget of your own before the action capsules, such as a status pill.
- Turning `scrollEdge` on after a page appears (say, once its entering
  transition settles) now fades the edge effects in, blur and fade together,
  over 0.9 s (`LiquidPrismScaffold.scrollEdgeFadeDuration`), instead of
  showing them at once; turning it off fades them out.

## 0.4.0

- Fix a second hoisted edge effect (a bottom bar's under a top bar's) being
  blurred only vertically: every effect's horizontal pass now runs before the
  vertical passes that share the group's capture.
- The large title sits 10 points lower, in its row below the bar frame, as
  measured on iOS 27 (it crowded the controls); content starts directly
  below that row. With a subtitle the title sits 3 points lower still.
- Fix the hard scroll edge's hairline, which had no width and never drew.
- The hard hairline is white at 10% in dark appearance, as measured
  (`GlassScrollEdgeStyle.darkHairlineColor`, `hairlineColorFor`).
- With actions in the bar, the inline title (and subtitle) now leads, after
  the leading control, in the scaffold and the sliver bar; without actions it
  still centres.
- The title swap now runs on springs: the inline title rises into place with
  a little bounce (`GlassNavigationBarStyle.revealSpring`, default
  `titleSpring`); `revealCurve` is deprecated.
- Add `subtitle` to `LiquidPrismScaffold` and `LiquidPrismSliverAppBar`, as
  measured from SwiftUI's `navigationSubtitle`: a 15-point title over a
  12-point secondary subtitle inline, an 11-point subtitle under a large
  title. Add `sheet: true` for bars in a sheet: controls 16 points below the
  sheet's top, with no status bar inset.
- In the scaffold and sliver bar, a hard edge now ends at the bar frame, 10 points below the
  controls, with its hairline there, as measured.
- Add `LiquidPrismScaffold.header`: content at the top of `slivers` that
  scrolls away under the bar, after which the inline title swaps in, as after
  a large title.
- Scroll a `slivers` page back to the top when its tab is tapped again
  (`LiquidPrismTabReselection`, also available to listen to) and, on iOS,
  when the status bar is tapped, so a page needs no Material `Scaffold`.
- Titles now focus in and out through a blur as they fade, as native soft
  bars do.
- Let `LiquidPrismScaffold` build the page's scroll view: `slivers:` in place
  of `body` pads the content below the bar, large title and accessory and
  above the tab bar, bottom bar and keyboard, follows its scroll and dismisses
  the keyboard on drag. `onRefresh` adds native pull to refresh below the bar;
  `scrollController` hands a page its controller.
- Add `LiquidPrismScaffold.bottomBar`: a bar pinned above the home indicator,
  tab bar or keyboard that pads the body, with a bottom scroll edge effect in
  the same glass group as the top one (one set of captures for both).
- Add `LiquidPrismScaffold.scrollDepth` so pages whose lists sit inside a tab
  view drive the bar from the visible list.
- Fix list content moving twice as fast as the finger while a large title
  collapsed: the body keeps the expanded bar's inset.
- Add `LiquidPrismSliverAppBar`, a pinned navigation bar for a
  `CustomScrollView` laid out as the scaffold's top bar: implied back
  button, inline and large titles with the measured collapse, `actions`
  (items or lists of items), an accessory row and the scroll edge effect.
  Its glass and edge effect share one glass group, so the controls refract
  the content before the effect blurs and fades it.
- Toolbar items entering or leaving now hold their final size and place:
  only their slot grows or shrinks (so the capsule resizes and neighbours
  slide), while the item blurs and fades, pinned to the side of the group
  its parent holds still. They no longer slide, scale or crop.
- Glass content now blurs as well as fades whenever glass enters or leaves,
  including Reduce Motion and presences that do not grow the lens (such as
  the search field's cancel action), as iOS does.
- Add `LiquidPrismSearchField.cancelVisibility` (and
  `GlassSearchStyle.cancelVisibility`): `GlassSearchCancelVisibility.always`
  keeps the cancel action visible and tappable while the field is unfocused,
  for a full-screen search whose cancel closes it. The default stays
  `focused`.

## 0.3.0

- Let `LiquidPrismScaffold.actions` hold several trailing capsules: each
  element is a `GlassToolbarItem` or a list of them (`[[filter], [share,
  more]]`), laid out as `LiquidPrismToolbar`. A flat list is still one
  capsule.
- Draw regular glass's thin dark outline all the way round in light
  appearance, as iOS 27 does: the top and bottom now keep about 30% of the
  ends' strength instead of fading out, so the white rim reads against it.
- Fix glass over a scroll edge effect refracting the blurred, faded content.
  The effect's clip walk to its group started at its own content layer and
  never hoisted, and neighbouring members (a bar button above a search-field
  accessory) left each other unshared through their reflection reach. They
  now share the pre-effect captures unless their glass overlaps, and their
  shadows paint over the effect rather than under it.
- Add tab `onLongPressed` using Flutter's long-press timeout, with cancellation,
  selection suppression, accessibility and feedback through the existing owner.
- Add theme `GlassHaptics` event routing for tabs/sidebar, switch and slider;
  per-component haptics flags remain authoritative. Native fallbacks are retained.
- Consume the scaffold body's bottom keyboard viewInset when folded into padding;
  `resizeToAvoidBottomInset: false` delegates avoidance to descendants.
- Add opt-in segmented `fitLabels` sizing and label padding (10 points a side,
  measured from a fixed-size iOS 27 Picker); fixed sizing stays default. Text scaling grows fitted slots and track height.
- Add badges to tabs and toolbar items (`GlassBadge.count`, `.text`, `.dot`)
  with accessible values and theme/local colour and typography. Geometry and
  type are measured on iOS 27: an 18.33-point capsule (18 on toolbar items),
  12-point medium white text, 4 points of padding, counts never shortened
  unless `overflow` is set.
- Add scaffold inline and large titles with a themed `GlassNavigationBarStyle`,
  measured on iOS 27: 17-point semibold inline title, 34-point bold large title
  in a 52-point row that scrolls with the content, then a timed swap (large out
  in 0.18 s, inline in over 0.53 s rising 15 points). Native icon-only tab bars
  keep the 86-point pitch, so that default is unchanged.
  See `doc/package_features_spec.md`.
- Add a lift-scaled chromatic fringe along held segmented/tab selection rims,
  including labels/icons. `GlassLensStyle.chromaticAberration` controls the
  full-lift red–blue split (3.5 points for segments/tabs, 0 for switches/sliders);
  `chromaticBand` controls depth (4.8 points). Explicit zero disables the fringe.
  Tab `rimRefraction` now scales this fringe and the preserved bright glint;
  its old radial rim split is replaced. Switch/slider generic dispersion stays
  unchanged. The foreground shader effect packet grows from vec2 to vec4.
  Labels take a quarter of the split, blended half with the plain glyph.

- Bend the segmented control's labels near the held selection's rim, as iOS 27
  does, with the tab bar's foreground lens filter. It applies only while the
  selection is lifted. New `GlassSegmentedStyle` fields `refractContent`,
  `contentRefraction` and `contentDepth` (defaults true, 14, 11.2) tune or
  disable it. No shader change.
- Make the held slider knob read like native, especially in dark mode. Its lens
  now uses the slider's measured glassBackground inputs (rim 6.66 points with
  11.1 points of refraction, face black .1) and keeps its measured contact
  shadow while lifted, with the measured ring geometry; rim light (1.0) and the
  ambient/ring opacities (.12/.2) are fitted to SwiftUI captures. New
  `GlassLensStyle` fields `rimWidth`, `rimRefraction`, `rimLight`, `faceBlack`
  and `heldContactShadow` tune this per component; switches, segmented controls
  and tab pills keep their current look by default. No shader change.
- Play a light impact on iOS when a slider drag, tap, key or accessibility step
  reaches its minimum or maximum, once per arrival and only when the parent
  accepts the value. External updates, cancellation and rejected values are
  silent. `LiquidPrismSlider.haptics` and `GlassSliderStyle.haptics` (default
  on) turn it off.
- Add scroll edge effects and progressive edge blurs. `LiquidPrismEdgeBlur`
  blurs and fades up to two opposite edges of its child per pixel along the
  smootherstep `GlassEdgeFade.curve`, as backdrop passes of a new
  `edge_blur.frag` that pairs its Gaussian taps into bilinear reads and derives
  the weights incrementally, so a 4-point strip costs 37 texture reads per pass
  instead of 73. `LiquidPrismScrollEdge` is a bar's effect driven by scroll
  progress; `LiquidPrismScrollFade` springs a scrollable's edges in and out;
  `GlassScrollEdgeStyle` themes them. `LiquidPrismScaffold` draws the effect
  under its top bar while the body is scrolled (`scrollEdge: false` opts out).
- Let edge effects join a glass group's shared captures. Inside a
  `LiquidPrismGroup` or the scaffold, the effect's passes are hoisted with the
  members' frost, cut out of their contours, and the members' optical passes
  read a capture taken before the fade and finished blur: glass over a scroll
  edge refracts the unblurred content beneath it, as native bar buttons do,
  and a bar's effect and capsules cost two captures together instead of two
  each. Plain clips (a viewport, an app bar's toolbar clip) between a member
  and its group no longer keep it out of the shared capture; the hoisted shadow
  and frost are clipped the same way.
- Measure iOS 27's scroll edge effect and build the defaults from it
  (`doc/native_scroll_edge_spec.md`, probe under `tool/native_scroll_edge_probe`).
  The native effect is a 16-point blur at half opacity under a light 1.5-point
  variable blur and a half fade, masked by a smoothstep; `GlassFadeCurve` is
  now smoothstep, `GlassEdgeBlur` gains `haze`, `hazeOpacity`, `hazePlateau`,
  `floor` and `fadeFloor`, and the defaults become sigma 1.5, falloff 98,
  reach 50 and a 16-point haze at half opacity. The old 4-point blur and
  smootherstep were fitted by eye and read harder than native.
- Measure the native dark appearance too: the same masks and radii, a 0.6
  haze and a fade of about 0.58 toward black; the package keeps 0.5 for both
  appearances. The haze shader divides the engine's blur by its coverage so
  the effect does not darken toward the screen's edge. The showcase drops the
  opaque gradient it used to paint over the top of every page, which ran to
  solid background above the Dynamic Island and read as the effect fading out
  before the edge.
- Add `GlassScrollEdgeVariant.hard`, the effect under a bar with a background:
  no reach past the bar, a 2-point blur keeping a quarter of its strength to
  the edge, the fade and haze held flat, and a one-pixel 10% black hairline.
  `LiquidPrismScaffold.accessory` adds a row of tabs or controls below the top
  bar inside the effect and the body's padding.
- Imply a leading control in `LiquidPrismScaffold`: when its route can pop
  and `leading` is null, a `LiquidPrismBackButton` draws a back chevron, or a
  close mark on a fullscreen dialog, and pops the route.
  `automaticallyImplyLeading: false` opts out. The button is public; its back
  glyph is shifted half a point toward its tip so it reads centred in the
  circle. An app sets its own glyphs once through `GlassToolbarStyle.backIcon`
  and `closeIcon` in the theme, which the implied button uses too;
  `backIconShift` and `backIconMirrors` (false for a glyph that draws the same
  in both directions) tune the shift. The body now keeps 14 points clear below the
  top bar's capsules (`LiquidPrismScaffold.topBarClearance`), as the measured
  iPhone Duo content safe area does.
- Animate toolbar items. `LiquidPrismToolbarGroup` materializes items in and
  out as `items` changes, resizing the capsule, and takes an empty list, which
  materializes the capsule away. New `LiquidPrismToolbar` lays several groups
  out with a gap and collapses empty ones, so every group a bar can show is
  declared once. `GlassToolbarStyle` gains `itemTransition`,
  `itemTransitionStyle` and `groupSpacing`.
- Cut backdrop pass breaks for grouped glass: shared members' shadows and frost
  passes are painted ahead of the first shared optical pass, so a group of
  frosted surfaces costs two backdrop captures instead of two per surface.
  `LiquidPrismScaffold` now groups its leading control, actions and tab bar.
- Skip the tab bar's separate 2-point selection blur pass when the housing is
  frosted at 3 points or more; `GlassTabBarStyle.selectionBlur` still forces it.
- Trim the optical shader: an interior fast path past every inward band, a
  two-tap rim reflection and two-tap broad lobe, major-axis-only footprint
  integration, and reflection reads ending where they can no longer move a
  channel by two 8-bit steps. Measured on the isolated Metal optical pass: 7–9%
  less GPU time for capsule bars and 15–17% for panels, with buttons inside the
  harness's scheduling noise.
- Fix unreliable drags on the tab bar, slider, switch and segmented control.
  Their axis-locked drag recognizers lost diagonal drags to an enclosing
  scroll view, needed 18 points of along-axis travel, and a held slider or
  segment cancelled its own drag when a slightly diagonal move rejected the
  tap recognizer first. Each control now has one recognizer that claims a
  touch on its thumb or selection (all of a switch or tab bar) on contact and
  drags at any angle past the touch slop, so flicks work without a hold.
- Holding an inactive part now does what iOS 27 does (measured with the
  native control probe): a held slider track lifts and moves nothing, and a
  held unselected segment dims its label to .4 while the selection stays put,
  then travels there, lifted, on release. A drag from an unselected segment
  moves that highlight. Mostly vertical drags from these parts scroll an
  enclosing list. Track taps and track drags keep their behavior. Controls no
  longer expose no-op scroll semantics actions from their drag detector.
- Fix the held tab pill's double rim and lighter patch. The touch glow under
  the pill was clipped to the housing's resting contour while the housing
  expands by `1 + 14.14 / width` on contact, so the glow ended in a hard edge
  about 7 points inside the expanded housing's ends: a second capsule with a
  lighter patch inside it, which the pill's underlay minification then pulled
  into concentric rims near its edge. The glow is now clipped to the housing as
  drawn. This predates the shared-capture change and is not caused by it.
- Add `GlassTabBarStyle.rimRefraction` (0–2, default 1, 0 turns it off): the
  held tab pill splits its view of the housing per color channel and adds a
  bright glint just inside its contour, so the pill reads as a refracting rim
  on a dark housing instead of nearly disappearing. Only the tab bar's pill
  uses it; buttons, toolbars, switches, sliders and segments are unchanged.
  The values are fitted by eye to an iOS 27 dark capture, not recovered from
  the native operator.

## 0.2.1

- Lay out a `LiquidPrismToolbarGroup` with a single item as a circle, as iOS
  draws a lone bar button: 44 × 44 in a navigation bar and 48 × 48 in a bottom
  toolbar or rail, following custom heights and insets. A navigation group was
  a 46 × 44 capsule. An explicit `GlassToolbarItem.width` is still honored, so
  a wider item stays a capsule; groups of several items are unchanged.

- Let apps host their own autocomplete on `LiquidPrismSearchField`:
  `fieldBuilder` wraps the glass capsule as an overlay anchor, `groupId` and
  `onTapOutside` share the editor's tap region, `onFocusChange` reports focus
  transitions, and `suffixBuilder` keeps or replaces the clear action. The
  cancel action now belongs to the editor's tap region group.
- Add `GlassSearchStyle.padding` and `prefixPadding` for the editor and the
  default search icon.
- Measure the tab foreground lens's raster scale when the scene is composed,
  from the layers that composite it. An ancestor transform that animates
  beneath a repaint boundary, such as a page scaled behind a modal sheet, no
  longer leaves the held tab's glyph lens on a stale scale, and a
  `Transform(filterQuality: ...)` ancestor no longer distorts it.
- In debug builds, report once when glass sits under an ancestor that moves it
  after it is rasterized, such as `Transform(filterQuality: ...)`. Glass cannot
  align its refraction and rim there; remove the `filterQuality` (see
  [rendering](doc/rendering.md#ancestor-transforms)).
- Add `example/lib/transform_main.dart`, a fixture placing glass, a toolbar
  group and a tab bar on a page scaled as a sheet's covered page.

## 0.2.0

- Add `LiquidPrismScaffold` and `GlassChromePlacement`: floating glass chrome
  that moves into the iPhone Duo sensor-bar rail and follows window resizes.
  On iOS 27.1 it follows UIKit's `verticalBarEdge` and reserved regions,
  collapses rail actions into an overflow menu when space runs out, and
  exposes a partial fold as a display feature.
- Add `LiquidPrismSystemChrome`, `GlassSystemChrome` and
  `GlassReservedRegion`: UIKit's vertical bar edge and reserved regions for
  your own sheets, dialogs and bars, with the fold added to
  `MediaQuery.displayFeatures` app-wide. `LiquidPrismViewController` and
  `setVerticalBarBehavior` let an app opt out of the vertical bar.
- Add `GlassTabBarPlacement.sidebar` to `LiquidPrismScaffold`: the measured
  native sidebar at regular width, with a hide and show toggle. Report UIKit's
  size classes as `GlassSystemChrome.horizontalSizeClass` and
  `verticalSizeClass`.
- Match the native sidebar's glass material and its show and hide motion: the
  panel slides on a measured spring while content reflows beneath it, and the
  show toggle materializes in place. Hiding the sidebar no longer moves the tabs
  into the tab bar or rail, matching iOS.
- Add `LiquidPrismVisibility`, `LiquidPrismPresence`, `GlassTransition` and
  `GlassTransitionStyle`: glass materializes in and out from the live backdrop
  while its content fades and sharpens, with a theme-level `transition`.
- Animate the search field's cancel action: the field shortens while the
  button slides in from the trailing edge and fades, with `cancelSpring`.
- Keep tab labels steady under the pill while it is dragged or lifted.
- Reserve the rail strip when UIKit reports a vertical bar edge without an
  inset, as for an app on the left of Split View. The showcase reflows its
  sections into two columns around a bent fold.
- End the rail's tab bar above system UI at the rail's bottom (the closed
  iPhone Duo in landscape), and put top actions beside a status bar in a top
  corner (the unfolded iPhone Duo in portrait), as native bars do.
- Add `axis` to `LiquidPrismTabBar` and `LiquidPrismToolbarGroup` for the
  measured vertical rail layout.
- Present native menus in the Flutter view's own window and close them when
  it resizes.
- Rebuild the showcase with native large titles, grouped lists and content
  that scrolls under its glass chrome.

- Add reusable component appearance styles and shared lens defaults through
  `LiquidPrismThemeData`, with partial inheritance and typed `copyWith`/`merge`.
- Expose small-control springs, minimum lift, velocity deformation and decay
  through `GlassControlMotion` and `GlassSpring`.
- Add circular icon buttons, search editor options, typed input-phase callbacks,
  slider accessibility formatting and configurable tab foreground refraction.
- Preserve native geometry, motion, palette and controlled-value defaults.
- Add a runnable API example, component/style guides and agent implementation docs.

- Match the measured iOS 27 interaction motion: tab pills lift into a glass
  lens with bar and icon scaling, glide on touch, chase the finger through a
  spring and stretch with speed; buttons use the native press and release
  springs and glow timing. `GlassMotion` gains press and release bounce fields.
- Remove the former native glass-rendering plugin, platform views, and rendering-mode API. Popup menus use the separate UIKit bridge.
- Calibrate regular material colors against SwiftUI and share foreground/selection defaults across platforms.

- Fix the fallback circle border in non-square layouts.
- Simplify renderer dispatch and batch grouping without changing the public API.
- Document research, source projects and rendering limitations in dedicated guides; keep the README focused on usage.

## 0.1.0

- Introduce LiquidPrism surfaces, glass buttons, and controlled spring tab bars.
- Support Flutter-rendered Liquid Glass with customizable Impeller optics.
- Add app-wide appearance, tint, foreground, motion, and shape configuration.
- Support custom tab icons, optional labels, finger tracking, and independent pill blur.
- Include mobile example, regression tests, and CI build checks.
