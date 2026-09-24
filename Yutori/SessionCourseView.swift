import SwiftUI

struct SessionCourseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = CourseStore.shared
    @State private var purchaseManager = PurchaseManager.shared
    @State private var selectedID: UUID?
    @State private var showCourses = false
    @State private var showPaywall = false
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
                    AppEmptyStateCard(
                        icon: "book.closed.fill",
                        title: "Create your first course",
                        message: "Add a course before starting your first study session.",
                        showsBackground: false
                    )
                } else {
                    ForEach(store.courses) { course in
                        Button { selectedID = course.id } label: {
                            HStack(spacing: 12) {
                                CourseBadge(course: course)
                                Text(course.name)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .foregroundStyle(AppTheme.ink)
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 66)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(selectedID == course.id ? AppTheme.ink : AppTheme.ink.opacity(0.10),
                                                  lineWidth: selectedID == course.id ? 2 : 1)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedID == course.id ? .isSelected : [])
                    }
                }
                if !store.loadFailed {
                    Button {
                        if store.courses.isEmpty || purchaseManager.isPro {
                            showCourses = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label("Create a course", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(store.courses.isEmpty ? AppTheme.paper : AppTheme.ink)
                            .padding(.horizontal, 20)
                            .frame(height: store.courses.isEmpty ? 42 : 22)
                            .background {
                                if store.courses.isEmpty {
                                    Capsule().fill(AppTheme.ink)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
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
                Text("Start session")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
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
            Group {
            NavigationStack {
                CourseEditorView(course: StudyCourse(name: ""), store: store, onSaved: { course in
                    selectedID = course.id
                }, onDeleted: {})
            }
            .presentationDetents([.large])

            }.presentationBackground(AppTheme.paper)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationBackground(AppTheme.paper)
                .presentationDragIndicator(.visible)
        }
    }
}
