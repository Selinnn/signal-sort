// Ham simülatör görüntülerini başlıklı App Store görsellerine dönüştürür (1320×2868, 6.9").
// Kullanım: swift scripts/compose-screenshots.swift <en|tr|es> <ham-klasör> <çıktı-klasörü>
import AppKit

let args = CommandLine.arguments
let lang = args[1], input = args[2], output = args[3]

let captions: [String: [String: String]] = [
    "01-hero": ["en": "Rotate arrows.\nRoute every signal.", "tr": "Okları çevir,\nher sinyali yönlendir.", "es": "Gira las flechas.\nGuía cada señal."],
    "02-failure": ["en": "See exactly\nwhat went wrong", "tr": "Neyin yanlış gittiğini\nanında gör", "es": "Mira exactamente\nqué salió mal"],
    "03-daily": ["en": "A new puzzle\nevery day", "tr": "Her gün\nyeni bir bulmaca", "es": "Un reto nuevo\ncada día"],
    "04-chapters": ["en": "150 levels,\n6 chapters", "tr": "6 bölüm,\n150 seviye", "es": "150 niveles,\n6 capítulos"],
    "05-themes": ["en": "Colors, switches\nand bridges", "tr": "Renkler, makaslar\nve köprüler", "es": "Colores, cambios\ny puentes"],
]

let width: CGFloat = 1320, height: CGFloat = 2868
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

for (name, texts) in captions.sorted(by: { $0.key < $1.key }) {
    guard let shot = NSImage(contentsOfFile: "\(input)/\(name).png"), let caption = texts[lang] else {
        print("atlandı: \(name)")
        continue
    }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Zemin: uygulama ikonu ile aynı lacivert geçiş.
    NSGradient(starting: NSColor(red: 0.09, green: 0.12, blue: 0.26, alpha: 1), ending: NSColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

    // Başlık (üstte, ortalı).
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineSpacing = 6
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 104, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
    ]
    NSAttributedString(string: caption, attributes: attributes)
        .draw(in: NSRect(x: 60, y: height - 480, width: width - 120, height: 380))

    // Ekran görüntüsü: yuvarlatılmış köşe, hafif gölge.
    let shotWidth = width * 0.80
    let shotHeight = shotWidth * shot.size.height / shot.size.width
    let frame = NSRect(x: (width - shotWidth) / 2, y: 90, width: shotWidth, height: shotHeight)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.shadowBlurRadius = 60
    shadow.set()
    let clip = NSBezierPath(roundedRect: frame, xRadius: 70, yRadius: 70)
    NSColor.black.setFill()
    clip.fill()
    NSShadow().set()
    clip.addClip()
    shot.draw(in: frame)

    NSGraphicsContext.restoreGraphicsState()
    // App Store saydamlık kabul etmez: saydamlıksız (noneSkipLast) bir CGContext'e düzleştir.
    let flat = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    flat.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
    let png = NSBitmapImageRep(cgImage: flat.makeImage()!).representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: "\(output)/iPhone69-\(name).png"))
    print("yazıldı: \(output)/iPhone69-\(name).png")
}
