#!/usr/bin/env swift
import AppKit
import CoreText
import Foundation

// Renders crisp BrandLogo / BrandWordmark PNGs from vector paths (no soft screenshots).

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)

func ensureDir(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed for \(url.lastPathComponent)"])
    }
    try data.write(to: url, options: .atomic)
    fputs("wrote \(url.path) (\(Int(image.size.width))x\(Int(image.size.height)))\n", stderr)
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

func drawWordmark(height: CGFloat, darkBackground: Bool) -> NSImage {
    let logoSize = height * 0.84
    let padding = height * 0.08
    let gap = height * 0.22
    let fontSize = height * 0.48

    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let redAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.882, green: 0.114, blue: 0.282, alpha: 1), // #e11d48
        .kern: -fontSize * 0.02
    ]
    let medColor = darkBackground
        ? NSColor(calibratedWhite: 0.92, alpha: 1)
        : NSColor(calibratedRed: 0.129, green: 0.122, blue: 0.122, alpha: 1) // #211F1F
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
    let width = padding + logoSize + gap + textSize.width + padding
    let image = NSImage(size: NSSize(width: ceil(width), height: ceil(height)))
    image.lockFocus()
    defer { image.unlockFocus() }

    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    if darkBackground {
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }

    let logo = drawLogo(size: logoSize)
    let logoY = (height - logoSize) / 2
    logo.draw(in: NSRect(x: padding, y: logoY, width: logoSize, height: logoSize))

    let textOrigin = NSPoint(
        x: padding + logoSize + gap,
        y: (height - textSize.height) / 2 - height * 0.02
    )
    text.draw(at: textOrigin)
    return image
}

do {
    let logoDir = root.appendingPathComponent("RedMed/Assets.xcassets/BrandLogo.imageset")
    let wordDir = root.appendingPathComponent("RedMed/Assets.xcassets/BrandWordmark.imageset")
    try ensureDir(logoDir)
    try ensureDir(wordDir)

    // Displayed up to ~96pt on launch; ship dense PNGs so @3x stays sharp.
    let logoScales: [(String, CGFloat)] = [
        ("BrandLogo.png", 180),
        ("BrandLogo@2x.png", 360),
        ("BrandLogo@3x.png", 540)
    ]
    for (name, px) in logoScales {
        try savePNG(drawLogo(size: px), to: logoDir.appendingPathComponent(name))
    }

    // Wordmark height matches the SVG viewBox ratio (~76pt design).
    let wordScales: [(String, CGFloat)] = [
        ("BrandWordmark.png", 159),
        ("BrandWordmark@2x.png", 318),
        ("BrandWordmark@3x.png", 477)
    ]
    for (name, h) in wordScales {
        // Transparent bg — launch / UI sit on light surfaces.
        try savePNG(drawWordmark(height: h, darkBackground: false), to: wordDir.appendingPathComponent(name))
    }

    // Also refresh the shared frisky asset copy when present.
    // Web display is 72 CSS px → 216 @3x; keep Pages / SW payloads small.
    let sharedLogo = root.deletingLastPathComponent().appendingPathComponent("assets/BrandLogo.png")
    if FileManager.default.fileExists(atPath: sharedLogo.deletingLastPathComponent().path) {
        try savePNG(drawLogo(size: 216), to: sharedLogo)
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
