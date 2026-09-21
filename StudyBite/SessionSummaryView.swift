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
    var savedSession: StudySession? = nil
    @State private var sessionID = UUID()
    @State private var adjustmentMinutes = 0
    @State private var confirmsLargeAdjustment = false
    @State private var confirmsLargeSave = false
    @State private var approvedDuration: TimeInterval?
    @State private var showsTimeEditor = false
    @State private var confirmDelete = false
    @State private var deleteFailed = false
    @State private var timeTick: Int? = 0
    @State private var initializedDraft = false
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


    private var needsTimeConfirmation: Bool {
        guard let session = savedSession, let duration = recordedDuration,
              adjustmentMinutes != 0, approvedDuration != duration else { return false }
        return abs(duration - (session.originalDuration ?? measuredDuration)) >= 3 * 3600
    }

    private var recordedDuration: TimeInterval? {
        let duration = savedSession == nil ? measuredDuration : max(1, measuredDuration + Double(adjustmentMinutes) * 60)
        guard duration.isFinite, duration >= 1, duration <= 3_599_999 else { return nil }
        return duration
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
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
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
                    if savedSession != nil {
                        Button("Edit", systemImage: "slider.horizontal.3") {
                            descriptionFocused = false
                            timeTick = adjustmentMinutes
                            showsTimeEditor = true
                        }
                    }
                } header: {
                    Text("Study time")
                }
                .listRowBackground(AppTheme.surface)
                if savedSession != nil {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Delete session", systemImage: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(AppTheme.surface)
                } else {
                    Section {
                        DiscardSessionButton(onDiscard: onDiscard)
                    }
                    .listRowBackground(AppTheme.surface)
                }
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
                    Button("Save") {
                        if needsTimeConfirmation { confirmsLargeSave = true }
                        else { save() }
                    }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                guard !initializedDraft else { return }
                initializedDraft = true
                if let savedSession { blockDescription = savedSession.blockDescription }
            }
            .alert("Couldn't save session", isPresented: $saveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your session is still here. Please try again.")
            }
        }
        .tint(AppTheme.ink)
        .interactiveDismissDisabled(savedSession == nil)
        .alert("Confirm time adjustment", isPresented: $confirmsLargeSave) {
            Button("Confirm and save") {
                approvedDuration = recordedDuration
                save()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You’re making a large change to your study time. Are you sure? This edited time will not evolve your bowl.")
        }
        .alert("Delete this session?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                guard let savedSession else { return }
                do {
                    try StudySessionStore.shared.deleteSession(id: savedSession.id)
                    dismiss()
                } catch { deleteFailed = true }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This session and its study time will be removed from your history.")
        }
        .alert("Couldn't delete session", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showsTimeEditor) {
            Group {
            timeEditor
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)

            }.modifier(FloatingSheet())
        }
        .sheet(isPresented: $showsCoursePicker) {
            Group {
            coursePickerSheet
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)

            }.modifier(FloatingSheet())
        }
    }

    private var timeEditor: some View {
        let original = savedSession?.originalDuration ?? measuredDuration
        let minimum = Int(ceil((max(1, original - 10 * 3600) - measuredDuration) / 60))
        let maximum = Int(floor((min(3_599_999, original + 10 * 3600) - measuredDuration) / 60))
        return VStack(spacing: 16) {
            Text("Adjust recorded time").font(.headline)
            Text(recordedTimeText).font(.system(size: 32, weight: .bold)).monospacedDigit()
            HStack(spacing: 8) {
                ForEach([-15, -5, 5, 15], id: \.self) { change in
                    Button(change > 0 ? "+\(change) min" : "\(change) min") {
                        let next = min(maximum, max(minimum, adjustmentMinutes + change))
                        adjustmentMinutes = next
                        timeTick = next
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AppTheme.surface, in: Capsule())
                    .disabled(change < 0 ? adjustmentMinutes <= minimum : adjustmentMinutes >= maximum)
                }
            }
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 0) {
                        ForEach(minimum...maximum, id: \.self) { tick in
                            let distance = abs(tick - adjustmentMinutes)
                            Capsule()
                                .fill(AppTheme.ink.opacity(distance == 0 ? 1 : (distance <= 2 ? 0.5 : 0.22)))
                                .frame(width: distance == 0 ? 5 : (distance <= 2 ? 4 : 2.5),
                                       height: distance == 0 ? 44 : (distance <= 2 ? 36 : 26))
                                .frame(width: 12, height: 56)
                            .id(tick)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, max(0, (geometry.size.width - 12) / 2), for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
                .scrollPosition(id: $timeTick, anchor: .center)
                .onChange(of: timeTick) { _, value in
                    if let value { adjustmentMinutes = min(maximum, max(minimum, value)) }
                }
                .sensoryFeedback(.selection, trigger: adjustmentMinutes) { old, new in
                    old != new
                }
            }
            .frame(height: 56)
            Button("Done") {
                if needsTimeConfirmation { confirmsLargeAdjustment = true }
                else { showsTimeEditor = false }
            }
                .font(.headline).foregroundStyle(AppTheme.paper)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppTheme.ink, in: Capsule())
                .padding(.horizontal, 32)
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .alert("Confirm time adjustment", isPresented: $confirmsLargeAdjustment) {
            Button("Confirm") {
                approvedDuration = recordedDuration
                showsTimeEditor = false
            }
            Button("Keep editing", role: .cancel) { }
        } message: {
            Text("You’re making a large change to your study time. Are you sure? This edited time will not evolve your bowl.")
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
        let duration = savedSession?.dishDuration ?? measuredDuration
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
                        .frame(width: 40, height: 140)
                    overviewBowl(level: final.level, width: columnWidth)
                }
            }
            .frame(height: 170)
            GeometryReader { geometry in
                let columnWidth = max(0, (geometry.size.width - 18) / 3)
                HStack(spacing: 4) {
                    overviewMetric(savedSession != nil && savedSession?.pauseCount == nil ? "—" : "\(pauseCount)", label: pauseCount == 1 ? "Pause" : "Pauses")
                        .frame(width: columnWidth)
                    overviewSeparator
                    overviewMetric(savedSession != nil && savedSession?.startingDishSeconds == nil ? "—" : "\(percent)%", label: "Bowl progress")
                        .frame(width: columnWidth)
                    overviewSeparator
                    overviewMetric(savedSession != nil && savedSession?.startingDishSeconds == nil ? "—" : "\(levels)", label: levels == 1 ? "Level gained" : "Levels gained")
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
        let scales: [CGFloat] = [0.74, 0.77, 0.84, 0.90, 0.95, 1.0]
        let index = min(max(level, 0), scales.count - 1)
        let artworkWidth = min(140, width * 0.96) * scales[index]
        return VStack(spacing: 6) {
            GeometryReader { geometry in
                if savedSession != nil && savedSession?.startingDishSeconds == nil {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 44)).foregroundStyle(AppTheme.secondaryInk)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                } else {
                DishArtworkView(level: index, availableWidth: width + 48,
                                preferredWidth: artworkWidth, kind: bowlKind)
                    .fixedSize()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .frame(width: width, height: 140)
            Text(savedSession != nil && savedSession?.startingDishSeconds == nil ? "Not recorded" : "Level \(level)")
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
            let draft = StudySession(
                id: savedSession?.id ?? sessionID, course: currentCourse, blockDescription: blockDescription,
                duration: duration, endedAt: savedSession?.endedAt ?? StudyTestClock.shared.date(for: endedAt),
                startingDishSeconds: savedSession == nil ? startingSeconds : savedSession?.startingDishSeconds,
                bowlKind: savedSession == nil ? bowlKind : savedSession?.bowlKind,
                pauseCount: savedSession == nil ? pauseCount : savedSession?.pauseCount,
                originalDuration: savedSession?.originalDuration ?? measuredDuration
            )
            try StudySessionStore.shared.save(draft)
            saved = true
            onSave(duration)
            if savedSession != nil { dismiss() }
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
