import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct YutoriActivityBundle: WidgetBundle {
    var body: some Widget { StudySessionActivityWidget() }
}

private let paper = Color(red: 247/255, green: 244/255, blue: 237/255)
private let ink = Color(red: 76/255, green: 72/255, blue: 61/255)
private let vermilion = Color(red: 198/255, green: 83/255, blue: 71/255)

struct StudySessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            GeometryReader { geometry in
                HStack(alignment: .center, spacing: 16) {
                    bowl(context.state, language: context.state.languageCode ?? context.attributes.languageCode, large: true)
                        .frame(width: min(140, geometry.size.width * 0.42), height: 132)
                    VStack(alignment: .center, spacing: 10) {
                        clock(context.state)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(activityText("Elapsed study time", language: context.state.languageCode ?? context.attributes.languageCode))
                        controls(context.attributes.sessionID,
                                 language: context.state.languageCode ?? context.attributes.languageCode,
                                 paused: context.state.runningSince == nil,
                                 size: 50, spacing: 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 132)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .foregroundStyle(ink)
             .background {
                ZStack {
                    Color.white
                    ActivityCourseMosaic(icon: context.attributes.courseIcon ?? "book.fill",
                                         sessionID: context.attributes.sessionID,
                                         accumulated: context.state.accumulated)
                }
            }
            .activityBackgroundTint(.white)
            .activitySystemActionForegroundColor(ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    // Keep both columns inside the usable area below the camera.
                    // Fixed-size lateral regions can extend beyond the system's lower mask.
                    HStack(alignment: .center, spacing: 12) {
                        bowl(context.state, language: context.state.languageCode ?? context.attributes.languageCode, large: true)
                            .frame(width: 132, height: 100)
                        VStack(spacing: 8) {
                            clock(context.state)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                            controls(context.attributes.sessionID,
                                     language: context.state.languageCode ?? context.attributes.languageCode,
                                     paused: context.state.runningSince == nil,
                                     size: 48, spacing: 16, systemStyle: true)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 100)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                bowl(context.state, language: context.state.languageCode ?? context.attributes.languageCode)
                    .frame(width: 28, height: 28)
            } compactTrailing: {
                clock(context.state)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52, height: 28, alignment: .trailing)
            } minimal: {
                bowl(context.state, language: context.state.languageCode ?? context.attributes.languageCode, compact: true).frame(width: 24, height: 24)
            }
            .keylineTint(ink)
        }
    }

    private func bowl(_ state: StudyActivityAttributes.ContentState, language: String?, compact: Bool = false, large: Bool = false) -> some View {
        Image(state.imageName + (compact ? "Small" : (large ? "Large" : ""))).resizable().interpolation(.none).scaledToFit()
            .accessibilityLabel(activityFormatted("Bowl level %lld", language: language, Int64(state.level)))
    }

    private func clock(_ state: StudyActivityAttributes.ContentState) -> some View {
        StudyActivityClock(state: state)
    }

    private func controls(_ id: String, language: String?, paused: Bool, size: CGFloat = 44, spacing: CGFloat? = nil, systemStyle: Bool = false) -> some View {
        let pauseColor = systemStyle ? Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255) : ink
        let stopColor = systemStyle ? Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255) : vermilion
        return HStack(spacing: spacing ?? (size == 60 ? 24 : 16)) {
            Button(intent: ToggleStudySessionIntent(sessionID: id)) {
                Image(systemName: paused ? "play.fill" : "pause.fill")
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .frame(width: size, height: size)
                    .background(pauseColor, in: Circle())
                    .contentShape(Circle())
            }
            .tint(pauseColor)
            .accessibilityLabel(activityText(paused ? "Resume session" : "Pause session", language: language))
            Button(intent: FinishStudySessionIntent(sessionID: id)) {
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .frame(width: size, height: size)
                    .background(stopColor, in: Circle())
                    .contentShape(Circle())
            }
            .tint(stopColor)
            .accessibilityLabel(activityText("Finish session", language: language))
        }
        .buttonStyle(.plain)
        .foregroundStyle(systemStyle ? Color.white : paper)
    }
}

private func activityText(_ key: String, language: String?) -> String {
    guard language == "es",
          let path = Bundle.main.path(forResource: "es", ofType: "lproj"),
          let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: key, table: "Localizable")
}

private func activityFormatted(_ key: String, language: String?, _ arguments: CVarArg...) -> String {
    String(format: activityText(key, language: language), locale: Locale(identifier: language ?? "en"), arguments: arguments)
}

private struct StudyActivityClock: View {
    let state: StudyActivityAttributes.ContentState
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            if let since = state.runningSince {
                let start = since.addingTimeInterval(-state.accumulated)
                if isLuminanceReduced {
                    // iOS suppresses ticking seconds on the Always-On display.
                    // Show complete minutes explicitly instead of a misleading frozen second count.
                    TimelineView(.periodic(from: start, by: 60)) { context in
                        let minutes = max(0, Int(context.date.timeIntervalSince(start) / 60))
                        Text(minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min")
                    }
                } else {
                    Text(timerInterval: start...start.addingTimeInterval(3_600_000),
                         countsDown: false, showsHours: true)
                }
            } else {
                let seconds = max(0, Int(state.accumulated))
                Text(seconds >= 3600
                     ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
                     : String(format: "%02d:%02d", seconds / 60, seconds % 60))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct ActivityCourseMosaic: View {
    let icon: String
    let sessionID: String
    let accumulated: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 64
            let seed = UUID(uuidString: sessionID)?.uuid.0 ?? 0
            let xDirection: CGFloat = seed & 1 == 0 ? 1 : -1
            let yDirection: CGFloat = seed & 2 == 0 ? 1 : -1
            // ActivityKit supplies snapshots rather than continuous animation frames.
            let drift = reduceMotion ? 0 : CGFloat(accumulated.truncatingRemainder(dividingBy: 44) / 44) * cell * 2
            var symbol = context.resolve(Image(systemName: icon).renderingMode(.template))
            symbol.shading = .color(ink)
            context.opacity = 0.05
            for row in -3...Int(size.height / cell + 3) {
                for column in -3...Int(size.width / cell + 3) {
                    let stagger: CGFloat = row.isMultiple(of: 2) ? 0 : cell / 2
                    context.draw(symbol, in: CGRect(x: CGFloat(column) * cell + stagger + drift * xDirection,
                                                    y: CGFloat(row) * cell + drift * yDirection,
                                                    width: 20, height: 20))
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
