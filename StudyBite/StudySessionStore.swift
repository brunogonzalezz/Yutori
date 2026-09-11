import Foundation
import Observation

struct DishProgress {
    static let secondsPerLevel: TimeInterval = 3600
    static let maximumLevel = 5
    let totalSeconds: TimeInterval

    init(totalSeconds: TimeInterval) {
        self.totalSeconds = totalSeconds.isFinite ? max(0, totalSeconds) : 0
    }

    init(sessions: [StudySession]) {
        totalSeconds = sessions.reduce(0) { total, session in
            total + (session.duration.isFinite ? max(0, session.duration) : 0)
        }
    }

    var level: Int {
        Int(min(totalSeconds / Self.secondsPerLevel, Double(Self.maximumLevel)))
    }
    var isComplete: Bool { level == Self.maximumLevel }
    var imageName: String { "DishLevel\(level)" }
    var fraction: Double {
        isComplete ? 1 : (totalSeconds - Double(level) * Self.secondsPerLevel) / Self.secondsPerLevel
    }
    var remainingMinutes: Int {
        isComplete ? 0 : Int(ceil((Double(level + 1) * Self.secondsPerLevel - totalSeconds) / 60))
    }
}

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
    private let dishBaselineKey = "dishProgress.existingSessionIDs.v1"
    private var existingDishSessionIDs: Set<UUID> = []

    var dishProgress: DishProgress {
        DishProgress(sessions: sessions.filter { !existingDishSessionIDs.contains($0.id) })
    }

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
        if let savedIDs = defaults.stringArray(forKey: dishBaselineKey) {
            existingDishSessionIDs = Set(savedIDs.compactMap { UUID(uuidString: $0) })
        } else if !loadFailed {
            // Begin the first dish without crediting sessions from before its introduction.
            existingDishSessionIDs = Set(sessions.map(\.id))
            defaults.set(existingDishSessionIDs.map(\.uuidString), forKey: dishBaselineKey)
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

    func deleteAllSessions() {
        defaults.removeObject(forKey: key)
        defaults.set([String](), forKey: dishBaselineKey)
        existingDishSessionIDs = []
        sessions = []
        loadFailed = false
    }

    enum SaveError: Error {
        case unavailable, invalidSession
    }
}
