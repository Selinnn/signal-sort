import Foundation
import GameCore

/// Uygulamaya gömülü kampanya (`campaign.json`, `signalsort-cli build-campaign` ile üretilir ve CI'da doğrulanır).
struct LevelCatalog {
    let campaign: Campaign
    let levels: [LevelDefinition]
    private let numbers: [String: Int]

    init(campaign: Campaign) {
        self.campaign = campaign
        levels = campaign.levels
        numbers = Dictionary(uniqueKeysWithValues: levels.enumerated().map { ($1.id, $0 + 1) })
    }

    var chapters: [Chapter] { campaign.chapters }

    /// Oyuncuya gösterilen seviye numarası (kampanya boyunca 1…150).
    func number(of levelID: String) -> Int { numbers[levelID] ?? 0 }

    func level(withID id: String) -> LevelDefinition? { levels.first { $0.id == id } }

    static let bundled: LevelCatalog = {
        guard let url = Bundle.main.url(forResource: "campaign", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let campaign = try? JSONDecoder().decode(Campaign.self, from: data) else {
            assertionFailure("campaign.json okunamadı")
            return LevelCatalog(campaign: Campaign(chapters: []))
        }
        return LevelCatalog(campaign: campaign)
    }()
}
