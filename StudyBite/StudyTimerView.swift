import Foundation
import SwiftUI

struct StudyTimerView: View {
    let course: StudyCourse
    let onFinish: (TimeInterval) -> Void

    @State private var accumulatedTime: TimeInterval = 0
    @State private var runningSince: Date?
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var showSummary = false
    @State private var endedAt = Date.now
    @State private var sessionStore = StudySessionStore.shared

    var body: some View {
        GeometryReader { geometry in
        ScrollView(showsIndicators: false) {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let progress = DishProgress(totalSeconds: sessionStore.dishProgress.totalSeconds + elapsedTime(at: context.date))
                VStack(spacing: 18) {
                    Image(progress.imageName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: min(geometry.size.width - 120, 250), height: min(geometry.size.width - 120, 250))
                        .accessibilityLabel("Dish level \(progress.level) of 5")

                    DishProgressBar(progress: progress)
                        .frame(width: max(0, geometry.size.width - 120))

                Text(formattedTime(at: context.date))
                    .font(.system(size: 68, weight: .bold))
                    .foregroundStyle(.black)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Elapsed study time")
                    .accessibilityValue(formattedTime(at: context.date))
                }
            }

            HStack(spacing: 24) {
                Button {
                    toggleTimer()
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(Color(white: 0.85))
                        .frame(width: 60, height: 60)
                        .background(Color(white: 0.29), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRunning ? "Pause" : "Resume")

                Button {
                    endedAt = .now
                    accumulatedTime = elapsedTime(at: endedAt)
                    isRunning = false
                    runningSince = nil
                    showSummary = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.59))
                        .frame(width: 60, height: 60)
                        .background(Color(red: 0.85, green: 0.06, blue: 0.17), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Finish study session")
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 40)
        .frame(width: geometry.size.width, alignment: .center)
        .frame(minHeight: geometry.size.height)
        }
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSummary) {
            SessionSummaryView(course: course, measuredDuration: accumulatedTime, endedAt: endedAt) { duration in
                showSummary = false
                onFinish(duration)
            }
        }
        .onAppear {
            startTimerIfNeeded()
        }
    }

    private func elapsedTime(at date: Date) -> TimeInterval {
        guard isRunning, let runningSince else {
            return accumulatedTime
        }

        return accumulatedTime + max(0, date.timeIntervalSince(runningSince))
    }

    private func formattedTime(at date: Date) -> String {
        let totalSeconds = Int(elapsedTime(at: date))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    private func toggleTimer() {
        let now = Date.now

        if isRunning {
            accumulatedTime = elapsedTime(at: now)
            isRunning = false
            runningSince = nil
        } else {
            runningSince = now
            isRunning = true
        }
    }

    private func startTimerIfNeeded() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        runningSince = .now
        isRunning = true
    }
}

#Preview {
    NavigationStack {
        StudyTimerView(course: StudyCourse(name: "Maths", icon: "percent")) { _ in }
    }
}
