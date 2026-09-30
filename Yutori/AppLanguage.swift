import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var title: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        }
    }

    static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .english
    }

    private static var localizedBundle: Bundle {
        guard selected != .english,
              let path = Bundle.main.path(forResource: selected.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }

        return bundle
    }

    static func localized(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: localized(key),
            locale: selected.locale,
            arguments: arguments
        )
    }
}
