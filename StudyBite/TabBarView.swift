import SwiftUI

struct TabBarView: View {
    private enum Tab: Hashable {
        case home
        case stats
        case startStudy
    }

    @State private var selectedTab: Tab = .home
    @State private var showStartStudy = false
    @State private var showStudyTimer = false
    @State private var startTimerAfterSheetCloses = false
    @State private var sessionCourse: StudyCourse?

    private var tabSelection: Binding<Tab> {
        Binding {
            selectedTab
        } set: { newTab in
            if newTab == .startStudy {
                showStartStudy = true
            } else {
                selectedTab = newTab
            }
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: tabSelection) {
                SwiftUI.Tab("Home", systemImage: "house", value: Tab.home) {
                    HomeView()
                }

                SwiftUI.Tab("Stats", systemImage: "chart.bar", value: Tab.stats) {
                    StatsView()
                }

                SwiftUI.Tab(value: Tab.startStudy, role: .search) {
                    currentTabView
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Start studying")
                }
            }

            if showStudyTimer, let sessionCourse {
                NavigationStack {
                    StudyTimerView(course: sessionCourse) { _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = .home
                            showStudyTimer = false
                            self.sessionCourse = nil
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).ignoresSafeArea())
                .transition(
                    .opacity.combined(with: .scale(scale: 0.985))
                )
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showStartStudy, onDismiss: openPendingTimer) {
            StartStudyView { course in
                sessionCourse = course
                startTimerAfterSheetCloses = true
                showStartStudy = false
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .stats:
            StatsView()
        case .home, .startStudy:
            HomeView()
        }
    }

    private func openPendingTimer() {
        guard startTimerAfterSheetCloses, sessionCourse != nil else {
            return
        }

        startTimerAfterSheetCloses = false
        withAnimation(.easeInOut(duration: 0.3)) {
            showStudyTimer = true
        }
    }
}

private struct StartStudyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = CourseStore.shared
    @State private var selectedCourseID: UUID?
    @State private var showCourses = false
    let onStart: (StudyCourse) -> Void

    private var selectedCourse: StudyCourse? {
        store.courses.first { $0.id == selectedCourseID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.loadFailed {
                        ContentUnavailableView("Couldn't load courses", systemImage: "exclamationmark.triangle", description: Text("Please reopen the app and try again."))
                    } else if store.courses.isEmpty {
                        ContentUnavailableView("Create a course first", systemImage: "books.vertical", description: Text("Every study session needs a course."))
                        Button("Create a course") { showCourses = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Which course are you studying?")
                            .font(.headline)
                            .padding(.bottom, 4)
                        ForEach(store.courses) { course in
                            Button {
                                selectedCourseID = course.id
                            } label: {
                                HStack(spacing: 12) {
                                    CourseBadge(course: course)
                                    Text(course.name)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: selectedCourseID == course.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedCourseID == course.id ? Color.blue : Color.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedCourseID == course.id ? .isSelected : [])
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if !store.courses.isEmpty && !store.loadFailed {
                    Button {
                        guard let selectedCourse else { return }
                        onStart(selectedCourse)
                    } label: {
                        Label("Start studying", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(selectedCourse == nil)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                }
            }
            .navigationTitle("New study session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(isPresented: $showCourses) {
                CoursesPage(store: store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    TabBarView()
}
