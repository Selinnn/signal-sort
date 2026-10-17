import GameCore
import SwiftUI

enum BoardMode: Equatable {
    case campaign(number: Int)
    case daily(DayKey)
}

struct BoardScreen: View {
    let level: LevelDefinition
    let mode: BoardMode
    let store: ProgressStore
    let onNext: () -> Void
    let showStore: () -> Void
    @State private var session: GameSession
    @State private var outcome: ResultOutcome?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(level: LevelDefinition, mode: BoardMode, store: ProgressStore, onNext: @escaping () -> Void, showStore: @escaping () -> Void) {
        self.level = level
        self.mode = mode
        self.store = store
        self.onNext = onNext
        self.showStore = showStore
        _session = State(initialValue: GameSession(level: level))
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            BoardView(session: session)
                .padding(.horizontal, 12)
            statusBanner
                .frame(minHeight: 44)
            controls
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { session.instantPlayback = reduceMotion }
        .onChange(of: reduceMotion) { _, value in session.instantPlayback = value }
        .onChange(of: session.showsResult) { _, solved in
            guard solved else { return }
            switch mode {
            case .campaign:
                let isNewBest = store.record(session.play)
                let isChapterEnd = store.progression.position(of: level.id).map {
                    $0.index == store.catalog.chapters[$0.chapter].levels.count - 1
                } ?? false
                outcome = ResultOutcome(isNewBest: isNewBest, completesChapter: isChapterEnd, shareText: nil)
            case .daily(let day):
                let isNewBest = store.recordDaily(day, session.play)
                outcome = ResultOutcome(isNewBest: isNewBest, completesChapter: false, shareText: DailyShare.text(day: day, session: session.play))
            }
        }
        .overlay {
            if session.showsResult, let outcome {
                ResultOverlay(session: session, outcome: outcome, onNext: onNext, onRetry: retry)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: session.showsResult)
    }

    /// Bakiye varsa ipucu verir ve bir ipucu düşer; bakiye yoksa mağazayı açar.
    private func useHint() {
        guard store.hintBalance > 0 else {
            showStore()
            return
        }
        guard session.canHint, store.spendHint() else { return }
        session.hint()
    }

    private var title: Text {
        switch mode {
        case .campaign(let number): Text("board.level \(number)")
        case .daily(let day): Text("board.daily \(day.localizedText)")
        }
    }

    private func retry() {
        outcome = nil
        let fresh = GameSession(level: level)
        fresh.instantPlayback = reduceMotion
        fresh.speed = session.speed
        session = fresh
    }

    private var header: some View {
        HStack {
            Text(movesText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("board.moves")
            Spacer()
            Button(action: session.toggleSpeed) {
                Text(session.speed == .normal ? "board.speed.normal" : "board.speed.fast")
                    .font(.subheadline.bold().monospacedDigit())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.surface))
            }
            .foregroundStyle(Theme.textPrimary)
            .accessibilityIdentifier("board.speed")
        }
        .padding(.horizontal, 20)
    }

    private var movesText: String {
        if let par = session.play.par {
            String(localized: "board.moves \(session.play.moves) \(par)")
        } else {
            String(localized: "board.movesNoPar \(session.play.moves)")
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let failure = session.visibleFailures.first, let color = session.color(ofSignal: failure.signalID) {
            Label(FailureText.message(failure.reason, color: color), systemImage: FailureText.symbol(failure.reason))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.failure)
                .padding(.horizontal, 20)
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(FailureText.message(failure.reason, color: color))
                .accessibilityIdentifier("board.failure")
                .transition(.opacity)
        } else if session.phase == .playing {
            Button(action: session.skip) {
                Label("board.skip", systemImage: "forward.end.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.textSecondary)
            .accessibilityIdentifier("board.skip")
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            ControlButton(title: "board.undo", symbol: "arrow.uturn.backward", identifier: "board.undo",
                          enabled: session.isInteractive && session.play.canUndo, action: session.undo)
            ControlButton(title: "board.reset", symbol: "arrow.counterclockwise", identifier: "board.reset",
                          enabled: session.isInteractive && session.play.canReset, action: session.reset)
            ControlButton(title: "board.hint", symbol: "lightbulb", identifier: "board.hint",
                          enabled: session.isInteractive, badge: store.hintBalance, action: useHint)
            Button(action: session.run) {
                Label("board.run", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(session.isInteractive ? Color.accentColor : Theme.surface))
                    .foregroundStyle(Theme.background)
            }
            .disabled(!session.isInteractive)
            .accessibilityIdentifier("board.run")
        }
        .padding(.horizontal, 16)
    }
}

private struct ControlButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let identifier: String
    let enabled: Bool
    var badge: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(width: 58, height: 52)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
            .foregroundStyle(enabled ? Theme.textPrimary : Theme.textSecondary.opacity(0.4))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge > 0 ? "\(badge)" : "+")
                        .font(.caption2.bold().monospacedDigit())
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(badge > 0 ? Theme.hint : Color.accentColor))
                        .foregroundStyle(Theme.background)
                        .offset(x: 6, y: -6)
                        .accessibilityIdentifier("\(identifier).badge")
                }
            }
        }
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }
}

struct ResultOutcome: Equatable {
    var isNewBest: Bool
    var completesChapter: Bool
    /// Günlükte paylaşım metni; kampanyada nil.
    var shareText: String?
}

private struct ResultOverlay: View {
    let session: GameSession
    let outcome: ResultOutcome
    let onNext: () -> Void
    let onRetry: () -> Void

    var body: some View {
        let stars = session.play.stars ?? 1
        VStack(spacing: 18) {
            Text(outcome.completesChapter ? "result.chapterComplete" : "result.title")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("result.title")
            HStack(spacing: 10) {
                ForEach(1...3, id: \.self) { index in
                    Image(systemName: index <= stars ? "star.fill" : "star")
                        .font(.system(size: 40))
                        .foregroundStyle(index <= stars ? Theme.hint : Theme.textSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("result.stars \(stars)"))
            if let par = session.play.par {
                Text("result.moves \(session.play.moves) \(par)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            if outcome.isNewBest {
                Text("result.newBest")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.success)
                    .accessibilityIdentifier("result.newBest")
            }
            if let shareText = outcome.shareText {
                ShareLink(item: shareText) {
                    Label("result.share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor))
                        .foregroundStyle(Theme.background)
                }
                .accessibilityIdentifier("result.share")
            }
            Button(action: onNext) {
                (outcome.shareText == nil ? Text("result.next") : Text("result.done"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(outcome.shareText == nil ? Color.accentColor : Theme.cell))
                    .foregroundStyle(outcome.shareText == nil ? Theme.background : Theme.textPrimary)
            }
            .accessibilityIdentifier("result.next")
            if stars < 3 {
                Button(action: onRetry) {
                    Label("result.retry", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityIdentifier("result.retry")
            }
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 28).fill(Theme.surface))
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.45).ignoresSafeArea())
    }
}

enum FailureText {
    static func message(_ reason: FailureReason, color: SignalColor) -> String {
        let name = color.localizedName
        return switch reason {
        case .outOfBounds: String(localized: "failure.outOfBounds \(name)")
        case .blocked: String(localized: "failure.blocked \(name)")
        case .swapCollision: String(localized: "failure.swapCollision \(name)")
        case .wrongReceiver: String(localized: "failure.wrongReceiver \(name)")
        case .collision: String(localized: "failure.collision \(name)")
        case .loop: String(localized: "failure.loop \(name)")
        }
    }

    static func symbol(_ reason: FailureReason) -> String {
        switch reason {
        case .outOfBounds: "arrow.up.right.square"
        case .blocked: "xmark.octagon"
        case .swapCollision, .collision: "burst"
        case .wrongReceiver: "exclamationmark.triangle"
        case .loop: "arrow.triangle.2.circlepath"
        }
    }
}
