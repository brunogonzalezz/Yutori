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

            if showStudyTimer {
                NavigationStack {
                    StudyTimerView { _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showStudyTimer = false
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
            StartStudyView {
                startTimerAfterSheetCloses = true
                showStartStudy = false
            }
            .presentationDetents([.medium])
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
        guard startTimerAfterSheetCloses else {
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
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "timer")
                    .font(.system(size: 42))

                Text("New study session")
                    .font(.title2.bold())

                Text("Start a timer and make every minute count towards your next dish.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    onStart()
                } label: {
                    Label("Start studying", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .padding(.top, 8)
            }
            .padding(32)
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TabBarView()
}
