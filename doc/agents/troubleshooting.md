# Troubleshooting

| Symptom | Investigate |
| --- | --- |
| Shader float RangeError after reload | Uniform packet mismatch or cached program; inspect ABI then stop/rebuild |
| Glass looks flat | Backend filter support, preload/logs, material identity, lack of painted backdrop |
| Missing unselected tab content | Foreground pass ownership/repaint boundaries and first-paint layer behavior |
| Glyph warp shifts during drag | Source crop origin, DPR/ancestor transform and contour bounds |
| Extra translucent capsule inside a lens | Shadow captured under the lens or prematurely clipped paint |
| Dark pill has a bright white hotspot | Halo kernel/opacity, material brightness and accidental face grading |
| Slider says 100% with incomplete fill | Fraction-to-fill mapping; preserve the continuous outer-2% blend |
| Fast motion produces no size change | Pointer timestamps, velocity sampling, decay and flex settings |
| A style option appears ignored | Direct argument precedence, merge wiring and final paint/layout consumption |
| False/zero overrides disappear | Nullable input handling; do not compare against default values |
| Switch has no haptics | iOS target, enabled callback, haptics precedence and physical-device testing |
| Search borrows a disposed controller | Ownership/listener migration; caller disposes caller-owned objects |
| Popup has wrong anchor | Trigger context/render bounds, keyboard/focus state and native bridge diagnostics |
| Only fallback looks correct | Real Impeller layer order and shader packet; headless tests are insufficient |

Start with a focused reproducer using the public barrel and default styles. Add
local overrides one at a time. Compare theme inheritance separately from material
sampling. An outer generic shape does not automatically override a lifted lens's
native contour; use `lens.shape` or a component lens override.

For async native presentation, verify mounted context and trigger bounds before
opening. Use the menu guide for callback/dismissal semantics. Do not recreate the
popup in Flutter to hide a bridge problem.

If a native measurement conflicts with an old fit, record provenance and update
specs/tests together. Describe the observed difference precisely; avoid claiming
pixel perfection from a single capture.
