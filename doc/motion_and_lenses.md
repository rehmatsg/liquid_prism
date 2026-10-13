# Motion and lifted lenses

Default motion and optics preserve the native-reference behavior. Override only
what you need; partially specified objects inherit the rest.

## Reusable lens appearance

```dart
const quietLens = GlassLensStyle(
  shadowOpacity: .06,
  ringOpacity: .03,
  shadowBlur: 6,
  shape: GlassShape.rect(cornerRadius: 16),
);

LiquidPrismTheme(
  data: const LiquidPrismThemeData(lens: quietLens),
  child: myApp,
)
```

A component style's `lens` merges over this shared default. It controls material,
complete optics, blur, shape, underlay minification and shadows. `shadow: false`
disables both the resting slider shadow and lifted shadows. Ambient/ring opacity
are separate. Blur/offset/ring-width metrics scale with lens height relative to
37.2 points unless `scaleShadows: false`; opacity does not scale with size.

The default lens uses clear glass. Switch/segment/tab underlays minify, while the
slider's underlying track does not. `minifyUnderlay` explicitly overrides that
choice. Enlarging a slider knob is separate: `GlassSliderStyle.heldScale` controls
its bounds. Keep those two settings independent.

An explicit `optics` is a complete `LiquidPrismStyle` packet. Use its `copyWith`
against a chosen preset instead of assuming unspecified fields inherit the native
lens recipe. It replaces the computed optical settings; shadow/layout settings
remain independent. Setting blur to zero is an explicit override.

### Rim and face

`rimWidth`, `rimRefraction`, `rimLight` and `faceBlack` tune the lens rim and
face without replacing the whole packet; `heldContactShadow` keeps the resting
contact shadow under a lifted lens. Lengths are for a 37.2-point-high lens and
scale with its actual height. Explicit `optics` ignores the rim fields.

The slider resolves these from the held small-lens capture in
`doc/native_controls_spec.json`. Measured: inner refraction height 6.66 and
amount 11.1, face color matrix black .1, the layer contact shadow (.14, radius 5,
offset 1) still present at the held frame, and the ring shadow geometry (width 4,
radius 3, offset 8). Mapping Apple's refraction height/amount onto this
renderer's rim band and displacement is an interpretation, not a recovered
algorithm. Fitted by eye against SwiftUI dark captures: rim light 1.0 (the
shared lens uses .6), ambient opacity .12 and ring opacity .2. The native
exterior key/fill darkening (color bias −.3) is only partly reproduced by the
existing side lobe. The switch (6.9 / 11.5, black .1) and segmented pill
(4.4 / 6.6, black 0) captures are recorded too, but those lenses keep their
accepted look; opt in per component through their `lens`.

## Small-control timing

```dart
const relaxed = GlassControlMotion(
  travel: GlassSpring(response: Duration(milliseconds: 500), bounce: .1),
  lift: GlassSpring(response: Duration(milliseconds: 300), bounce: .2),
  release: GlassSpring(response: Duration(milliseconds: 550), bounce: .15),
  minimumLiftDuration: Duration(milliseconds: 300),
);

LiquidPrismSwitch(value: enabled, onChanged: changeEnabled, motion: relaxed)
```

Use `LiquidPrismThemeData.controlMotion` for switches, sliders and segmented
controls together, or a widget's `motion` for local overrides. Fields are:

| Field | Meaning |
| --- | --- |
| `travel` | Selection, tap and external-value travel spring |
| `tracking` | Drag spring for switch/segment; grabbed sliders remain direct |
| `lift` / `release` | Growth and lowering |
| `minimumLiftDuration` | Minimum contact-to-lowering window; zero disables it |
| `flex` | Velocity deformation/recoil spring |
| `flexStrength` | Displacement per point/second; zero disables velocity input |
| `maxStretch` | Maximum fractional target deformation |
| `velocityDecay` | Stationary-sample timeout before flex target returns to zero |

A `GlassSpring` accepts duration/bounce, or Flutter physics:

```dart
const spring = GlassSpring.physical(
  SpringDescription(mass: 1, stiffness: 300, damping: 26),
);
```

Import `package:flutter/physics.dart` if your widget library does not export that
type. `description` is the resolved Flutter spring. `copyWith()` preserves a
physical spring; passing duration/bounce creates a duration preset instead.
Use positive spring responses and nonnegative minimum/decay durations.

Default switch travel is .3 s with critical damping; sliders/segments travel at
.4 s with their own damping. Switch/slider lenses lift at .27 s / .625 damping and lower
at .5 s / .7; segmented lenses use .25 s with critical damping on both edges. Switches/segments have a 220 ms minimum lift; sliders do not delay
release by default. Native spec inputs and fitted flex coupling are distinguished
in [control measurements](native_controls_spec.md).

## Buttons, toolbar and tab travel

These use `GlassMotion`, independently from small-control motion:

```dart
const motion = GlassMotion(
  response: Duration(milliseconds: 450),
  pressResponse: Duration(milliseconds: 300),
  releaseResponse: Duration(milliseconds: 400),
  pressScale: 1.10,
);
```

Button/toolbar press and release fields customize their growth. Tab travel uses
`response`/`bounce`, press scale controls its spatial amplitude, and
`dragProjection` adjusts release prediction. The tab's captured lift, tracking,
housing and deformation timings remain separate native/fitted settings. Do not
assume a shared duration changes every optical or nonspatial leg.

The tab lens has an independent foreground filter. Configure its glyph displacement
and depth through `GlassTabBarStyle.contentRefraction` / `contentDepth`, or turn it
off with `refractContent: false`. The housing minification remains a lens setting.

## Interaction guarantees

Value callbacks remain prompt; slower animation does not postpone a tap's value
change. Boundary callbacks describe input, not animation completion. Recontact
retargets momentum and replaces the minimum-lift window. Cancel, disabling,
reordering and disposal stop stale work. Parent-rejected values settle back.
RTL reverses physical travel while logical values stay stable. Reduce Motion
removes lift, stretch and animated travel even when custom motion is supplied.
