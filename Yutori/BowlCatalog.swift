import Foundation

struct BowlCatalogEntry: Identifiable {
    let id: Int
    let name: String
    let kind: BowlKind?
    let previewImageName: String?
    var requiredHours: Int { (id / 3) * BowlCatalog.hoursPerGroup }
}

enum BowlCatalog {
    // Each milestone opens the entire next row of three.
    static let hoursPerGroup = 10
    static let entries: [BowlCatalogEntry] = [
        "Teriyaki Bowl", "Katsu Ramen", "Tofu Curry", "Chirashi Bowl",
        "Tendon", "Yakiniku Bowl", "Salmon Don", "Karaage Bowl",
        "Katsu Curry Bowl", "Oyakodon", "Unadon", "Tekka Don",
        "Ebi Tempura Bowl", "Ochazuke Bowl", "Gyoza Rice Bowl", "Miso Tofu Bowl",
        "Yakitori Bowl", "Soba Sesame Bowl", "Soboro Bowl", "Zosui Bowl", "Nasu Dengaku Bowl"
    ].enumerated().map { index, name in
        let kind: BowlKind? = switch index {
        case 0: .teriyaki
        case 1: .katsuRamen
        case 2: .tofuCurry
        default: nil
        }
        let previewImageName: String? = switch index {
        case 3: "ChirashiBowlLevel5"
        case 4: "TendonLevel5"
        case 5: "YakinikuBowlLevel5"
        default: nil
        }
        return BowlCatalogEntry(id: index, name: name, kind: kind, previewImageName: previewImageName)
    }

    static func unlockedCount(seconds: TimeInterval) -> Int {
        let hours = seconds.isFinite ? max(0, seconds) / 3600 : 0
        let groups = min(entries.count / 3, Int(min(hours / Double(hoursPerGroup), 6)) + 1)
        return groups * 3
    }
}
