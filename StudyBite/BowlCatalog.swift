import Foundation

struct BowlCatalogEntry: Identifiable {
    let id: Int
    let name: String
    let kind: BowlKind?
    var requiredHours: Int { (id / 3) * BowlCatalog.hoursPerGroup }
}

enum BowlCatalog {
    // Each milestone opens the entire next row of three.
    static let hoursPerGroup = 15
    static let entries: [BowlCatalogEntry] = [
        "Katsu Ramen", "Teriyaki Bowl", "Tofu Curry", "Miso Ramen",
        "Shoyu Ramen", "Spicy Ramen", "Chicken Curry", "Katsu Curry",
        "Salmon Bowl", "Tuna Bowl", "Veggie Bowl", "Beef Bowl",
        "Tempura Bowl", "Bibimbap", "Kimchi Rice", "Fried Rice",
        "Udon Bowl", "Soba Bowl", "Gyoza Bowl", "Mushroom Bowl", "Unagi Bowl"
    ].enumerated().map { index, name in
        BowlCatalogEntry(id: index, name: name,
                         kind: index == 0 ? .katsuRamen : (index == 1 ? .teriyaki : nil))
    }

    static func unlockedCount(seconds: TimeInterval) -> Int {
        let hours = seconds.isFinite ? max(0, seconds) / 3600 : 0
        let groups = min(entries.count / 3, Int(min(hours / Double(hoursPerGroup), 6)) + 1)
        return groups * 3
    }
}
