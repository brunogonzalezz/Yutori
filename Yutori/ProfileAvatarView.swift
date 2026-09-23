import SwiftUI
import UIKit

struct ProfileAvatarView: View {
    let size: CGFloat
    @AppStorage("profileAvatarColor") private var avatarColor = "Teal"
    @AppStorage("profilePhoto") private var photoData = Data()

    static let colors: [(name: String, color: Color)] = [
        ("Jade Teal", CourseColor.teal.tint),
        ("Matcha Green", CourseColor.green.tint),
        ("Golden Yellow", CourseColor.lemon.tint),
        ("Persimmon Orange", CourseColor.orange.tint),
        ("Torii Vermilion", CourseColor.red.tint),
        ("Plum Purple", CourseColor.purple.tint)
    ]

    private var color: Color {
        Self.colors.first { $0.name == Self.updatedColorName(avatarColor) }?.color ?? CourseColor.teal.tint
    }

    static func updatedColorName(_ name: String) -> String {
        switch name {
        case "Teal": return "Jade Teal"
        case "Green": return "Matcha Green"
        case "Blue", "Yellow": return "Golden Yellow"
        case "Orange": return "Persimmon Orange"
        case "Pink", "Red": return "Torii Vermilion"
        case "Purple": return "Plum Purple"
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
                    .background(color.opacity(0.15))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 54 / 132, style: .continuous))
        .accessibilityHidden(true)
    }
}
