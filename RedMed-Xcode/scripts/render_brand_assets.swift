#!/usr/bin/env swift
import AppKit
import CoreText
import Foundation

// Scales repo-root pheart.png into BrandLogo / BrandWordmark / AppIcon slots.
// pheart is the circular heart on cream #fff7f7 (same as Color.redmedBg).

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)

func ensureDir(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func savePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed for \(url.lastPathComponent)"])
    }
    try data.write(to: url, options: .atomic)
    fputs("wrote \(url.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))\n", stderr)
}

/// Renders at exact pixel dimensions regardless of the screen's Retina backing
/// scale — `NSImage.lockFocus()` silently doubles output on Retina displays,
/// which previously made every "size N" export come out as N*2 pixels.
func renderPixels(_ pixels: Int, draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.cgContext.interpolationQuality = .high
    draw(ctx.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func heartPath(in rect: CGRect) -> CGPath {
    // Normalized from the brand SVG path (32 x ~30 design space).
    let path = CGMutablePath()
    let sx = rect.width / 32
    let sy = rect.height / 30
    let o = rect.origin
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * sx, y: o.y + (30 - y) * sy) }

    path.move(to: P(24, 0))
    path.addCurve(to: P(16, 7), control1: P(19.6, 0), control2: P(17, 3.4))
    path.addCurve(to: P(8, 0), control1: P(15, 3.4), control2: P(12.4, 0))
    path.addCurve(to: P(0, 9), control1: P(3.2, 0), control2: P(0, 4))
    path.addCurve(to: P(16, 28), control1: P(0, 19), control2: P(7, 26))
    path.addCurve(to: P(32, 9), control1: P(25, 26), control2: P(32, 19))
    path.addCurve(to: P(24, 0), control1: P(32, 4), control2: P(28.8, 0))
    path.closeSubpath()
    return path
}

func ecgPath(in heartRect: CGRect) -> CGPath {
    // Original polyline in the 32x30 heart design space.
    let pts: [(CGFloat, CGFloat)] = [
        (7, 14), (12.15, 14), (14.3, 11), (16.8, 18), (18.97, 14), (25, 14)
    ]
    let sx = heartRect.width / 32
    let sy = heartRect.height / 30
    let o = heartRect.origin
    let path = CGMutablePath()
    for (i, p) in pts.enumerated() {
        let pt = CGPoint(x: o.x + p.0 * sx, y: o.y + (30 - p.1) * sy)
        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
    }
    return path
}

func drawLogo(size: CGFloat, cornerRadius: CGFloat? = nil) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)

    // Flat solid tile — no gradient, no sheen, circular border.
    let tileColor = NSColor(calibratedRed: 0.882, green: 0.114, blue: 0.180, alpha: 1) // #e11d2e
    let tile = CGPath(ellipseIn: bounds, transform: nil)
    ctx.addPath(tile)
    ctx.clip()
    ctx.setFillColor(tileColor.cgColor)
    ctx.fill(bounds)

    // Heart + ECG (centered, ~64% of tile so it clears the circular edge)
    let heartW = size * 0.64
    let heartH = heartW * (30.0 / 32.0)
    let heartRect = CGRect(
        x: (size - heartW) / 2,
        y: (size - heartH) / 2 - size * 0.01,
        width: heartW,
        height: heartH
    )
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(heartPath(in: heartRect))
    ctx.fillPath()

    ctx.setStrokeColor(NSColor(calibratedRed: 0.949, green: 0.227, blue: 0.275, alpha: 1).cgColor)
    ctx.setLineWidth(max(2, size * 0.045))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(ecgPath(in: heartRect))
    ctx.strokePath()

    return image
}

func scaledSquare(_ image: NSImage, size: Int, opaqueBackground: NSColor? = nil) -> NSBitmapImageRep {
    guard let bg = opaqueBackground else {
        return renderPixels(size) { ctx in
            image.draw(
                in: NSRect(x: 0, y: 0, width: size, height: size),
                from: .zero,
                operation: .copy,
                fraction: 1
            )
        }
    }
    // App Store icon: no alpha *plane* at all (not just opaque pixels) — an
    // NSBitmapImageRep can't be a no-alpha NSGraphicsContext target, so render
    // into a raw CGContext(.noneSkipLast) instead, which supports it.
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    ctx.interpolationQuality = .high
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    ctx.setFillColor(bg.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    image.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: ctx.makeImage()!)
}

func drawWordmark(logo: NSImage, height: Int, darkBackground: Bool) -> NSBitmapImageRep {
    let heightF = CGFloat(height)
    let logoSize = heightF * 0.84
    let padding = heightF * 0.08
    let gap = heightF * 0.22
    let fontSize = heightF * 0.48

    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let redAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.882, green: 0.114, blue: 0.282, alpha: 1), // #e11d48
        .kern: -fontSize * 0.02
    ]
    let medColor = darkBackground
        ? NSColor(calibratedWhite: 0.92, alpha: 1)
        : NSColor(calibratedRed: 0.110, green: 0.098, blue: 0.086, alpha: 1) // #1c1917
    let medAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: medColor,
        .kern: -fontSize * 0.02
    ]

    let red = NSAttributedString(string: "Red", attributes: redAttrs)
    let med = NSAttributedString(string: "Med", attributes: medAttrs)
    let text = NSMutableAttributedString()
    text.append(red)
    text.append(med)

    let textSize = text.size()
    let width = Int(ceil(padding + logoSize + gap + textSize.width + padding))

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    if darkBackground {
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }

    let mark = scaledSquare(logo, size: Int(logoSize.rounded()))
    let logoY = (heightF - logoSize) / 2
    if let markImage = mark.cgImage {
        ctx.draw(markImage, in: CGRect(x: padding, y: logoY, width: logoSize, height: logoSize))
    }

    let textOrigin = NSPoint(
        x: padding + logoSize + gap,
        y: (heightF - textSize.height) / 2 - heightF * 0.02
    )
    text.draw(at: textOrigin)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

do {
    let repoRoot = root.deletingLastPathComponent()
    let pheartURL = repoRoot.appendingPathComponent("pheart.png")
    guard let pheart = NSImage(contentsOf: pheartURL) else {
        fputs("error: missing \(pheartURL.path)\n", stderr)
        exit(1)
    }

    let logoDir = root.appendingPathComponent("RedMed/Assets.xcassets/BrandLogo.imageset")
    let wordDir = root.appendingPathComponent("RedMed/Assets.xcassets/BrandWordmark.imageset")
    let iconDir = root.appendingPathComponent("RedMed/Assets.xcassets/AppIcon.appiconset")
    try ensureDir(logoDir)
    try ensureDir(wordDir)

    let logoScales: [(String, Int)] = [
        ("BrandLogo.png", 180),
        ("BrandLogo@2x.png", 360),
        ("BrandLogo@3x.png", 540)
    ]
    for (name, px) in logoScales {
        try savePNG(scaledSquare(pheart, size: px), to: logoDir.appendingPathComponent(name))
    }

    let wordScales: [(String, Int)] = [
        ("BrandWordmark.png", 159),
        ("BrandWordmark@2x.png", 318),
        ("BrandWordmark@3x.png", 477)
    ]
    for (name, h) in wordScales {
        try savePNG(drawWordmark(logo: pheart, height: h, darkBackground: false), to: wordDir.appendingPathComponent(name))
    }

    // App Store marketing icon: must be exactly 1024x1024 with no alpha channel.
    let redmedCream = NSColor(calibratedRed: 1, green: 0.969, blue: 0.969, alpha: 1) // #fff7f7
    try savePNG(
        scaledSquare(pheart, size: 1024, opaqueBackground: redmedCream),
        to: iconDir.appendingPathComponent("AppIcon-1024.png")
    )

    // Web display is 72 CSS px → 216 @3x; keep Pages / SW payloads small.
    let sharedLogo = repoRoot.appendingPathComponent("assets/BrandLogo.png")
    if FileManager.default.fileExists(atPath: sharedLogo.deletingLastPathComponent().path) {
        try savePNG(scaledSquare(pheart, size: 216), to: sharedLogo)
        try savePNG(scaledSquare(pheart, size: 216), to: repoRoot.appendingPathComponent("assets/pheart.png"))
        try savePNG(scaledSquare(pheart, size: 216), to: repoRoot.appendingPathComponent("BrandLogo.png"))
        try savePNG(scaledSquare(pheart, size: 216), to: repoRoot.appendingPathComponent("tapper/BrandLogo.png"))
        try savePNG(scaledSquare(pheart, size: 216), to: repoRoot.appendingPathComponent("tapper/pheart.png"))
        try savePNG(scaledSquare(pheart, size: 216), to: root.appendingPathComponent("RedMed/BrandLogo.png"))
        try savePNG(scaledSquare(pheart, size: 1024), to: root.appendingPathComponent("RedMed/pheart.png"))
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
