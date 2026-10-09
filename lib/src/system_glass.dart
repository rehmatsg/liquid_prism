import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'material.dart';
import 'pressable.dart';

/// System follows native glass preferences on iOS 26+. Other platforms and
/// unavailable plugins use the shader. Explicit optics/blur also use the shader.
enum GlassRendering { system, shader }

@internal
final class SystemGlass {
  SystemGlass._();
  static const _channel = MethodChannel('dev.liquidprism/system');
  static bool supported = false;
  static int appearanceVersion = 26;
  static Future<void>? _loading;
  static Future<void> initialize() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return Future.value();
    return _loading ??= _read();
  }

  static Future<void> _read() async {
    try {
      supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      supported = false;
    } on PlatformException {
      supported = false;
    }
    if (supported) {
      try {
        appearanceVersion =
            await _channel.invokeMethod<int>('appearanceVersion') ?? 26;
      } on MissingPluginException {
        appearanceVersion = 26;
      } on PlatformException {
        appearanceVersion = 26;
      }
    }
  }
}

@internal
class SystemGlassSurface extends StatefulWidget {
  const SystemGlassSurface({
    super.key,
    required this.glass,
    required this.shape,
    required this.brightness,
    required this.child,
  });
  final Glass glass;
  final GlassShape shape;
  final Brightness brightness;
  final Widget child;
  @override
  State<SystemGlassSurface> createState() => _SystemGlassSurfaceState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Glass>('glass', glass))
      ..add(DiagnosticsProperty<GlassShape>('shape', shape))
      ..add(EnumProperty('brightness', brightness));
  }
}

class _SystemGlassSurfaceState extends State<SystemGlassSurface> {
  MethodChannel? _channel;
  Map<String, Object?> get _values => {
    'clear': widget.glass.variant == GlassVariant.clear,
    'tint': widget.glass.tintColor?.toARGB32(),
    'radius': widget.shape.radius,
    'circle': widget.shape.isCircle,
    'smooth': widget.shape.isSmooth,
    'dark': widget.brightness == Brightness.dark,
  };
  @override
  void didUpdateWidget(SystemGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glass != widget.glass ||
        oldWidget.shape != widget.shape ||
        oldWidget.brightness != widget.brightness) {
      unawaited(_update());
    }
  }

  Future<void> _update() async {
    if (!mounted) return;
    try {
      await _channel?.invokeMethod<void>('update', _values);
    } on MissingPluginException {
      // A platform view may be removed while its final update is in flight.
    } on PlatformException catch (error) {
      if (mounted) debugPrint('LiquidPrism native update: $error');
    }
  }

  @override
  void dispose() {
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: UiKitView(
            viewType: 'dev.liquidprism/material',
            creationParams: _values,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (id) {
              if (!mounted) return;
              _channel = MethodChannel('dev.liquidprism/material/$id');
              unawaited(_update());
            },
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: ClipPath(
            clipper: GlassShapeClipper(widget.shape),
            child: ColoredBox(
              color: const Color(
                0xFFFFFFFF,
              ).withValues(alpha: .08 * LiquidPrismPressFeedback.of(context)),
            ),
          ),
        ),
      ),
      ClipPath(
        clipper: GlassShapeClipper(widget.shape),
        child: SystemGlassBackground(native: true, child: widget.child),
      ),
    ],
  );
}

/// Native backdrops cannot receive Flutter color matrices. The iOS embedder
/// supports blur-only backdrop filters through its platform-view composition.
@internal
class SystemGlassBackground extends InheritedWidget {
  const SystemGlassBackground({
    super.key,
    required this.native,
    required super.child,
  });
  final bool native;
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SystemGlassBackground>()
          ?.native ??
      false;
  @override
  bool updateShouldNotify(SystemGlassBackground oldWidget) =>
      native != oldWidget.native;
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('native', value: native, ifTrue: 'native'));
  }
}
