import SwiftUI

struct SessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let course: StudyCourse
    let measuredDuration: TimeInterval
    let endedAt: Date
    let onSave: (TimeInterval) -> Void
    @State private var sessionID = UUID()
    @State private var blockDescription = ""
    @State private var hours = "0"
    @State private var minutes = "0"
    @State private var seconds = "0"
    @State private var initialized = false
    @State private var saveFailed = false
    @State private var saved = false

    private var correctedDuration: TimeInterval? {
        guard let h = Int(hours), let m = Int(minutes), let s = Int(seconds),
              (0...999).contains(h), (0...59).contains(m), (0...59).contains(s) else { return nil }
        let total = h * 3600 + m * 60 + s
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
                Section("What did you study?") {
                    TextField("Describe this study block", text: $blockDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: blockDescription) { _, value in
                            if value.count > 500 { blockDescription = String(value.prefix(500)) }
                        }
                }
                Section {
                    HStack(spacing: 16) {
                        timeField("Hours", text: $hours)
                        timeField("Minutes", text: $minutes)
                        timeField("Seconds", text: $seconds)
                    }
                    Button("Use recorded time") { resetTime() }
                    if correctedDuration == nil {
                        Text("Enter a positive duration. Minutes and seconds must be between 0 and 59.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Study time")
                } footer: {
                    Text("You can increase or decrease the recorded time before saving.")
                }
            }
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
        .tint(.blue)
        .interactiveDismissDisabled()
    }

    private func timeField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .monospacedDigit()
                .accessibilityLabel(title)
        }
    }

    private func resetTime() {
        let total = min(3_599_999, max(1, Int(measuredDuration)))
        hours = String(total / 3600)
        minutes = String((total % 3600) / 60)
        seconds = String(total % 60)
    }

    private func save() {
        guard canSave, let duration = correctedDuration else { return }
        do {
            try StudySessionStore.shared.save(StudySession(
                id: sessionID, course: course, blockDescription: blockDescription,
                duration: duration, endedAt: endedAt
            ))
            saved = true
            onSave(duration)
        } catch {
            saveFailed = true
        }
    }
}
