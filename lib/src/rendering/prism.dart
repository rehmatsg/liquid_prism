import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'prism_display.dart';

/// Entry point for renderer capabilities and shader initialization.
abstract final class Prism {
  /// Whether the renderer supports custom backdrop shader filters.
  static bool get isShaderSupported => ui.ImageFilter.isShaderFilterSupported;

  /// Loads rendering programs and configures optional HDR rim lighting.
  static Future<void> initialize({bool? enableHDR}) =>
      PrismShaderCache.ensureLoaded(enableHDR: enableHDR);
}

/// Shared shader programs, samplers, and blur-fill filters.
@internal
abstract final class PrismShaderCache {
  static ui.FragmentProgram? get program => _program;
  static ui.FragmentProgram? get batchProgram => _batchProgram;
  static ui.FragmentProgram? get edgeProgram => _edgeProgram;
  static ui.FragmentProgram? get fillProgram => _fillProgram;
  static ui.Image? get linearSampler => _linearSampler;
  static ui.FragmentProgram? _program;
  static ui.FragmentProgram? _batchProgram;
  static ui.FragmentProgram? _edgeProgram;
  static ui.FragmentProgram? _fillProgram;
  static ui.FragmentShader? _fillShader;
  static final Map<double, ui.ImageFilter> _fillFilters =
      <double, ui.ImageFilter>{};

  static ui.ImageFilter? fillFilter(double sigma) {
    final program = _fillProgram;
    if (program == null) return null;

    if (_fillFilters.length > 8 && !_fillFilters.containsKey(sigma)) {
      _fillFilters.clear();
    }
    return _fillFilters[sigma] ??= ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(
        _fillShader ??= program.fragmentShader()
          ..setImageSampler(
            0,
            _linearSampler!,
            filterQuality: ui.FilterQuality.low,
          ),
        filterQuality: ui.FilterQuality.low,
      ),
      inner: ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: ui.TileMode.clamp,
      ),
    );
  }

  static ui.Image? _linearSampler;
  static Future<void>? _loading;

  static Future<void> ensureLoaded({bool? enableHDR}) async {
    if (Prism.isShaderSupported) await PrismDisplay.configure(enableHDR);
    if (_loading != null) return _loading!;
    if (!Prism.isShaderSupported ||
        (_program != null && _linearSampler != null)) {
      return;
    }
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final picture = recorder.endRecording();
      try {
        _linearSampler ??= await picture.toImage(1, 1);
      } finally {
        picture.dispose();
      }
      _fillProgram = await ui.FragmentProgram.fromAsset(
        'packages/liquid_prism/shaders/frost_fill.frag',
      );
      _program = await ui.FragmentProgram.fromAsset(
        'packages/liquid_prism/shaders/glass.frag',
      );
      try {
        _batchProgram = await ui.FragmentProgram.fromAsset(
          'packages/liquid_prism/shaders/glass_batch.frag',
        );
      } catch (error) {
        debugPrint('RawPrismSurface: shared optical pass unavailable: $error');
      }
      try {
        _edgeProgram ??= await ui.FragmentProgram.fromAsset(
          'packages/liquid_prism/shaders/edge_blur.frag',
        );
      } catch (error) {
        debugPrint('RawPrismSurface: edge blur unavailable: $error');
      }
    } finally {
      _loading = null;
    }
  }

  static ui.FragmentShader? createShader() {
    final shader = _program?.fragmentShader();
    if (shader != null) {
      shader.setImageSampler(
        0,
        _linearSampler!,
        filterQuality: ui.FilterQuality.low,
      );
    }
    return shader;
  }

  static ui.FragmentShader? createEdgeShader() {
    final shader = _edgeProgram?.fragmentShader();
    if (shader != null && _linearSampler != null) {
      shader.setImageSampler(
        0,
        _linearSampler!,
        filterQuality: ui.FilterQuality.low,
      );
    }
    return shader;
  }
}
