import QuartzCore
import UIKit

/// Enables EDR only on Flutter's existing nonlinear extended-sRGB XR surface.
/// The engine owns its pixel format and color space; neither is changed here.
@MainActor
final class GlassDisplayObserver {
  var onChange: ((Double) -> Void)?
  private weak var view: UIView?
  private weak var layer: CAMetalLayer?
  private var originalEDR = false
  private var enabled = true
  private var sentinel: DisplaySentinel?
  private var notifications: [NSObjectProtocol] = []
  private var headroomObservation: NSKeyValueObservation?
  private weak var screen: UIScreen?
  private var lastHeadroom: Double?
  private var generation = 0

  static func supports(_ layer: CAMetalLayer) -> Bool {
    layer.pixelFormat == .bgra10_xr && layer.colorspace?.name == CGColorSpace.extendedSRGB
  }

  func attach(to view: UIView, enabled: Bool) {
    self.enabled = enabled
    if self.view === view { refresh(); return }
    detach()
    self.view = view
    let sentinel = DisplaySentinel(frame: view.bounds)
    sentinel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    sentinel.isUserInteractionEnabled = false
    sentinel.isAccessibilityElement = false
    sentinel.update = { [weak self] in self?.refresh() }
    self.sentinel = sentinel
    view.insertSubview(sentinel, at: 0)
    for name in [UIScreen.brightnessDidChangeNotification,
                 UIApplication.didBecomeActiveNotification,
                 UIApplication.didEnterBackgroundNotification,
                 NSNotification.Name.NSProcessInfoPowerStateDidChange] {
      notifications.append(NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.refresh() }
      })
    }
    refresh()
    // EDR headroom ramps up after the first drawable. Bounded startup reads
    // also cover OS versions that don't deliver KVO for that transition.
    let token = generation
    for delay in [0.25, 0.75, 1.5, 3.0] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        guard let self, self.generation == token else { return }
        self.refresh()
      }
    }
  }

  func detach() {
    generation += 1
    if #available(iOS 16.0, *), let layer { layer.wantsExtendedDynamicRangeContent = originalEDR }
    layer = nil
    screen = nil
    headroomObservation = nil
    notifications.forEach(NotificationCenter.default.removeObserver)
    notifications.removeAll()
    sentinel?.removeFromSuperview()
    sentinel = nil
    view = nil
    lastHeadroom = nil
  }

  func refresh() {
    guard #available(iOS 16.0, *), let view,
          let target = view.layer as? CAMetalLayer else {
      publish(1)
      return
    }
    if layer !== target {
      if let layer { layer.wantsExtendedDynamicRangeContent = originalEDR }
      layer = target
      originalEDR = target.wantsExtendedDynamicRangeContent
    }
    let supported = Self.supports(target)
    // The system's HDR usage limit (Control Center, app switcher) is not a
    // reason to drop the rim: native glass keeps its HDR rendition there.
    let allowed = UIApplication.shared.applicationState != .background
    let requested = originalEDR || (enabled && supported && allowed)
    if target.wantsExtendedDynamicRangeContent != requested {
      target.wantsExtendedDynamicRangeContent = requested
    }
    let currentScreen = view.window?.screen
    if screen !== currentScreen {
      headroomObservation = nil
      screen = currentScreen
      headroomObservation = currentScreen?.observe(\.currentEDRHeadroom, options: [.new]) {
        [weak self] _, _ in
        DispatchQueue.main.async { self?.refresh() }
      }
    }
    publish(enabled && supported && allowed ? Double(currentScreen?.currentEDRHeadroom ?? 1) : 1)
  }

  private func publish(_ value: Double) {
    let headroom = value.isFinite ? min(max(value, 1), 1.3) : 1
    guard headroom != lastHeadroom else { return }
    lastHeadroom = headroom
    onChange?(headroom)
  }
}

private final class DisplaySentinel: UIView {
  var update: (() -> Void)?
  override func didMoveToWindow() { super.didMoveToWindow(); update?() }
  override func layoutSubviews() { super.layoutSubviews(); update?() }
}
