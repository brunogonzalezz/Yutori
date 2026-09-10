import Foundation
import Observation

struct StudySession: Identifiable, Codable, Equatable {
    var id = UUID()
    let course: StudyCourse
    var blockDescription: String
    var duration: TimeInterval
    let endedAt: Date

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(seconds)s"
    }
}

@Observable
final class StudySessionStore {
    static let shared = StudySessionStore()
    private(set) var sessions: [StudySession] = []
    private(set) var loadFailed = false
    private let defaults: UserDefaults
    private let key = "studySessions.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            do {
                sessions = try JSONDecoder().decode([StudySession].self, from: data)
                    .sorted { $0.endedAt > $1.endedAt }
            } catch {
                loadFailed = true
            }
        }
    }

    func save(_ draft: StudySession) throws {
        guard !loadFailed else { throw SaveError.unavailable }
        var session = draft
        session.blockDescription = session.blockDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard session.duration.isFinite, session.duration >= 1,
              session.duration <= 3_599_999,
              !session.blockDescription.isEmpty, session.blockDescription.count <= 500 else {
            throw SaveError.invalidSession
        }
        var updated = sessions.filter { $0.id != session.id }
        updated.append(session)
        updated.sort { $0.endedAt > $1.endedAt }
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: key)
        sessions = updated
    }

    enum SaveError: Error {
        case unavailable, invalidSession
    }
}
