// Offline SF Pro wordmark renderer. Requires macOS, Metal, and locally installed SF Pro.
// Fonts are resolved locally and are never copied into the output.
import Foundation
import CoreText
import CoreGraphics
import ImageIO
import Metal
import simd
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

struct Options {
    var text = "Liquid Prism"
    var output = "artifacts/branding/liquid-prism-coded.png"
    var font = "SFProDisplay-Semibold"
    var scale = 2
    var outputMultiplier = 1
    var fontSize: Float = 230
    var bevel: Float = 4.4
    var tracking: Float = -5.6
    var faceStrength: Float = 1
    var shadowStrength: Float = 0.8
}
var options = Options()
var args = CommandLine.arguments.dropFirst().makeIterator()
while let key = args.next() {
    if key == "--4k" {
        options.outputMultiplier = 2
        continue
    }
    if key == "--help" {
        print("render_wordmark [--4k] [--text TEXT] [--output PATH] [--font NAME] [--scale 1...4] [--font-size POINTS] [--tracking POINTS] [--bevel POINTS] [--face-strength FLOAT] [--shadow-strength FLOAT]")
        exit(0)
    }
    guard let value = args.next() else { fail("Missing value for \(key)") }
    switch key {
    case "--text": options.text = value
    case "--output": options.output = value
    case "--font": options.font = value
    case "--scale": options.scale = Int(value) ?? 0
    case "--font-size": options.fontSize = Float(value) ?? 0
    case "--bevel": options.bevel = Float(value) ?? 0
    case "--tracking": options.tracking = Float(value) ?? 0
    case "--face-strength": options.faceStrength = Float(value) ?? -1
    case "--shadow-strength": options.shadowStrength = Float(value) ?? -1
    default: fail("Unknown argument: \(key)")
    }
}
guard (1...4).contains(options.scale), options.fontSize > 0,
      options.bevel > 0, options.faceStrength >= 0, options.shadowStrength >= 0,
      !options.text.isEmpty else { fail("Invalid renderer options") }

let width = 1920, height = 1080
let outputWidth = width * options.outputMultiplier
let outputHeight = height * options.outputMultiplier
// Keep all layout and lighting in reference coordinates, increasing raster
// density for 4K independently from the final supersampling resolve.
let scale = options.scale * options.outputMultiplier
let w = width * scale, h = height * scale
let count = w * h
let font = CTFontCreateWithName(options.font as CFString, CGFloat(options.fontSize), nil)
guard CTFontCopyPostScriptName(font) as String == options.font else {
    fail("Font \(options.font) is unavailable; install SF Pro locally.")
}
let line = CTLineCreateWithAttributedString(NSAttributedString(
    string: options.text,
    attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTKernAttributeName as String): options.tracking]
))
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
guard bounds.width < CGFloat(width - 160) else { fail("Text is too wide for the canvas") }
// Reference fit: 230 pt SF Pro Display, baseline y=622, on a 1920 x 1080 canvas.
let originX = CGFloat(width) / 2 + 5 - bounds.midX
let baseline: CGFloat = 622
var mask = [UInt8](repeating: 0, count: count)
mask.withUnsafeMutableBytes { bytes in
    guard let ctx = CGContext(data: bytes.baseAddress, width: w, height: h,
        bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue) else { fail("Cannot create font mask") }
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    ctx.setFillColor(gray: 1, alpha: 1)
    // Draw vector outlines so no platform text smoothing or font hinting enters the mask.
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n)
        var positions = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        let attributes = CTRunGetAttributes(run) as NSDictionary
        let runFont = attributes[kCTFontAttributeName] as! CTFont
        for i in 0..<n {
            guard let path = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }
            var transform = CGAffineTransform(translationX: originX + positions[i].x,
                y: CGFloat(height) - baseline + positions[i].y)
            ctx.addPath(path.copy(using: &transform)!)
            ctx.fillPath()
        }
    }
}

// Exact squared Euclidean distance transform (lower envelope of parabolas).
// Work only around the glyphs; the surrounding canvas is a constant distance.
let pad = 90
let x0 = max(0, Int(floor(originX + bounds.minX)) - pad) * scale
let x1 = min(width, Int(ceil(originX + bounds.maxX)) + pad) * scale
let y0 = max(0, Int(floor(baseline - bounds.maxY)) - pad) * scale
let y1 = min(height, Int(ceil(baseline - bounds.minY)) + pad) * scale
let cw = x1 - x0, ch = y1 - y0
func distanceTransform(inside: Bool) -> [Float] {
    let far: Float = 1e12
    var data = [Float](repeating: far, count: cw * ch)
    for y in 0..<ch {
        for x in 0..<cw {
            if (mask[(y + y0) * w + x + x0] >= 128) == inside { data[y * cw + x] = 0 }
        }
    }
    let maxLength = max(cw, ch)
    var f = [Float](repeating: 0, count: maxLength)
    var d = f
    var v = [Int](repeating: 0, count: maxLength)
    var z = [Float](repeating: 0, count: maxLength + 1)
    func transform(_ n: Int) {
        var k = 0
        v[0] = 0; z[0] = -.infinity; z[1] = .infinity
        for q in 1..<n {
            var s: Float = 0
            while true {
                let p = v[k]
                s = ((f[q] + Float(q * q)) - (f[p] + Float(p * p))) / Float(2 * (q - p))
                if s > z[k] || k == 0 { break }
                k -= 1
            }
            k += 1; v[k] = q; z[k] = s; z[k + 1] = .infinity
        }
        k = 0
        for q in 0..<n {
            while z[k + 1] < Float(q) { k += 1 }
            let delta = q - v[k]
            d[q] = Float(delta * delta) + f[v[k]]
        }
    }
    for y in 0..<ch {
        for x in 0..<cw { f[x] = data[y * cw + x] }
        transform(cw)
        for x in 0..<cw { data[y * cw + x] = d[x] }
    }
    for x in 0..<cw {
        for y in 0..<ch { f[y] = data[y * cw + x] }
        transform(ch)
        for y in 0..<ch { data[y * cw + x] = d[y] }
    }
    return data
}
let toInk = distanceTransform(inside: true)
let toEmpty = distanceTransform(inside: false)
var distances = [Float](repeating: -Float(pad), count: count)
let pixelScale = Float(scale)
let cornerRadius: Float = 1.6
for y in 0..<ch {
    for x in 0..<cw {
        let i = y * cw + x, j = (y + y0) * w + x + x0
        let coverage = Float(mask[j]) / 255
        let signed = sqrt(toEmpty[i]) - sqrt(toInk[i])
        // Place the boundary between pixel centers, retaining the outline's fractional coverage.
        distances[j] = (signed + (signed > 0 ? -0.5 : 0.5) + coverage - (coverage >= 0.5 ? 1 : 0)) / pixelScale
        mask[j] = distances[j] >= cornerRadius ? 255 : 0
    }
}
// A small morphological opening rounds the sharp font corners into a glass contour.
let insetInk = distanceTransform(inside: true)
let insetEmpty = distanceTransform(inside: false)
for y in 0..<ch {
    for x in 0..<cw {
        let i = y * cw + x, j = (y + y0) * w + x + x0
        let signed = sqrt(insetEmpty[i]) - sqrt(insetInk[i])
        distances[j] = (signed + (signed > 0 ? -0.5 : 0.5)) / pixelScale + cornerRadius
        mask[j] = UInt8(min(255, max(0, (distances[j] * pixelScale + 0.5) * 255)))
    }
}
// Identify complete small islands, rather than using per-pixel neighborhood tests
// that would produce seams when a stroke bends through the sampling footprint.
var islands = [Float](repeating: 0, count: count)
var visited = [Bool](repeating: false, count: count)
for y in y0..<y1 {
    for x in x0..<x1 {
        let start = y * w + x
        if mask[start] < 128 || visited[start] { continue }
        var component = [start], cursor = 0
        var minX = x, maxX = x, minY = y, maxY = y
        visited[start] = true
        while cursor < component.count {
            let index = component[cursor]
            let px = index % w, py = index / w
            minX = min(minX, px); maxX = max(maxX, px)
            minY = min(minY, py); maxY = max(maxY, py)
            for neighbor in [index - 1, index + 1, index - w, index + w] {
                if neighbor >= 0, neighbor < count, mask[neighbor] >= 128, !visited[neighbor] {
                    visited[neighbor] = true
                    component.append(neighbor)
                }
            }
            cursor += 1
        }
        if maxX - minX < 46 * scale, maxY - minY < 46 * scale {
            for index in component { islands[index] = 1 }
        }
    }
}
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    fail("A Metal GPU is required")
}
let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("wordmark.metal")
let source = try String(contentsOf: sourceURL, encoding: .utf8)
let library = try device.makeLibrary(source: source, options: nil)
func pipeline(_ name: String) throws -> MTLComputePipelineState {
    guard let function = library.makeFunction(name: name) else { fail("Missing kernel \(name)") }
    return try device.makeComputePipelineState(function: function)
}
let blurPipeline = try pipeline("gaussian")
let shadePipeline = try pipeline("wordmark")
let resolvePipeline = try pipeline("resolve")
func texture(_ format: MTLPixelFormat, width: Int = w, height: Int = h) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format,
        width: width, height: height, mipmapped: false)
    descriptor.usage = [.shaderRead, .shaderWrite]
    descriptor.storageMode = .shared
    guard let texture = device.makeTexture(descriptor: descriptor) else { fail("Cannot allocate texture") }
    return texture
}
let maskTexture = texture(.r32Float)
let maskFloats = mask.map { Float($0) / 255 }
maskTexture.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0,
    withBytes: maskFloats, bytesPerRow: w * 4)
let distanceTexture = texture(.r32Float)
distanceTexture.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0,
    withBytes: distances, bytesPerRow: w * 4)
let islandTexture = texture(.r32Float)
islandTexture.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0,
    withBytes: islands, bytesPerRow: w * 4)
guard let commands = queue.makeCommandBuffer() else { fail("Cannot create command buffer") }
func dispatch(_ p: MTLComputePipelineState, width: Int = w, height: Int = h,
              setup: (MTLComputeCommandEncoder) -> Void) {
    let encoder = commands.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(p)
    setup(encoder)
    encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
    encoder.endEncoding()
}
func blur(_ input: MTLTexture, sigma: Float) -> MTLTexture {
    let intermediate = texture(.r32Float), result = texture(.r32Float)
    for pass in 0..<2 {
        var parameters = SIMD4<Float>(sigma * pixelScale, Float(pass), 0, 0)
        dispatch(blurPipeline) { encoder in
            encoder.setTexture(pass == 0 ? input : intermediate, index: 0)
            encoder.setTexture(pass == 0 ? intermediate : result, index: 1)
            encoder.setBytes(&parameters, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        }
    }
    return result
}
let smoothDistance = blur(distanceTexture, sigma: 0.65)
let broadShadow = blur(maskTexture, sigma: 10)
let contactShadow = blur(maskTexture, sigma: 3.5)
let image = texture(.rgba32Float)
var parameters = [SIMD4<Float>(pixelScale, options.fontSize, Float(baseline), options.bevel),
    SIMD4<Float>(options.faceStrength, options.shadowStrength, 0, 0)]
dispatch(shadePipeline) { encoder in
    for (i, t) in [maskTexture, smoothDistance, broadShadow, contactShadow, islandTexture, image].enumerated() {
        encoder.setTexture(t, index: i)
    }
    encoder.setBytes(&parameters, length: parameters.count * MemoryLayout<SIMD4<Float>>.stride, index: 0)
}
let resolved = texture(.rgba8Unorm, width: outputWidth, height: outputHeight)
var resolveScale = UInt32(options.scale)
dispatch(resolvePipeline, width: outputWidth, height: outputHeight) { encoder in
    encoder.setTexture(image, index: 0); encoder.setTexture(resolved, index: 1)
    encoder.setBytes(&resolveScale, length: 4, index: 0)
}
commands.commit()
commands.waitUntilCompleted()
if let error = commands.error { fail("Metal render failed: \(error)") }
var pixels = [UInt8](repeating: 0, count: outputWidth * outputHeight * 4)
resolved.getBytes(&pixels, bytesPerRow: outputWidth * 4,
    from: MTLRegionMake2D(0, 0, outputWidth, outputHeight), mipmapLevel: 0)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let provider = CGDataProvider(data: Data(pixels) as CFData)!
let cgImage = CGImage(width: outputWidth, height: outputHeight, bitsPerComponent: 8, bitsPerPixel: 32,
    bytesPerRow: outputWidth * 4, space: colorSpace,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
    decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
let output = URL(fileURLWithPath: options.output)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(output as CFURL,
    UTType.png.identifier as CFString, 1, nil) else { fail("Cannot write \(output.path)") }
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else { fail("PNG export failed") }
print("Rendered \(options.text) with \(options.font) on \(device.name): \(output.path) (\(outputWidth)x\(outputHeight), \(options.scale)x supersampling)")
