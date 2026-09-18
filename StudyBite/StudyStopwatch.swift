import Foundation

struct StudyStopwatch {
    private(set) var accumulated: TimeInterval = 0
    private(set) var runningSince: Date?
    var isRunning: Bool { runningSince != nil }

    func elapsed(at date: Date) -> TimeInterval {
        accumulated + (runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    mutating func resume(at date: Date) {
        guard !isRunning else { return }
        runningSince = date
    }

    mutating func pause(at date: Date) {
        accumulated = elapsed(at: date)
        runningSince = nil
    }

    func formattedElapsed(at date: Date) -> String {
        let seconds = Int(elapsed(at: date))
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
