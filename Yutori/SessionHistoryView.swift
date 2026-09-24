import SwiftUI

struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StudySessionStore.shared
    @State private var selectedSession: StudySession?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.loadFailed {
                        Text("Couldn't load your sessions. Please reopen the app.")
                            .foregroundStyle(AppTheme.secondaryInk)
                    } else if store.sessions.isEmpty {
                        SessionEmptyStateCard()
                        .padding(.top, 36)
                    }
                    ForEach(store.sessions) { session in
                        Button { selectedSession = session } label: {
                            HStack(spacing: 12) {
                                CourseBadge(course: session.course)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.course.name).font(.headline)
                                    if !session.blockDescription.isEmpty {
                                        Text(session.blockDescription).font(.subheadline)
                                            .foregroundStyle(AppTheme.secondaryInk).lineLimit(2)
                                    }
                                    Text(session.endedAt, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                                        .font(.caption).foregroundStyle(AppTheme.secondaryInk)
                                }
                                Spacer(minLength: 4)
                                Text(session.formattedDuration)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CourseColor.green.tint)
                            }
                            .foregroundStyle(AppTheme.ink)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                            .contentShape(RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.paper)
            .navigationTitle("All sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedSession) { session in
            Group {
                SessionSummaryView(course: session.course, measuredDuration: session.duration,
                                   startingSeconds: session.startingDishSeconds ?? 0,
                                   bowlKind: session.bowlKind ?? .teriyaki,
                                   pauseCount: session.pauseCount ?? 0,
                                   endedAt: session.endedAt, onDiscard: {}, onSave: { _ in },
                                   savedSession: session)

            }.presentationBackground(AppTheme.paper)
        }
        }
        .tint(AppTheme.ink)
    }
}
