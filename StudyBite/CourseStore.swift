import Foundation
import Observation

enum CourseColor: String, Codable, CaseIterable {
    case blue, teal, green, orange, pink, purple, red, indigo
    case mint, peach, lemon, lavender, rose, sky, sage, sand
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

    func save(_ draft: StudyCourse) throws {
        guard !loadFailed else { throw SaveError.unavailable }
        var course = draft
        course.name = course.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !course.name.isEmpty, course.name.count <= 60 else { throw SaveError.invalidName }
        var updated = courses
        if let index = updated.firstIndex(where: { $0.id == course.id }) {
            updated[index] = course
        } else {
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

    enum SaveError: Error {
        case invalidName, unavailable
    }
}
