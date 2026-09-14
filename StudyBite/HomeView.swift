
import SwiftUI
import UIKit

struct HomeView: View {
    
    @State var showSettings = false
    @State private var sessionStore = StudySessionStore.shared
    @State private var courseStore = CourseStore.shared
    @AppStorage("profileName") private var profileName = "Bruno Gonzalez"
    private var greeting: String { Self.sessionGreeting }
    private var dishProgress: DishProgress { sessionStore.dishProgress }

    private var recentCourseSessions: [StudySession] {
        Array(sessionStore.sessions.prefix(3))
    }

    // Pick once per app process, including when HomeView is recreated.
    private static let sessionGreeting: String = {
        let greetings = [
            "Hi!", "Welcome back!", "Good to see you!",
            "Ready to study?", "Let's get started!", "Time to focus!",
            "You've got this!", "One step at a time!", "Let's learn something new!",
            "Make today count!", "A little progress every day!", "Ready for a fresh start?",
            "Your next chapter starts here!", "Small steps, big dreams!", "Keep your curiosity alive!",
            "Let's make progress!", "Time to grow!", "One study bite at a time!",
            "Bring your ideas to life!", "Build a little momentum!"
        ]
        let defaults = UserDefaults.standard
        let lastGreeting = defaults.string(forKey: "lastHomeGreeting")
        let greeting = greetings.filter { $0 != lastGreeting }.randomElement() ?? "Hi!"
        defaults.set(greeting, forKey: "lastHomeGreeting")
        return greeting
    }()

    var body: some View {
        GeometryReader { geometry in
        ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    showSettings = true
                } label: {
                    ProfileAvatarView(size: 50)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(profileName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(greeting) \(profileName)")
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 32)
            
            VStack(spacing: 20) {
                
                DishArtworkView(level: dishProgress.level, availableWidth: geometry.size.width)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, dishProgress.level == 5 ? -6 : 0)
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 0) {
                            Button {
                                sessionStore.stepDishPreview(by: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .frame(width: 36, height: 44)
                            }
                            .accessibilityLabel("Preview previous dish level")
                            Button {
                                sessionStore.stepDishPreview(by: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .frame(width: 36, height: 44)
                            }
                            .accessibilityLabel("Preview next dish level")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }
                
                // The badge extends below the track; tuck the left-aligned caption
                // into that reserved space without moving the track or badge.
                VStack(alignment: .leading, spacing: -4) {
                    DishProgressBar(progress: dishProgress)
                    
                    Text(sessionStore.loadFailed ? "Progress unavailable" : dishProgress.isComplete ? "Dish complete!" : "\(dishProgress.remainingMinutes) min remaining")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 60)
            }
            .padding(.bottom, 32)
            
            VStack(alignment: .leading, spacing: 14) {
                
                Spacer()
                    .frame(height: 5)
                
                Text("Last sessions")
                    .font(.system(size: 24, weight: .bold))
                
                if sessionStore.loadFailed {
                    Text("Couldn't load your sessions. Please reopen the app and try again.")
                        .foregroundStyle(.secondary)
                } else if sessionStore.sessions.isEmpty {
                    Text("Your completed study sessions will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentCourseSessions) { session in
                        let course = courseStore.courses.first { $0.id == session.course.id } ?? session.course
                        HStack(spacing: 12) {
                            CourseBadge(course: course)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.name)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(session.blockDescription)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Text(session.formattedDuration)
                                .font(.system(size: 17, weight: .medium))
                                .fixedSize()
                        }
                        .accessibilityElement(children: .combine)
                        if session.id != recentCourseSessions.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
        }
        .frame(width: geometry.size.width)
        .padding(.bottom, 32)
        }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    HomeView()
}


struct DishArtworkView: View {
    let level: Int
    let availableWidth: CGFloat
    @Environment(\.displayScale) private var displayScale

    // Original canvases and measured nontransparent bounds; the PNGs remain untouched.
    private static let artwork: [(canvas: CGSize, bounds: CGRect)] = [
        (CGSize(width: 180, height: 180), CGRect(x: 4, y: 34, width: 173, height: 127)),
        (CGSize(width: 233, height: 233), CGRect(x: 57, y: 72, width: 119, height: 99)),
        (CGSize(width: 224, height: 224), CGRect(x: 31, y: 51, width: 162, height: 132)),
        (CGSize(width: 223, height: 209), CGRect(x: 11, y: 24, width: 201, height: 162)),
        (CGSize(width: 251, height: 251), CGRect(x: 3, y: 18, width: 245, height: 216)),
        (CGSize(width: 287, height: 287), CGRect(x: 3, y: 7, width: 280, height: 270))
    ]

    var body: some View {
        let index = min(max(level, 0), 5)
        let asset = Self.artwork[index]
        let targetWidths: [CGFloat] = [205, 174, 210, 240, 253, 266]
        let screenFactor = min(1, max(0, availableWidth - 80) / 266)
        let width = (targetWidths[index] * screenFactor * displayScale).rounded() / displayScale
        let scale = width / asset.bounds.width

        ZStack {
            PixelDishImage(level: index, bounds: asset.bounds, canvas: asset.canvas)
                .frame(width: width, height: (asset.bounds.height * scale * displayScale).rounded() / displayScale)
        }
        .padding(.top, index == 0 ? 14 * screenFactor : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dish level \(index) of 5")
    }
}

// Use the original pixel data directly, without SwiftUI's resized/clipped intermediate layers.
private struct PixelDishImage: UIViewRepresentable {
    let level: Int
    let bounds: CGRect
    let canvas: CGSize

    func makeUIView(context: Context) -> PixelDishSurface {
        PixelDishSurface()
    }

    func updateUIView(_ view: PixelDishSurface, context: Context) {
        guard view.displayedLevel != level else { return }
        view.displayedLevel = level
        let image = UIImage(named: "DishLevel\(level)")?.cgImage
        // Cropping changes only the display bounds, not the source pixels or assets.
        if let image {
            let scaleX = CGFloat(image.width) / canvas.width
            let scaleY = CGFloat(image.height) / canvas.height
            let sourceBounds = CGRect(x: bounds.minX * scaleX, y: bounds.minY * scaleY,
                                      width: bounds.width * scaleX, height: bounds.height * scaleY)
            view.artwork.contents = image.cropping(to: sourceBounds)
        }
    }
}

private final class PixelDishSurface: UIView {
    let artwork = CALayer()
    var displayedLevel: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
        artwork.magnificationFilter = .nearest
        // The ×4 exports are reduced on Retina screens; linear sampling avoids
        // skipping source pixels while nearest preserves edges when enlarged.
        artwork.minificationFilter = .linear
        artwork.contentsGravity = .resize
        artwork.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer.addSublayer(artwork)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.scale ?? traitCollection.displayScale
        let origin = convert(CGPoint.zero, to: nil)
        let x = (origin.x * scale).rounded() / scale - origin.x
        let y = (origin.y * scale).rounded() / scale - origin.y
        artwork.frame = CGRect(x: x, y: y,
                               width: (bounds.width * scale).rounded() / scale,
                               height: (bounds.height * scale).rounded() / scale)
    }
}

struct DishProgressBar: View {
    let progress: DishProgress

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.25)).frame(height: 7)
                Capsule().fill(.black)
                    .frame(width: geometry.size.width * progress.fraction, height: 7)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(45))
                    Text("\(min(progress.level + 1, DishProgress.maximumLevel))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 36)
        }
        .frame(height: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.isComplete ? "Dish complete" : "Progress to level \(progress.level + 1)")
        .accessibilityValue("\(Int(progress.fraction * 100)) percent")
    }
}
