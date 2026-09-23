import SwiftUI

/// Use one system sheet surface, including its bottom safe area.
/// Do not clip or inset a second card inside the presentation.
struct AppSheetStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackground(AppTheme.paper)

    }
}
