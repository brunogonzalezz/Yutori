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
    @State private var levelBeforeSave = 0
    @State private var savedDuration: TimeInterval?
    @State private var discardedSession = false
    @State private var showEvolution = false

    var body: some View {
        GeometryReader { geometry in
        ScrollView(showsIndicators: false) {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let progress = DishProgress(totalSeconds: sessionStore.dishProgress.totalSeconds + elapsedTime(at: context.date))
                VStack(spacing: 18) {
                    DishArtworkView(level: progress.level, availableWidth: geometry.size.width)

                    DishProgressBar(progress: progress)
                        .frame(width: max(0, geometry.size.width - 120))
                        .padding(.top, progress.level == 5 ? -6 : 0)

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
                    levelBeforeSave = sessionStore.dishProgress.level
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
        .overlay {
            if showEvolution {
                DishEvolutionView(fromLevel: levelBeforeSave, toLevel: sessionStore.dishProgress.level) {
                    guard let savedDuration else { return }
                    showEvolution = false
                    onFinish(savedDuration)
                }
            }
        }
        .sheet(isPresented: $showSummary, onDismiss: completeSavedSession) {
            SessionSummaryView(course: course, measuredDuration: accumulatedTime, endedAt: endedAt, onDiscard: {
                discardedSession = true
                showSummary = false
            }) { duration in
                savedDuration = duration
                showSummary = false
            }
        }
        .onAppear {
            startTimerIfNeeded()
        }
    }

    private func completeSavedSession() {
        if discardedSession {
            onFinish(0)
            return
        }
        guard let savedDuration else { return }
        if sessionStore.dishProgress.level > levelBeforeSave {
            showEvolution = true
        } else {
            onFinish(savedDuration)
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

private struct DishEvolutionView: View {
    let fromLevel: Int
    let toLevel: Int
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var charging = false
    @State private var glow = false
    @State private var revealed = false
    @State private var ready = false
    @AppStorage("lastEvolutionMessage") private var lastMessage = -1
    @State private var messageIndex: Int?

    private static let messages: [(before: String, after: String, detail: String, footer: String)] = [
        ("Something is cooking…", "A new level of delicious.", "Your study time is paying off", "Every study bite helps you grow."),
        ("A little focus. A big change.", "Look what you cooked up!", "Your next level is almost ready", "Small sessions. Real progress."),
        ("Your effort is showing…", "Made with focus.", "Good things take study time", "You earned every bit of this."),
        ("Something good is on its way…", "Fresh progress, served.", "A new chapter for your dish", "Keep your curiosity growing."),
        ("Time to add a little magic…", "Another bite, another level.", "All those minutes add up", "One step closer to something great."),
        ("Ready for a little surprise?", "Now that's progress!", "Your dish has something to show you", "A little more learned. A little more earned.")
    ]

    var body: some View {
        let message = Self.messages[messageIndex ?? 0]
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Spacer(minLength: 24)
                VStack(spacing: 8) {
                    Text(revealed ? message.after : message.before)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(revealed ? "Level \(toLevel) unlocked" : message.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(glow ? 0.3 : 0.08))
                        .frame(width: 240, height: 240)
                        .blur(radius: 24)
                        .scaleEffect(charging && !reduceMotion ? 1.2 : 0.85)
                    ForEach(0..<12) { index in
                        let angle = Double(index) * .pi / 6
                        Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                            .font(.system(size: index.isMultiple(of: 2) ? 18 : 5))
                            .foregroundStyle(Color.orange.opacity(0.8))
                            .offset(x: cos(angle) * (revealed ? 150 : 110),
                                    y: sin(angle) * (revealed ? 150 : 110))
                            .opacity(charging ? (ready ? 0.35 : 1) : 0)
                    }
                    DishArtworkView(level: revealed ? toLevel : fromLevel, availableWidth: geometry.size.width)
                        .brightness(glow ? 0.8 : 0)
                        .scaleEffect(reduceMotion ? 1 : glow ? 0.9 : 1)
                        .shadow(color: .orange.opacity(glow ? 0.6 : 0), radius: 20)
                }
                .frame(height: 320)
                Text(message.footer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(ready ? 1 : 0)
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 260, minHeight: 52)
                        .background(.black, in: Capsule())
                        .contentShape(Capsule())
                }
                    .buttonStyle(.plain)
                    .opacity(ready ? 1 : 0)
                    .disabled(!ready)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.white.ignoresSafeArea())
        .task {
            if messageIndex == nil {
                let next = Self.messages.indices.filter { $0 != lastMessage }.randomElement() ?? 0
                messageIndex = next
                lastMessage = next
            }
            do {
                withAnimation(.easeInOut(duration: 0.8)) { charging = true }
                try await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 900))
                withAnimation(.easeInOut(duration: 0.6)) { glow = !reduceMotion }
                try await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 650))
                revealed = true
                withAnimation(.easeOut(duration: 0.7)) { glow = false }
                try await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeInOut(duration: 0.3)) { ready = true }
            } catch { }
        }
    }
}

#Preview {
    NavigationStack {
        StudyTimerView(course: StudyCourse(name: "Maths", icon: "percent")) { _ in }
    }
}
