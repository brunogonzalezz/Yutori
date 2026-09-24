import SwiftUI

struct StudyStreakView: View {
    let sessions: [StudySession]
    @State private var testClock = StudyTestClock.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let calendar = Calendar.autoupdatingCurrent
            let effectiveNow = testClock.date(for: timeline.date)
            let today = calendar.startOfDay(for: effectiveNow)
            let streak = StudyStreak(sessionDates: sessions.map(\.endedAt), now: effectiveNow, calendar: calendar)
            let mondayOffset = (calendar.component(.weekday, from: today) + 5) % 7
            let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today)!
            VStack(alignment: .leading, spacing: 14) {
                Text("Study streak")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                VStack(spacing: 18) {
                    HStack(spacing: 8) {
                        ForEach(0..<7) { index in
                            let day = calendar.date(byAdding: .day, value: index, to: monday)!
                            let dominantCourse = dominantCourse(on: day, through: effectiveNow, calendar: calendar)
                            let studied = dominantCourse != nil
                            VStack(spacing: 7) {
                                ZStack {
                                    if studied {
                                        StreakFlame(variation: index)
                                    } else {
                                        Circle()
                                            .fill(AppTheme.paper.opacity(0.72))
                                            .overlay {
                                                Circle().strokeBorder(
                                                    day == today ? AppTheme.ink.opacity(0.65) : AppTheme.muted.opacity(0.55),
                                                    lineWidth: day == today ? 2 : 1.5
                                                )
                                            }
                                    }
                                }
                                .frame(width: 34, height: 34)

                                Text(["M", "T", "W", "T", "F", "S", "S"][index])
                                    .font(.system(size: 11, weight: day == today ? .bold : .semibold, design: .rounded))
                                    .foregroundStyle(day == today ? AppTheme.ink : AppTheme.secondaryInk)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month().day()))
                            .accessibilityValue(dominantCourse.map { "Studied most: \($0.name)" }
                                                ?? (day == today ? "Today, not studied yet" : "Not studied"))
                        }
                    }

                    VStack(spacing: 6) {
                        Text(streakTitle(streak.count))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(streak.days.contains(today)
                             ? "A little progress each day builds a lasting habit."
                             : (streak.count > 0
                                ? "Study today to keep your rhythm going."
                                : "Complete a session to begin your study streak."))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 12)
                }
                .padding(18)
                .background(AppTheme.surface.opacity(0.66), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(AppTheme.ink.opacity(0.14), lineWidth: 1)
                }
            }
            .foregroundStyle(AppTheme.ink)
        }
    }

    private func streakTitle(_ count: Int) -> String {
        switch count {
        case 0: "Start your streak"
        case 1: "You've started a streak!"
        default: "\(count)-day study streak!"
        }
    }

    private func dominantCourse(on day: Date, through now: Date, calendar: Calendar) -> StudyCourse? {
        let daySessions = sessions.filter {
            $0.endedAt <= now && calendar.isDate($0.endedAt, inSameDayAs: day)
        }
        let grouped = Dictionary(grouping: daySessions, by: { $0.course.id })
        let totals = grouped.compactMap { _, sessions -> (course: StudyCourse, duration: TimeInterval, latest: Date)? in
            guard let course = sessions.first?.course else { return nil }
            let duration = sessions.reduce(0.0) { total, session in
                total + (session.duration.isFinite ? max(0, session.duration) : 0)
            }
            let latest = sessions.map(\.endedAt).max() ?? .distantPast
            return (course, duration, latest)
        }
        return totals.max { left, right in
            left.duration == right.duration ? left.latest < right.latest : left.duration < right.duration
        }?.course
    }
}

private struct StreakFlame: View {
    let variation: Int

    private var rotation: Double { [-3, 2, -1.5, 3, -2, 1, -0.5][variation % 7] }
    private var scale: CGFloat { [0.96, 1.00, 0.98, 0.95, 0.99, 0.97, 1.00][variation % 7] }

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .font(.system(size: 35, weight: .bold))
                .foregroundStyle(Color(red: 0.86, green: 0.20, blue: 0.10))

            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 1.00, green: 0.66, blue: 0.12))
                .scaleEffect(x: 0.72, y: 0.88)
                .offset(y: 4)
        }
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .accessibilityHidden(true)
    }
}
