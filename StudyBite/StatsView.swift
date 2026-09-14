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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                profileButton
                    .padding(.leading, 9)
                    .padding(.bottom, 24)

                Text("My weekly stats")
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.leading, 8)
                    .padding(.bottom, 28)

                weeklyMetrics(stats)
                    .padding(.bottom, 30)

                if sessionStore.loadFailed {
                    Text("Couldn't load your sessions. Please reopen the app and try again.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }

                Text("My weekly summary")
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.leading, 8)
                    .padding(.bottom, 20)

                WeeklySummaryChart(courses: CourseWeeklySeries.series(from: stats), days: stats.days)
                    .frame(height: 190)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
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
        HStack(spacing: 8) {
            MetricView(value: sessionStore.loadFailed ? "—" : "\(stats.sessions.count)", label: "sessions")

            Divider()
                .frame(height: 50)

            MetricView(value: sessionStore.loadFailed ? "—" : "\(stats.totalMinutes)", label: "min studied")

            Divider()
                .frame(height: 50)

            MetricView(value: sessionStore.loadFailed ? "—" : "\(stats.courses.count)", label: "subjects")
        }
    }

}

private struct MetricView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 40, weight: .bold))
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WeeklySummaryChart: View {
    let courses: [CourseWeeklySeries]
    let days: [Date]

    private var yAxisMaximum: Int {
        let highestValue = courses
            .flatMap(\.dailyMinutes)
            .map(\.minutes)
            .max() ?? 0

        return Swift.max(30, Int(ceil(Double(highestValue) / 30)) * 30)
    }

    private var yAxisValues: [Int] {
        let step = yAxisMaximum / 3
        return Array(stride(from: 0, through: yAxisMaximum, by: step))
    }

    private var weekDomain: ClosedRange<Date> {
        let firstDate = days.first ?? .now
        let lastDate = days.last ?? firstDate
        return firstDate...lastDate
    }

    var body: some View {
        Chart {
            ForEach(courses) { course in
                ForEach(course.dailyMinutes) { day in
                    AreaMark(
                        x: .value("Day", day.date),
                        yStart: .value("Baseline", 0),
                        yEnd: .value("Study time", day.minutes),
                        series: .value("Course", course.id.uuidString)
                    )
                    .foregroundStyle(course.fillColor)
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Day", day.date),
                        y: .value("Study time", day.minutes),
                        series: .value("Course", course.id.uuidString)
                    )
                    .foregroundStyle(course.color)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 2.5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: weekDomain)
        .chartYScale(domain: 0...yAxisMaximum)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.secondary.opacity(0.20))
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .clipped()
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.24))
                        .frame(width: 2)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.24))
                        .frame(height: 2)
                }
        }
        .accessibilityHidden(true)
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

    // Preblend the pastel against the background, then draw it fully opaque.
    // An overlapping area replaces the one below instead of mixing their colors.
    var fillColor: Color {
        Color(uiColor: UIColor { traits in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            var backgroundRed: CGFloat = 0, backgroundGreen: CGFloat = 0, backgroundBlue: CGFloat = 0
            UIColor.systemBackground.resolvedColor(with: traits)
                .getRed(&backgroundRed, green: &backgroundGreen, blue: &backgroundBlue, alpha: &alpha)
            let amount: CGFloat = 0.42
            return UIColor(red: red * amount + backgroundRed * (1 - amount),
                           green: green * amount + backgroundGreen * (1 - amount),
                           blue: blue * amount + backgroundBlue * (1 - amount), alpha: 1)
        })
    }

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
