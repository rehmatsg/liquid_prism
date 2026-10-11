import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiquidPrismBench") {
      BenchChannel.register(registrar.messenger())
    }
  }
}

/// Device telemetry for lib/bench_main.dart: keeps the screen awake at a fixed
/// brightness and reports thermal state, battery and process CPU time.
enum BenchChannel {
  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "liquid_prism/bench", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setup":
        let args = call.arguments as? [String: Any]
        UIApplication.shared.isIdleTimerDisabled = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        if let brightness = args?["brightness"] as? Double {
          for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.screen.brightness = brightness
          }
        }
        result(nil)
      case "stats":
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let cpu = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6
          + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
        var brightness = -1.0
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
          brightness = Double(scene.screen.brightness)
        }
        UIApplication.shared.isIdleTimerDisabled = true
        result([
          "thermal": ProcessInfo.processInfo.thermalState.rawValue,
          "battery": Double(UIDevice.current.batteryLevel),
          "batteryState": UIDevice.current.batteryState.rawValue,
          "lowPower": ProcessInfo.processInfo.isLowPowerModeEnabled,
          "cpu": cpu,
          "brightness": brightness,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
