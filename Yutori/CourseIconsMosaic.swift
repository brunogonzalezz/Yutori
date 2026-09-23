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
                        symbol.shading = .color(AppTheme.paper)
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
