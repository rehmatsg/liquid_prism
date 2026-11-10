import SwiftUI
import UIKit

struct NavigationSampler: UIViewRepresentable {
  func makeUIView(context: Context) -> NavigationSamplingView { NavigationSamplingView() }
  func updateUIView(_ view: NavigationSamplingView, context: Context) {}
}

final class NavigationSamplingView: UIView {
  private var displayLink: CADisplayLink?
  private var samples: [[String: Any]] = []
  private var start = CACurrentMediaTime()
  private var savedAt = 0.0

  override func didMoveToWindow() {
    super.didMoveToWindow()
    displayLink?.invalidate()
    guard window != nil else { return }
    start = CACurrentMediaTime()
    let link = CADisplayLink(target: self, selector: #selector(sample))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  private func animation(_ animation: CAAnimation) -> [String: Any] {
    var result: [String: Any] = [
      "type": String(describing: type(of: animation)), "duration": animation.duration,
      "beginTime": animation.beginTime,
    ]
    if let timing = animation.timingFunction {
      var p1: [Float] = [0, 0]
      var p2: [Float] = [0, 0]
      timing.getControlPoint(at: 1, values: &p1)
      timing.getControlPoint(at: 2, values: &p2)
      result["curve"] = p1 + p2
    }
    if let basic = animation as? CABasicAnimation {
      if let from = basic.fromValue as? NSNumber { result["from"] = from }
      if let to = basic.toValue as? NSNumber { result["to"] = to }
      result["keyPath"] = basic.keyPath
    }
    if let spring = animation as? CASpringAnimation {
      result["mass"] = spring.mass
      result["stiffness"] = spring.stiffness
      result["damping"] = spring.damping
      result["initialVelocity"] = spring.initialVelocity
      result["settlingDuration"] = spring.settlingDuration
    }
    if let group = animation as? CAAnimationGroup {
      result["children"] = group.animations?.map(self.animation) ?? []
    }
    return result
  }

  @objc private func sample() {
    guard let window, samples.count < 2400 else { return }
    let t = CACurrentMediaTime() - start
    var labels: [[String: Any]] = []
    var bars: [[Double]] = []
    var scroll: [String: Any] = [:]
    func rect(_ rect: CGRect) -> [Double] { [rect.minX, rect.minY, rect.width, rect.height] }
    func visit(_ view: UIView) {
      if let bar = view as? UINavigationBar {
        bars.append(rect(bar.convert(bar.bounds, to: window)))
      }
      if let label = view as? UILabel,
        label.text == DispersionSpecs.value("--navigation-title", "Library") {
        let layer = label.layer.presentation() ?? label.layer
        let frame = layer.convert(layer.bounds, to: window.layer.presentation() ?? window.layer)
        var animations: [[String: Any]] = []
        var filters: [String] = []
        var ancestor: CALayer? = label.layer
        while let current = ancestor, current !== window.layer {
          filters += (current.presentation() ?? current).filters?.map { String(describing: $0) } ?? []
          for key in current.animationKeys() ?? [] {
            if let value = current.animation(forKey: key) {
              var data = animation(value)
              data["key"] = key
              animations.append(data)
            }
          }
          ancestor = current.superlayer
        }
        var effectiveOpacity = 1.0
        var clippedFrame = frame
        var hidden = false
        var ancestorView: UIView? = label
        while let current = ancestorView {
          hidden = hidden || current.isHidden
          effectiveOpacity *= Double((current.layer.presentation() ?? current.layer).opacity)
          if current.clipsToBounds {
            clippedFrame = clippedFrame.intersection(current.convert(current.bounds, to: window))
          }
          ancestorView = current.superview
        }
        labels.append([
          "effectiveOpacity": hidden ? 0 : effectiveOpacity,
          "visibleFrame": clippedFrame.isNull ? [] : rect(clippedFrame),
          "fontSize": label.font.pointSize, "fontName": label.font.fontName,
          "modelFrame": rect(label.convert(label.bounds, to: window)), "frame": rect(frame),
          "alpha": label.alpha, "opacity": layer.opacity, "hidden": label.isHidden,
          "animations": animations, "filters": filters,
        ])
      }
      if let scroller = view as? UIScrollView, scroller.contentSize.height > 2000 {
        scroll = [
          "offset": scroller.contentOffset.y, "inset": scroller.adjustedContentInset.top,
          "frame": rect(scroller.convert(scroller.bounds, to: window)),
        ]
      }
      for child in view.subviews { visit(child) }
    }
    visit(window)
    samples.append(["t": t, "labels": labels, "bars": bars, "scroll": scroll])
    if t - savedAt > 0.25 {
      savedAt = t
      let suffix = [
        DispersionSpecs.value("--title-mode", "large"),
        DispersionSpecs.value("--minimization", "never"),
        flag("--restore-at-edge") ? "atScrollEdge" : "automatic",
      ].joined(separator: "-")
      let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("navigation-\(suffix).json")
      if let data = try? JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys]) {
        try? data.write(to: file, options: .atomic)
      }
    }
  }
}
