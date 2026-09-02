#!/usr/bin/env swift
import AppKit
import Foundation

// Scales repo-root BrandLogo.png into BrandLogo / BrandWordmark / AppIcon slots.
// Source art is the white heart + red ECG glyph (App Store icon flattens onto cream #fff7f7).

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)

func ensureDir(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func savePNG(_ rep: NSBitmapImageRep, to url: URL, quantize: Bool = true) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed for \(url.lastPathComponent)"])
    }
    try data.write(to: url, options: .atomic)
    if quantize { quantizePNG(at: url) }
    fputs("wrote \(url.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))\n", stderr)
}

/// NSBitmapImageRep's PNG encoder writes plain truecolor+alpha with no
/// palette reduction — 2-3x larger than needed for flat brand art. Best
/// effort only: silently no-ops when pngquant isn't on PATH (e.g. CI),
/// so the pipeline still runs without it, just with bigger files.
func quantizePNG(at url: URL) {
    let pngquant = [
        "/opt/homebrew/bin/pngquant",
        "/usr/local/bin/pngquant",
        "/usr/bin/pngquant"
    ].first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    guard let pngquant else { return }
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: pngquant)
    proc.arguments = ["--quality=85-100", "--speed", "1", "--strip", "--force", "--ext", ".png", url.path]
    proc.standardError = FileHandle.nullDevice
    proc.standardOutput = FileHandle.nullDevice
    try? proc.run()
    proc.waitUntilExit()
}

/// Renders at exact pixel dimensions regardless of the screen's Retina backing
/// scale — `NSImage.lockFocus()` silently doubles output on Retina displays,
/// which previously made every "size N" export come out as N*2 pixels.
func renderPixels(_ pixels: Int, draw: (CGContext) -> Void) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
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
    ) else {
        fatalError("Failed to allocate \(pixels)x\(pixels) bitmap rep")
    }
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Failed to create graphics context for bitmap rep")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.cgContext.interpolationQuality = .high
    draw(ctx.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
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
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        fatalError("Failed to create \(size)x\(size) no-alpha CGContext")
    }
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
    guard let cgImage = ctx.makeImage() else {
        fatalError("Failed to produce CGImage from no-alpha context")
    }
    return NSBitmapImageRep(cgImage: cgImage)
}

func drawWordmark(logo: NSImage, height: Int) -> NSBitmapImageRep {
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
    let medAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.110, green: 0.098, blue: 0.086, alpha: 1), // #1c1917
        .kern: -fontSize * 0.02
    ]

    let red = NSAttributedString(string: "Red", attributes: redAttrs)
    let med = NSAttributedString(string: "Med", attributes: medAttrs)
    let text = NSMutableAttributedString()
    text.append(red)
    text.append(med)

    let textSize = text.size()
    let width = Int(ceil(padding + logoSize + gap + textSize.width + padding))

    guard let rep = NSBitmapImageRep(
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
    ) else {
        fatalError("Failed to allocate \(width)x\(height) wordmark bitmap rep")
    }
    guard let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Failed to create graphics context for wordmark bitmap rep")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

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
    let brandLogoURL = repoRoot.appendingPathComponent("BrandLogo.png")
    guard let brandLogo = NSImage(contentsOf: brandLogoURL) else {
        fputs("error: missing \(brandLogoURL.path)\n", stderr)
        exit(1)
    }

    let logoDir = root.appendingPathComponent("RedMed/Assets.xcassets/BrandLogo.imageset")
    let wordDir = root.appendingPathComponent("RedMed/Assets.xcassets/BrandWordmark.imageset")
    let iconDir = root.appendingPathComponent("RedMed/Assets.xcassets/AppIcon.appiconset")
    try ensureDir(logoDir)
    try ensureDir(wordDir)
    try ensureDir(iconDir)

    // Drawn at RedMedChrome.logoSize (72pt) → 72 / 144 / 216. Do not ship
    // 180-pt slots; iOS still decodes the extra pixels then downscales.
    let logoScales: [(String, Int)] = [
        ("BrandLogo.png", 72),
        ("BrandLogo@2x.png", 144),
        ("BrandLogo@3x.png", 216)
    ]
    for (name, px) in logoScales {
        try savePNG(scaledSquare(brandLogo, size: px), to: logoDir.appendingPathComponent(name))
    }

    // Drawn at RedMedChrome.wordmarkHeight (42pt).
    let wordScales: [(String, Int)] = [
        ("BrandWordmark.png", 42),
        ("BrandWordmark@2x.png", 84),
        ("BrandWordmark@3x.png", 126)
    ]
    for (name, h) in wordScales {
        try savePNG(drawWordmark(logo: brandLogo, height: h), to: wordDir.appendingPathComponent(name))
    }

    // App Store marketing icon: must be exactly 1024x1024 with no alpha channel.
    let redmedCream = NSColor(calibratedRed: 1, green: 0.969, blue: 0.969, alpha: 1) // #fff7f7
    try savePNG(
        scaledSquare(brandLogo, size: 1024, opaqueBackground: redmedCream),
        to: iconDir.appendingPathComponent("AppIcon-1024.png")
    )

    // Web display is 72 CSS px → 216 @3x; keep Pages / SW payloads small.
    // repoRoot BrandLogo.png is the source (read above), not a write target here.
    let sharedLogo = repoRoot.appendingPathComponent("assets/BrandLogo.png")
    if FileManager.default.fileExists(atPath: sharedLogo.deletingLastPathComponent().path) {
        let sharedTargets = [
            sharedLogo,
            repoRoot.appendingPathComponent("assets/pheart.png"),
            repoRoot.appendingPathComponent("tapper/BrandLogo.png"),
            repoRoot.appendingPathComponent("tapper/pheart.png"),
            root.appendingPathComponent("RedMed/BrandLogo.png"),
            root.appendingPathComponent("RedMed/pheart.png")
        ]
        for target in sharedTargets {
            try savePNG(scaledSquare(brandLogo, size: 216), to: target)
        }
        // Loose BrandWordmark.png is not bundled — native uses the imageset,
        // passerby HTML never loads a wordmark image.
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
