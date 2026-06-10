#!/usr/bin/env swift
import AppKit

_ = NSApplication.shared

func makeIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Rounded background
    let path = CGPath(roundedRect: rect, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [CGColor(red: 0.40, green: 0.65, blue: 1.0, alpha: 1),
                  CGColor(red: 0.13, green: 0.38, blue: 0.90, alpha: 1)] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: s / 2, y: s),
                           end: CGPoint(x: s / 2, y: 0), options: [])
    ctx.restoreGState()

    // White SF Symbol centered
    if let sym = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil) {
        let sp = s * 0.54
        let tinted = NSImage(size: NSSize(width: sp, height: sp))
        tinted.lockFocus()
        sym.draw(in: CGRect(x: 0, y: 0, width: sp, height: sp))
        let tc = NSGraphicsContext.current!.cgContext
        tc.setBlendMode(.sourceAtop)
        tc.setFillColor(CGColor.white)
        tc.fill(CGRect(x: 0, y: 0, width: sp, height: sp))
        tinted.unlockFocus()

        let ox = (s - sp) / 2
        let oy = (s - sp) / 2
        tinted.draw(in: CGRect(x: ox, y: oy, width: sp, height: sp))
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("error: failed to encode \(path)\n", stderr); return
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),   ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),   ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, size) in specs {
    savePNG(makeIcon(size: size), to: "\(out)/\(name)")
    print("  \(name)")
}
print("Iconset gerado em \(out)")
