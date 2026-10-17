import SwiftUI

/// Sistem açılış ekranının (aynı renk ve aynı yerde aynı logo) devamı olan kısa giriş: logo hafifçe büyür,
/// isim ve slogan belirir, sonra ana ekrana yumuşak geçiş. Reduce Motion açıkken yalnız kısa bir solma.
struct SplashView: View {
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    /// DEBUG'da `-splashDuration <sn>` UI testinin splash'i yakalayabilmesi için süreyi uzatır.
    static func durationMilliseconds(reduceMotion: Bool) -> Int {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-splashDuration"), index + 1 < arguments.count,
           let seconds = Double(arguments[index + 1]) {
            return Int(seconds * 1_000)
        }
        #endif
        return reduceMotion ? 500 : 1_100
    }

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchLogo")
                .resizable()
                .frame(width: 128, height: 128)
                .scaleEffect(revealed && !reduceMotion ? 1.08 : 1)
                .shadow(color: Color.accentColor.opacity(revealed ? 0.45 : 0), radius: 30)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text("Signal Sort")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                Text("home.subtitle")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .offset(y: 130)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed || reduceMotion ? 0 : 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("splash")
        .task {
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.45)) { revealed = true }
            try? await Task.sleep(for: .milliseconds(Self.durationMilliseconds(reduceMotion: reduceMotion)))
            onFinished()
        }
    }
}
