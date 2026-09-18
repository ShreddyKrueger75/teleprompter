// Renders Resources/Assets.xcassets/AppIcon.appiconset from code, so the icon is
// reproducible and no binary art needs to live in the repo.
// Run: swift Tools/makeicon.swift
import AppKit

let out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

/// One square of artwork at `px` pixels: the prompter window, mid-read.
func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        let u = s / 1024                                   // design units -> pixels

        // macOS icon plate: 824pt square inside a 1024pt canvas, squircle-ish corners
        let plate = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
        let corner = 185 * u
        ctx.addPath(CGPath(roundedRect: plate, cornerWidth: corner, cornerHeight: corner, transform: nil))
        ctx.clip()
        ctx.setFillColor(NSColor(white: 0.055, alpha: 1).cgColor)
        ctx.fill(plate)

        // Script lines: the one on the reading line is lit, its neighbours fall away.
        let left = 236 * u, right = plate.maxX - 130 * u
        let barH = 62 * u, radius = barH / 2
        func bar(y: CGFloat, width: CGFloat, white: CGFloat) {
            let r = CGRect(x: left, y: y - barH / 2, width: width, height: barH)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.setFillColor(NSColor(white: white, alpha: 1).cgColor)
            ctx.fillPath()
        }
        let mid = plate.midY
        let gap = 176 * u
        bar(y: mid + gap, width: (right - left) * 0.74, white: 0.26)
        bar(y: mid,       width: right - left,          white: 1.00)
        bar(y: mid - gap, width: (right - left) * 0.52, white: 0.17)

        // Reading marker, the one spot of colour
        let mx = 164 * u, mh = 92 * u, mw = 66 * u
        ctx.move(to: CGPoint(x: mx, y: mid + mh / 2))
        ctx.addLine(to: CGPoint(x: mx + mw, y: mid))
        ctx.addLine(to: CGPoint(x: mx, y: mid - mh / 2))
        ctx.closePath()
        ctx.setFillColor(NSColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1).cgColor)
        ctx.fillPath()
        return true
    }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(px), height: CGFloat(px)))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Every size the Mac App Store requires, as idiom/size/scale triples.
let sizes = [16, 32, 128, 256, 512]
var images: [[String: String]] = []
for pt in sizes {
    for scale in [1, 2] {
        let px = pt * scale
        let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
        try draw(px).write(to: out.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(pt)x\(pt)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: out.appendingPathComponent("Contents.json"))
print("wrote \(images.count) icon images to \(out.path)")
