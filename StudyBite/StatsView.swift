import Charts
import Foundation
import SwiftUI

struct StatsView: View {
    @State private var showSettings = false
    @State private var selectedPeriod = "weekly"
    private let periods = ["daily", "weekly", "monthly", "lifetime"]
    private let weeklyCourses = CourseWeeklySeries.sampleWeek()
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                profileButton
                    .padding(.leading, 9)
                    .padding(.bottom, 36)

                HStack(spacing: 7) {
                    Text("My")
                    Menu {
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(periods, id: \.self) { period in
                                Text(period.capitalized).tag(period)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(selectedPeriod)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stats period")
                    .accessibilityValue(selectedPeriod)
                    Text("stats")
                }
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.leading, 8)
                    .padding(.bottom, 28)

                weeklyMetrics
                    .padding(.bottom, 30)

                Text("My weekly summary")
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.leading, 8)
                    .padding(.bottom, 20)

                WeeklySummaryChart(courses: weeklyCourses)
                    .frame(height: 190)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemBackground))
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

    private var weeklyMetrics: some View {
        HStack(spacing: 8) {
            MetricView(value: "8", label: "sessions")

            Divider()
                .frame(height: 50)

            MetricView(value: "\(totalMinutes)", label: "min studied")

            Divider()
                .frame(height: 50)

            MetricView(value: "14", label: "subjects")
        }
    }

    private var totalMinutes: Int {
        weeklyCourses.reduce(0) { total, course in
            total + course.dailyMinutes.reduce(0) { $0 + $1.minutes }
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
        let dates = courses.flatMap(\.dailyMinutes).map(\.date)
        let firstDate = dates.min() ?? .now
        let lastDate = dates.max() ?? firstDate
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
                        series: .value("Course", course.name)
                    )
                    .foregroundStyle(course.color.opacity(0.42))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Day", day.date),
                        y: .value("Study time", day.minutes),
                        series: .value("Course", course.name)
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
    let minutes: Int

    var id: Date { date }
}

private struct CourseWeeklySeries: Identifiable {
    let name: String
    let color: Color
    let dailyMinutes: [DailyStudyMinutes]

    var id: String { name }

    static func sampleWeek(
        calendar: Calendar = .autoupdatingCurrent,
        referenceDate: Date = .now
    ) -> [CourseWeeklySeries] {
        guard let weekStart = calendar.dateInterval(
            of: .weekOfYear,
            for: referenceDate
        )?.start else {
            return []
        }

        let sampleCourses = [
            (
                name: "Maths",
                color: Color(red: 0.59, green: 0.75, blue: 0.79),
                minutes: [4, 15, 3, 22, 7, 18, 5]
            ),
            (
                name: "Science",
                color: Color(red: 0.49, green: 0.90, blue: 0.77),
                minutes: [12, 3, 14, 2, 10, 1, 6]
            )
        ]
        
        

        return sampleCourses.map { course in
            let dailyMinutes = course.minutes.enumerated().compactMap {
                dayOffset,
                minutes -> DailyStudyMinutes? in
                guard let date = calendar.date(
                    byAdding: .day,
                    value: dayOffset,
                    to: weekStart
                ) else {
                    return nil
                }

                return DailyStudyMinutes(date: date, minutes: minutes)
            }

            return CourseWeeklySeries(
                name: course.name,
                color: course.color,
                dailyMinutes: dailyMinutes
            )
        }
    }
}

#Preview {
    StatsView()
}
