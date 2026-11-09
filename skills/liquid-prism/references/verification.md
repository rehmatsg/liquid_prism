# Integration verification

Choose scenarios based on the affected composition, not a mandatory whole-app
sweep for every edit.

For scaffold or pinned-row changes, check regular bottom chrome and side-rail
placement, at the top, during collapse, fully pinned, reversing direction and
returning to the top. Include the app's configured spacing overrides. Check an
accessory with every supported minimization mode. Measure effect bounds in one
coordinate space when diagnosing seams; a test that asserts the same hardcoded
padding used by the implementation cannot establish continuity.

For safe-area changes, also check window resizing/rotation, keyboard visibility,
route presentation and interactive dismissal. Compare a rounded sheet and the
scaled underlying page. Ensure custom overlays align to the intended content
region rather than the entire screen. Check RTL and larger text when placement
or title sizing changes.

For glass changes, compare light/dark appearance and supported clear-to-tinted
device settings with the same background, scroll position and window geometry.
Check local/theme overrides first. Run on a real Impeller simulator or device:
headless widget tests exercise fallback rendering and cannot prove shader output.
Record platform/runtime and package version with visual evidence. Treat native
captures as observations, and renderer tuning as a fit rather than Apple's
private algorithm.

Test meaningful behavior: interactive titles still activate, disabled controls
stay disabled, parent-rejected values remain authoritative, accessory rows remain
reachable and reduced motion resolves appropriately. After Dart changes, reload
or restart the running app; after shader/asset changes, stop and rebuild. Run the
consumer app's relevant analysis/tests and repository-required checks. Report
exactly which checks ran, which device was observed and any remaining gap.
