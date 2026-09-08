import Charts
import SwiftUI

struct StatsView: View {
    @State private var showSettings = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                profileButton
                    .padding(.bottom, 22)

                Text("My weekly stats")
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.leading, 8)
                    .padding(.bottom, 28)

                weeklyMetrics
                    .padding(.bottom, 30)

                Text("My weekly summary")
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.leading, 8)
                    .padding(.bottom, 12)

                WeeklySummaryChart()
                    .frame(height: 190)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
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
            Image("perfilePic")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
    }

    private var weeklyMetrics: some View {
        HStack(spacing: 8) {
            MetricView(value: "8", label: "sessions")

            Divider()
                .frame(height: 50)

            MetricView(value: "122", label: "min studied")

            Divider()
                .frame(height: 50)

            MetricView(value: "14", label: "subjects")
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
    private let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    private let bluePoints = [
        ChartPoint(day: 0, minutes: 0),
        ChartPoint(day: 1, minutes: 0),
        ChartPoint(day: 2, minutes: 0),
        ChartPoint(day: 3, minutes: 22),
        ChartPoint(day: 4, minutes: 8),
        ChartPoint(day: 5, minutes: 14),
        ChartPoint(day: 6, minutes: 28)
    ]

    private let greenPoints = [
        ChartPoint(day: 0, minutes: 8),
        ChartPoint(day: 1, minutes: 10),
        ChartPoint(day: 2, minutes: 5),
        ChartPoint(day: 3, minutes: 0),
        ChartPoint(day: 4, minutes: 0),
        ChartPoint(day: 5, minutes: 12),
        ChartPoint(day: 6, minutes: 15)
    ]

    var body: some View {
        Chart {
            ForEach(bluePoints) { point in
                AreaMark(
                    x: .value("Day", point.day),
                    yStart: .value("Baseline", 0),
                    yEnd: .value("Blue study time", point.minutes)
                )
                .foregroundStyle(by: .value("Course", "Blue"))
                .opacity(0.48)
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Blue study time", point.minutes)
                )
                .foregroundStyle(by: .value("Course", "Blue"))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            ForEach(greenPoints) { point in
                AreaMark(
                    x: .value("Day", point.day),
                    yStart: .value("Baseline", 0),
                    yEnd: .value("Green study time", point.minutes)
                )
                .foregroundStyle(by: .value("Course", "Green"))
                .opacity(0.50)
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Green study time", point.minutes)
                )
                .foregroundStyle(by: .value("Course", "Green"))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
        }
        .chartForegroundStyleScale([
            "Blue": Color(red: 0.59, green: 0.75, blue: 0.79),
            "Green": Color(red: 0.49, green: 0.90, blue: 0.77)
        ])
        .chartLegend(.hidden)
        .chartXScale(domain: 0...6)
        .chartYScale(domain: 0...30)
        .chartXAxis {
            AxisMarks(values: Array(0...6)) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), days.indices.contains(index) {
                        Text(days[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 10, 20, 30]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.secondary.opacity(0.20))

                AxisValueLabel {
                    if let minutes = value.as(Int.self) {
                        Text("\(minutes)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
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

private struct ChartPoint: Identifiable {
    var id: Int { day }

    let day: Int
    let minutes: Int
}

#Preview {
    StatsView()
}
