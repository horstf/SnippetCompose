#!/usr/bin/env swift
import AppKit
import CoreGraphics

// ── Shared helpers ────────────────────────────────────────────────────────────

func makeBitmapRep(size: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0
    )!
}

func makeImage(rep: NSBitmapImageRep, size: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.addRepresentation(rep)
    return img
}

func writePNG(_ image: NSImage, to path: String) {
    guard let rep = image.representations.first as? NSBitmapImageRep,
          let data = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(path)"); return
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("Wrote \(path) (\(rep.pixelsWide)×\(rep.pixelsHigh)px)")
    } catch { print("Error writing \(path): \(error)") }
}

func monoFont(size: CGFloat) -> NSFont {
    let name = NSFont(name: "SFMono-Bold",  size: size) != nil ? "SFMono-Bold"
             : NSFont(name: "Menlo-Bold",   size: size) != nil ? "Menlo-Bold"
             : "Monaco"
    return NSFont(name: name, size: size) ?? NSFont.boldSystemFont(ofSize: size)
}

func drawText(_ label: String, fontSize: CGFloat, color: NSColor, dim: CGFloat, nudgeY: CGFloat = -0.01) {
    let paraStyle = NSMutableParagraphStyle(); paraStyle.alignment = .center
    let str = NSAttributedString(string: label, attributes: [
        .font: monoFont(size: fontSize),
        .foregroundColor: color,
        .paragraphStyle: paraStyle,
    ])
    let textSize = str.size()
    str.draw(in: CGRect(x: (dim - textSize.width) / 2,
                        y: (dim - textSize.height) / 2 + dim * nudgeY,
                        width: textSize.width, height: textSize.height))
}

// ── App icon: eggshell/beige filled key with "::C" ───────────────────────────

func renderAppIcon(size: Int) -> NSImage {
    let dim = CGFloat(size)
    let rep = makeBitmapRep(size: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: dim, height: dim))

    let pad = dim * 0.07
    let keyRect = CGRect(x: pad, y: pad, width: dim - pad * 2, height: dim - pad * 2)
    let radius = dim * 0.18
    let keyPath = CGPath(roundedRect: keyRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -dim * 0.04),
                  blur: dim * 0.06,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(keyPath)
    ctx.setFillColor(CGColor(red: 0.80, green: 0.75, blue: 0.62, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Key face — eggshell/beige gradient
    ctx.saveGState()
    ctx.addPath(keyPath)
    ctx.clip()
    let colors = [CGColor(red: 0.97, green: 0.94, blue: 0.87, alpha: 1),   // top: light eggshell
                  CGColor(red: 0.89, green: 0.85, blue: 0.75, alpha: 1)] as CFArray  // bottom: warm beige
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: dim / 2, y: keyRect.maxY),
                           end:   CGPoint(x: dim / 2, y: keyRect.minY), options: [])
    ctx.restoreGState()

    // Inner highlight rim
    ctx.saveGState()
    let rimInset = dim * 0.025
    let rimPath = CGPath(roundedRect: keyRect.insetBy(dx: rimInset, dy: rimInset),
                         cornerWidth: radius - rimInset, cornerHeight: radius - rimInset, transform: nil)
    ctx.addPath(rimPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.55))
    ctx.setLineWidth(dim * 0.022)
    ctx.strokePath()
    ctx.restoreGState()

    // Label "::C" in dark brown/black
    drawText("::C", fontSize: dim * 0.32,
             color: NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.08, alpha: 1), dim: dim)

    return makeImage(rep: rep, size: size)
}

// ── Menu bar icon: outline key, "::" text ────────────────────────────────────

func renderMenuBarIcon(pixelSize: Int) -> NSImage {
    let dim = CGFloat(pixelSize)
    let rep = makeBitmapRep(size: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: dim, height: dim))

    let stroke = dim * 0.055
    let pad = stroke / 2 + dim * 0.03
    let keyRect = CGRect(x: pad, y: pad, width: dim - pad * 2, height: dim - pad * 2)
    let radius = dim * 0.18
    let keyPath = CGPath(roundedRect: keyRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Outline only
    ctx.addPath(keyPath)
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.setLineWidth(stroke)
    ctx.strokePath()

    // Label "::"
    drawText("::", fontSize: dim * 0.45, color: .black, dim: dim)

    let img = makeImage(rep: rep, size: pixelSize)
    img.isTemplate = true
    return img
}

// ── Menu bar icon (active): filled key with "::" punched out ─────────────────

func renderMenuBarIconActive(pixelSize: Int) -> NSImage {
    let dim = CGFloat(pixelSize)
    let rep = makeBitmapRep(size: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: dim, height: dim))

    let stroke = dim * 0.055
    let pad = stroke / 2 + dim * 0.03
    let keyRect = CGRect(x: pad, y: pad, width: dim - pad * 2, height: dim - pad * 2)
    let radius = dim * 0.18
    let keyPath = CGPath(roundedRect: keyRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Filled key (solid black)
    ctx.addPath(keyPath)
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillPath()

    // Punch out "::" with .clear blend mode so it becomes transparent
    ctx.setBlendMode(.clear)
    drawText("::", fontSize: dim * 0.45, color: .black, dim: dim)
    ctx.setBlendMode(.normal)

    let img = makeImage(rep: rep, size: pixelSize)
    img.isTemplate = true
    return img
}

// ── Write helpers ─────────────────────────────────────────────────────────────

func writeDir(_ path: String) {
    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
}

func writeImageSet(_ name: String, sizes: [(Int, String)], render: (Int) -> NSImage, template: Bool) {
    let dir = "SnippetCompose/Assets.xcassets/\(name).imageset"
    writeDir(dir)
    var imageEntries = ""
    for (px, scale) in sizes {
        let filename = "\(name.lowercased())_\(scale.replacingOccurrences(of: "x", with: "")).png"
        writePNG(render(px), to: "\(dir)/\(filename)")
        imageEntries += "    { \"filename\" : \"\(filename)\", \"idiom\" : \"universal\", \"scale\" : \"\(scale)\" },\n"
    }
    imageEntries = String(imageEntries.dropLast(2)) // trim trailing comma+newline
    let templateLine = template ? ",\n  \"properties\" : { \"template-rendering-intent\" : \"template\" }" : ""
    try! """
    {
      "images" : [
    \(imageEntries)
      ],
      "info" : { "author" : "xcode", "version" : 1 }\(templateLine)
    }
    """.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
    print("Wrote \(name) Contents.json")
}

// ── Main ──────────────────────────────────────────────────────────────────────

// App icon
let appIconDir = "SnippetCompose/Assets.xcassets/AppIcon.appiconset"
writeDir(appIconDir)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    writePNG(renderAppIcon(size: size), to: "\(appIconDir)/icon_\(size)x\(size).png")
}
try! """
{
  "images" : [
    { "filename" : "icon_16x16.png",     "idiom" : "mac", "scale" : "1x", "size" : "16x16"   },
    { "filename" : "icon_32x32.png",     "idiom" : "mac", "scale" : "2x", "size" : "16x16"   },
    { "filename" : "icon_32x32.png",     "idiom" : "mac", "scale" : "1x", "size" : "32x32"   },
    { "filename" : "icon_64x64.png",     "idiom" : "mac", "scale" : "2x", "size" : "32x32"   },
    { "filename" : "icon_128x128.png",   "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",   "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",   "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",   "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",   "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024x1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""".write(toFile: "\(appIconDir)/Contents.json", atomically: true, encoding: .utf8)
print("Wrote AppIcon Contents.json")

// Menu bar idle icon
writeImageSet("MenuBarIcon",       sizes: [(18, "1x"), (36, "2x")], render: renderMenuBarIcon,       template: true)
// Menu bar active icon
writeImageSet("MenuBarIconActive", sizes: [(18, "1x"), (36, "2x")], render: renderMenuBarIconActive, template: true)
