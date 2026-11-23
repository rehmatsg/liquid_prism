import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Semantic source colors resolved for light or dark appearance.
@immutable
final class PrismColors {
  /// Creates a semantic palette for [brightness].
  const new(this.brightness);

  /// Light appearance palette.
  static const PrismColors light = PrismColors(Brightness.light);

  /// Dark appearance palette.
  static const PrismColors dark = PrismColors(Brightness.dark);

  /// Resolves the active palette from [context].
  static PrismColors of(BuildContext context) => PrismTheme.colorsOf(context);

  /// Appearance brightness for this palette.
  final Brightness brightness;

  bool get _dark => brightness == Brightness.dark;

  /// Semantic blue accent.
  Color get blue => _dark ? const Color(0xFF0091FF) : const Color(0xFF0088FF);

  /// Semantic brown accent.
  Color get brown => _dark ? const Color(0xFFB78A66) : const Color(0xFFAC7F5E);

  /// Semantic cyan accent.
  Color get cyan => _dark ? const Color(0xFF3CD3FE) : const Color(0xFF00C0E8);

  /// Semantic green accent.
  Color get green => _dark ? const Color(0xFF30D158) : const Color(0xFF34C759);

  /// Semantic indigo accent.
  Color get indigo => _dark ? const Color(0xFF6D7CFF) : const Color(0xFF6155F5);

  /// Semantic mint accent.
  Color get mint => _dark ? const Color(0xFF00DAC3) : const Color(0xFF00C8B3);

  /// Semantic orange accent.
  Color get orange => _dark ? const Color(0xFFFF9230) : const Color(0xFFFF8D28);

  /// Semantic pink accent.
  Color get pink => _dark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55);

  /// Semantic purple accent.
  Color get purple => _dark ? const Color(0xFFDB34F2) : const Color(0xFFCB30E0);

  /// Semantic red accent.
  Color get red => _dark ? const Color(0xFFFF4245) : const Color(0xFFFF383C);

  /// Semantic teal accent.
  Color get teal => _dark ? const Color(0xFF00D2E0) : const Color(0xFF00C3D0);

  /// Semantic yellow accent.
  Color get yellow => _dark ? const Color(0xFFFFD600) : const Color(0xFFFFCC00);

  /// Primary label color.
  Color get label => _dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// Resting fill color for small control thumbs.
  Color get controlThumb => const Color(0xFFFFFFFF);

  /// Label color above a resting segmented selection.
  Color get controlThumbLabel => label;

  /// Default inactive slider track color.
  Color get sliderTrack => _dark
      ? const Color.from(alpha: .1, red: 1, green: 1, blue: 1)
      : const Color.from(alpha: .1, red: 0, green: 0, blue: 0);

  /// Secondary label color.
  Color get secondaryLabel => _dark
      ? const Color.from(
          alpha: 0.6,
          red: 235 / 255,
          green: 235 / 255,
          blue: 245 / 255,
        )
      : const Color.from(
          alpha: 0.6,
          red: 60 / 255,
          green: 60 / 255,
          blue: 67 / 255,
        );

  /// Tertiary label color.
  Color get tertiaryLabel => _dark
      ? const Color.from(
          alpha: 0.2980392156862745,
          red: 235 / 255,
          green: 235 / 255,
          blue: 245 / 255,
        )
      : const Color.from(
          alpha: 0.2980392156862745,
          red: 60 / 255,
          green: 60 / 255,
          blue: 67 / 255,
        );

  /// Quaternary label color.
  Color get quaternaryLabel => _dark
      ? const Color.from(
          alpha: 0.1568627450980392,
          red: 235 / 255,
          green: 235 / 255,
          blue: 245 / 255,
        )
      : const Color.from(
          alpha: 0.17647058823529413,
          red: 60 / 255,
          green: 60 / 255,
          blue: 67 / 255,
        );

  /// Primary system fill color.
  Color get systemFill => _dark
      ? const Color.from(
          alpha: 0.36,
          red: 120 / 255,
          green: 120 / 255,
          blue: 128 / 255,
        )
      : const Color.from(
          alpha: 0.2,
          red: 120 / 255,
          green: 120 / 255,
          blue: 128 / 255,
        );

  /// Secondary system fill color.
  Color get secondarySystemFill => _dark
      ? const Color.from(
          alpha: 0.32,
          red: 120 / 255,
          green: 120 / 255,
          blue: 128 / 255,
        )
      : const Color.from(
          alpha: 0.16,
          red: 120 / 255,
          green: 120 / 255,
          blue: 128 / 255,
        );

  /// Tertiary system fill color.
  Color get tertiarySystemFill => _dark
      ? const Color.from(
          alpha: 0.24,
          red: 118 / 255,
          green: 118 / 255,
          blue: 128 / 255,
        )
      : const Color.from(
          alpha: 0.12,
          red: 118 / 255,
          green: 118 / 255,
          blue: 128 / 255,
        );

  /// Quaternary system fill color.
  Color get quaternarySystemFill => _dark
      ? const Color.from(
          alpha: 0.18,
          red: 118 / 255,
          green: 118 / 255,
          blue: 128 / 255,
        )
      : const Color.from(
          alpha: 0.08,
          red: 116 / 255,
          green: 116 / 255,
          blue: 128 / 255,
        );

  /// Label color for disabled controls.
  Color get disabledLabel => tertiaryLabel;

  /// Named accent colors for pickers and demos.
  Map<String, Color> get accents => Map<String, Color>.unmodifiable({
    'blue': blue,
    'brown': brown,
    'cyan': cyan,
    'green': green,
    'indigo': indigo,
    'mint': mint,
    'orange': orange,
    'pink': pink,
    'purple': purple,
    'red': red,
    'teal': teal,
    'yellow': yellow,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismColors && other.brightness == brightness;

  @override
  int get hashCode => brightness.hashCode;
}
