import Charts
import Foundation
import SwiftUI
import UIKit

struct StatsView: View {
    @State private var showSettings = false
    @State private var sessionStore = StudySessionStore.shared
    @State private var courseStore = CourseStore.shared
    @State private var testClock = StudyTestClock.shared

    var body: some View {
        // Read the observable stores in the parent so every mutation redraws Stats.
        let sessions = sessionStore.sessions
        let courses = courseStore.courses
        // The periodic refresh only handles calendar changes while the screen is idle.
        TimelineView(.periodic(from: .now, by: 60)) { _ in
        let stats = WeeklyStudyStats(sessions: sessions, courses: courses,
                                    now: testClock.date(for: .now))
        let weeklySeries = CourseWeeklySeries.series(from: stats)
        let hasStudyActivity = weeklySeries.contains { series in
            series.dailyMinutes.contains { $0.minutes > 0 }
        }
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                profileButton
                    .padding(.leading, 9)
                    .padding(.bottom, 16)

                Text("Your study journey")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 24)

                weeklyMetrics(stats)
                    .padding(.bottom, 26)

                sectionDivider
                    .padding(.bottom, 24)

                if sessionStore.loadFailed {
                    Text("Couldn't load your sessions. Please reopen the app and try again.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .padding(.bottom, 20)
                }

                Text("Study activity")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.leading, 8)
                    .padding(.bottom, hasStudyActivity ? 32 : 18)

                WeeklySummaryChart(courses: weeklySeries, days: stats.days)
                    .frame(height: hasStudyActivity ? 240 : 174)

                sectionDivider
                    .padding(.top, hasStudyActivity ? 28 : 18)
                    .padding(.bottom, 24)

                StudyCalendarView(sessions: sessions, courses: courses,
                                  bowls: sessionStore.collectedBowls,
                                  now: testClock.date(for: .now))
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(AppTheme.paper)
        }
        .sheet(isPresented: $showSettings) {
            Group {
            SettingsView()

            }.presentationBackground(AppTheme.paper)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppTheme.ink.opacity(0.10))
            .frame(height: 1)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
    }

    private var profileButton: some View {
        Button {
            showSettings = true
        } label: {
            ProfileAvatarView(size: 50)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open settings")
    }

    private func weeklyMetrics(_ stats: WeeklyStudyStats) -> some View {
        let totalSeconds = stats.sessions.reduce(0) { $0 + $1.duration }
        let totalHours = totalSeconds / 3600
        let showsDays = totalHours >= 10_000
        let studyTime = (showsDays ? totalHours / 24 : totalHours)
            .formatted(.number.precision(.fractionLength(0)))
        let studyTimeLabel = showsDays ? "days studied" : "hours studied"
        let average = stats.sessions.isEmpty ? 0 : totalSeconds / Double(stats.sessions.count)
        let averageText = average > 0 && average < 60 ? "<1" : "\(Int((average / 60).rounded()))"
        let collected = sessionStore.collectedBowls.count

        return VStack(spacing: 16) {
            MetricRowLayout(weights: [0.29, 0, 0.42, 0, 0.29]) {
                MetricView(value: sessionStore.loadFailed ? "—" : "\(stats.sessions.count)", label: "sessions")
                metricSeparator
                MetricView(value: sessionStore.loadFailed ? "—" : studyTime, label: studyTimeLabel)
                metricSeparator
                MetricView(value: sessionStore.loadFailed ? "—" : "\(stats.courses.count)", label: "subjects")
            }
            MetricRowLayout(weights: [0.5, 0, 0.5]) {
                MetricView(value: "\(collected)", label: "bowls collected")
                metricSeparator
                MetricView(value: sessionStore.loadFailed ? "—" : averageText, label: "session average", suffix: sessionStore.loadFailed ? "" : "m")
            }
        }
        .padding(.horizontal, 4)
    }

    private var metricSeparator: some View {
        Rectangle()
            .fill(AppTheme.muted)
            .frame(width: 1, height: 52)
            .accessibilityHidden(true)
    }
}

// The longer middle caption gets more room without shifting either row off centre.
private struct MetricRowLayout: Layout {
    let weights: [CGFloat]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let available = max(0, width - CGFloat(weights.filter { $0 == 0 }.count))
        let height = subviews.enumerated().map { index, view in
            view.sizeThatFits(ProposedViewSize(width: weights[index] == 0 ? 1 : available * weights[index], height: nil)).height
        }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let available = max(0, bounds.width - CGFloat(weights.filter { $0 == 0 }.count))
        var x = bounds.minX
        for (index, view) in subviews.enumerated() {
            let width = weights[index] == 0 ? 1 : available * weights[index]
            view.place(at: CGPoint(x: x + width / 2, y: bounds.midY), anchor: .center,
                       proposal: ProposedViewSize(width: width, height: nil))
            x += width
        }
    }
}

private struct MetricView: View {
    let value: String
    let label: String
    var suffix: String = ""
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 40.0
    @ScaledMetric(relativeTo: .subheadline) private var labelSize = 16.0

    var body: some View {
        VStack(spacing: 1) {
            Text("\(Text(value).font(.system(size: numberSize, weight: .bold, design: .rounded)))\(Text(suffix).font(.system(size: numberSize * 0.80, weight: .bold, design: .rounded)))")
                .foregroundStyle(AppTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label)
                .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 161 / 255, green: 154 / 255, blue: 138 / 255))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

private struct WeeklySummaryChart: View {
    let courses: [CourseWeeklySeries]
    let days: [Date]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ActivityBar: Identifiable {
        let id: String
        let course: String
        let date: Date
        let minutes: Double
        let color: Color
        let dayIndex: Double
    }

    private var bars: [ActivityBar] {
        days.enumerated().flatMap { index, date in
            let entries = courses.compactMap { course -> (CourseWeeklySeries, Double)? in
                guard let minutes = course.dailyMinutes.first(where: { $0.date == date })?.minutes,
                      minutes > 0 else { return nil }
                return (course, minutes)
            }
            return entries.sorted { $0.0.id.uuidString < $1.0.id.uuidString }.map { entry in
                ActivityBar(id: "\(index)-\(entry.0.id)", course: entry.0.name,
                            date: date, minutes: entry.1, color: entry.0.color,
                            dayIndex: Double(index))
            }
        }
    }

    private var maximumDailyMinutes: Double {
        let totals = Dictionary(grouping: bars, by: \.dayIndex).values.map { segments in
            segments.reduce(0.0) { $0 + $1.minutes }
        }
        return totals.max() ?? 0
    }

    private var usesHours: Bool { maximumDailyMinutes >= 120 }
    private var divisor: Double { usesHours ? 60 : 1 }
    private var tickStep: Double {
        let maximum = maximumDailyMinutes / divisor
        let desired = max(1.0, maximum * 1.12 / 4)
        let magnitude = pow(10, floor(log10(desired)))
        return ceil(([1.0, 2, 5, 10].first { $0 * magnitude >= desired } ?? 10) * magnitude)
    }

    var body: some View {
        Group {
            if bars.isEmpty {
                AppEmptyStateCard(
                    icon: "chart.bar.fill",
                    title: "A fresh week",
                    message: "Complete a study session and your activity will grow here.",
                    compact: true
                )
                .padding(.horizontal, 8)
            } else {
                activityChart()
                    .padding(.trailing, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func activityChart() -> some View {
        let activity: [ActivityBar] = bars
        let heights: [Double] = activity.map { $0.minutes }
        let range: ClosedRange<Double> = 0.0...(tickStep * 4.0)
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.3)
        return Chart(activity) { bar in
            activityMark(bar)
        }
        .chartLegend(.hidden)
        .chartXScale(domain: days.indices.map { String($0) })
        .chartYScale(domain: range)
        .chartXAxis { dayAxis }
        .chartYAxis { durationAxis }
        .animation(animation, value: heights)
    }

    private func activityMark(_ bar: ActivityBar) -> some ChartContent {
        let centre: String = String(Int(bar.dayIndex))
        let height: Double = bar.minutes / divisor
        let day: String = bar.date.formatted(.dateTime.weekday(.wide))
        let minutes: String = bar.minutes.formatted(.number.precision(.fractionLength(0...1)))
        let label = Text(verbatim: bar.course + ", " + day)
        let value = Text(verbatim: minutes + " minutes")
        return BarMark(
            x: .value("Day", centre),
            y: .value("Study time", height),
            width: .ratio(0.65)
        )
        .foregroundStyle(bar.color)
        .cornerRadius(10)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var dayAxis: some AxisContent {
        AxisMarks(values: days.indices.map { String($0) }) { value in
            AxisValueLabel(anchor: .top, collisionResolution: .disabled) { dayLabel(value) }
        }
    }

    @ViewBuilder
    private func dayLabel(_ value: AxisValue) -> some View {
        if let key = value.as(String.self), let position = Int(key), days.indices.contains(position) {
            Text(days[position], format: .dateTime.weekday(.abbreviated))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .textCase(.uppercase)
                .padding(.top, 6)
        }
    }

    private var durationAxis: some AxisContent {
        let ticks: [Double] = (0...4).map { Double($0) * tickStep }
        return AxisMarks(position: .leading, values: ticks) { value in
            AxisValueLabel { durationLabel(value) }
        }
    }

    @ViewBuilder
    private func durationLabel(_ value: AxisValue) -> some View {
        if let amount = value.as(Double.self) {
            Text(amount.formatted(.number.precision(.fractionLength(0))))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk.opacity(0.65))
                .padding(.trailing, 6)
        }
    }

}

private struct DailyStudyMinutes: Identifiable {
    let date: Date
    let minutes: Double

    var id: Date { date }
}

private struct CourseWeeklySeries: Identifiable {
    let id: UUID
    let name: String
    let color: Color
    let dailyMinutes: [DailyStudyMinutes]

    static func series(from stats: WeeklyStudyStats) -> [CourseWeeklySeries] {
        stats.courses.map { course in
            CourseWeeklySeries(id: course.id, name: course.name, color: course.color.chartTint,
                dailyMinutes: stats.days.map { day in
                    DailyStudyMinutes(date: day, minutes: stats.minutes(for: course, on: day))
                })
        }
    }
}

#Preview {
    StatsView()
}
