import SwiftUI

struct StudyCalendarView: View {
    let sessions: [StudySession]
    let courses: [StudyCourse]
    let bowls: [CollectedBowl]
    let now: Date
    @AppStorage("appFirstUseTimestamp") private var firstUseTimestamp = 0.0
    @State private var monthOffset = 0

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    private var currentMonthStart: Date {
        calendar.dateInterval(of: .month, for: now)!.start
    }

    private var monthStart: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: currentMonthStart) ?? currentMonthStart
    }

    private var inferredFirstUseDate: Date {
        let activityDates = sessions.map(\.endedAt) + bowls.map(\.collectedAt)
        return activityDates.filter { $0 <= now }.min() ?? now
    }

    private var firstUseDate: Date {
        guard firstUseTimestamp > 0 else { return inferredFirstUseDate }
        return min(Date(timeIntervalSince1970: firstUseTimestamp), now)
    }

    private var firstAvailableMonth: Date {
        calendar.dateInterval(of: .month, for: firstUseDate)!.start
    }

    private var canMoveBackward: Bool {
        monthStart > firstAvailableMonth
    }

    private var canMoveForward: Bool {
        monthOffset < 0
    }

    private var leadingDays: Int {
        (calendar.component(.weekday, from: monthStart) + 5) % 7
    }

    private var dayCount: Int { calendar.range(of: .day, in: .month, for: monthStart)!.count }

    var body: some View {
        let sessionsByDay = Dictionary(grouping: sessions.filter { $0.duration.isFinite && $0.duration > 0 && $0.endedAt <= now }) {
            calendar.startOfDay(for: $0.endedAt)
        }
        let bowlsByDay = Dictionary(grouping: bowls.filter { $0.collectedAt <= now }) {
            calendar.startOfDay(for: $0.collectedAt)
        }
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    calendarTitle
                    Spacer(minLength: 10)
                    monthNavigation
                }

                VStack(alignment: .leading, spacing: 10) {
                    calendarTitle
                    monthNavigation
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 7) {
                ForEach(0..<7, id: \.self) { index in
                    let symbol = calendar.veryShortStandaloneWeekdaySymbols[(index + 1) % 7]
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 3)
                }
                ForEach(0..<(leadingDays + dayCount), id: \.self) { index in
                    if index < leadingDays {
                        Color.clear.aspectRatio(0.73, contentMode: .fit)
                            .accessibilityHidden(true)
                    } else {
                        let date = calendar.date(byAdding: .day, value: index - leadingDays, to: monthStart)!
                        CalendarDayView(
                            date: date,
                            number: index - leadingDays + 1,
                            isToday: calendar.isDate(date, inSameDayAs: now),
                            course: dominantCourse(in: sessionsByDay[date] ?? []),
                            bowls: Array((bowlsByDay[date] ?? []).sorted { $0.collectedAt < $1.collectedAt }.prefix(3))
                        )
                    }
                }
            }
        }
        .onAppear {
            if firstUseTimestamp == 0 {
                firstUseTimestamp = inferredFirstUseDate.timeIntervalSince1970
            }
        }
    }

    private var calendarTitle: some View {
        Text("Calendar")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.ink)
    }

    private var monthNavigation: some View {
        HStack(spacing: 5) {
            monthButton(systemImage: "chevron.left", enabled: canMoveBackward) {
                withAnimation(.easeInOut(duration: 0.22)) { monthOffset -= 1 }
            }

            Text(monthStart, format: .dateTime.month(.wide).year())
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .allowsTightening(true)
                .frame(width: 142)
                .contentTransition(.numericText())

            monthButton(systemImage: "chevron.right", enabled: canMoveForward) {
                withAnimation(.easeInOut(duration: 0.22)) { monthOffset += 1 }
            }
        }
    }

    private func monthButton(systemImage: String, enabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(enabled ? AppTheme.ink : AppTheme.muted.opacity(0.45))
                .frame(width: 30, height: 30)
                .background(AppTheme.surface.opacity(enabled ? 0.82 : 0.36), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(AppLanguage.localized(systemImage == "chevron.left" ? "Previous month" : "Next month"))
    }

    private func dominantCourse(in sessions: [StudySession]) -> StudyCourse? {
        let grouped = Dictionary(grouping: sessions, by: { $0.course.id })
        let winner = grouped.keys.sorted { left, right in
            let leftTime = grouped[left, default: []].reduce(0) { $0 + $1.duration }
            let rightTime = grouped[right, default: []].reduce(0) { $0 + $1.duration }
            return leftTime == rightTime ? left.uuidString < right.uuidString : leftTime > rightTime
        }.first
        guard let winner else { return nil }
        return courses.first { $0.id == winner } ?? grouped[winner]?.first?.course
    }
}

private struct CalendarDayView: View {
    let date: Date
    let number: Int
    let isToday: Bool
    let course: StudyCourse?
    let bowls: [CollectedBowl]

    var body: some View {
        GeometryReader { geometry in
            let shape = RoundedRectangle(cornerRadius: min(20, geometry.size.width * 0.36), style: .continuous)
            ZStack {
                if let course {
                    shape.fill(AppTheme.paper)
                    shape.fill(course.color.tint.opacity(isToday ? 0.38 : 0.28))
                    shape.strokeBorder(course.color.tint, lineWidth: 2.5)
                } else {
                    shape.fill(isToday ? AppTheme.muted : AppTheme.surface)
                }
                if bowls.isEmpty {
                    Text("\(number)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                } else {
                    // Fit the whole stack, with room inside the coloured border.
                    let count = CGFloat(bowls.count)
                    let sizeFactor: CGFloat = bowls.count == 1 ? 1 : (bowls.count == 2 ? 0.94 : 0.90)
                    let overlapStep: CGFloat = bowls.count == 3 ? 0.38 : 0.56
                    let width = max(0, min((geometry.size.width - 10) * sizeFactor,
                                          (geometry.size.height - 14) / (1 + (count - 1) * overlapStep)))
                    let step = width * overlapStep
                    ZStack {
                        ForEach(Array(bowls.enumerated()), id: \.element.id) { index, bowl in
                            DishArtworkView(level: 5, availableWidth: width + 48,
                                            preferredWidth: width, kind: bowl.bowlKind)
                                .offset(y: (CGFloat(index) - CGFloat(bowls.count - 1) / 2) * step)
                                .zIndex(Double(index))
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(shape)
        }
        .aspectRatio(0.73, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(
            .dateTime.weekday(.wide).day().month().locale(AppLanguage.selected.locale)
        ))
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        if isToday { parts.append(AppLanguage.localized("Today")) }
        if let course { parts.append(course.name) }
        if !bowls.isEmpty {
            parts.append(AppLanguage.formatted("%lld bowls collected", Int64(bowls.count)))
        }
        return parts.isEmpty ? AppLanguage.localized("No study activity") : parts.joined(separator: ", ")
    }
}
