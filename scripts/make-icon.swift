// Renders the VzheClip app icon (stacked history cards on a blue→violet squircle)
// into VzheClip/Assets.xcassets/AppIcon.appiconset at every size macOS needs.
// Usage: swift scripts/make-icon.swift
import AppKit

let canvas: CGFloat = 1024

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawCard(_ ctx: CGContext, center: CGPoint, angle: CGFloat, fill: CGColor, detailed: Bool) {
    let size = CGSize(width: 520, height: 400)
    let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)

    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angle * .pi / 180)

    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: color(0x1A1045, alpha: 0.45))
    ctx.addPath(roundedRect(rect, radius: 48))
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    if detailed {
        // Text lines on the left.
        let lineColor = color(0xB9BDD6)
        let lines: [(CGFloat, CGFloat)] = [(-200, 250), (-200, 190), (-200, 230), (-200, 150)]
        for (index, line) in lines.enumerated() {
            let y = 110 - CGFloat(index) * 62
            ctx.addPath(roundedRect(CGRect(x: line.0, y: y, width: line.1, height: 30), radius: 15))
        }
        ctx.setFillColor(lineColor)
        ctx.fillPath()

        // Photo thumbnail on the right: sky, sun and two mountains.
        let photo = CGRect(x: 80, y: -130, width: 150, height: 170)
        ctx.saveGState()
        ctx.addPath(roundedRect(photo, radius: 22))
        ctx.clip()
        let sky = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [color(0x7CC8FF), color(0x3D7BFF)] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: photo.maxY), end: CGPoint(x: 0, y: photo.minY), options: [])
        ctx.setFillColor(color(0xFFD45C))
        ctx.fillEllipse(in: CGRect(x: photo.maxX - 62, y: photo.maxY - 64, width: 38, height: 38))
        ctx.setFillColor(color(0x2FB67C))
        ctx.move(to: CGPoint(x: photo.minX - 10, y: photo.minY))
        ctx.addLine(to: CGPoint(x: photo.minX + 55, y: photo.minY + 95))
        ctx.addLine(to: CGPoint(x: photo.minX + 115, y: photo.minY))
        ctx.fillPath()
        ctx.setFillColor(color(0x1F8F5F))
        ctx.move(to: CGPoint(x: photo.minX + 50, y: photo.minY))
        ctx.addLine(to: CGPoint(x: photo.minX + 120, y: photo.minY + 70))
        ctx.addLine(to: CGPoint(x: photo.maxX + 10, y: photo.minY))
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()
}

func renderMaster() -> CGImage {
    let ctx = CGContext(
        data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // macOS icon grid: 824×824 body centred on a 1024 canvas, with a soft drop shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = roundedRect(body, radius: 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, alpha: 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x3B3FD8))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x3A8DFF), color(0x5B4BF0), color(0x8A3FE0)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    ctx.drawLinearGradient(background, start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])
    // Subtle top highlight.
    let highlight = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0xFFFFFF, alpha: 0.22), color(0xFFFFFF, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(highlight, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.midY), options: [])

    // Fanned history cards, back to front.
    drawCard(ctx, center: CGPoint(x: 548, y: 598), angle: 12, fill: color(0xFFFFFF, alpha: 0.45), detailed: false)
    drawCard(ctx, center: CGPoint(x: 530, y: 552), angle: 5, fill: color(0xFFFFFF, alpha: 0.7), detailed: false)
    drawCard(ctx, center: CGPoint(x: 505, y: 470), angle: -4, fill: color(0xFFFFFF), detailed: true)
    ctx.restoreGState()

    return ctx.makeImage()!
}

func resized(_ image: CGImage, to pixels: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("VzheClip/Assets.xcassets")
let iconSet = catalog.appendingPathComponent("AppIcon.appiconset")
try! FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)

let master = renderMaster()
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        writePNG(pixels == 1024 ? master : resized(master, to: pixels), to: iconSet.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}

let info = ["author": "xcode", "version": 1] as [String: Any]
let iconContents: [String: Any] = ["images": images, "info": info]
let catalogContents: [String: Any] = ["info": info]
for (url, json) in [(iconSet.appendingPathComponent("Contents.json"), iconContents),
                    (catalog.appendingPathComponent("Contents.json"), catalogContents)] {
    let data = try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: url)
}
print("Wrote \(images.count) icon sizes to \(iconSet.path)")
