import SwiftUI

struct TabBarView: View {
    private enum Tab: Hashable {
        case home
        case stats
        case startStudy
    }

    @State private var selectedTab: Tab = .home
    @State private var showStartStudy = false

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
        .sheet(isPresented: $showStartStudy) {
            StartStudyView()
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
}

private struct StartStudyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "timer")
                    .font(.system(size: 42))

                Text("New study session")
                    .font(.title2.bold())

                Text("Course selection and the timer will live here.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
