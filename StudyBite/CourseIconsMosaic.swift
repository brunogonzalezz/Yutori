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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30,
                                paused: reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let symbols = CourseIconCatalog.icons
                context.opacity = 0.065
                for index in 0..<symbols.count {
                    let seed = Double(index)
                    let width = max(1, size.width + 32)
                    let height = max(1, size.height + 32)
                    let velocityX = 2.4 + Double(index % 5) * 0.54
                    let velocityY = 1.2 + Double(index % 3) * 0.42
                    let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
                    let x = (seed * 73.7 + time * velocityX * direction).truncatingRemainder(dividingBy: width)
                    let y = (seed * 41.3 + time * velocityY).truncatingRemainder(dividingBy: height)
                    var symbol = context.resolve(Image(systemName: symbols[index].0).renderingMode(.template))
                    symbol.shading = .color(AppTheme.paper)
                    context.draw(symbol, in: CGRect(x: (x + width).truncatingRemainder(dividingBy: width) - 16,
                                                   y: (y + height).truncatingRemainder(dividingBy: height) - 16,
                                                   width: 17, height: 17))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
