import Foundation

struct BowlCatalogEntry: Identifiable {
    let id: Int
    let sourceName: String
    let kind: BowlKind?
    let previewImageName: String?
    var name: String { AppLanguage.localized(sourceName) }
    var requiredHours: Int { id < BowlCatalog.initialUnlockedCount ? 0 : (id - 2) * BowlCatalog.hoursPerBowl }
}

enum BowlCatalog {
    static let initialUnlockedCount = 3
    static let hoursPerBowl = 5
    static let entries: [BowlCatalogEntry] = [
        "Teriyaki Bowl", "Chirashi Bowl", "Katsu Ramen", "Tofu Curry",
        "Tendon", "Yakiniku Bowl", "Salmon Don", "Karaage Bowl",
        "Katsu Curry Bowl", "Oyakodon", "Unadon", "Tekka Don",
        "Ebi Tempura Bowl", "Ochazuke Bowl", "Gyoza Rice Bowl", "Miso Tofu Bowl",
        "Yakitori Bowl", "Soba Sesame Bowl", "Soboro Bowl", "Zosui Bowl", "Nasu Dengaku Bowl"
    ].enumerated().map { index, name in
        let kind: BowlKind? = switch index {
        case 0: .teriyaki
        case 1: .chirashi
        case 2: .katsuRamen
        case 3: .tofuCurry
        default: nil
        }
        let previewImageName: String? = switch index {
        case 4: "TendonLevel5"
        case 5: "YakinikuBowlLevel5"
        case 6: "SalmonDonLevel5"
        case 7: "KaraageBowlLevel5"
        case 8: "KatsuCurryBowlLevel5"
        case 9: "OyakodonLevel5"
        case 10: "UnadonLevel5"
        case 11: "TekkaDonLevel5"
        case 12: "EbiTempuraBowlLevel5"
        case 13: "OchazukeBowlLevel5"
        case 14: "GyozaRiceBowlLevel5"
        case 15: "MisoTofuBowlLevel5"
        case 16: "YakitoriBowlLevel5"
        case 17: "SobaSesameBowlLevel5"
        case 18: "SoboroBowlLevel5"
        case 19: "ZosuiBowlLevel5"
        case 20: "NasuDengakuBowlLevel5"
        default: nil
        }
        return BowlCatalogEntry(id: index, sourceName: name, kind: kind, previewImageName: previewImageName)
    }

    static func unlockedCount(seconds: TimeInterval) -> Int {
        let hours = seconds.isFinite ? max(0, seconds) / 3600 : 0
        let earnedUnlocks = Int(hours / Double(hoursPerBowl))
        return min(entries.count, initialUnlockedCount + earnedUnlocks)
    }
}
