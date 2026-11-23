import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'package:liquid_prism_example/showcase/widgets.dart';

/// Mutable settings and style builders for the scaffold lab.
class ScaffoldLabOptions {
  /// Numeric style overrides keyed by lab control name.
  final values = <String, double>{};

  /// The names of currently expanded settings sections.
  final expanded = <String>{};

  /// The alignment of the inline navigation title.
  PrismTitleAlignment titleAlignment = PrismTitleAlignment.automatic;

  /// The alignment of the expanded navigation title.
  PrismTitleAlignment largeTitleAlignment = PrismTitleAlignment.automatic;

  /// The safe-area policy used during bar minimization.
  PrismMinimizationSafeArea safeArea = PrismMinimizationSafeArea.automatic;

  /// The optional override for bar minimization behavior.
  PrismMinimizationBehavior? minimization;

  /// The optional override for restoring a minimized bar.
  PrismMinimizationRestoration? restoration;

  /// The optional override for navigation chrome placement.
  PrismChromePlacement? placement;

  /// The placement of the scaffold tab bar.
  PrismTabBarPlacement tabPlacement = PrismTabBarPlacement.automatic;

  /// The placement of toolbar actions.
  PrismToolbarPlacement actionPlacement = PrismToolbarPlacement.automatic;

  /// The index of the selected title composition.
  int titleKind = 0;

  /// The index of the selected leading control.
  int leadingKind = 0;

  /// The index of the selected scaffold background.
  int background = 0;

  /// The index of the selected title-capsule material.
  int capsuleGlass = 0;

  /// The index of the selected scroll-edge fade color.
  int fadeColor = 0;

  /// The index of the selected large-title fade curve.
  int fadeCurve = 0;

  /// The index of the selected tab-bar alignment.
  int tabAlignment = 0;

  /// The index of the selected bottom-bar alignment.
  int bottomAlignment = 0;

  /// The optional override for the scroll-edge hairline.
  bool? hairline;

  /// Whether the scaffold infers a leading navigation control.
  bool implyLeading = true;

  /// Whether the lab shows trailing toolbar actions.
  bool trailing = false;

  /// Whether the lab shows a tab bar.
  bool tabs = false;

  /// Whether the scaffold resizes around the keyboard.
  bool resize = true;

  /// Whether the bottom bar includes a text field.
  bool textField = false;

  /// Whether the lab uses right-to-left text direction.
  bool rtl = false;

  /// Whether the lab supplies a body instead of slivers.
  bool bodyMode = false;

  /// Whether the lab uses a standalone sliver app bar.
  bool sliverAppBar = false;

  /// The notification depth of the lab scroll view.
  int scrollDepth = 0;

  /// Returns the numeric override for the given control key.
  double? n(String key) => values[key];

  /// Converts a numeric millisecond override to a duration.
  Duration? duration(String key) =>
      n(key) == null ? null : Duration(milliseconds: n(key)!.round());

  /// Builds a spring from response and bounce overrides.
  PrismSpring? spring(String prefix) =>
      n('${prefix}Response') == null && n('${prefix}Bounce') == null
      ? null
      : PrismSpring(
          response:
              duration('${prefix}Response') ??
              const Duration(milliseconds: 400),
          bounce: n('${prefix}Bounce') ?? .15,
        );

  /// Builds a text style from typography overrides.
  TextStyle? textStyle(String prefix) =>
      values.keys.any(
        (key) =>
            key.startsWith('${prefix}Font') ||
            key == '${prefix}Weight' ||
            key == '${prefix}LetterSpacing' ||
            key == '${prefix}LineHeight',
      )
      ? TextStyle(
          fontSize: n('${prefix}FontSize'),
          fontWeight: n('${prefix}Weight') == null
              ? null
              : FontWeight.values[n('${prefix}Weight')!.round() - 1],
          letterSpacing: n('${prefix}LetterSpacing'),
          height: n('${prefix}LineHeight'),
        )
      : null;

  /// Builds optional insets from the matching numeric overrides.
  EdgeInsetsGeometry? insets(String prefix, {bool directional = false}) {
    if (!values.keys.any((key) => key.startsWith(prefix))) return null;
    if (directional) {
      return EdgeInsetsDirectional.fromSTEB(
        n('${prefix}Start') ?? 0,
        n('${prefix}Top') ?? 0,
        n('${prefix}End') ?? 0,
        n('${prefix}Bottom') ?? 0,
      );
    }
    return EdgeInsetsDirectional.fromSTEB(
      n('${prefix}Start') ?? n('${prefix}Horizontal') ?? 0,
      n('${prefix}Top') ?? n('${prefix}Vertical') ?? 0,
      n('${prefix}End') ?? n('${prefix}Horizontal') ?? 0,
      n('${prefix}Bottom') ?? n('${prefix}Vertical') ?? 0,
    );
  }

  /// Resolves a lab alignment index to a directional alignment.
  AlignmentGeometry? alignment(int value) => switch (value) {
    1 => AlignmentDirectional.centerStart,
    2 => Alignment.center,
    3 => AlignmentDirectional.centerEnd,
    _ => null,
  };

  /// Builds the navigation-bar style from the current lab settings.
  PrismNavigationBarStyle navigation(
    PrismMinimizationBehavior behavior,
    PrismMinimizationRestoration restore, {
    required PrismTitleDisplayMode titleDisplayMode,
  }) => PrismNavigationBarStyle(
    titleDisplayMode: titleDisplayMode,
    titleAlignment: titleAlignment,
    largeTitleAlignment: largeTitleAlignment,
    minimizationBehavior: minimization ?? behavior,
    minimizationRestoration: restoration ?? restore,
    minimizationSafeArea: safeArea,
    minimizationThreshold: n('minimizationThreshold'),
    controlRowHeight: n('controlRowHeight'),
    contentPadding: insets('contentPadding', directional: true),
    gutter: n('gutter'),
    controlGap: n('controlGap'),
    contentSpacing: n('contentSpacing'),
    largeTitleExtent: n('largeTitleExtent'),
    revealExtent: n('revealExtent'),
    titleStyle: textStyle('title'),
    largeTitleStyle: textStyle('largeTitle'),
    subtitleStyle: textStyle('subtitle'),
    largeSubtitleStyle: textStyle('largeSubtitle'),
    revealSpring: spring('reveal'),
    hideSpring: spring('hide'),
    inlineTitleDelay: duration('inlineTitleDelay'),
    largeTitleFadeDuration: duration('largeTitleFadeDuration'),
    largeTitleFadeCurve: switch (fadeCurve) {
      1 => Curves.linear,
      2 => Curves.easeInOut,
      3 => Curves.easeOutCubic,
      _ => null,
    },
    titleCapsule: PrismTitleStyle(
      avatarSize: n('avatarSize'),
      avatarOverlap: n('avatarOverlap'),
      leadingSize: n('leadingSize'),
      leadingCornerRadius: n('leadingCornerRadius'),
      leadingPadding: values.keys.any((key) => key.startsWith('leadingPadding'))
          ? EdgeInsetsDirectional.fromSTEB(
              n('leadingPaddingStart') ?? 11,
              n('leadingPaddingTop') ?? 11,
              n('leadingPaddingEnd') ?? 10,
              n('leadingPaddingBottom') ?? 11,
            )
          : null,
      padding: values.keys.any((key) => key.startsWith('titlePadding'))
          ? EdgeInsets.fromLTRB(
              n('titlePaddingLeft') ?? n('titlePaddingHorizontal') ?? 14,
              n('titlePaddingTop') ?? n('titlePaddingVertical') ?? 9,
              n('titlePaddingRight') ?? n('titlePaddingHorizontal') ?? 14,
              n('titlePaddingBottom') ?? n('titlePaddingVertical') ?? 9,
            )
          : null,
      minHeight: n('titleMinHeight'),
      glass: switch (capsuleGlass) {
        1 => PrismGlass.regular,
        2 => PrismGlass.clear,
        _ => null,
      },
    ),
  );

  /// The scaffold style derived from dock geometry overrides.
  PrismScaffoldStyle get scaffold => PrismScaffoldStyle(
    tabBarAlignment: alignment(tabAlignment),
    tabBarMargin: insets('tabBarMargin'),
    tabBarMaxWidth: n('tabBarMaxWidth'),
    bottomBarAlignment: alignment(bottomAlignment),
    bottomBarMargin: insets('bottomBarMargin'),
    bottomBarMaxWidth: n('bottomBarMaxWidth'),
  );

  /// Builds the scroll-edge style from the current lab settings.
  PrismScrollEdgeStyle edge(
    PrismScrollEdgeVariant variant,
    PrismColors colors,
  ) => PrismScrollEdgeStyle(
    variant: variant,
    sigma: n('sigma'),
    falloff: n('falloff'),
    extension: n('extension'),
    floor: n('floor'),
    fadeColor: switch (fadeColor) {
      1 => colors.groupedBackground,
      2 => colors.blue,
      3 => colors.label,
      _ => null,
    },
    fadeOpacity: n('fadeOpacity'),
    haze: n('haze'),
    hazeOpacity: n('hazeOpacity'),
    hairline: hairline,
    revealExtent: n('edgeRevealExtent'),
    spring: spring('edge'),
  );

  /// Builds the settings controls and reports changes to the caller.
  Widget controls(VoidCallback changed) {
    Widget cycle<T>(
      String label,
      T value,
      List<T> choices,
      void Function(T) write, {
      String Function(T)? name,
    }) => ListRow(
      title: label,
      trailing: CupertinoButton(
        key: ValueKey('lab-$label'),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onPressed: () {
          write(choices[(choices.indexOf(value) + 1) % choices.length]);
          changed();
        },
        child: Text(
          name?.call(value) ??
              (value is Enum ? value.name : value?.toString() ?? 'Native'),
        ),
      ),
    );
    Widget toggle(String label, bool value, void Function(bool) write) =>
        ListRow(
          title: label,
          trailing: PrismSwitch(
            key: ValueKey('lab-$label'),
            label: label,
            value: value,
            onChanged: (value) {
              write(value);
              changed();
            },
          ),
        );
    Widget number(String key, double initial, double min, double max) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      key.replaceAllMapped(
                        RegExp('([a-z])([A-Z])'),
                        (m) => '${m[1]} ${m[2]}',
                      ),
                    ),
                  ),
                  Text(n(key)?.toStringAsFixed(max <= 2 ? 2 : 0) ?? 'Native'),
                  CupertinoSwitch(
                    key: ValueKey('lab-enable-$key'),
                    value: n(key) != null,
                    onChanged: (enabled) {
                      if (enabled) {
                        values[key] = initial;
                      } else {
                        values.remove(key);
                      }
                      changed();
                    },
                  ),
                ],
              ),
              if (n(key) != null)
                PrismSlider(
                  key: ValueKey('lab-$key'),
                  label: key,
                  value: n(key)!,
                  min: min,
                  max: max,
                  onChanged: (value) {
                    values[key] = value;
                    changed();
                  },
                ),
            ],
          ),
        );
    Widget section(String label, List<Widget> children) => InsetSection(
      header: label,
      children: [
        CupertinoButton(
          key: ValueKey('lab-expand-$label'),
          onPressed: () {
            if (!expanded.add(label)) expanded.remove(label);
            changed();
          },
          child: Text(
            expanded.contains(label) ? 'Hide options' : 'Show options',
          ),
        ),
        if (expanded.contains(label)) ...children,
      ],
    );
    return Column(
      children: [
        section('Structure and placement', [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Body mode owns its scrolling and insets. Refresh and custom '
              'scrolling headers use sliver mode. Notification depth 1 '
              'previews a list inside a page view.',
            ),
          ),
          cycle(
            'Title composition',
            titleKind,
            [0, 1, 2, 3, 4],
            (v) => titleKind = v,
            name: (v) =>
                ['Text', 'Capsule', 'Avatar above', 'Inline avatar', 'None'][v],
          ),
          cycle(
            'Leading control',
            leadingKind,
            [0, 1, 2],
            (v) => leadingKind = v,
            name: (v) => ['Automatic', 'Custom', 'None'][v],
          ),
          toggle('Imply back button', implyLeading, (v) => implyLeading = v),
          toggle('Trailing widget', trailing, (v) => trailing = v),
          cycle(
            'Toolbar placement',
            actionPlacement,
            PrismToolbarPlacement.values,
            (v) => actionPlacement = v,
          ),
          cycle<PrismChromePlacement?>('Chrome placement', placement, [
            null,
            ...PrismChromePlacement.values,
          ], (v) => placement = v),
          toggle('Tab bar', tabs, (v) => tabs = v),
          cycle(
            'Tab placement',
            tabPlacement,
            PrismTabBarPlacement.values,
            (v) => tabPlacement = v,
          ),
          cycle(
            'Tab alignment',
            tabAlignment,
            [0, 1, 2, 3],
            (v) => tabAlignment = v,
            name: (v) => ['Native', 'Leading', 'Center', 'Trailing'][v],
          ),
          cycle(
            'Bottom alignment',
            bottomAlignment,
            [0, 1, 2, 3],
            (v) => bottomAlignment = v,
            name: (v) => ['Native', 'Leading', 'Center', 'Trailing'][v],
          ),
          cycle(
            'Background',
            background,
            [0, 1, 2],
            (v) => background = v,
            name: (v) => ['Grouped', 'Plain', 'Tinted'][v],
          ),
          toggle('Keyboard avoidance', resize, (v) => resize = v),
          toggle('Keyboard field', textField, (v) => textField = v),
          toggle('Right to left', rtl, (v) => rtl = v),
          toggle('Body instead of slivers', bodyMode, (v) {
            bodyMode = v;
            if (v) sliverAppBar = false;
          }),
          toggle('Standalone sliver app bar', sliverAppBar, (v) {
            sliverAppBar = v;
            if (v) bodyMode = false;
          }),
          cycle('Scroll notification depth', scrollDepth, [
            0,
            1,
          ], (v) => scrollDepth = v),
        ]),
        section('Alignment and minimization', [
          cycle(
            'Inline alignment',
            titleAlignment,
            PrismTitleAlignment.values,
            (v) => titleAlignment = v,
          ),
          cycle(
            'Large alignment',
            largeTitleAlignment,
            PrismTitleAlignment.values,
            (v) => largeTitleAlignment = v,
          ),
          cycle<PrismMinimizationBehavior?>(
            'Minimization override',
            minimization,
            [null, ...PrismMinimizationBehavior.values],
            (v) => minimization = v,
          ),
          cycle<PrismMinimizationRestoration?>(
            'Restoration override',
            restoration,
            [null, ...PrismMinimizationRestoration.values],
            (v) => restoration = v,
          ),
          cycle(
            'Safe-area adjustment',
            safeArea,
            PrismMinimizationSafeArea.values,
            (v) => safeArea = v,
          ),
          cycle(
            'Large title fade curve',
            fadeCurve,
            [0, 1, 2, 3],
            (v) => fadeCurve = v,
            name: (v) =>
                ['Native', 'Linear', 'Ease in/out', 'Ease out cubic'][v],
          ),
          cycle(
            'Capsule material',
            capsuleGlass,
            [0, 1, 2],
            (v) => capsuleGlass = v,
            name: (v) => ['Native', 'Regular', 'Clear'][v],
          ),
          cycle(
            'Edge fade color',
            fadeColor,
            [0, 1, 2, 3],
            (v) => fadeColor = v,
            name: (v) => ['Native', 'Grouped', 'Blue', 'Label'][v],
          ),
          cycle<bool?>('Hard-edge hairline', hairline, [
            null,
            true,
            false,
          ], (v) => hairline = v),
        ]),
        section('Navigation geometry', [
          number('controlRowHeight', 44, 44, 88),
          number('gutter', 16, 0, 40),
          number('controlGap', 8, 0, 32),
          number('contentSpacing', 12, 0, 40),
          number('contentPaddingStart', 0, 0, 32),
          number('contentPaddingEnd', 0, 0, 32),
          number('contentPaddingTop', 0, 0, 24),
          number('contentPaddingBottom', 0, 0, 24),
          number('largeTitleExtent', 52, 0, 120),
          number('revealExtent', 52, 0, 120),
          number('minimizationThreshold', 13.33, 0, 80),
        ]),
        section('Title motion', [
          number('revealResponse', 400, 100, 900),
          number('revealBounce', 0.15, 0, 0.5),
          number('hideResponse', 500, 100, 900),
          number('hideBounce', 0, 0, 0.5),
          number('inlineTitleDelay', 12, 0, 200),
          number('largeTitleFadeDuration', 200, 0, 600),
        ]),
        section('Title capsule', [
          number('avatarSize', 64, 16, 96),
          number('avatarOverlap', 6, 0, 20),
          number('leadingSize', 22, 12, 48),
          number('leadingCornerRadius', 11, 0, 24),
          number('leadingPaddingStart', 11, 0, 28),
          number('leadingPaddingEnd', 10, 0, 28),
          number('leadingPaddingTop', 11, 0, 24),
          number('leadingPaddingBottom', 11, 0, 24),
          number('titlePaddingHorizontal', 14, 0, 32),
          number('titlePaddingVertical', 9, 0, 24),
          number('titlePaddingLeft', 14, 0, 32),
          number('titlePaddingTop', 9, 0, 32),
          number('titlePaddingRight', 14, 0, 32),
          number('titlePaddingBottom', 9, 0, 32),

          number('titleMinHeight', 38, 24, 80),
        ]),
        section('Docks', [
          number('tabBarMaxWidth', 440, 160, 700),
          number('tabBarMarginHorizontal', 0, 0, 40),
          number('tabBarMarginVertical', 8, 0, 40),
          number('tabBarMarginStart', 0, 0, 40),
          number('tabBarMarginTop', 8, 0, 40),
          number('tabBarMarginEnd', 0, 0, 40),
          number('tabBarMarginBottom', 8, 0, 40),

          number('bottomBarMaxWidth', 440, 160, 700),
          number('bottomBarMarginHorizontal', 0, 0, 40),
          number('bottomBarMarginVertical', 8, 0, 40),
          number('bottomBarMarginStart', 0, 0, 40),
          number('bottomBarMarginTop', 8, 0, 40),
          number('bottomBarMarginEnd', 0, 0, 40),
          number('bottomBarMarginBottom', 8, 0, 40),

          number('accessoryHeight', 48, 32, 100),
        ]),
        section('Scroll edge', [
          number('sigma', 1.5, 0, 12),
          number('falloff', 98, 0, 160),
          number('extension', 50, 0, 100),
          number('floor', 0, 0, 1),
          number('fadeOpacity', 0.5, 0, 1),
          number('haze', 16, 0, 40),
          number('hazeOpacity', 0.5, 0, 1),
          number('edgeRevealExtent', 16, 1, 80),
          number('edgeResponse', 400, 100, 900),
          number('edgeBounce', 0.15, 0, 0.5),
        ]),
        section('title typography', [
          number('titleFontSize', 17, 10, 48),
          number('titleWeight', 6, 1, 9),
          number('titleLetterSpacing', 0, -2, 4),
          number('titleLineHeight', 1.2, 1, 2),
        ]),
        section('largeTitle typography', [
          number('largeTitleFontSize', 34, 10, 48),
          number('largeTitleWeight', 7, 1, 9),
          number('largeTitleLetterSpacing', 0, -2, 4),
          number('largeTitleLineHeight', 1.2, 1, 2),
        ]),
        section('subtitle typography', [
          number('subtitleFontSize', 12, 10, 48),
          number('subtitleWeight', 4, 1, 9),
          number('subtitleLetterSpacing', 0, -2, 4),
          number('subtitleLineHeight', 1.2, 1, 2),
        ]),
        section('largeSubtitle typography', [
          number('largeSubtitleFontSize', 11, 10, 48),
          number('largeSubtitleWeight', 4, 1, 9),
          number('largeSubtitleLetterSpacing', 0, -2, 4),
          number('largeSubtitleLineHeight', 1.2, 1, 2),
        ]),
      ],
    );
  }
}
