import SwiftUI

/// Ayarlar: ses, haptik, şekil desteği, oynatma hızı, tema, gizlilik, destek, satın alımları geri yükleme.
struct SettingsView: View {
    let shop: StoreService
    let ads: AdsCoordinator
    let showStore: () -> Void
    @State private var settings = SettingsStore.shared
    @State private var themes = ThemeManager.shared
    @State private var restoring = false
    @State private var restored = false

    var body: some View {
        List {
            Section("settings.gameplay") {
                Toggle("settings.sound", isOn: $settings.soundEnabled).accessibilityIdentifier("settings.sound")
                Toggle("settings.haptics", isOn: $settings.hapticsEnabled).accessibilityIdentifier("settings.haptics")
                Toggle(isOn: $settings.strongShapes) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.strongShapes")
                        Text("settings.strongShapes.detail").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .accessibilityIdentifier("settings.strongShapes")
                Toggle("settings.fastPlayback", isOn: $settings.fastPlayback).accessibilityIdentifier("settings.fastPlayback")
            }
            .listRowBackground(Theme.surface)

            Section("settings.theme") {
                ForEach(ThemeID.allCases) { theme in
                    let locked = theme.isPremium && !themes.fullGameUnlocked
                    Button {
                        if locked { showStore() } else { themes.selection = theme }
                    } label: {
                        HStack(spacing: 12) {
                            ThemeSwatch(palette: theme.palette)
                            Text(theme.localizedName).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if locked {
                                Image(systemName: "crown.fill").foregroundStyle(Theme.hint)
                            } else if themes.effective == theme {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .accessibilityIdentifier("settings.theme.\(theme.rawValue)")
                    .accessibilityAddTraits(themes.effective == theme ? .isSelected : [])
                }
            }
            .listRowBackground(Theme.surface)

            Section("settings.privacyAndSupport") {
                if ads.consent.isPrivacyOptionsRequired {
                    Button("settings.privacyOptions") { Task { await ads.consent.presentPrivacyOptions() } }
                        .accessibilityIdentifier("settings.privacyOptions")
                }
                Link("settings.privacyPolicy", destination: AppLinks.privacyPolicy)
                Link("settings.support", destination: AppLinks.support)
                Button {
                    restoring = true
                    Task {
                        await shop.restore()
                        restoring = false
                        restored = true
                    }
                } label: {
                    HStack {
                        Text("store.restore")
                        if restoring { Spacer(); ProgressView() }
                    }
                }
                .disabled(restoring)
                .accessibilityIdentifier("settings.restore")
            }
            .listRowBackground(Theme.surface)

            Section {
                Text("settings.version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .tint(Color.accentColor)
        .navigationTitle(Text("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .alert("store.restored", isPresented: $restored) { Button("store.ok", role: .cancel) {} }
    }
}

private struct ThemeSwatch: View {
    let palette: Palette

    var body: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4).fill(palette.background)
            RoundedRectangle(cornerRadius: 4).fill(palette.cell)
            RoundedRectangle(cornerRadius: 4).fill(palette.arrow)
        }
        .frame(width: 48, height: 22)
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4)))
        .accessibilityHidden(true)
    }
}
