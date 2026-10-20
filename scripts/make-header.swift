// App Store ürün sayfası kapak görseli (3840×1646, saydamlıksız PNG).
// Kullanım: swift scripts/make-header.swift <en|tr|es> <ham-görüntü-klasörü> <çıktı.png>
import AppKit

let args = CommandLine.arguments
let lang = args[1], raw = args[2], output = args[3]
let width: CGFloat = 3840, height: CGFloat = 1646

let titles: [String: (String, String)] = [
    "en": ("Signal Sort", "Rotate arrows. Route every signal."),
    "tr": ("Signal Sort", "Okları çevir, her sinyali yönlendir."),
    "es": ("Signal Sort", "Gira las flechas. Guía cada señal."),
]
let (title, tagline) = titles[lang]!

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSGradient(starting: NSColor(red: 0.10, green: 0.13, blue: 0.29, alpha: 1), ending: NSColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -30)

// Sol: logo, isim, slogan.
if let logo = NSImage(contentsOfFile: "SignalSort/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo.png") {
    logo.draw(in: NSRect(x: 260, y: height / 2 + 60, width: 300, height: 300))
}
let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 200, weight: .heavy), .foregroundColor: NSColor.white]
NSAttributedString(string: title, attributes: titleAttrs).draw(at: NSPoint(x: 250, y: height / 2 - 220))
let tagAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 92, weight: .semibold),
                                               .foregroundColor: NSColor(red: 0.902, green: 0.624, blue: 0.0, alpha: 1)]
NSAttributedString(string: tagline, attributes: tagAttrs).draw(in: NSRect(x: 255, y: height / 2 - 520, width: 1700, height: 260))

// Sağ: üç ekran görüntüsü, hafif yükseklik farkıyla.
let shots = ["01-hero", "02-failure", "05-themes"]
let phoneHeight: CGFloat = 1300, gap: CGFloat = 70, rightMargin: CGFloat = 140
let phoneWidth = phoneHeight * 1320 / 2868
let startX = width - rightMargin - (3 * phoneWidth + 2 * gap)
for (i, name) in shots.enumerated() {
    guard let image = NSImage(contentsOfFile: "\(raw)/\(name).png") else { continue }
    let x = startX + CGFloat(i) * (phoneWidth + gap)
    let y = (height - phoneHeight) / 2 + (i == 1 ? 60 : -30)
    let frame = NSRect(x: x, y: y, width: phoneWidth, height: phoneHeight)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
    shadow.shadowBlurRadius = 50
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let clip = NSBezierPath(roundedRect: frame, xRadius: 60, yRadius: 60)
    NSColor.black.setFill()
    clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: frame, xRadius: 60, yRadius: 60).addClip()
    image.draw(in: frame)
    NSGraphicsContext.restoreGraphicsState()
}
NSGraphicsContext.restoreGraphicsState()

let flat = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                     space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
flat.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
try NSBitmapImageRep(cgImage: flat.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("yazıldı: \(output)")
