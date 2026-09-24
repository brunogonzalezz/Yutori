import SwiftUI
import UIKit

enum AppTheme {
    static let surface = Color(red: 227 / 255, green: 221 / 255, blue: 207 / 255) // E3DDCF
    static let secondaryInk = Color(red: 120 / 255, green: 113 / 255, blue: 98 / 255)
    static let muted = Color(red: 187 / 255, green: 177 / 255, blue: 157 / 255)
    static let darkSurface = Color(red: 89 / 255, green: 84 / 255, blue: 72 / 255) // 595448
    static let ink = Color(uiColor: inkColor)
    static let inkColor = UIColor(red: 76 / 255, green: 72 / 255, blue: 61 / 255, alpha: 1)
    static let paper = Color(uiColor: paperBackground)
    static let paperBackground = UIColor(red: 247 / 255, green: 244 / 255, blue: 237 / 255, alpha: 1)
}

extension BowlKind {
    var evolutionColors: [Color] {
        switch self {
        case .teriyaki:
            [
                Color(red: 0.91, green: 0.32, blue: 0.12),
                Color(red: 0.35, green: 0.64, blue: 0.19),
                Color(red: 0.98, green: 0.73, blue: 0.10),
                Color(red: 0.82, green: 0.20, blue: 0.46),
                Color(red: 0.96, green: 0.80, blue: 0.61)
            ]
        case .katsuRamen:
            [
                Color(red: 0.90, green: 0.43, blue: 0.12),
                Color(red: 0.31, green: 0.57, blue: 0.22),
                Color(red: 0.97, green: 0.72, blue: 0.25),
                Color(red: 0.86, green: 0.48, blue: 0.42),
                Color(red: 0.95, green: 0.84, blue: 0.68)
            ]
        }
    }
}

struct AppEmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var showsBackground = true
    var compact = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .frame(width: 52, height: 44)

            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 250)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.paper)
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(AppTheme.ink, in: Capsule())
                    .buttonStyle(.plain)
                    .padding(.top, 2)
            }

        }
        .frame(maxWidth: .infinity, minHeight: compact ? 152 : (actionTitle == nil ? 150 : 184))
        .padding(.horizontal, 20)
        .background {
            if showsBackground {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.72))
            }
        }
        .overlay {
            if showsBackground {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(AppTheme.ink.opacity(0.08), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
