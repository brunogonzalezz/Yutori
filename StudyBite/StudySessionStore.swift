import Foundation
import Observation

@Observable
final class StudyTestClock {
    static let shared = StudyTestClock()
    var enabled = false
    var selectedDay = Date.now

    func date(for realDate: Date, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Date {
        guard enabled else { return realDate }
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                             to: calendar.startOfDay(for: selectedDay)).day ?? 0
        return calendar.date(byAdding: .day, value: offset, to: realDate) ?? realDate
    }
}

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
    static let descriptionWordLimit = 30
    static let descriptionCharacterLimit = 200

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    static func limitedDescription(_ text: String) -> String {
        let shortened = String(text.prefix(descriptionCharacterLimit))
        let words = shortened.split(whereSeparator: { $0.isWhitespace })
        guard words.count > descriptionWordLimit else { return shortened }
        return String(shortened[..<words[descriptionWordLimit - 1].endIndex])
    }

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

struct WeeklyStudyStats {
    let days: [Date]
    let sessions: [StudySession]
    let courses: [StudyCourse]
    private let calendar: Calendar

    init(sessions: [StudySession], courses: [StudyCourse], now: Date = .now,
         calendar: Calendar = .autoupdatingCurrent) {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        self.calendar = weekCalendar
        let start = weekCalendar.dateInterval(of: .weekOfYear, for: now)!.start
        let end = weekCalendar.date(byAdding: .day, value: 7, to: start)!
        days = (0..<7).map { weekCalendar.date(byAdding: .day, value: $0, to: start)! }
        let included = sessions.filter {
            $0.endedAt >= start && $0.endedAt < end && $0.endedAt <= now &&
            $0.duration.isFinite && $0.duration > 0
        }
        self.sessions = included
        var seen = Set<UUID>()
        self.courses = included.sorted { $0.endedAt > $1.endedAt }.compactMap { session in
            guard seen.insert(session.course.id).inserted else { return nil }
            return courses.first { $0.id == session.course.id } ?? session.course
        }
    }

    var totalMinutes: Int { Int(sessions.reduce(0) { $0 + $1.duration } / 60) }

    func minutes(for course: StudyCourse, on day: Date) -> Double {
        sessions.filter { $0.course.id == course.id && calendar.isDate($0.endedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.duration } / 60
    }
}

enum BowlKind: String, Codable, CaseIterable {
    case katsuRamen, teriyaki
    var name: String { self == .katsuRamen ? "Katsu Ramen" : "Teriyaki Bowl" }
    func imageName(level: Int) -> String {
        self == .katsuRamen ? "DishLevel\(level)" : "TeriyakiLevel\(level)"
    }
}

struct CollectedBowl: Identifiable, Codable {
    var id = UUID()
    var collectedAt = Date.now
    var kind: BowlKind? = nil
    var bowlKind: BowlKind { kind ?? .katsuRamen }
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
    // Temporary visual testing override; never written to saved study data.
    private var previewDishOffset: TimeInterval = 0
    private struct Collection: Codable {
        var bowls: [CollectedBowl] = []
        var usedSeconds: TimeInterval = 0
        var needsSelection: Bool?
        var activeKind: BowlKind?
    }
    private var collection = Collection()
    private let collectionKey = "collectedBowls.v1"
    private(set) var collectionLoadFailed = false
    var collectedBowls: [CollectedBowl] { collection.bowls }
    var activeBowlKind: BowlKind { collection.activeKind ?? .katsuRamen }
    var collectedKinds: Set<BowlKind> { Set(collection.bowls.map(\.bowlKind)) }
    var hasActiveBowl: Bool {
        !(collection.needsSelection ?? !collection.bowls.isEmpty)
    }

    @discardableResult
    func selectNextBowl(_ kind: BowlKind = .katsuRamen) -> Bool {
        guard !hasActiveBowl, !collectionLoadFailed else { return false }
        var updated = collection
        updated.needsSelection = false
        updated.activeKind = kind
        guard let data = try? JSONEncoder().encode(updated) else { return false }
        defaults.set(data, forKey: collectionKey)
        collection = updated
        previewDishOffset = 0
        return true
    }
    private var availableDishSeconds: TimeInterval {
        max(0, earnedDishSeconds - collection.usedSeconds)
    }
    var canCollectBowl: Bool {
        hasActiveBowl && !loadFailed && !collectionLoadFailed && DishProgress(totalSeconds: availableDishSeconds).isComplete
    }

    @discardableResult
    func collectBowl() -> Bool {
        guard canCollectBowl else { return false }
        var updated = collection
        updated.bowls.insert(CollectedBowl(kind: activeBowlKind), at: 0)
        updated.needsSelection = true
        updated.usedSeconds += Double(DishProgress.maximumLevel) * DishProgress.secondsPerLevel
        guard let data = try? JSONEncoder().encode(updated) else { return false }
        defaults.set(data, forKey: collectionKey)
        collection = updated
        previewDishOffset = 0
        return true
    }

    private var earnedDishSeconds: TimeInterval {
        DishProgress(sessions: sessions.filter { !existingDishSessionIDs.contains($0.id) }).totalSeconds
    }

    var dishProgress: DishProgress {
        DishProgress(totalSeconds: availableDishSeconds + previewDishOffset)
    }

    func advanceDishPreview() {
        stepDishPreview(by: 1)
    }

    func stepDishPreview(by step: Int) {
        let count = DishProgress.maximumLevel + 1
        let nextLevel = ((dishProgress.level + step) % count + count) % count
        previewDishOffset = Double(nextLevel) * DishProgress.secondsPerLevel - availableDishSeconds
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: collectionKey) {
            if let saved = try? JSONDecoder().decode(Collection.self, from: data),
               saved.usedSeconds.isFinite, saved.usedSeconds >= 0 {
                collection = saved
            } else {
                collectionLoadFailed = true
            }
        }
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
              !session.blockDescription.isEmpty,
              session.blockDescription.count <= StudySession.descriptionCharacterLimit,
              StudySession.wordCount(session.blockDescription) <= StudySession.descriptionWordLimit else {
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
        // Reset current study progress while keeping already collected bowls.
        if !collectionLoadFailed {
            collection.usedSeconds = 0
            if let data = try? JSONEncoder().encode(collection) {
                defaults.set(data, forKey: collectionKey)
            }
        }
        previewDishOffset = 0
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
