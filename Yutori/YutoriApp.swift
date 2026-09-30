
import SwiftUI
import UIKit

@main
struct YutoriApp: App {
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
            YutoriRootView()
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .background(AppTheme.paper.ignoresSafeArea())
        }
    }
}

private struct YutoriRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.english.rawValue
    @State private var appReset = AppReset.shared

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()

            if hasCompletedOnboarding {
                TabBarView()
                    .transition(.opacity)
            } else if appReset.shouldShowResetLoading {
                YutoriLaunchView()
                    .transition(.opacity)
            } else {
                OnboardingView(allowsDismiss: false) {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        hasCompletedOnboarding = true
                    }
                }
                .transition(.opacity)
            }
        }
        .environment(\.locale, AppLanguage(rawValue: appLanguage)?.locale ?? AppLanguage.english.locale)
        .animation(.easeInOut(duration: 0.62), value: hasCompletedOnboarding)
        .id(appLanguage)
        .id(appReset.revision)
        .onChange(of: appLanguage) {
            Task { await ActiveStudySession.shared.syncActivity() }
        }
        .task(id: appReset.revision) {
            guard appReset.shouldShowResetLoading else { return }
            try? await Task.sleep(for: .milliseconds(1650))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.32)) {
                appReset.finishResetLoading()
            }
        }
    }
}

private struct YutoriLaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(CourseColor.green.tint)

                Text("Yutori")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Preparing your space to focus…")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { appeared = true }
        }
    }
}
