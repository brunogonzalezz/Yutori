import Foundation

struct StudyStreak {
    let days: Set<Date>
    let count: Int

    init(sessionDates: [Date], now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let today = calendar.startOfDay(for: now)
        days = Set(sessionDates.filter { $0 <= now }.map { calendar.startOfDay(for: $0) })
        var cursor = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var total = 0
        while days.contains(cursor) {
            total += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        count = total
    }
}
