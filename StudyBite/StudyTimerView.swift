import Foundation
import SwiftUI

struct StudyTimerView: View {
    let onFinish: (TimeInterval) -> Void

    @State private var accumulatedTime: TimeInterval = 0
    @State private var runningSince: Date?
    @State private var isRunning = false
    @State private var hasStarted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "timer")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Study time")
                    .font(.title2.bold())

                Text(isRunning ? "Session in progress" : "Session paused")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(formattedTime(at: context.date))
                    .font(.system(size: 58, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("Elapsed study time")
                    .accessibilityValue(formattedTime(at: context.date))
            }

            HStack(spacing: 14) {
                Button {
                    toggleTimer()
                } label: {
                    Label(
                        isRunning ? "Pause" : "Resume",
                        systemImage: isRunning ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glass)

                Button {
                    onFinish(elapsedTime(at: .now))
                } label: {
                    Label("Finish", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(.black)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
        .navigationTitle("Study session")
        .navigationBarTitleDisplayMode(.inline)
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

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
        StudyTimerView { _ in }
    }
}
