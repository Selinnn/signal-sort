import GameCore
import SwiftUI

/// Tahta: hücreler, Run izi, sinyaller ve hata işaretleri katmanları.
struct BoardView: View {
    let session: GameSession

    var body: some View {
        GeometryReader { geometry in
            let level = session.level
            let size = floor(min(geometry.size.width / CGFloat(level.width), geometry.size.height / CGFloat(level.height)))
            ZStack(alignment: .topLeading) {
                cells(size: size)
                TrailLayer(session: session, size: size)
                    .allowsHitTesting(false)
                failureMarkers(size: size)
                    .allowsHitTesting(false)
                signals(size: size)
                    .allowsHitTesting(false)
            }
            .frame(width: size * CGFloat(level.width), height: size * CGFloat(level.height))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(CGFloat(session.level.width) / CGFloat(session.level.height), contentMode: .fit)
    }

    static func center(_ c: Coordinate, _ size: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(c.x) + 0.5) * size, y: (CGFloat(c.y) + 0.5) * size)
    }

    // MARK: Hücreler

    private func cells(size: CGFloat) -> some View {
        let level = session.level
        let tiles = Dictionary(uniqueKeysWithValues: level.tiles.map { ($0.coordinate, $0) })
        let sources = Dictionary(uniqueKeysWithValues: level.sources.map { ($0.coordinate, $0) })
        let receivers = Dictionary(uniqueKeysWithValues: level.receivers.map { ($0.coordinate, $0) })
        let delivered = Set(session.snapshot?.signals.filter { $0.status == .delivered }.map(\.coordinate) ?? [])
        let coordinates = (0..<level.height).flatMap { y in (0..<level.width).map { Coordinate($0, y) } }

        return ForEach(coordinates, id: \.self) { coordinate in
            let content: CellView.Content =
                if let tile = tiles[coordinate] { .tile(tile) }
                else if let source = sources[coordinate] { .source(source) }
                else if let receiver = receivers[coordinate] { .receiver(receiver) }
                else { .empty }
            let tile = tiles[coordinate]
            let cell = CellView(
                content: content,
                size: size,
                angle: tile.map { session.angle(for: $0) } ?? 0,
                isHinted: tile != nil && tile?.id == session.hintTileID,
                receiverFilled: delivered.contains(coordinate))
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: tile.map { session.angle(for: $0) })

            let label = accessibilityLabel(content, tile: tile)
            let identifier = "cell.\(coordinate.x).\(coordinate.y)"
            Group {
                if let tile, tile.rotatable, tile.kind.isDirectional {
                    Button { session.tap(tile) } label: { cell }
                        .buttonStyle(.plain)
                        .disabled(!session.isInteractive)
                        .accessibilityLabel(label)
                        .accessibilityHint(Text("a11y.rotateHint"))
                        .accessibilityIdentifier(identifier)
                } else {
                    cell
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(label)
                        .accessibilityIdentifier(identifier)
                }
            }
            .position(Self.center(coordinate, size))
        }
    }

    private func accessibilityLabel(_ content: CellView.Content, tile: Tile?) -> String {
        switch content {
        case .empty:
            return String(localized: "a11y.empty")
        case .source(let source):
            return String(localized: "a11y.source \(source.color.localizedName) \(source.direction.localizedName)")
        case .receiver(let receiver):
            return String(localized: "a11y.receiver \(receiver.color.localizedName)")
        case .tile(let tile):
            let direction = session.play.state.direction(of: tile)?.localizedName ?? ""
            switch tile.kind {
            case .blocker: return String(localized: "a11y.blocker")
            case .bridge: return String(localized: "a11y.bridge")
            case .router: return tile.rotatable ? String(localized: "a11y.router \(direction)") : String(localized: "a11y.fixedRouter \(direction)")
            case .colorRouter: return String(localized: "a11y.colorRouter \(tile.color?.localizedName ?? "") \(direction)")
            case .toggle: return String(localized: "a11y.toggle \(direction)")
            }
        }
    }

    // MARK: Sinyaller

    private func signals(size: CGFloat) -> some View {
        let snapshot = session.snapshot
        let failures = Dictionary(uniqueKeysWithValues: session.visibleFailures.map { ($0.signalID, $0) })
        // Aynı hücredeki (çarpışan) sinyaller üst üste binmesin diye çapraz kaydırılır.
        var stacked: [Coordinate: [String]] = [:]
        for signal in snapshot?.signals ?? [] where signal.status != .delivered {
            stacked[signal.coordinate, default: []].append(signal.signalID)
        }
        return ForEach(snapshot?.signals ?? [], id: \.signalID) { signal in
            var point = Self.center(signal.coordinate, size)
            if let group = stacked[signal.coordinate], group.count > 1, let order = group.firstIndex(of: signal.signalID) {
                let shift = (CGFloat(order) - CGFloat(group.count - 1) / 2) * size * 0.26
                point.x += shift
                point.y += shift
            }
            if let failure = failures[signal.signalID], [.outOfBounds, .blocked].contains(failure.reason) {
                // Duvara/kenara çarpma: sinyal gideceği yöne doğru hafifçe kayar.
                let bump = failure.reason == .outOfBounds ? 0.42 : 0.3
                point.x += CGFloat(signal.direction.dx) * size * bump
                point.y += CGFloat(signal.direction.dy) * size * bump
            }
            return SignalGlyph(color: signal.color)
                .frame(width: size * 0.38, height: size * 0.38)
                .shadow(color: signal.color.color.opacity(0.9), radius: size * 0.12)
                .overlay {
                    if signal.status == .failed {
                        Circle().stroke(Theme.failure, lineWidth: 3).frame(width: size * 0.62, height: size * 0.62)
                    }
                }
                .scaleEffect(signal.status == .delivered ? 0.55 : 1)
                .opacity(signal.status == .delivered ? 0.0 : 1)
                .position(point)
        }
    }

    // MARK: Hatalar

    private func failureMarkers(size: CGFloat) -> some View {
        ForEach(Array(Set(session.visibleFailures.map(\.coordinate))), id: \.self) { coordinate in
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(Theme.failure.opacity(0.22))
                .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(Theme.failure, lineWidth: 2))
                .frame(width: size * 0.92, height: size * 0.92)
                .position(Self.center(coordinate, size))
                .transition(.opacity)
        }
    }
}

/// Sinyallerin o ana kadar izlediği yol.
private struct TrailLayer: View {
    let session: GameSession
    let size: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard let result = session.result, session.phase != .planning else { return }
            let last = min(session.playbackTick, result.trace.count - 1)
            for (index, signal) in result.trace[0].signals.enumerated() {
                var path = Path()
                path.move(to: BoardView.center(signal.coordinate, size))
                for tick in 0...last {
                    path.addLine(to: BoardView.center(result.trace[tick].signals[index].coordinate, size))
                }
                context.stroke(path, with: .color(signal.color.color.opacity(0.45)),
                               style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
