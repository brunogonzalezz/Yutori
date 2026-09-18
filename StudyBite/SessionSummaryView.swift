import SwiftUI

struct SessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let course: StudyCourse
    let measuredDuration: TimeInterval
    let endedAt: Date
    let onDiscard: () -> Void
    let onSave: (TimeInterval) -> Void
    @State private var sessionID = UUID()
    @State private var blockDescription = ""
    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var initialized = false
    @State private var saveFailed = false
    @State private var saved = false
    @State private var isEditingTime = false

    private var correctedDuration: TimeInterval? {
        let total = hours * 3600 + minutes * 60 + seconds
        return total > 0 ? TimeInterval(total) : nil
    }

    private var canSave: Bool {
        correctedDuration != nil && !blockDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !saved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CourseBadge(course: course)
                        Text(course.name).font(.headline)
                    }
                }
                .listRowBackground(AppTheme.surface)
                Section("What did you study?") {
                    TextField("Describe this study block", text: $blockDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: blockDescription) { _, value in
                            let limited = StudySession.limitedDescription(value)
                            if limited != value { blockDescription = limited }
                        }
                }
                .listRowBackground(AppTheme.surface)
                Section {
                    HStack {
                        Label(isEditingTime ? "Study time" : "Recorded time", systemImage: "timer")
                            .foregroundStyle(AppTheme.secondaryInk)
                        Spacer()
                        Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    if isEditingTime {
                    HStack(spacing: 0) {
                        timeWheel("Hours", selection: $hours, range: 0...999)
                        Text(":")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .padding(.top, 16)
                        timeWheel("Minutes", selection: $minutes, range: 0...59)
                        Text(":")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .padding(.top, 16)
                        timeWheel("Seconds", selection: $seconds, range: 0...59)
                    }
                    Button("Use recorded time") {
                        resetTime()
                        isEditingTime = false
                    }
                    if correctedDuration == nil {
                        Text("Choose at least one second.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    } else {
                        Button("Edit study time", systemImage: "pencil") {
                            isEditingTime = true
                        }
                        .font(.subheadline)
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
            .navigationTitle("Session summary")
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
            .onAppear {
                if !initialized {
                    resetTime()
                    initialized = true
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
    }

    private func timeWheel(_ title: String, selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.caption).foregroundStyle(AppTheme.secondaryInk)
            GeometryReader { geometry in
                Picker(title, selection: selection) {
                    ForEach(range, id: \.self) { value in
                        Text(String(format: "%02d", value))
                            .font(.system(size: 30, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(width: geometry.size.width, height: 216)
                .clipped()
            }
            .frame(height: 216)
        }
        .frame(maxWidth: .infinity)
    }

    private func resetTime() {
        let total = min(3_599_999, max(1, Int(measuredDuration)))
        hours = total / 3600
        minutes = (total % 3600) / 60
        seconds = total % 60
    }

    private func save() {
        guard canSave, let duration = correctedDuration else { return }
        do {
            try StudySessionStore.shared.save(StudySession(
                id: sessionID, course: course, blockDescription: blockDescription,
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
