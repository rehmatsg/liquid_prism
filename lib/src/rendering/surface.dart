import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/prism_pressable.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';
import 'package:liquid_prism/src/navigation/prism_system_chrome.dart';
import 'package:liquid_prism/src/rendering/glass_group.dart';
import 'package:liquid_prism/src/rendering/prism.dart';
import 'package:liquid_prism/src/rendering/prism_display.dart';
import 'package:liquid_prism/src/rendering/prism_transition.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface_render.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Live backdrop glass with sharp foreground content.
class PrismSurface extends StatelessWidget {
  /// Creates a surface using local, themed, and native material defaults.
  const new({
    super.key,
    this.glass,
    this.blur,
    this.optics,
    this.shape,
    this.shadow,
    this.child,
  });

  /// Material override, otherwise inherited from the theme.
  final PrismGlass? glass;

  /// Backdrop blur sigma in logical pixels.
  final double? blur;

  /// Complete optical override for the material recipe.
  final PrismOptics? optics;

  /// Surface contour, otherwise inherited or resolved from optics.
  final PrismShape? shape;

  /// Whether exterior and inset material shadows are painted.
  final bool? shadow;

  /// Foreground content painted above the glass.
  final Widget? child;

  @override
  Widget build(BuildContext context) => RawPrismSurface(
    glass: glass,
    blur: blur,
    optics: optics,
    shape: shape,
    shadow: shadow,
    child: child,
  );
}

/// Internal surface with resolved component roles and optical state.
@internal
class RawPrismSurface extends StatefulWidget {
  const new({
    super.key,
    this.glass,
    this.blur,
    this.optics,
    this.shape,
    this.shadow,
    this.child,
    this.role = PrismRole.surface,
    this.lensRim = 0,
    this.chromaticSplit = 0,
    this.chromaticBand = 0,
    this.underlay = 0,
    this.resting = false,
    this.materialOptics = false,
    this.disabledProminent = false,
  }) : assert(
         blur == null || (blur >= 0 && blur <= 12),
         'blur must be null or in [0, 12]',
       ),
       assert(lensRim >= 0, 'lensRim must be nonnegative'),
       assert(chromaticSplit >= 0, 'chromaticSplit must be nonnegative'),
       assert(chromaticBand >= 0, 'chromaticBand must be nonnegative'),
       assert(underlay >= 0, 'underlay must be nonnegative');
  final PrismGlass? glass;
  final double? blur;

  final PrismOptics? optics;

  final PrismShape? shape;

  final bool? shadow;
  @internal
  final PrismRole role;

  @internal
  final double lensRim;

  @internal
  final double chromaticSplit;
  @internal
  final double chromaticBand;

  @internal
  final double underlay;

  @internal
  final bool resting;

  @internal
  final bool materialOptics;
  @internal
  final bool disabledProminent;
  final Widget? child;
  @override
  State<RawPrismSurface> createState() => _RawPrismSurfaceState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<PrismOptics>('optics', optics))
      ..add(DiagnosticsProperty<PrismGlass>('glass', glass))
      ..add(DoubleProperty('blur', blur))
      ..add(DiagnosticsProperty<PrismShape>('shape', shape));
  }
}

class _RawPrismSurfaceState extends State<RawPrismSurface> {
  PrismGlass get _material =>
      widget.glass ?? _theme.glass ?? PrismGlass.regular;
  PrismThemeData _theme = const PrismThemeData();

  final ValueListenable<double?> _deviceTint =
      PrismSystemChrome.deviceGlassTintAmount;
  @override
  void initState() {
    super.initState();
    _deviceTint.addListener(_deviceTintChanged);
    PrismDisplay.headroom.addListener(_displayChanged);
  }

  void _displayChanged() {
    if (mounted) setState(() {});
  }

  void _deviceTintChanged() {
    if (mounted && _theme.glassTint == null) setState(() {});
  }

  double _tint = GlassTint.standard;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('glassTint', _tint));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = PrismTheme.of(context);
    _ensureShader();
  }

  ui.FragmentShader? _shader;
  @override
  void didUpdateWidget(RawPrismSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureShader();
  }

  bool _loadingShader = false;
  void _ensureShader() {
    if (_material.variant == PrismGlassVariant.identity ||
        _material.isInteractive ||
        _shader != null ||
        _loadingShader) {
      return;
    }
    if (PrismShaderCache.program != null) {
      _shader = PrismShaderCache.createShader();
    } else if (Prism.isShaderSupported) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    _loadingShader = true;
    try {
      await PrismShaderCache.ensureLoaded();
      if (mounted &&
          _material.variant != PrismGlassVariant.identity &&
          !_material.isInteractive) {
        setState(() {
          _shader = PrismShaderCache.createShader();
        });
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'liquid_prism',
          context: ErrorDescription('while compiling the glass shader'),
        ),
      );
    } finally {
      _loadingShader = false;
    }
  }

  @override
  void dispose() {
    _deviceTint.removeListener(_deviceTintChanged);
    PrismDisplay.headroom.removeListener(_displayChanged);
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_material.variant == PrismGlassVariant.identity) {
      return widget.child ?? const SizedBox.shrink();
    }
    if (_material.isInteractive) {
      return PrismPressable.feedback(
        child: RawPrismSurface(
          glass: _material.interactive(false),
          optics: widget.optics,
          shape: widget.shape,
          shadow: widget.shadow,
          blur: widget.blur,
          role: widget.role,
          lensRim: widget.lensRim,
          chromaticSplit: widget.chromaticSplit,
          chromaticBand: widget.chromaticBand,
          underlay: widget.underlay,
          resting: widget.resting,
          materialOptics: widget.materialOptics,
          child: widget.child,
        ),
      );
    }
    final theme = _theme;
    final optics = widget.optics ?? theme.optics;
    final shape =
        widget.shape ??
        (widget.optics == null
            ? null
            : PrismShape.rect(cornerRadius: widget.optics!.cornerRadius)) ??
        theme.shape ??
        (optics == null
            ? PrismShape.capsule
            : PrismShape.rect(cornerRadius: optics.cornerRadius));
    if (widget.resting) {
      return ClipPath(
        clipper: PrismShapeClipper(shape),
        child: widget.child ?? const SizedBox.shrink(),
      );
    }
    final presenceScope = PrismPresence.maybeData(context);
    final presence = presenceScope == null
        ? 1.0
        : presenceScope.progress.value.clamp(0.0, 1.0);
    final materialize = presenceScope?.materialize ?? false;
    final tint = _tint = GlassTint.resolve(theme.glassTint, _deviceTint.value);
    final recipe =
        PrismRecipe.resolve(
              _material,
              PrismTheme.materialBrightnessOf(context),
              widget.role,
              customOptics: optics != null,
              disabledProminent: widget.disabledProminent,
            )
            .withTint(tint)
            .withPresence(presence)
            .withLensRim(widget.lensRim)
            .withChromaticFringe(widget.chromaticSplit, widget.chromaticBand)
            .withUnderlay(widget.underlay * (materialize ? presence : 1))
            .withShadow(widget.shadow ?? theme.shadow ?? true);
    var style = resolveSurfaceOptics(
      optics ?? recipe.optics(shape.radius),
      cornerRadius: shape.radius,
      widgetOptics: widget.optics,
      widgetBlur: widget.blur,
      themeBlur: theme.blur,
      themeRefraction: theme.refraction,
    );
    final followsTint =
        widget.blur == null &&
        theme.blur == null &&
        (optics == null || widget.materialOptics);
    var frost = resolveSurfaceFrost(
      recipe,
      style.frost,
      tint: tint,
      followsTint: followsTint,
    );

    final bleed =
        followsTint && recipe.kind == 1 && recipe.dark && frost.isNotEmpty
        ? presence
        : 0.0;
    if (presence < 1) {
      frost = [for (final pass in frost) pass.scaled(presence)];
      style = style.copyWith(
        refraction: materialize ? style.refraction * presence : null,
        dispersion: materialize ? style.dispersion * presence : null,
      );
    }

    style = style.copyWith(
      frost: math.min(FrostPass.effectiveSigma(frost), 12),
    );
    final shader = _shader;
    final press = PrismPressFeedback.of(context);
    final pressScale = PrismPressFeedback.scaleOf(context);

    final content = PrismPressFeedback(
      progress: press,
      child: PrismContentPresence(
        presence: presence,
        blur: presenceScope?.contentBlur ?? 0,
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
    final fallbackTint = Color.alphaBlend(
      _material.tintColor ?? const Color(0x00000000),
      optics?.tint ?? Color(recipe.dark ? 0x99000000 : 0x99FFFFFF),
    );
    final glass = CustomPaint(
      painter: shader == null
          ? PrismExteriorShadow(
              shape,
              strength: recipe.shadowStrength,
              nativeControl: recipe.usesNativeControlShadow,
              hdrSurface: isHDRSurface(recipe),
            )
          : null,
      child: shader != null
          ? PrismSurfaceRenderWidget(
              shader: shader,
              style: style,
              shape: shape,
              recipe: recipe,
              frost: frost,
              bleed: bleed,
              sizedLens:
                  optics == null &&
                  theme.refraction == null &&
                  recipe.kind == 1 &&
                  widget.role == PrismRole.surface,
              press: press,
              scale: pressScale,
              group: PrismGroupScope.of(context),
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
              child: ClipPath(
                clipper: PrismShapeClipper(shape),
                child: content,
              ),
            )
          : ClipPath(
              clipper: PrismShapeClipper(shape),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: frostReachOf(frost) + 4,
                  sigmaY: frostReachOf(frost) + 4,
                ),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Color.alphaBlend(
                      Color.from(
                        alpha: 0.08 * press,
                        red: 1,
                        green: 1,
                        blue: 1,
                      ),
                      fallbackTint,
                    ),
                    shape: shape.isSmooth
                        ? RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(shape.radius),
                            side: const BorderSide(color: Color(0x55FFFFFF)),
                          )
                        : shape.isCircle
                        ? const CircleBorder(
                            side: BorderSide(color: Color(0x55FFFFFF)),
                          )
                        : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(shape.radius),
                            side: const BorderSide(color: Color(0x55FFFFFF)),
                          ),
                  ),
                  child: content,
                ),
              ),
            ),
    );

    return shader == null
        ? Transform.scale(
            scale: pressScale,
            child: Opacity(opacity: recipe.presence, child: glass),
          )
        : glass;
  }
}
