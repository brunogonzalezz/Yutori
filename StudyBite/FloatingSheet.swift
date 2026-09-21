import SwiftUI

struct FloatingSheet: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let bottomGap = max(20, geometry.safeAreaInsets.bottom + 12)
            content
                .frame(width: max(0, geometry.size.width - 24),
                       height: max(0, geometry.size.height - bottomGap))
                .background(AppTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 12)
        }
        .presentationBackground(.clear)
        .presentationDragIndicator(.hidden)
    }
}
