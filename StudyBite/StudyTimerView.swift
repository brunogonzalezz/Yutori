import Foundation
import SwiftUI

struct StudyTimerView: View {
    let course: StudyCourse
    var onEvolution: ((Int, Int, TimeInterval) -> Void)? = nil
    let onFinish: (TimeInterval) -> Void

    @State private var activeSession = ActiveStudySession.shared
    private var stopwatch: StudyStopwatch { activeSession.stopwatch }
    @State private var startingSeconds: TimeInterval
    @State private var highestRevealedLevel: Int
    @State private var dishFrame: CGRect = .zero
    @State private var liveEvolutionActive = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasStarted = false
    @State private var showSummary = false
    @State private var endedAt = Date.now
    @State private var sessionStore = StudySessionStore.shared
    @State private var levelBeforeSave = 0
    @State private var savedDuration: TimeInterval?
    @State private var discardedSession = false
    @State private var showEvolution = false

    init(course: StudyCourse,
         onEvolution: ((Int, Int, TimeInterval) -> Void)? = nil,
         onFinish: @escaping (TimeInterval) -> Void) {
        self.course = course
        self.onEvolution = onEvolution
        self.onFinish = onFinish
        let store = StudySessionStore.shared
        _startingSeconds = State(initialValue: ActiveStudySession.shared.id == nil ? store.earnedDishProgress.totalSeconds : ActiveStudySession.shared.startingSeconds)
        _highestRevealedLevel = State(initialValue: ActiveStudySession.shared.id == nil ? store.earnedDishProgress.level : ActiveStudySession.shared.revealedLevel)
    }

    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let progress = DishProgress(totalSeconds: startingSeconds + stopwatch.elapsed(at: context.date))
                VStack(spacing: 18) {
                    DishArtworkView(level: highestRevealedLevel, availableWidth: geometry.size.width)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { dishFrame = $0 }
                        .frame(maxWidth: .infinity)
                        .opacity(liveEvolutionActive ? 0 : 1)

                    DishProgressBar(progress: progress)
                        .frame(width: max(0, geometry.size.width - 120))
                        .padding(.top, progress.level == 5 ? -6 : 0)

                Text(stopwatch.formattedElapsed(at: context.date))
                    .font(.system(size: 68, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Elapsed study time")
                    .accessibilityValue(stopwatch.formattedElapsed(at: context.date))
                }
            }

            HStack(spacing: 24) {
                Button {
                    toggleTimer()
                } label: {
                    Image(systemName: stopwatch.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(AppTheme.paper)
                        .frame(width: 60, height: 60)
                        .background(AppTheme.ink, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(stopwatch.isRunning ? "Pause" : "Resume")

                Button {
                    finishSession(at: .now)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(AppTheme.paper)
                        .frame(width: 60, height: 60)
                        .background(CourseColor.red.tint, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Finish study session")
            }

            HStack(spacing: 12) {
                Text("Test").foregroundStyle(AppTheme.secondaryInk)
                Button("+10 min") { activeSession.advanceForTesting(by: 600) }
                Button("+25 min") { activeSession.advanceForTesting(by: 1500) }
                Button("+1 h") { activeSession.advanceForTesting(by: 3600) }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.surface, in: Capsule())

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 40)
        .frame(width: geometry.size.width, alignment: .center)
        .frame(height: geometry.size.height)
        .opacity(liveEvolutionActive ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: liveEvolutionActive)
        .allowsHitTesting(!liveEvolutionActive)
        .accessibilityHidden(liveEvolutionActive)
        }
        .background {
            ZStack {
                AppTheme.paper
                CourseMosaicBackground(icon: course.icon,
                                       sessionID: activeSession.id,
                                       isAnimating: scenePhase == .active && !showSummary && !liveEvolutionActive)
                    .opacity(liveEvolutionActive ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: liveEvolutionActive)
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                LiveDishEvolutionView(
                    initialLevel: DishProgress(totalSeconds: startingSeconds).level,
                    targetLevel: DishProgress(totalSeconds: startingSeconds + stopwatch.elapsed(at: context.date)).level,
                    kind: sessionStore.activeBowlKind,
                    sourceFrame: dishFrame,
                    isActive: scenePhase == .active && !showSummary && !showEvolution,
                    onActivity: { liveEvolutionActive = $0 }
                ) { level in
                    highestRevealedLevel = max(highestRevealedLevel, level)
                    activeSession.reveal(level)
                }
            }
            .allowsHitTesting(false)
        }
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
            SessionSummaryView(course: course, measuredDuration: stopwatch.accumulated, startingSeconds: startingSeconds, bowlKind: sessionStore.activeBowlKind, pauseCount: activeSession.pauseCount, endedAt: endedAt, onDiscard: {
                discardedSession = true
                showSummary = false
            }) { duration in
                savedDuration = duration
                showSummary = false
            }
        }
        .onAppear {
            startTimerIfNeeded()
            if let date = activeSession.finishedAt { finishSession(at: date) }
        }
        .onChange(of: activeSession.finishedAt) { _, date in
            if let date { finishSession(at: date) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if let date = activeSession.finishedAt { finishSession(at: date) }
                Task { await activeSession.syncActivity() }
            }
        }
    }

    private func completeSavedSession() {
        if discardedSession {
            activeSession.clear()
            onFinish(0)
            return
        }
        guard let savedDuration else { return }
        activeSession.clear()
        if sessionStore.dishProgress.level > levelBeforeSave {
            if let onEvolution {
                onEvolution(levelBeforeSave, sessionStore.dishProgress.level, savedDuration)
            } else {
                showEvolution = true
            }
        } else {
            onFinish(savedDuration)
        }
    }

    private func finishSession(at date: Date) {
        guard !showSummary else { return }
        endedAt = date
        activeSession.finish(at: date)
        // Only celebrate levels not already revealed during this session.
        levelBeforeSave = max(DishProgress(totalSeconds: startingSeconds).level, highestRevealedLevel)
        guard stopwatch.accumulated >= 1 else {
            activeSession.clear()
            onFinish(0)
            return
        }
        showSummary = true
    }

    private func toggleTimer() {
        activeSession.toggle()
    }

    private func startTimerIfNeeded() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        activeSession.start(course: course)
    }
}

private struct CourseMosaicBackground: View {
    let icon: String
    let sessionID: UUID?
    let isAnimating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion || !isAnimating)) { timeline in
            Canvas { context, size in
                let cell: CGFloat = 64
                // Repeat over two rows so the staggered pattern loops seamlessly.
                let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 44) / 44
                let drift = CGFloat(phase) * cell * 2
                // UUID bytes keep the random direction stable when a session is restored.
                let seed = sessionID?.uuid.0 ?? 0
                let directionX: CGFloat = seed & 1 == 0 ? 1 : -1
                let directionY: CGFloat = seed & 2 == 0 ? 1 : -1
                var symbol = context.resolve(Image(systemName: icon).renderingMode(.template))
                symbol.shading = .color(AppTheme.ink)
                context.opacity = 0.05
                for row in -3...Int(size.height / cell + 3) {
                    for column in -3...Int(size.width / cell + 3) {
                        let stagger: CGFloat = row.isMultiple(of: 2) ? 0 : cell / 2
                        let x = CGFloat(column) * cell + stagger + drift * directionX
                        let y = CGFloat(row) * cell + drift * directionY
                        context.draw(symbol, in: CGRect(x: x, y: y, width: 20, height: 20))
                    }
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DishEvolutionView: View {
    let fromLevel: Int
    let toLevel: Int
    var dishNamespace: Namespace.ID? = nil
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var charging = false
    @State private var glow = false
    @State private var revealed = false
    @State private var ready = false
    @State private var displayedLevel: Int?
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
        let currentLevel = displayedLevel ?? fromLevel
        let evolutionCount = max(1, toLevel - fromLevel)
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Spacer(minLength: 24)
                VStack(spacing: 10) {
                    Text(revealed ? (currentLevel < toLevel ? "And there's more…" : message.after) : message.before)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(revealed ? "Level \(currentLevel) unlocked" : message.detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
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
                            .accessibilityHidden(true)
                    }
                    DishArtworkView(level: currentLevel, availableWidth: geometry.size.width)
                        .modifier(DishTravelModifier(namespace: dishNamespace, isSource: true))
                        .brightness(glow ? 0.8 : 0)
                        .scaleEffect(reduceMotion ? 1 : glow ? 0.9 : 1)
                        .shadow(color: .orange.opacity(glow ? 0.6 : 0), radius: 20)
                }
                .frame(height: 320)
                    Text(evolutionCount > 1 ? "\(evolutionCount) levels earned, one study bite at a time." : message.footer)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .opacity(ready ? 1 : 0)
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 260, minHeight: 52)
                        .background(AppTheme.ink, in: Capsule())
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
        .background(AppTheme.paper.ignoresSafeArea())
        .task {
            if messageIndex == nil {
                let next = Self.messages.indices.filter { $0 != lastMessage }.randomElement() ?? 0
                messageIndex = next
                lastMessage = next
            }
            do {
                EvolutionSound.shared.prepare()
                withAnimation(.easeInOut(duration: 0.8)) { charging = true }
                try await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 900))
                if toLevel > fromLevel {
                    for level in (fromLevel + 1)...toLevel {
                        withAnimation(.easeInOut(duration: 0.6)) { glow = !reduceMotion }
                        try await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 650))
                        displayedLevel = level
                        revealed = true
                        EvolutionSound.shared.play()
                        withAnimation(.easeOut(duration: 0.7)) { glow = false }
                        // Let each intermediate dish be seen before the next burst.
                        try await Task.sleep(for: .milliseconds(level < toLevel ? 1100 : 700))
                    }
                }
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
