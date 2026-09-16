import SwiftUI
import UIKit

struct TabBarView: View {
    private enum Tab: Hashable {
        case home
        case bowls
        case stats
        case startStudy
    }

    @State private var selectedTab: Tab = .home
    @State private var showStartStudy = false
    @State private var showBowlPicker = false
    @State private var showStudyTimer = false
    @State private var startTimerAfterSheetCloses = false
    @State private var sessionCourse: StudyCourse?
    @Namespace private var dishNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var evolution: (from: Int, to: Int)?
    @State private var returningHome = false
    @State private var homeRevision = 0
    @State private var collectingFrame: CGRect?
    @State private var collectionArrived = false
    @State private var tabAnchor: UIView?

    private var tabSelection: Binding<Tab> {
        Binding {
            selectedTab
        } set: { newTab in
            if newTab == .startStudy {
                if StudySessionStore.shared.hasActiveBowl {
                    showStartStudy = true
                } else {
                    showBowlPicker = true
                }
            } else {
                selectedTab = newTab
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
        ZStack {
            TabView(selection: tabSelection) {
                SwiftUI.Tab("Home", systemImage: "house", value: Tab.home) {
                    HomeView(dishNamespace: reduceMotion ? nil : dishNamespace,
                             hideDishForEvolution: evolution != nil,
                             isCollecting: collectingFrame != nil,
                             onCollect: { frame in
                        guard collectingFrame == nil, frame.width > 0,
                              StudySessionStore.shared.canCollectBowl else { return }
                        collectionArrived = false
                        collectingFrame = frame
                    }, onSelectBowl: { showBowlPicker = true })
                        .id(homeRevision)
                }

                SwiftUI.Tab("Bowls", systemImage: "fork.knife", value: Tab.bowls) {
                    BowlsView()
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
                    StudyTimerView(course: sessionCourse, onEvolution: { from, to, _ in
                        // Prepare Home behind the celebration, with its dish at the top.
                        selectedTab = .home
                        homeRevision += 1
                        evolution = (from, to)
                        showStudyTimer = false
                        self.sessionCourse = nil
                    }) { _ in
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

            if let evolution {
                DishEvolutionView(fromLevel: evolution.from, toLevel: evolution.to,
                                  dishNamespace: reduceMotion ? nil : dishNamespace) {
                    guard !returningHome else { return }
                    returningHome = true
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.75, bounce: 0.08),
                                  completionCriteria: .removed) {
                        self.evolution = nil
                    } completion: {
                        returningHome = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }

            if let frame = collectingFrame {
                let origin = geometry.frame(in: .global).origin
                let destination = bowlsTabCenter() ?? CGPoint(
                    x: origin.x + geometry.size.width * 0.4,
                    y: origin.y + geometry.size.height - 30)
                DishArtworkView(level: 5, availableWidth: geometry.size.width)
                    .frame(width: frame.width, height: frame.height)
                    .scaleEffect(collectionArrived && !reduceMotion ? 0.1 : 1)
                    .opacity(collectionArrived ? (reduceMotion ? 0 : 0.7) : 1)
                    .position(
                        x: (collectionArrived && !reduceMotion ? destination.x : frame.midX) - origin.x,
                        y: (collectionArrived && !reduceMotion ? destination.y : frame.midY) - origin.y)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(3)
                    .onAppear {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.2) :
                                        .timingCurve(0.35, 0, 0.2, 1, duration: 0.85),
                                      completionCriteria: .removed) {
                            collectionArrived = true
                        } completion: {
                            if StudySessionStore.shared.collectBowl() {
                                selectedTab = .bowls
                            }
                            collectingFrame = nil
                            collectionArrived = false
                        }
                    }
            }
        }
        .background(CollectionTabAnchor { tabAnchor = $0 })
        .allowsHitTesting(!returningHome && collectingFrame == nil)
        .sheet(isPresented: $showBowlPicker) {
            BowlPickerView {
                selectedTab = .home
            }
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(32)
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
    }

    private func bowlsTabCenter() -> CGPoint? {
        guard let window = tabAnchor?.window else { return nil }
        func findTabBar(in view: UIView) -> UITabBar? {
            if let bar = view as? UITabBar, !bar.isHidden { return bar }
            for child in view.subviews {
                if let bar = findTabBar(in: child) { return bar }
            }
            return nil
        }
        guard let bar = findTabBar(in: window) else { return nil }
        let buttons = bar.subviews.filter { $0 is UIControl && !$0.isHidden }
            .sorted { $0.frame.midX < $1.frame.midX }
        guard buttons.count >= 3 else { return nil }
        let button = buttons[1]
        return button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .bowls:
            BowlsView()
        case .stats:
            StatsView()
        case .home, .startStudy:
            HomeView(onSelectBowl: { showBowlPicker = true })
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

private struct CollectionTabAnchor: UIViewRepresentable {
    var onResolve: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async { onResolve(view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
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
