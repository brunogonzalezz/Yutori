import SwiftUI

struct StudyStreakView: View {
    let sessions: [StudySession]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let calendar = Calendar.autoupdatingCurrent
            let today = calendar.startOfDay(for: timeline.date)
            let streak = StudyStreak(sessionDates: sessions.map(\.endedAt), now: timeline.date, calendar: calendar)
            let mondayOffset = (calendar.component(.weekday, from: today) + 5) % 7
            let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today)!
            VStack(alignment: .leading, spacing: 14) {
                Text("Study streak")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 27, design: .rounded))
                            .foregroundStyle(CourseColor.orange.tint)
                            .frame(width: 52, height: 52)
                            .background(AppTheme.paper.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(streak.count) \(streak.count == 1 ? "day" : "days")")
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(streak.days.contains(today) ? "A little progress, every day." : (streak.count > 0 ? "Study today to keep it going." : "Your next session starts a new streak."))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        ForEach(0..<7) { index in
                            let day = calendar.date(byAdding: .day, value: index, to: monday)!
                            let studied = streak.days.contains(day)
                            VStack(spacing: 8) {
                                Text(["M", "T", "W", "T", "F", "S", "S"][index])
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.secondaryInk)
                                ZStack {
                                    Circle().fill(studied ? AppTheme.ink : AppTheme.paper.opacity(0.7))
                                    if studied {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(AppTheme.paper)
                                    } else {
                                        Circle().fill(AppTheme.muted).frame(width: 5, height: 5)
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { Circle().strokeBorder(day == today ? AppTheme.ink : .clear, lineWidth: 1.5) }
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month().day()))
                            .accessibilityValue(studied ? "Studied" : (day == today ? "Today, not studied yet" : "Not studied"))
                        }
                    }
                }
                .padding(18)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 28))
            }
            .foregroundStyle(AppTheme.ink)
        }
    }
}
