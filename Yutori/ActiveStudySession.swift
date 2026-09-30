import ActivityKit
import Foundation
import Observation

@MainActor @Observable
final class ActiveStudySession {
    static let shared = ActiveStudySession()
    private(set) var id: UUID?
    private(set) var course: StudyCourse?
    private(set) var stopwatch = StudyStopwatch()
    private(set) var startingSeconds: TimeInterval = 0
    private(set) var kind: BowlKind = .teriyaki
    private(set) var finishedAt: Date?
    private(set) var revealedLevel = 0
    private(set) var pauseCount = 0
    private let key = "activeStudySession.v1"
    private struct Snapshot: Codable {
        let id: UUID
        let course: StudyCourse
        let stopwatch: StudyStopwatch
        let startingSeconds: TimeInterval
        let kind: BowlKind
        let finishedAt: Date?
        let revealedLevel: Int
        let pauseCount: Int?
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            id = saved.id; course = saved.course; stopwatch = saved.stopwatch
            startingSeconds = saved.startingSeconds; kind = saved.kind
            finishedAt = saved.finishedAt; revealedLevel = saved.revealedLevel
            pauseCount = saved.pauseCount ?? 0
        }
    }

    func start(course: StudyCourse) {
        guard id == nil else { return }
        id = UUID(); self.course = course
        pauseCount = 0
        startingSeconds = StudySessionStore.shared.earnedDishProgress.totalSeconds
        kind = StudySessionStore.shared.activeBowlKind
        revealedLevel = StudySessionStore.shared.earnedDishProgress.level
        finishedAt = nil; stopwatch = StudyStopwatch(); stopwatch.resume(at: .now)
        persist()
        Task { await syncActivity() }
    }
    func toggle() {
        if stopwatch.isRunning {
            stopwatch.pause(at: .now)
            pauseCount += 1
        }
        else { finishedAt = nil; stopwatch.resume(at: .now) }
        persist()
        Task { await syncActivity() }
    }
    func finish(at date: Date) {
        guard id != nil else { return }
        stopwatch.pause(at: date)
        if finishedAt == nil { finishedAt = date }
        persist()
        Task { await syncActivity() }
    }
    func reveal(_ level: Int) {
        revealedLevel = max(revealedLevel, level)
        persist()
        Task { await syncActivity() }
    }
    func clear() {
        let oldID = id?.uuidString
        id = nil; course = nil; finishedAt = nil; stopwatch = StudyStopwatch(); pauseCount = 0
        UserDefaults.standard.removeObject(forKey: key)
        Task {
            for activity in Activity<StudyActivityAttributes>.activities where activity.attributes.sessionID == oldID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    private func persist() {
        guard let id, let course else { return }
        let snapshot = Snapshot(id: id, course: course, stopwatch: stopwatch,
                                startingSeconds: startingSeconds, kind: kind,
                                finishedAt: finishedAt, revealedLevel: revealedLevel, pauseCount: pauseCount)
        if let data = try? JSONEncoder().encode(snapshot) { UserDefaults.standard.set(data, forKey: key) }
    }
    func syncActivity() async {
        guard let id, let course else { return }
        let level = DishProgress(totalSeconds: startingSeconds + stopwatch.elapsed(at: .now)).level
        let state = StudyActivityAttributes.ContentState(
            accumulated: stopwatch.accumulated,
            runningSince: stopwatch.runningSince,
            imageName: kind.imageName(level: level),
            level: level,
            languageCode: AppLanguage.selected.rawValue
        )
        let content = ActivityContent(state: state, staleDate: nil)
        let activities = Activity<StudyActivityAttributes>.activities.filter { $0.attributes.sessionID == id.uuidString }
        if finishedAt != nil {
            for activity in activities { await activity.end(content, dismissalPolicy: .immediate) }
        } else if !activities.isEmpty {
            for activity in activities { await activity.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: StudyActivityAttributes(
                    sessionID: id.uuidString,
                    courseName: course.name,
                    courseIcon: course.icon,
                    courseColorHex: course.color.rgbHex,
                    languageCode: AppLanguage.selected.rawValue
                ),
                                         content: content, pushType: nil)
            } catch {
                // The session remains usable if Live Activities are disabled or unavailable.
            }
        }
    }
}
