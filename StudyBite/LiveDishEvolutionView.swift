import SwiftUI

/// A local artwork animation: the stopwatch and its controls remain independent.
struct LiveDishEvolutionView: View {
    let targetLevel: Int
    let kind: BowlKind
    let sourceFrame: CGRect
    let onActivity: (Bool) -> Void
    let isActive: Bool
    let onReveal: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedLevel: Int
    @State private var animating = false
    @State private var centered = false
    @State private var backdrop = false
    @State private var glowing = false
    @State private var particlesVisible = false
    @State private var particlesExpanded = false
    @State private var showCaption = false
    @State private var artworkScale: CGFloat = 1
    @State private var lift: CGFloat = 0
    @State private var light: Double = 0
    @State private var orbit: Double = 0
    @State private var ringsExpanded = false
    @State private var ringsVisible = false

    private struct AnimationRequest: Equatable {
        let level: Int
        let active: Bool
    }

    init(initialLevel: Int, targetLevel: Int, kind: BowlKind,
         sourceFrame: CGRect, isActive: Bool,
         onActivity: @escaping (Bool) -> Void, onReveal: @escaping (Int) -> Void) {
        self.targetLevel = targetLevel
        self.kind = kind
        self.sourceFrame = sourceFrame
        self.onActivity = onActivity
        self.isActive = isActive
        self.onReveal = onReveal
        _displayedLevel = State(initialValue: initialLevel)
    }

    var body: some View {
        GeometryReader { geometry in
        let availableWidth = geometry.size.width
        let origin = geometry.frame(in: .global).origin
        let radius = min(180, max(0, availableWidth - 48) / 2)
        let naturalWidth = DishArtworkView.naturalWidth(level: displayedLevel, availableWidth: availableWidth)
        let largestWidth = DishArtworkView.naturalWidth(level: 5, availableWidth: availableWidth)
        // Use one magnification factor for every level, keeping their relative sizes.
        let enlargedWidth = naturalWidth * min(340, max(0, availableWidth - 64)) / max(1, largestWidth)
        ZStack {
            AppTheme.ink.opacity(backdrop && !reduceMotion ? 0.78 : 0)
                .ignoresSafeArea()
            ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white, Color.orange.opacity(0.32), .clear],
                                     center: .center, startRadius: 12, endRadius: radius))
                .frame(width: radius * 1.55, height: radius * 1.55)
                .blur(radius: 14)
                .scaleEffect(glowing ? 1.35 : 0.75)
                .opacity(glowing && !reduceMotion ? 1 : 0)
                .offset(y: -12)

            ForEach(0..<2) { index in
                Circle()
                    .stroke(Color.orange.opacity(index == 0 ? 0.45 : 0.22), lineWidth: index == 0 ? 2 : 1)
                    .frame(width: radius * 1.6, height: radius * 1.6)
                    .scaleEffect(ringsExpanded ? (index == 0 ? 1.25 : 1.08) : 0.45)
                    .opacity(ringsVisible && !reduceMotion ? 1 : 0)
                    .offset(y: -12)
                    .accessibilityHidden(true)
            }

            DishArtworkView(level: displayedLevel, availableWidth: availableWidth,
                            preferredWidth: centered && !reduceMotion
                                ? enlargedWidth : sourceFrame.width,
                            kind: kind)
                .brightness(reduceMotion ? 0 : light)
                .scaleEffect(reduceMotion ? 1 : artworkScale)
                .offset(y: reduceMotion ? 0 : lift)
                .shadow(color: .orange.opacity(glowing && !reduceMotion ? 0.35 : 0), radius: 22)

            ForEach(0..<12) { index in
                let angle = Double(index) * .pi / 6
                Image(systemName: "sparkle")
                    .font(.system(size: index.isMultiple(of: 2) ? 15 : 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.7))
                    .rotationEffect(.degrees(-orbit))
                    .offset(x: cos(angle) * radius * (particlesExpanded ? 1.04 : 0.65),
                            y: sin(angle) * radius * (particlesExpanded ? 0.85 : 0.55))
                    .rotationEffect(.degrees(orbit))
                    .offset(y: -12)
                    .scaleEffect(particlesExpanded ? 1 : 0.6)
                    .opacity(particlesVisible && !reduceMotion ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        // This artwork is above the scroll view, free to travel to the screen center.
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .overlay(alignment: .bottom) {
            Text("Level \(displayedLevel) unlocked")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(centered && !reduceMotion ? Color.white : AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .offset(y: 56)
                .opacity(showCaption ? 1 : 0)
                .accessibilityHidden(!showCaption)
        }
        .position(x: centered && !reduceMotion ? geometry.size.width / 2 : sourceFrame.midX - origin.x,
                  y: centered && !reduceMotion ? geometry.size.height / 2 - 28 : sourceFrame.midY - origin.y)
        }
        .opacity(animating ? 1 : 0)
        }
        .allowsHitTesting(false)
        .sensoryFeedback(.success, trigger: displayedLevel)
        .task(id: AnimationRequest(level: targetLevel, active: isActive)) {
            guard isActive, sourceFrame.width > 0, targetLevel > displayedLevel else { return }
            do {
                EvolutionSound.shared.prepare()
                animating = true
                onActivity(true)
                withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.75)) {
                    centered = true
                    backdrop = true
                }
                try await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 800))
                // Catch up in order if multiple thresholds passed in the background.
                while displayedLevel < targetLevel {
                    try Task.checkCancellation()
                    particlesExpanded = false
                    showCaption = false
                    ringsExpanded = false
                    orbit = 0
                    if reduceMotion {
                        try await Task.sleep(for: .milliseconds(150))
                        displayedLevel += 1
                        onReveal(displayedLevel)
                        EvolutionSound.shared.play()
                        withAnimation(.easeOut(duration: 0.2)) { showCaption = true }
                        try await Task.sleep(for: .milliseconds(1400))
                        withAnimation(.easeOut(duration: 0.2)) { showCaption = false }
                        continue
                    }
                    // Draw inward, then grow and brighten into a single soft flash.
                    withAnimation(.easeInOut(duration: 0.4)) {
                        glowing = true
                        particlesVisible = true
                        artworkScale = 0.94
                        light = 0.15
                    }
                    try await Task.sleep(for: .milliseconds(400))
                    withAnimation(.easeInOut(duration: 1.2)) {
                        artworkScale = 1.08
                        lift = -14
                        light = 1
                        orbit = 65
                        particlesExpanded = true
                    }
                    try await Task.sleep(for: .milliseconds(1200))
                    // Keep both anticipation pulses on the old dish.
                    for _ in 0..<2 {
                        withAnimation(.easeInOut(duration: 0.4)) { artworkScale = 0.98 }
                        try await Task.sleep(for: .milliseconds(400))
                        withAnimation(.easeInOut(duration: 0.4)) { artworkScale = 1.08 }
                        try await Task.sleep(for: .milliseconds(400))
                    }
                    try Task.checkCancellation()
                    // Swap at peak brightness; reveal the new artwork as the light recedes.
                    withAnimation(.easeInOut(duration: 0.65)) {
                        displayedLevel += 1
                    }
                    onReveal(displayedLevel)
                    ringsVisible = true
                    withAnimation(.easeOut(duration: 0.9)) {
                        ringsExpanded = true
                        orbit = 100
                    }
                    withAnimation(.easeOut(duration: 1)) {
                        artworkScale = 1
                        lift = 0
                    }
                    withAnimation(.easeOut(duration: 1)) {
                        light = 0
                        glowing = false
                        showCaption = true
                    }
                    EvolutionSound.shared.play()
                    try await Task.sleep(for: .milliseconds(450))
                    withAnimation(.easeOut(duration: 0.75)) {
                        ringsVisible = false
                        particlesVisible = false
                    }
                    try await Task.sleep(for: .milliseconds(1550))
                    withAnimation(.easeOut(duration: 0.35)) { showCaption = false }
                    try await Task.sleep(for: .milliseconds(350))
                }
                withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.95)) {
                    centered = false
                    backdrop = false
                }
                try await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 1000))
                // Keep the returning artwork visible until the session's 0.3s fade-in
                // finishes. Removing it first leaves both copies invisible briefly.
                onActivity(false)
                try await Task.sleep(for: .milliseconds(350))
                var handoff = Transaction()
                handoff.disablesAnimations = true
                withTransaction(handoff) { animating = false }
            } catch {
                // A sheet, backgrounding, or leaving the session cancels visuals only.
                animating = false
                centered = false
                backdrop = false
                onActivity(false)
                glowing = false
                particlesVisible = false
                showCaption = false
                artworkScale = 1
                lift = 0
                light = 0
                ringsVisible = false
            }
        }
    }
}
