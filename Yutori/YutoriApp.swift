
import SwiftUI
import UIKit

@main
struct YutoriApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        PurchaseManager.shared.configure()

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = AppTheme.paperBackground
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [.foregroundColor: AppTheme.inkColor, .font: roundedFont(size: 17, weight: .semibold)]
        navigation.largeTitleTextAttributes = [.foregroundColor: AppTheme.inkColor, .font: roundedFont(size: 34, weight: .bold)]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
    }

    private func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: size)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    TabBarView()
                } else {
                    OnboardingView(allowsDismiss: false) {
                        hasCompletedOnboarding = true
                    }
                }
            }
                .id(AppReset.shared.revision)
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .background(AppTheme.paper.ignoresSafeArea())
        }
    }
}
