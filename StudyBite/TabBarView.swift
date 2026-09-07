
import SwiftUI

struct TabBarView: View {
    var body: some View {
        
        TabView() {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                StatsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
            }
        }
}

#Preview {
    TabBarView()
}
