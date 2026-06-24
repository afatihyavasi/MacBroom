// Generates a 1024×1024 starter app icon PNG (zinc/indigo squircle + glyph).
// Usage: swift scripts/_gen_icon.swift <output.png>
// Replace the result with your own 1024×1024 PNG to use a custom logo.
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let S: CGFloat = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: S, height: S)

NSGraphicsContext.saveGraphicsState()
let g = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = g
let ctx = g.cgContext

// Squircle clip (macOS-ish continuous corner ≈ 22.4% of the side).
let rect = CGRect(x: 0, y: 0, width: S, height: S)
let radius = S * 0.2237
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.clip()

// Indigo gradient background (matches the app accent).
let colors = [
    NSColor(srgbRed: 0.45, green: 0.46, blue: 0.98, alpha: 1).cgColor,  // light indigo
    NSColor(srgbRed: 0.20, green: 0.18, blue: 0.55, alpha: 1).cgColor,  // deep indigo
] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

// Soft top highlight for depth.
ctx.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
ctx.fillEllipse(in: CGRect(x: -S * 0.3, y: S * 0.45, width: S * 1.6, height: S * 0.9))

// Centered white glyph (SF Symbol → tinted white).
func whiteSymbol(_ name: String, point: CGFloat) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: point, weight: .semibold)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return nil }
    let tinted = NSImage(size: base.size)
    tinted.lockFocus()
    NSColor.white.set()
    let r = NSRect(origin: .zero, size: base.size)
    base.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()
    return tinted
}

if let glyph = whiteSymbol("wand.and.stars.inverse", point: S * 0.46) {
    let gw = glyph.size.width, gh = glyph.size.height
    glyph.draw(in: NSRect(x: (S - gw) / 2, y: (S - gh) / 2, width: gw, height: gh))
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("PNG encode failed\n".utf8)); exit(1)
}
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
