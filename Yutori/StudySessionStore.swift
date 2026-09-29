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
            total + (session.dishDuration.isFinite ? max(0, session.dishDuration) : 0)
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
    var startingDishSeconds: TimeInterval? = nil
    var bowlKind: BowlKind? = nil
    var pauseCount: Int? = nil
    var originalDuration: TimeInterval? = nil

    var dishDuration: TimeInterval { originalDuration ?? duration }

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
    case teriyaki, katsuRamen, tofuCurry, chirashi
    var name: String {
        switch self {
        case .teriyaki: "Teriyaki Bowl"
        case .katsuRamen: "Katsu Ramen"
        case .tofuCurry: "Tofu Curry"
        case .chirashi: "Chirashi Bowl"
        }
    }
    func imageName(level: Int) -> String {
        switch self {
        case .teriyaki: "TeriyakiLevel\(level)"
        case .katsuRamen: "DishLevel\(level)"
        case .tofuCurry: "TofuCurryLevel\(level)"
        case .chirashi: "ChirashiBowlLevel\(level)"
        }
    }
}

struct CollectedBowl: Identifiable, Codable {
    var id = UUID()
    var collectedAt = Date.now
    var kind: BowlKind? = nil
    var sourceSessionIDs: [UUID]? = nil
    var usedSecondsBeforeCollection: TimeInterval? = nil
    var isStarterGift: Bool? = nil
    var bowlKind: BowlKind { kind ?? .teriyaki }
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
    var activeBowlKind: BowlKind { collection.activeKind ?? .teriyaki }
    var collectedKinds: Set<BowlKind> { Set(collection.bowls.map(\.bowlKind)) }
    var earnedDishProgress: DishProgress { DishProgress(totalSeconds: availableDishSeconds) }

    private let unlockSecondsKey = "bowlUnlock.studySeconds.v1"
    private let unlockedCountKey = "bowlUnlock.claimedCount.v1"
    private(set) var bowlUnlockSeconds: TimeInterval = 0
    private(set) var unlockedBowlCount: Int
    private var hasLoadedUnlockedCount: Bool
    var nextBowlMilestone: Int? {
        unlockedBowlCount < BowlCatalog.entries.count
            ? BowlCatalog.entries[unlockedBowlCount].requiredHours : nil
    }
    var canUnlockNextBowl: Bool {
        unlockedBowlCount < BowlCatalog.entries.count
            && unlockedBowlCount < BowlCatalog.unlockedCount(seconds: bowlUnlockSeconds)
    }
    func isBowlUnlocked(_ entry: BowlCatalogEntry) -> Bool { entry.id < unlockedBowlCount }

    @discardableResult
    func unlockNextBowl() -> Bool {
        guard canUnlockNextBowl else { return false }
        unlockedBowlCount += 1
        defaults.set(unlockedBowlCount, forKey: unlockedCountKey)
        hasLoadedUnlockedCount = true
        return true
    }

    private func updateBowlUnlocks() {
        // Manual time edits never count: dishDuration keeps the originally recorded time.
        let studied = sessions.reduce(0.0) { total, session in
            total + (session.dishDuration.isFinite ? max(0, session.dishDuration) : 0)
        }
        bowlUnlockSeconds = studied
        defaults.set(bowlUnlockSeconds, forKey: unlockSecondsKey)
        let eligibleCount = BowlCatalog.unlockedCount(seconds: bowlUnlockSeconds)
        if hasLoadedUnlockedCount {
            unlockedBowlCount = min(max(BowlCatalog.initialUnlockedCount, unlockedBowlCount), eligibleCount)
        } else {
            // Preserve bowls earned before unlocks became an explicit action.
            unlockedBowlCount = eligibleCount
            hasLoadedUnlockedCount = true
        }
        defaults.set(unlockedBowlCount, forKey: unlockedCountKey)
    }

    private func reconcileCollectionWithEarnedTime(deleting sessionID: UUID? = nil) {
        guard !collectionLoadFailed else { return }
        let earned = earnedDishSeconds
        let bowlCost = DishProgress.secondsPerLevel * Double(DishProgress.maximumLevel)
        let supportedBowls = Int(earned / bowlCost)
        var updated = collection
        var restoredKind: BowlKind?

        if let sessionID,
           let affectedIndex = updated.bowls.firstIndex(where: { $0.sourceSessionIDs?.contains(sessionID) == true }) {
            let affected = updated.bowls[affectedIndex]
            restoredKind = affected.bowlKind
            updated.bowls.removeFirst(affectedIndex + 1)
            updated.usedSeconds = affected.usedSecondsBeforeCollection
                ?? max(0, updated.usedSeconds - bowlCost * Double(affectedIndex + 1))
        }

        // Rewind completed bowls until the remaining study history can support them.
        while updated.usedSeconds > earned ||
              updated.bowls.filter({ $0.isStarterGift != true }).count > supportedBowls {
            guard let removableIndex = updated.bowls.firstIndex(where: { $0.isStarterGift != true }) else { break }
            let restored = updated.bowls.remove(at: removableIndex)
            restoredKind = restored.bowlKind
            updated.usedSeconds = max(0, updated.usedSeconds - bowlCost)
        }

        if let restoredKind {
            updated.activeKind = restoredKind
            updated.needsSelection = false
            previewDishOffset = 0
        }

        updated.usedSeconds = min(updated.usedSeconds, earned)
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: collectionKey)
            collection = updated
        }
    }


    func discoveredLevel(for kind: BowlKind) -> Int {
        if collectedKinds.contains(kind) { return DishProgress.maximumLevel }
        return hasActiveBowl && activeBowlKind == kind ? earnedDishProgress.level : 0
    }

    func clearDishPreview() { previewDishOffset = 0 }
    var hasActiveBowl: Bool {
        !(collection.needsSelection ?? !collection.bowls.isEmpty)
    }

    @discardableResult
    func selectNextBowl(_ kind: BowlKind = .teriyaki) -> Bool {
        guard !hasActiveBowl, !loadFailed, !collectionLoadFailed,
              let entry = BowlCatalog.entries.first(where: { $0.kind == kind }),
              isBowlUnlocked(entry) else { return false }
        var updated = collection
        updated.needsSelection = false
        updated.activeKind = kind
        // A newly selected bowl only receives study time earned from this point onward.
        updated.usedSeconds = earnedDishSeconds
        guard let data = try? JSONEncoder().encode(updated) else { return false }
        defaults.set(data, forKey: collectionKey)
        collection = updated
        previewDishOffset = 0
        return true
    }

    func clearActiveBowlSelection() {
        guard !loadFailed, !collectionLoadFailed else { return }
        var updated = collection
        updated.activeKind = nil
        updated.needsSelection = true
        updated.usedSeconds = earnedDishSeconds
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: collectionKey)
        collection = updated
        previewDishOffset = 0
    }

    @discardableResult
    func grantStarterTeriyakiBowlIfNeeded() -> Bool {
        guard !loadFailed, !collectionLoadFailed else { return false }
        guard !collection.bowls.contains(where: { $0.bowlKind == .teriyaki }) else { return true }

        var updated = collection
        updated.bowls.append(
            CollectedBowl(
                collectedAt: StudyTestClock.shared.date(for: .now),
                kind: .teriyaki,
                sourceSessionIDs: [],
                usedSecondsBeforeCollection: updated.usedSeconds,
                isStarterGift: true
            )
        )
        updated.activeKind = nil
        updated.needsSelection = true
        updated.usedSeconds = earnedDishSeconds
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
        let collectedAt = StudyTestClock.shared.date(for: .now)
        let previousCollectionDate = updated.bowls.first?.collectedAt
        let sourceSessionIDs = sessions.filter { session in
            let isAfterPreviousCollection = previousCollectionDate.map { session.endedAt > $0 } ?? true
            return !existingDishSessionIDs.contains(session.id)
                && session.bowlKind == activeBowlKind
                && session.endedAt <= collectedAt
                && isAfterPreviousCollection
        }.map(\.id)
        updated.bowls.insert(
            CollectedBowl(
                collectedAt: collectedAt,
                kind: activeBowlKind,
                sourceSessionIDs: sourceSessionIDs,
                usedSecondsBeforeCollection: updated.usedSeconds
            ),
            at: 0
        )
        updated.needsSelection = true
        // Consume the entire session balance, including time beyond the final evolution.
        updated.usedSeconds = earnedDishSeconds
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
        let savedUnlockedCount = defaults.object(forKey: unlockedCountKey) as? NSNumber
        unlockedBowlCount = savedUnlockedCount?.intValue ?? BowlCatalog.initialUnlockedCount
        hasLoadedUnlockedCount = savedUnlockedCount != nil
        let savedUnlockSeconds = defaults.double(forKey: unlockSecondsKey)
        bowlUnlockSeconds = savedUnlockSeconds.isFinite ? max(0, savedUnlockSeconds) : 0
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
        if !loadFailed { updateBowlUnlocks() }
    }

    func save(_ draft: StudySession) throws {
        guard !loadFailed else { throw SaveError.unavailable }
        var session = draft
        session.blockDescription = session.blockDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard session.duration.isFinite, session.duration >= 1,
              session.duration <= 3_599_999,
              session.blockDescription.count <= StudySession.descriptionCharacterLimit,
              StudySession.wordCount(session.blockDescription) <= StudySession.descriptionWordLimit else {
            throw SaveError.invalidSession
        }
        if let existing = sessions.first(where: { $0.id == session.id }) {
            let original = existing.originalDuration ?? existing.duration
            guard abs(session.duration - original) <= 10 * 3600 else { throw SaveError.invalidSession }
            session.originalDuration = original
        } else {
            // Newly recorded sessions must always carry their historical bowl snapshot.
            guard let start = session.startingDishSeconds, start.isFinite, start >= 0,
                  session.bowlKind != nil, let pauses = session.pauseCount, pauses >= 0 else {
                throw SaveError.invalidSession
            }
            session.originalDuration = session.duration
        }
        var updated = sessions.filter { $0.id != session.id }
        updated.append(session)
        updated.sort { $0.endedAt > $1.endedAt }
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: key)
        sessions = updated
        updateBowlUnlocks()
    }

    func deleteSession(id: UUID) throws {
        guard !loadFailed else { throw SaveError.unavailable }
        let updated = sessions.filter { $0.id != id }
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: key)
        sessions = updated
        if existingDishSessionIDs.remove(id) != nil {
            defaults.set(existingDishSessionIDs.map(\.uuidString), forKey: dishBaselineKey)
        }
        updateBowlUnlocks()
        reconcileCollectionWithEarnedTime(deleting: id)
    }

    func deleteAllSessions() {
        previewDishOffset = 0
        defaults.removeObject(forKey: key)
        defaults.set([String](), forKey: dishBaselineKey)
        existingDishSessionIDs = []
        sessions = []
        updateBowlUnlocks()
        reconcileCollectionWithEarnedTime()
        loadFailed = false
    }

    func resetAllData() {
        bowlUnlockSeconds = 0
        unlockedBowlCount = BowlCatalog.initialUnlockedCount
        hasLoadedUnlockedCount = true
        defaults.removeObject(forKey: unlockSecondsKey)
        defaults.set(unlockedBowlCount, forKey: unlockedCountKey)
        defaults.removeObject(forKey: key)
        defaults.set([String](), forKey: dishBaselineKey)
        defaults.removeObject(forKey: "bowlWallet.v1")
        collection = Collection()
        collection.needsSelection = true
        // Preserve only the empty state: no bowl is selected after a full reset.
        if let data = try? JSONEncoder().encode(collection) {
            defaults.set(data, forKey: collectionKey)
        }
        sessions = []
        existingDishSessionIDs = []
        previewDishOffset = 0
        loadFailed = false
        collectionLoadFailed = false
    }

    enum SaveError: Error {
        case unavailable, invalidSession
    }
}
