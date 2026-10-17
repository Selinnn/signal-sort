import AVFoundation
import UIKit

/// Oyun içi olaylar: ses, haptik ve VoiceOver duyurusu buradan tetiklenir.
enum BoardEvent: Equatable {
    case rotate
    case run
    case deliver
    case fail
    case solve
}

/// Kodla sentezlenen kısa tonlar (PLAN §4: ses dosyası yok, lisans riski yok). `.ambient` oturum: sessiz
/// moda uyar ve kullanıcının müziğini kesmez. Motor ilk seste başlar.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [BoardEvent: AVAudioPCMBuffer] = [:]
    private var isRunning = false

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.35
        buffers = [
            .rotate: tone([(1_250, 0.025)], volume: 0.25),
            .run: tone([(660, 0.05), (880, 0.07)], volume: 0.4),
            .deliver: tone([(988, 0.06), (1_319, 0.10)], volume: 0.45),
            .fail: tone([(220, 0.09), (165, 0.16)], volume: 0.5, square: true),
            .solve: tone([(523, 0.08), (659, 0.08), (784, 0.08), (1_047, 0.22)], volume: 0.5),
        ]
    }

    func play(_ event: BoardEvent) {
        guard SettingsStore.shared.soundEnabled, let buffer = buffers[event] else { return }
        if !isRunning {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            do {
                try engine.start()
                isRunning = true
            } catch {
                return
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    /// Ardışık notalar; her notada kısa atak ve üstel sönüm.
    private func tone(_ notes: [(frequency: Double, duration: Double)], volume: Float, square: Bool = false) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let total = AVAudioFrameCount(notes.reduce(0) { $0 + $1.duration } * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total)!
        buffer.frameLength = total
        let samples = buffer.floatChannelData![0]
        var index = 0
        for note in notes {
            let count = Int(note.duration * rate)
            for i in 0..<count where index < Int(total) {
                let t = Double(i) / rate
                let attack = min(1, t / 0.004)
                let decay = exp(-t / (note.duration * 0.45))
                var wave = sin(2 * .pi * note.frequency * t)
                if square { wave = wave >= 0 ? 0.6 : -0.6 }
                samples[index] = Float(wave * attack * decay) * volume
                index += 1
            }
        }
        return buffer
    }
}

@MainActor
enum Haptics {
    static func play(_ event: BoardEvent) {
        guard SettingsStore.shared.hapticsEnabled else { return }
        switch event {
        case .rotate: UISelectionFeedbackGenerator().selectionChanged()
        case .run: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .deliver: UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .fail: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .solve: UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
