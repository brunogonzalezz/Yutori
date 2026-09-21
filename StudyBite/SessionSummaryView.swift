import SwiftUI

struct SessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let course: StudyCourse
    let measuredDuration: TimeInterval
    let startingSeconds: TimeInterval
    let bowlKind: BowlKind
    let pauseCount: Int
    let endedAt: Date
    let onDiscard: () -> Void
    let onSave: (TimeInterval) -> Void
    @State private var sessionID = UUID()
    @State private var blockDescription = ""
    @State private var saveFailed = false
    @State private var saved = false
    @State private var showsCoursePicker = false
    @State private var selectedCourse: StudyCourse?
    @State private var courseStore = CourseStore.shared
    @State private var descriptionExample = "Reviewed my notes"
    @FocusState private var descriptionFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var currentCourse: StudyCourse { selectedCourse ?? course }
    private var animatesDescription: Bool {
        blockDescription.isEmpty && !descriptionFocused && !reduceMotion && scenePhase == .active
    }

    private func animateDescriptions() async {
        guard animatesDescription else { return }
        let examples = ["Reviewed my notes", "Practised exam questions", "Finished chapter 3", "Revised for tomorrow's test", "Studied a new topic"]
        do {
            while !Task.isCancelled {
                for example in examples {
                    descriptionExample = ""
                    for letter in example {
                        try Task.checkCancellation()
                        descriptionExample.append(letter)
                        try await Task.sleep(for: .milliseconds(65))
                    }
                    try await Task.sleep(for: .seconds(2))
                    while !descriptionExample.isEmpty {
                        try Task.checkCancellation()
                        descriptionExample.removeLast()
                        try await Task.sleep(for: .milliseconds(30))
                    }
                    try await Task.sleep(for: .milliseconds(250))
                }
            }
        } catch {
            descriptionExample = "Reviewed my notes"
        }
    }


    private var recordedDuration: TimeInterval? {
        guard measuredDuration.isFinite, measuredDuration >= 1, measuredDuration <= 3_599_999 else { return nil }
        return measuredDuration
    }

    private var recordedTimeText: String {
        let total = Int(recordedDuration ?? 0)
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    private var canSave: Bool {
        recordedDuration != nil && !saved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    sessionOverview
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                Section("Course") {
                    Button {
                        descriptionFocused = false
                        showsCoursePicker = true
                    } label: {
                        HStack(spacing: 12) {
                            CourseBadge(course: currentCourse)
                            Text(currentCourse.name).font(.headline)
                            Spacer()
                            Text("Change").font(.subheadline)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(AppTheme.ink)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(courseStore.loadFailed || courseStore.courses.isEmpty)
                    .accessibilityLabel("Change course")
                    .accessibilityValue(currentCourse.name)
                }
                .listRowBackground(AppTheme.surface)
                Section("What did you study?") {
                    TextField("Description (optional)", text: $blockDescription,
                              prompt: Text(descriptionExample), axis: .vertical)
                        .focused($descriptionFocused)
                        .accessibilityLabel("Description (optional)")
                        .task(id: animatesDescription) { await animateDescriptions() }
                        .lineLimit(3...6)
                        .onChange(of: blockDescription) { _, value in
                            let limited = StudySession.limitedDescription(value)
                            if limited != value { blockDescription = limited }
                        }
                }
                .listRowBackground(AppTheme.surface)
                Section {
                    HStack {
                        Label("Recorded time", systemImage: "timer")
                            .foregroundStyle(AppTheme.secondaryInk)
                        Spacer()
                        Text(recordedTimeText)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                } header: {
                    Text("Study time")
                }
                .listRowBackground(AppTheme.surface)
                Section {
                    DiscardSessionButton(onDiscard: onDiscard)
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.paper)
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Couldn't save session", isPresented: $saveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your session is still here. Please try again.")
            }
        }
        .tint(AppTheme.ink)
        .interactiveDismissDisabled()
        .sheet(isPresented: $showsCoursePicker) {
            coursePickerSheet
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
                .presentationCornerRadius(28)
        }
    }

    private var coursePickerSheet: some View {
        VStack(spacing: 16) {
            Text("Choose a course")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .padding(.top, 24)
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(courseStore.courses) { candidate in
                        Button {
                            selectedCourse = candidate
                            showsCoursePicker = false
                        } label: {
                            HStack(spacing: 12) {
                                CourseBadge(course: candidate)
                                Text(candidate.name)
                                    .font(.body.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(AppTheme.ink)
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(candidate.id == currentCourse.id ? AppTheme.ink : .clear, lineWidth: 2)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(candidate.id == currentCourse.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(AppTheme.paper)
    }

    private var sessionOverview: some View {
        let duration = recordedDuration ?? 0
        let initial = DishProgress(totalSeconds: startingSeconds)
        let final = DishProgress(totalSeconds: startingSeconds + duration)
        let capacity = DishProgress.secondsPerLevel * Double(DishProgress.maximumLevel)
        let gained = max(0, min(final.totalSeconds, capacity) - min(initial.totalSeconds, capacity))
        let percent = Int((gained / capacity * 100).rounded())
        let levels = final.level - initial.level
        return VStack(spacing: 22) {
            GeometryReader { geometry in
                let columnWidth = max(0, (geometry.size.width - 48) / 2)
                HStack(alignment: .top, spacing: 4) {
                    overviewBowl(level: initial.level, width: columnWidth)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 40, height: 128)
                    overviewBowl(level: final.level, width: columnWidth)
                }
            }
            .frame(height: 158)
            GeometryReader { geometry in
                let columnWidth = max(0, (geometry.size.width - 18) / 3)
                HStack(spacing: 4) {
                    overviewMetric("\(pauseCount)", label: pauseCount == 1 ? "Pause" : "Pauses")
                        .frame(width: columnWidth)
                    overviewSeparator
                    overviewMetric("+\(percent)%", label: "Bowl progress")
                        .frame(width: columnWidth)
                    overviewSeparator
                    overviewMetric("\(levels)", label: levels == 1 ? "Level gained" : "Levels gained")
                        .frame(width: columnWidth)
                }
                .frame(height: geometry.size.height)
            }
            .frame(height: 74)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 18)
            .background {
                ZStack {
                    AppTheme.ink
                    TimelineView(.animation(minimumInterval: 1.0 / 30,
                                            paused: reduceMotion || scenePhase != .active)) { timeline in
                        Canvas { context, size in
                            var symbol = context.resolve(Image(systemName: "chart.bar.fill").renderingMode(.template))
                            symbol.shading = .color(AppTheme.paper)
                            context.opacity = 0.035
                            let spacing: CGFloat = 48
                            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 48) / 48
                            let drift = CGFloat(phase) * spacing * 2
                            for row in -3...Int(size.height / spacing + 1) {
                                for column in -3...Int(size.width / spacing + 1) {
                                    let stagger: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                                    let rect = CGRect(x: CGFloat(column) * spacing + stagger + drift,
                                                      y: CGFloat(row) * spacing + drift,
                                                      width: 12, height: 12)
                                    context.draw(symbol, in: rect)
                                }
                            }
                        }
                    }
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .padding(.top, 0)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
    }

    private var overviewSeparator: some View {
        Rectangle().fill(AppTheme.paper.opacity(0.22))
            .frame(width: 1, height: 45)
            .accessibilityHidden(true)
    }

    private func overviewBowl(level: Int, width: CGFloat) -> some View {
        // Keep growth readable without letting the final bowls fill their entire column.
        let scales: [CGFloat] = [0.64, 0.68, 0.76, 0.84, 0.92, 1.0]
        let index = min(max(level, 0), scales.count - 1)
        let artworkWidth = min(122, width) * scales[index]
        return VStack(spacing: 6) {
            GeometryReader { geometry in
                DishArtworkView(level: index, availableWidth: width + 48,
                                preferredWidth: artworkWidth, kind: bowlKind)
                    .fixedSize()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(width: width, height: 128)
            Text("Level \(level)")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(width: width)
    }

    private func overviewMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.system(size: 34, weight: .bold)).monospacedDigit()
                .foregroundStyle(AppTheme.paper)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.paper.opacity(0.72))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        guard canSave, let duration = recordedDuration else { return }
        do {
            try StudySessionStore.shared.save(StudySession(
                id: sessionID, course: currentCourse, blockDescription: blockDescription,
                duration: duration, endedAt: StudyTestClock.shared.date(for: endedAt)
            ))
            saved = true
            onSave(duration)
        } catch {
            saveFailed = true
        }
    }
}

private struct DiscardSessionButton: View {
    let onDiscard: () -> Void
    @State private var confirmDiscard = false

    var body: some View {
        Button(role: .destructive) {
            confirmDiscard = true
        } label: {
            Label("Delete session", systemImage: "trash")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert("Delete this session?", isPresented: $confirmDiscard) {
            Button("Delete session", role: .destructive, action: onDiscard)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This study time won't be saved or added to your dish.")
        }
    }
}
