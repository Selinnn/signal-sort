import Foundation
import GameCore

/// Uygulamaya gömülü kampanya (`campaign.json`, `signalsort-cli build-campaign` ile üretilir ve CI'da doğrulanır).
struct LevelCatalog {
    let chapters: [Chapter]
    let levels: [LevelDefinition]

    init(campaign: Campaign) {
        chapters = campaign.chapters
        levels = campaign.levels
    }

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
