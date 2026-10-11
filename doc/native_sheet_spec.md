# Native sheet reference

The reference is an uncustomized SwiftUI sheet with medium/large detents and a
visible grabber on iPhone 17, iOS 27.0 (24A5370g), 402 × 874 points at 3×.
Both light and dark native fixtures passed their UI tests. Measurements query
UIView/CALayer bounds, transforms, corner radii and material inputs directly.
The reproducible probe is in tool/native_sheet_probe; raw capture data stays local.

| Property | Medium | Large |
| --- | --- | --- |
| Window frame (x, y, width, height) | 8, 415.026534, 386, 450.973466 | 0, 62, 402, 812 |
| Unscaled bounds | 402 × 469⅔ | 402 × 812 |
| Content scale | 386 / 402 | 1 |
| Edge/bottom inset | 8 | 0 |
| Top corner radii | 38 | 38 |
| Bottom corner radii | 54 | 62 |
| Grabber bounds | 60 × 4, scaled with the sheet | 60 × 4 |
| Grabber top spacing | 6 | 6 |

UIDropShadowView.preferredCornerRadii provides the asymmetric corner values;
its environmentCornerRadii are 62 on this phone. Continuous curves are used
throughout. The whole medium sheet, including its contents, scales down rather
than relaying out at a narrower width.

Native dimming source opacity is .48 in dark appearance and .2 in light.
The expanded background is #1C1C1E in dark appearance and white in light.
These live in GlassColors.sheetBarrier and GlassColors.sheetBackground.
The medium glass inputs include a 4-point blur, 20-point inner refraction band
and −60 inner refraction amount, with the regular light/dark face matrices.
Native constructors from UISheetPresentationController include a .5-second,
critically damped behavior and a separate mass=3, stiffness=1000, damping=500
behavior. The JSON preserves the call sites; they do not expose all property
bindings or the private transition scheduler.

The responsive medium-height formula (half the viewport plus the bottom safe
area minus four device pixels), scale/inset interpolation and timing mapping are
derived from this reference. Other phone/window sizes are adaptive fallbacks,
not separately measured native layouts. Private glass kernels, shadows,
entry/exit curves and body-scroll snapping remain approximations. The lower
corner clip is exact to the captured radii; the optical field retains the top
radius profile. The expanded background hides that optical approximation.

Use showLiquidPrismSheet with a body that attaches its supplied ScrollController
to a ListView or SingleChildScrollView, even for short content. This coordinates
body scrolling with resizing. The header also accepts dragging and accessible
increase/decrease actions. The sheet supports barrier/back/Escape/drag dismissal,
returned results, disabled dismissal/drag, inherited themes, keyboard expansion,
safe-area padding and Reduce Motion. Bodies receive padding/viewInsets with the
handled vertical insets removed so SafeArea and text fields do not apply them twice.

From tool/native_sheet_probe, generate the project with xcodegen and run the
SheetSpecs scheme tests on the reference simulator. Copy app Documents/specs,
Documents/extracted and Documents/motion to a raw directory named specs, layers
and motion, then run python3 tool/extract_sheet_spec.py RAW_DIRECTORY from the
repository root. The --auto launch argument captures a medium sheet without
UI automation; add --large or --light for the other reference states.
