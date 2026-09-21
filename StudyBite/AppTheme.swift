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
