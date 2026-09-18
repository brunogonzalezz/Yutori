
import SwiftUI
import UIKit

@main
struct StudyBiteApp: App {
    init() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = AppTheme.paperBackground
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [.foregroundColor: AppTheme.inkColor]
        navigation.largeTitleTextAttributes = [.foregroundColor: AppTheme.inkColor]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
    }

    var body: some Scene {
        WindowGroup {
            TabBarView()
                .id(AppReset.shared.revision)
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .background(AppTheme.paper.ignoresSafeArea())
                .presentationBackground(AppTheme.paper)
        }
    }
}
