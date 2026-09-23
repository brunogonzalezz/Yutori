
import SwiftUI
import UIKit

@main
struct YutoriApp: App {
    init() {
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
            TabBarView()
                .id(AppReset.shared.revision)
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .background(AppTheme.paper.ignoresSafeArea())
        }
    }
}
