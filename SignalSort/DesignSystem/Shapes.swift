import GameCore
import SwiftUI

/// Yukarıyı gösteren ok.
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.12))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.48))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.60, y: rect.minY + h * 0.48))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.60, y: rect.minY + h * 0.88))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.40, y: rect.minY + h * 0.88))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.40, y: rect.minY + h * 0.48))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.48))
        p.closeSubpath()
        return p
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        var p = Path()
        for i in 0..<10 {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = Double(i) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            i == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        p.closeSubpath()
        return p
    }
}

/// Renk körlüğü için her rengin şekli: turuncu daire, mavi kare, yeşil üçgen, sarı elmas, pembe yıldız.
struct SignalGlyph: View {
    let color: SignalColor
    var filled = true
    var lineWidth: CGFloat = 2

    var body: some View {
        switch color {
        case .orange: styled(Circle())
        case .blue: styled(RoundedRectangle(cornerRadius: 2))
        case .green: styled(TriangleShape())
        case .yellow: styled(DiamondShape())
        case .pink: styled(StarShape())
        }
    }

    @ViewBuilder
    private func styled(_ shape: some Shape) -> some View {
        if filled {
            shape.fill(color.color)
        } else {
            shape.stroke(color.color, lineWidth: lineWidth)
        }
    }
}
