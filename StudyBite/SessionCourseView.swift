import SwiftUI

struct SessionCourseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = CourseStore.shared
    @State private var selectedID: UUID?
    @State private var showCourses = false
    @State private var starting = false
    let onStart: (StudyCourse) -> Void

    private var selectedCourse: StudyCourse? { store.courses.first { $0.id == selectedID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if store.loadFailed {
                    Text("Couldn't load your courses. Please reopen the app.")
                        .foregroundStyle(AppTheme.secondaryInk)
                } else if store.courses.isEmpty {
                    Text("Create a course for your first study block.")
                        .foregroundStyle(AppTheme.secondaryInk)
                } else {
                    ForEach(store.courses) { course in
                        Button { selectedID = course.id } label: {
                            HStack(spacing: 12) {
                                CourseBadge(course: course)
                                Text(course.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: selectedID == course.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedID == course.id ? AppTheme.ink : AppTheme.secondaryInk.opacity(0.4))
                            }
                            .foregroundStyle(AppTheme.ink)
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 66)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                            .contentShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedID == course.id ? .isSelected : [])
                    }
                }
                if !store.loadFailed {
                    Button("Create a course", systemImage: "plus") { showCourses = true }
                        .font(.subheadline)
                        .tint(AppTheme.ink)
                        .padding(.vertical, 12)
                }
            }
            .padding(24)
        }
        .background(AppTheme.paper)
        .safeAreaInset(edge: .bottom) {
            Button {
                guard !starting, !store.loadFailed, let selectedCourse else { return }
                starting = true
                onStart(selectedCourse)
            } label: {
                Text("Start block")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.ink.opacity(selectedCourse == nil ? 0.3 : 1), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedCourse == nil || store.loadFailed || starting)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(AppTheme.paper)
        }
        .navigationTitle("Choose a course")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
        .sheet(isPresented: $showCourses) {
            CoursesPage(store: store).presentationDetents([.large])
        }
    }
}
