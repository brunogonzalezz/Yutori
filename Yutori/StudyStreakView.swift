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

                                Text((AppLanguage.selected == .spanish
                                      ? ["L", "M", "X", "J", "V", "S", "D"]
                                      : ["M", "T", "W", "T", "F", "S", "S"])[index])
                                    .font(.system(size: 11, weight: day == today ? .bold : .semibold, design: .rounded))
                                    .foregroundStyle(day == today ? AppTheme.ink : AppTheme.secondaryInk)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month().day()))
                            .accessibilityValue(dominantCourse.map {
                                AppLanguage.formatted("Studied most: %@", $0.name)
                            } ?? AppLanguage.localized(day == today ? "Today, not studied yet" : "Not studied"))
                        }
                    }

                    VStack(spacing: 6) {
                        Text(streakTitle(streak.count))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(AppLanguage.localized(streak.days.contains(today)
                             ? "A little progress each day builds a lasting habit."
                             : (streak.count > 0
                                ? "Study today to keep your rhythm going."
                                : "Complete a session to begin your study streak.")))
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
        case 0: AppLanguage.localized("Start your streak")
        case 1: AppLanguage.localized("You've started a streak!")
        default: AppLanguage.formatted("%lld-day study streak!", Int64(count))
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

    // Stable variations make the week feel naturally scattered without moving on redraw.
    private var rotation: Double { [-11, 7, -5, 12, -9, 4, -2][variation % 7] }
    private var scale: CGFloat { [0.91, 0.95, 0.93, 0.90, 0.94, 0.92, 0.96][variation % 7] }
    private var offset: CGSize {
        let offsets: [CGSize] = [
            .init(width: -1.5, height: 1), .init(width: 1, height: -0.5),
            .init(width: -0.5, height: 0), .init(width: 1.5, height: 1),
            .init(width: -1, height: -0.5), .init(width: 0.5, height: 1),
            .init(width: 0, height: -0.5)
        ]
        return offsets[variation % offsets.count]
    }

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(CourseColor.red.tint)

            Image(systemName: "flame.fill")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(CourseColor.orange.tint)
                .scaleEffect(x: 0.68, y: 0.84)
                .offset(y: 4)

            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.paper.opacity(0.92))
                .scaleEffect(x: 0.62, y: 0.76)
                .offset(y: 7)
        }
        .frame(width: 32, height: 34)
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
        .accessibilityHidden(true)
    }
}
