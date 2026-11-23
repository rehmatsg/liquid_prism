// swift tool/hdr_probe/analyze.swift [--x 114 --y 175 --count 160] IMAGE...
// ImageIO/Core Image decode the original HDR image, never an SDR conversion.
import Foundation
import CoreImage
import ImageIO

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String, _ fallback: Int) -> Int {
  guard let i = args.firstIndex(of: name), i + 1 < args.count,
        let value = Int(args[i + 1]) else { return fallback }
  args.removeSubrange(i...i + 1)
  return value
}
let x = option("--x", 114)
let y = option("--y", 175)
let count = option("--count", 160)
var rawPath: String?
if let i = args.firstIndex(of: "--raw"), i + 1 < args.count {
  rawPath = args[i + 1]
  args.removeSubrange(i...i + 1)
}
let horizontal = args.contains("--horizontal")
args.removeAll { $0 == "--horizontal" }
let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
let context = CIContext(options: [.workingColorSpace: space])
var records: [[String: Any]] = []
for path in args {
  let url = URL(fileURLWithPath: path)
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CIImage(contentsOf: url, options: [.expandToHDR: true]) else {
    fatalError("Cannot decode \(path)")
  }
  let w = Int(image.extent.width), h = Int(image.extent.height)
  var pixels = [Float](repeating: 0, count: w * h * 4)
  pixels.withUnsafeMutableBytes {
    context.render(image, toBitmap: $0.baseAddress!, rowBytes: w * 16,
                   bounds: image.extent, format: .RGBAf, colorSpace: space)
  }
  if let rawPath {
    try pixels.withUnsafeBufferPointer { buffer in
      try Data(buffer: buffer).write(to: URL(fileURLWithPath: rawPath))
    }
  }
  // render(toBitmap:) produces top-to-bottom rows here; do not invert y.
  func rgb(_ x: Int, _ y: Int) -> [Float] {
    let i = (y * w + x) * 4
    return Array(pixels[i..<i + 3])
  }
  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
  records.append([
    "file": url.lastPathComponent, "width": w, "height": h,
    "depth": properties[kCGImagePropertyDepth as String] ?? NSNull(),
    "profile": properties[kCGImagePropertyProfileName as String] ?? NSNull(),
    "contentHeadroom": image.contentHeadroom,
    "colorSpace": "extendedLinearSRGB",
    "pageWhite": rgb(min(200, w - 1), min(120, h - 1)),
    "profileX": x,
    "samples": (max(0, horizontal ? x : y)..<min(horizontal ? w : h, (horizontal ? x : y) + count)).map { position in
      [horizontal ? "x" : "y": position,
       "rgb": rgb(horizontal ? position : min(max(0, x), w - 1),
                  horizontal ? min(max(0, y), h - 1) : position)] as [String: Any]
    },
  ])
}
let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
