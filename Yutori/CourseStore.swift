import Foundation
import Observation

enum CourseColor: String, Codable, CaseIterable {
    case blue, teal, green, orange, pink, purple, red, indigo
    case mint, peach, lemon, lavender, rose, sky, sage, sand, moss

    // Keep stored identifiers compatible with existing courses and sessions.
    var paletteColor: CourseColor {
        switch self {
        case .mint: .teal
        case .peach: .orange
        case .lavender: .purple
        case .rose: .pink
        case .sage: .green
        default: self
        }
    }

    var displayName: String {
        switch paletteColor {
        case .sky: "Asagi Blue"
        case .moss: "Moss Olive"
        case .red: "Torii Vermilion"
        case .blue: "Aizome Indigo"
        case .green: "Matcha Green"
        case .pink: "Sakura Pink"
        case .lemon: "Golden Yellow"
        case .teal: "Jade Teal"
        case .purple: "Plum Purple"
        case .orange: "Persimmon Orange"
        case .indigo: "Kōbai Rose"
        default: "Walnut Brown"
        }
    }

    var rgbHex: UInt32 {
        switch paletteColor {
        case .sky: 0x69A6BE
        case .moss: 0x92905B
        case .red: 0xC65347
        case .blue: 0x365D88
        case .green: 0x718A52
        case .pink: 0xD77F9A
        case .lemon: 0xC5A044
        case .teal: 0x438E89
        case .purple: 0x80628F
        case .orange: 0xD9844B
        case .indigo: 0xAD5275
        default: 0x8E6A50
        }
    }
}

struct StudyCourse: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var color: CourseColor = .blue
    var icon = "book.fill"
}

@Observable
final class CourseStore {
    static let shared = CourseStore()
    private(set) var courses: [StudyCourse] = []
    private(set) var loadFailed = false
    private let defaults: UserDefaults
    private let storageKey = "studyCourses.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey) {
            do {
                courses = try JSONDecoder().decode([StudyCourse].self, from: data)
            } catch {
                loadFailed = true
            }
        }
    }

    func isColorAvailable(_ color: CourseColor, for courseID: UUID) -> Bool {
        !courses.contains { $0.id != courseID && $0.color.paletteColor == color.paletteColor }
    }

    func save(_ draft: StudyCourse) throws {
        guard !loadFailed else { throw SaveError.unavailable }
        var course = draft
        course.name = course.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !course.name.isEmpty, course.name.count <= 60 else { throw SaveError.invalidName }
        guard isColorAvailable(course.color, for: course.id) else { throw SaveError.colorInUse }
        var updated = courses
        if let index = updated.firstIndex(where: { $0.id == course.id }) {
            updated[index] = course
        } else {
            guard courses.isEmpty || PurchaseManager.shared.isPro else {
                throw SaveError.proRequired
            }
            updated.append(course)
        }
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: storageKey)
        courses = updated
    }

    func delete(_ course: StudyCourse) throws {
        guard !loadFailed else { throw SaveError.unavailable }
        let updated = courses.filter { $0.id != course.id }
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: storageKey)
        courses = updated
    }

    func resetAllData() {
        defaults.removeObject(forKey: storageKey)
        courses = []
        loadFailed = false
    }

    enum SaveError: Error {
        case invalidName, unavailable, colorInUse, proRequired
    }
}
