import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';
import 'package:material_ui/material_ui.dart'
    show MaterialBasedCupertinoThemeData, Theme;

const _systemFamilies = {
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
  '.SF Pro Text',
  '.SF Pro Display',
  '.SF UI Text',
  '.SF UI Display',
  '.AppleSystemUIFont',
};

/// Resolves a Prism label style from [native] metrics and the app typography.
@internal
TextStyle prismTextStyle(BuildContext context, TextStyle native) {
  final host = CupertinoTheme.of(context);
  final app = host is MaterialBasedCupertinoThemeData
      ? Theme.of(context).textTheme.bodyMedium
      : host.textTheme.textStyle;
  final family = app?.fontFamily;
  final base = family == null || _systemFamilies.contains(family)
      ? native
      : native.copyWith(
          fontFamily: family,
          fontFamilyFallback: app?.fontFamilyFallback,
        );
  return base.merge(PrismTheme.of(context).textStyle).copyWith(inherit: false);
}
