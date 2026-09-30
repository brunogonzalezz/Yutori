import SwiftUI

enum CourseIconCatalog {
    static let icons = [
        ("book.fill", "Book"), ("books.vertical.fill", "Literature"),
        ("graduationcap.fill", "Education"), ("studentdesk", "Study"),
        ("pencil", "Writing"), ("textformat.abc", "Language"),
        ("number", "Numbers"), ("percent", "Maths"), ("sum", "Algebra"),
        ("function", "Calculus"), ("ruler.fill", "Geometry"), ("chart.bar.fill", "Statistics"),
        ("atom", "Science"), ("flask.fill", "Chemistry"), ("testtube.2", "Laboratory"),
        ("bolt.fill", "Physics"), ("gearshape.fill", "Mechanics"), ("hammer.fill", "Engineering"),
        ("leaf.fill", "Biology"), ("pawprint.fill", "Zoology"), ("drop.fill", "Water"),
        ("sun.max.fill", "Weather"), ("moon.stars.fill", "Space"), ("sparkles", "Astronomy"),
        ("heart.fill", "Health"), ("cross.case.fill", "Medicine"), ("stethoscope", "Nursing"),
        ("brain.head.profile", "Psychology"), ("figure.run", "Exercise"), ("fork.knife", "Nutrition"),
        ("globe.europe.africa.fill", "Geography"), ("map.fill", "Maps"), ("clock.fill", "History"),
        ("building.columns.fill", "Classics"), ("character.bubble.fill", "Conversation"), ("briefcase.fill", "Business"),
        ("paintpalette.fill", "Art"), ("music.note", "Music"), ("camera.fill", "Photography"),
        ("film.fill", "Cinema"), ("theatermasks.fill", "Theatre"), ("scissors", "Crafts"),
        ("desktopcomputer", "Computing"), ("curlybraces", "Programming"), ("network", "Networks"),
        ("chart.pie.fill", "Data"), ("dollarsign.circle.fill", "Economics"), ("sportscourt.fill", "Sports")
    ]
}

struct CourseIconsMosaic: View {
    var animated = true
    var iconColor = AppTheme.paper
    var iconOpacity = 0.065
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30,
                                paused: !animated || reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = animated && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
                let symbols = CourseIconCatalog.icons
                context.opacity = iconOpacity
                let spacing = 38.0
                let travel = time * 3.0 / spacing
                let wholeSteps = Int(floor(travel))
                let offset = (travel - floor(travel)) * spacing
                for row in -1...Int(size.height / spacing + 1) {
                    for column in -1...Int(size.width / spacing + 1) {
                        // A single translation moves the entire grid; icon order stays fixed.
                        let cell = (row - wholeSteps) * 17 + (column - wholeSteps) * 31
                        let index = ((cell % symbols.count) + symbols.count) % symbols.count
                        var symbol = context.resolve(Image(systemName: symbols[index].0).renderingMode(.template))
                        symbol.shading = .color(iconColor)
                        context.draw(symbol, in: CGRect(x: Double(column) * spacing + offset,
                                                       y: Double(row) * spacing + offset,
                                                       width: 17, height: 17))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SessionEmptyStateCard: View {
    private let badges: [(CourseColor, String)] = [
        (.teal, "function"),
        (.orange, "book.fill"),
        (.blue, "atom"),
        (.pink, "character.bubble.fill"),
        (.lemon, "globe.europe.africa.fill")
    ]

    var body: some View {
        ZStack {
            AppTheme.surface.opacity(0.66)

            CourseIconsMosaic(animated: false, iconColor: AppTheme.ink, iconOpacity: 0.052)

            VStack(spacing: 10) {
                HStack(spacing: -9) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { index, badge in
                        Image(systemName: badge.1)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(badge.0.tint, in: Circle())
                            .overlay { Circle().strokeBorder(badge.0.deepTint.opacity(0.55), lineWidth: 1.25) }
                            .zIndex(Double(3 - abs(index - 2)))
                    }
                }
                .offset(y: -5)

                VStack(spacing: 5) {
                    Text("Your study story starts here")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                        .allowsTightening(true)

                    Text("Complete a session and it will appear in your history.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, minHeight: 174)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

extension CourseColor {
    var deepTint: Color {
        let factor = 0.62
        return Color(
            red: Double((rgbHex >> 16) & 0xff) / 255 * factor,
            green: Double((rgbHex >> 8) & 0xff) / 255 * factor,
            blue: Double(rgbHex & 0xff) / 255 * factor
        )
    }
}
