import SwiftUI
import UIKit

struct ProfileAvatarView: View {
    let size: CGFloat
    @AppStorage("profileAvatarColor") private var avatarColor = "Teal"
    @AppStorage("profilePhoto") private var photoData = Data()

    static let colors: [(name: String, color: Color)] = [
        ("Teal", .teal),
        ("Green", .green),
        ("Yellow", .yellow),
        ("Orange", Color(red: 0.90, green: 0.33, blue: 0.14)),
        ("Red", .red),
        ("Purple", .purple)
    ]

    private var color: Color {
        Self.colors.first { $0.name == Self.updatedColorName(avatarColor) }?.color ?? .teal
    }

    static func updatedColorName(_ name: String) -> String {
        switch name {
        case "Blue": return "Yellow"
        case "Pink": return "Red"
        default: return name
        }
    }

    var body: some View {
        Group {
            if let photo = UIImage(data: photoData) {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                SettingsAvatar()
                    .foregroundStyle(color)
                    .background(color.opacity(0.08))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 54 / 132, style: .continuous))
        .accessibilityHidden(true)
    }
}
