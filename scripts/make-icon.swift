// Uygulama ikonunu (1024×1024, saydamlıksız PNG) CoreGraphics ile çizer. Kullanım:
//   swift scripts/make-icon.swift SignalSort/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// CoreGraphics'te y yukarı; çizimi y aşağı düşünmek için çevir.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// Zemin: lacivert dikey geçiş.
let gradient = CGGradient(colorsSpace: space, colors: [rgb(0.09, 0.12, 0.26), rgb(0.04, 0.05, 0.12)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size), options: [])

// 3×3 hücre ızgarası.
let margin: CGFloat = 132, gap: CGFloat = 28
let cell = (size - 2 * margin - 2 * gap) / 3
func cellRect(_ col: Int, _ row: Int) -> CGRect {
    CGRect(x: margin + CGFloat(col) * (cell + gap), y: margin + CGFloat(row) * (cell + gap), width: cell, height: cell)
}
func center(_ col: Int, _ row: Int) -> CGPoint { CGPoint(x: cellRect(col, row).midX, y: cellRect(col, row).midY) }
for row in 0..<3 {
    for col in 0..<3 {
        ctx.addPath(CGPath(roundedRect: cellRect(col, row), cornerWidth: 44, cornerHeight: 44, transform: nil))
        ctx.setFillColor(rgb(0.14, 0.18, 0.33))
        ctx.fillPath()
    }
}

let orange = rgb(0.902, 0.624, 0.0)
let blue = rgb(0.337, 0.706, 0.914)

// Turuncu sinyal izi: soldan merkeze, merkezde aşağı döner, çıkışa iner.
let path = CGMutablePath()
path.move(to: center(0, 1))
path.addLine(to: center(1, 1))
path.addLine(to: center(1, 2))
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 60, color: rgb(0.902, 0.624, 0.0, 0.9))
ctx.addPath(path)
ctx.setStrokeColor(orange)
ctx.setLineWidth(64)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.strokePath()
ctx.restoreGState()

// Kaynak: dolu turuncu daire.
let source = center(0, 1)
ctx.setFillColor(orange)
ctx.fillEllipse(in: CGRect(x: source.x - 78, y: source.y - 78, width: 156, height: 156))

// Çıkış: turuncu çerçeve.
let exit = cellRect(1, 2).insetBy(dx: 34, dy: 34)
ctx.addPath(CGPath(roundedRect: exit, cornerWidth: 30, cornerHeight: 30, transform: nil))
ctx.setStrokeColor(orange)
ctx.setLineWidth(26)
ctx.strokePath()

// Dönüş hücresinde aşağıyı gösteren beyaz ok.
let c = center(1, 1)
let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: c.x, y: c.y + 92))
arrow.addLine(to: CGPoint(x: c.x + 86, y: c.y + 4))
arrow.addLine(to: CGPoint(x: c.x + 34, y: c.y + 4))
arrow.addLine(to: CGPoint(x: c.x + 34, y: c.y - 92))
arrow.addLine(to: CGPoint(x: c.x - 34, y: c.y - 92))
arrow.addLine(to: CGPoint(x: c.x - 34, y: c.y + 4))
arrow.addLine(to: CGPoint(x: c.x - 86, y: c.y + 4))
arrow.closeSubpath()
ctx.addPath(arrow)
ctx.setFillColor(rgb(1, 1, 1))
ctx.fillPath()

// Mavi kare sinyal (ikinci renk) sağ üstte.
let b = center(2, 0)
ctx.addPath(CGPath(roundedRect: CGRect(x: b.x - 70, y: b.y - 70, width: 140, height: 140), cornerWidth: 18, cornerHeight: 18, transform: nil))
ctx.setFillColor(blue)
ctx.fillPath()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("yazıldı: \(output)")
