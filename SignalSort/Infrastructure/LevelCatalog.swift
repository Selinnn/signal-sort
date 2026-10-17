import Foundation
import GameCore

/// Uygulamaya gömülü kampanya seviyeleri (`campaign.json`, CLI ile üretilir ve doğrulanır).
struct LevelCatalog {
    let levels: [LevelDefinition]

    static let bundled: LevelCatalog = {
        guard let url = Bundle.main.url(forResource: "campaign", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let levels = try? JSONDecoder().decode([LevelDefinition].self, from: data) else {
            assertionFailure("campaign.json okunamadı")
            return LevelCatalog(levels: [])
        }
        return LevelCatalog(levels: levels)
    }()
}
