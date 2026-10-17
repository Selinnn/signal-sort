import GameCore
import SwiftUI

/// Tek bir hücrenin görünümü: boş, engel, köprü, oklar, kaynak veya çıkış.
struct CellView: View {
    enum Content {
        case empty
        case tile(Tile)
        case source(Source)
        case receiver(Receiver)
    }

    let content: Content
    let size: CGFloat
    var angle: Double = 0
    var isHinted = false
    var receiverFilled = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(background)
                .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(Theme.cellBorder, lineWidth: 1))
            foreground
            if isHinted {
                RoundedRectangle(cornerRadius: size * 0.16)
                    .stroke(Theme.hint, lineWidth: 3)
                    .phaseAnimator([0.4, 1.0]) { view, opacity in view.opacity(opacity) } animation: { _ in .easeInOut(duration: 0.5) }
            }
        }
        .padding(size * 0.04)
        .frame(width: size, height: size)
    }

    private var background: Color {
        if case .tile(let tile) = content, tile.kind == .blocker { return Theme.blocker }
        return Theme.cell
    }

    @ViewBuilder
    private var foreground: some View {
        switch content {
        case .empty:
            EmptyView()
        case .tile(let tile):
            tileForeground(tile)
        case .source(let source):
            ZStack {
                Circle().fill(source.color.color.opacity(0.22))
                SignalGlyph(color: source.color).frame(width: size * 0.34, height: size * 0.34)
                ArrowShape()
                    .fill(source.color.color)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .offset(y: -size * 0.33)
                    .rotationEffect(.degrees(source.direction.degrees))
            }
            .padding(size * 0.08)
        case .receiver(let receiver):
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.12)
                    .stroke(receiver.color.color, lineWidth: size * 0.06)
                    .padding(size * 0.12)
                SignalGlyph(color: receiver.color, filled: receiverFilled, lineWidth: size * 0.045)
                    .frame(width: size * 0.32, height: size * 0.32)
            }
        }
    }

    @ViewBuilder
    private func tileForeground(_ tile: Tile) -> some View {
        switch tile.kind {
        case .blocker:
            Image(systemName: "xmark")
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.18))
        case .bridge:
            ZStack {
                Rectangle().fill(Color.white.opacity(0.18)).frame(width: size * 0.22)
                Rectangle().fill(Color.white.opacity(0.30)).frame(height: size * 0.22)
            }
            .padding(.vertical, size * 0.04)
            .padding(.horizontal, size * 0.04)
        case .router:
            arrow(tile.rotatable ? Theme.arrow : Theme.fixedArrow)
                .overlay(alignment: .bottomTrailing) { if !tile.rotatable { lockBadge } }
        case .colorRouter:
            ZStack {
                arrow(tile.color?.color ?? Theme.arrow)
                if let color = tile.color {
                    SignalGlyph(color: color).frame(width: size * 0.16, height: size * 0.16)
                        .overlay(SignalGlyph(color: color, filled: false, lineWidth: 1.5).foregroundStyle(Theme.cell))
                }
            }
        case .toggle:
            ZStack {
                Circle()
                    .trim(from: 0.08, to: 0.86)
                    .stroke(Theme.arrow.opacity(0.35), style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round, dash: [size * 0.06, size * 0.05]))
                    .padding(size * 0.12)
                    .rotationEffect(.degrees(angle))
                arrow(Theme.arrow).scaleEffect(0.8)
            }
        }
    }

    private func arrow(_ color: Color) -> some View {
        ArrowShape()
            .fill(color)
            .padding(size * 0.16)
            .rotationEffect(.degrees(angle))
    }

    private var lockBadge: some View {
        Circle().fill(Theme.fixedArrow).frame(width: size * 0.12, height: size * 0.12).padding(size * 0.1)
    }
}
