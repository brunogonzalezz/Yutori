import SwiftUI

struct OnboardingView: View {
    let allowsDismiss: Bool
    let onComplete: () -> Void

    @State private var page = 0
    @State private var name = UserDefaults.standard.string(forKey: "profileName") ?? ""
    @State private var course = StudyCourse(name: "", color: .orange, icon: "book.fill")
    @State private var errorMessage: String?
    @State private var courseStore = CourseStore.shared
    @State private var sessionStore = StudySessionStore.shared
    @State private var starterBowlCollected = StudySessionStore.shared.collectedKinds.contains(.teriyaki)
    @State private var onboardingBowlLevel = 0
    @State private var movesForward = true
    @AppStorage("profileAvatarColor") private var avatarColor = "Jade Teal"
    @FocusState private var focusedField: Field?

    private enum Field { case name, course }
    private let pageCount = 7
    private let icons = CourseIconCatalog.icons

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Capsule()
                            .fill(index <= page ? AppTheme.ink : AppTheme.muted.opacity(0.45))
                            .frame(width: index == page ? 28 : 8, height: 6)
                    }
                }

                Spacer()

                if allowsDismiss {
                    Button(action: onComplete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(AppTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close onboarding")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            ZStack {
                currentPage
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: movesForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: movesForward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.spring(duration: 0.52, bounce: 0.12), value: page)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 12) {
                if page > 0 {
                    Button {
                        focusedField = nil
                        movesForward = false
                        withAnimation(.spring(duration: 0.52, bounce: 0.12)) { page -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 52, height: 52)
                            .background(AppTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }

                if page < pageCount - 1 {
                    Button(action: advance) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.paper)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppTheme.ink, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdvance)
                    .opacity(canAdvance ? 1 : 0.35)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        .interactiveDismissDisabled(!allowsDismiss)
        .onAppear {
            guard courseStore.courses.isEmpty,
                  let firstColor = CourseColor.selectable.first(where: { courseStore.isColorAvailable($0, for: course.id) })
            else { return }
            course.color = firstColor
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch page {
        case 0: welcomePage
        case 1: namePage
        case 2: storyPage
        case 3: coursesExplanationPage
        case 4: coursePage
        case 5: growthPage
        default: collectionExplanationPage
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()
            OnboardingWelcomeAnimation()
                .frame(height: 290)

            VStack(spacing: 10) {
                Text("Welcome to Yutori")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Turn focused study time into bowls you can grow, complete and collect.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 320)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var coursesExplanationPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                onboardingHeader(icon: "books.vertical.fill", color: CourseColor.teal.tint,
                                 title: "First, choose what matters",
                                 text: "Courses organise your study time. Each subject gets its own name, colour and icon, so every session and statistic stays easy to recognise.")

                OnboardingCoursesExplanation()
                    .frame(height: 310)

                Label("You will create your first course next", systemImage: "arrow.right.circle.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var storyPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                onboardingHeader(icon: "sparkles", color: CourseColor.purple.tint,
                                 title: "Make studying feel rewarding",
                                 text: "Staying focused has never been harder. Yutori exists to make studying more fun, turn effort into something visible and give you a reason to return tomorrow.")

                OnboardingAttentionStory()
                    .frame(height: 260)

                VStack(spacing: 12) {
                    storyReason(icon: "bell.slash.fill", color: CourseColor.red.tint,
                                title: "Make room to focus",
                                text: "A study session gives one task your full attention, away from the noise around you.")
                    storyReason(icon: "chart.line.uptrend.xyaxis", color: CourseColor.teal.tint,
                                title: "Turn effort into progress",
                                text: "Every focused minute helps a bowl grow, making study time feel more playful and rewarding.")
                    storyReason(icon: "leaf.fill", color: CourseColor.green.tint,
                                title: "Build a calm habit",
                                text: "Consistency grows one session at a time. You do not need to do everything today.")
                }
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var growthPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                onboardingHeader(icon: "timer", color: CourseColor.orange.tint,
                                 title: "Study and watch it grow",
                                 text: "Your active bowl receives the focused time from each session. Every hour adds one level until it reaches level 5.")

                if let savedCourse = courseStore.courses.first {
                    HStack(spacing: 10) {
                        CourseBadge(course: savedCourse)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(savedCourse.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text("Your first course")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        Spacer()
                        Image(systemName: "arrow.down")
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                OnboardingGrowthAnimation(level: $onboardingBowlLevel)
                    .frame(height: 330)

                HStack(spacing: 8) {
                    Label("1 hour", systemImage: "clock.fill")
                    Image(systemName: "arrow.right")
                    Text("1 new level")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var collectionExplanationPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                onboardingHeader(icon: "square.grid.2x2", color: CourseColor.pink.tint,
                                 title: "Build your collection",
                                 text: "When a bowl reaches level 5, it becomes collected forever. Then you choose another unlocked bowl and begin growing it in your next sessions.")

                OnboardingCollectionJourneyView(isCollected: $starterBowlCollected,
                                                 onCollect: collectStarterBowl,
                                                 onFinished: finishInCollection)
                    .frame(height: 470)

                Text(starterBowlCollected
                     ? "Your Teriyaki Bowl is now part of My bowls."
                     : "Tap Collect when you are ready to add your first bowl.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var namePage: some View {
        ZStack {
            Circle()
                .fill(CourseColor.orange.tint.opacity(0.16))
                .frame(width: 92, height: 92)
                .offset(x: -145, y: -225)
            Circle()
                .fill(CourseColor.pink.tint.opacity(0.15))
                .frame(width: 54, height: 54)
                .offset(x: 156, y: -132)
            Circle()
                .fill(CourseColor.lemon.tint.opacity(0.17))
                .frame(width: 34, height: 34)
                .offset(x: -128, y: 170)
            Circle()
                .fill(CourseColor.purple.tint.opacity(0.13))
                .frame(width: 72, height: 72)
                .offset(x: 154, y: 224)

            VStack(spacing: 26) {
                Spacer()
                Button(action: chooseRandomAvatarColor) {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatarView(size: 112)
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.ink, in: Circle())
                            .overlay { Circle().strokeBorder(AppTheme.paper, lineWidth: 3) }
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: avatarColor)
                .accessibilityLabel("Change avatar colour")
                .accessibilityHint("Chooses another colour")

                VStack(spacing: 8) {
                    Text("What should we call you?")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("This name will appear on your home screen. Tap your avatar to try another colour.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .frame(maxWidth: 320)
                }
                .multilineTextAlignment(.center)

                TextField("Your name", text: $name)
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focusedField, equals: .name)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 330, minHeight: 58)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(focusedField == .name ? AppTheme.ink : AppTheme.ink.opacity(0.10), lineWidth: focusedField == .name ? 2 : 1)
                    }
                    .onChange(of: name) { _, value in
                        if value.count > 40 { name = String(value.prefix(40)) }
                    }
                Spacer()
            }
            .padding(24)
        }
    }

    private func chooseRandomAvatarColor() {
        let current = ProfileAvatarView.updatedColorName(avatarColor)
        let alternatives = ProfileAvatarView.colors.filter { $0.name != current }
        if let next = alternatives.randomElement() {
            withAnimation(.spring(duration: 0.38, bounce: 0.22)) {
                avatarColor = next.name
            }
        }
    }

    private func storyReason(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppTheme.surface.opacity(0.70), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var coursePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                onboardingHeader(icon: "book.closed.fill", color: CourseColor.orange.tint,
                                 title: courseStore.courses.isEmpty ? "Create your first course" : "Your first course is ready",
                                 text: courseStore.courses.isEmpty
                                    ? "A course tells Yutori what you are studying. Every session is saved under it, with its own colour and icon. Create yours now."
                                    : "You already have a course, so you are ready to begin a session.")

                if let existing = courseStore.courses.first {
                    HStack(spacing: 14) {
                        CourseBadge(course: existing)
                        Text(existing.name)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(CourseColor.green.tint)
                    }
                    .padding(16)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    HStack(spacing: 14) {
                        CourseBadge(course: course)
                        TextField("Course name", text: $course.name)
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .course)
                            .onChange(of: course.name) { _, value in
                                if value.count > 60 { course.name = String(value.prefix(60)) }
                            }
                    }
                    .padding(14)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Colour").font(.system(size: 14, weight: .semibold, design: .rounded))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(CourseColor.selectable, id: \.self) { color in
                                Button { course.color = color } label: {
                                    Circle()
                                        .fill(color.tint)
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            if course.color.paletteColor == color.paletteColor {
                                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon").font(.system(size: 14, weight: .semibold, design: .rounded))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(icons, id: \.0) { icon, label in
                                Button { course.icon = icon } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 19, weight: .medium))
                                        .foregroundStyle(course.icon == icon ? .white : AppTheme.ink)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(course.icon == icon ? course.color.tint : AppTheme.surface,
                                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(label)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var canAdvance: Bool {
        if page == 1 { return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if page == 4 && courseStore.courses.isEmpty {
            return !course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func advance() {
        errorMessage = nil
        focusedField = nil
        if page == 1 {
            UserDefaults.standard.set(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)),
                                      forKey: "profileName")
        }
        if page == 4 && courseStore.courses.isEmpty {
            do {
                try courseStore.save(course)
            } catch {
                errorMessage = "Your course could not be created. Please check its name and try again."
                return
            }
        }
        movesForward = true
        withAnimation(.spring(duration: 0.52, bounce: 0.12)) { page += 1 }
    }

    private func collectStarterBowl() -> Bool {
        guard sessionStore.grantStarterTeriyakiBowlIfNeeded() else {
            errorMessage = "Your starter bowl could not be added. Please try again."
            return false
        }
        starterBowlCollected = true
        return true
    }

    private func finishInCollection() {
        sessionStore.clearActiveBowlSelection()
        UserDefaults.standard.removeObject(forKey: "openBowlsAfterOnboarding")
        NotificationCenter.default.post(name: Notification.Name("OpenHomeFromOnboarding"), object: nil)
        onComplete()
    }

    private func onboardingHeader(icon: String, color: Color, title: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(color)
                .frame(height: 46)
            Capsule()
                .fill(color.opacity(0.55))
                .frame(width: 34, height: 3)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 340)
        }
    }

    private func ideaCard(icon: String, color: Color, title: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 138)
        .padding(.horizontal, 8)
        .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func processRow(number: String, color: Color, title: String, text: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(text).font(.system(size: 13, design: .rounded)).foregroundStyle(AppTheme.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var onboardingDivider: some View {
        Rectangle().fill(AppTheme.ink.opacity(0.09)).frame(height: 1).padding(.leading, 70)
    }
}

private struct OnboardingWelcomeAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false
    @State private var orbiting = false

    var body: some View {
        ZStack {
            Circle()
                .fill(CourseColor.orange.tint.opacity(0.16))
                .frame(width: 250, height: 250)
                .scaleEffect(floating ? 1.05 : 0.94)
            Circle()
                .fill(CourseColor.pink.tint.opacity(0.17))
                .frame(width: 76, height: 76)
                .offset(x: orbiting ? 108 : 92, y: orbiting ? -70 : -90)
            Circle()
                .fill(CourseColor.teal.tint.opacity(0.18))
                .frame(width: 56, height: 56)
                .offset(x: orbiting ? -112 : -96, y: orbiting ? 78 : 58)

            ForEach(0..<6, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 13 : 5, weight: .bold))
                    .foregroundStyle([CourseColor.orange.tint, CourseColor.pink.tint, CourseColor.teal.tint][index % 3])
                    .offset(x: cos(Double(index) * .pi / 3) * (orbiting ? 145 : 126),
                            y: sin(Double(index) * .pi / 3) * (orbiting ? 118 : 104))
            }

            DishArtworkView(level: 5, availableWidth: 300, preferredWidth: 250, kind: .teriyaki)
                .offset(y: floating ? -8 : 7)
                .rotationEffect(.degrees(floating ? 1.2 : -1.2))
                .shadow(color: CourseColor.orange.tint.opacity(0.22), radius: 18, y: 12)
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) { floating = true }
            withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true)) { orbiting = true }
        }
    }
}

private struct OnboardingFocusFlow: View {
    @State private var activeStep = 0
    private let steps: [(String, String, Color)] = [
        ("book.fill", "Choose", CourseColor.teal.tint),
        ("timer", "Focus", CourseColor.orange.tint),
        ("leaf.fill", "Grow", CourseColor.green.tint)
    ]

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 9) {
                        Image(systemName: step.0)
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 68, height: 68)
                            .background(step.2, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                            .scaleEffect(activeStep == index ? 1.12 : 0.92)
                            .shadow(color: step.2.opacity(activeStep == index ? 0.34 : 0), radius: 14)
                        Text(step.1)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)

                    if index < steps.count - 1 {
                        Capsule()
                            .fill(index < activeStep ? steps[index + 1].2 : AppTheme.muted.opacity(0.38))
                            .frame(width: 30, height: 4)
                            .animation(.easeInOut(duration: 0.35), value: activeStep)
                    }
                }
            }

            Text(["Pick what matters now", "Give it your attention", "Keep the progress you made"][activeStep])
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .contentTransition(.numericText())
        }
        .padding(20)
        .background(AppTheme.surface.opacity(0.64), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .task {
            while !Task.isCancelled {
                for step in steps.indices {
                    withAnimation(.spring(duration: 0.45, bounce: 0.18)) { activeStep = step }
                    try? await Task.sleep(for: .milliseconds(900))
                    if Task.isCancelled { return }
                }
            }
        }
    }
}

private struct OnboardingCoursesExplanation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected = 0

    private let examples: [(String, String, Color)] = [
        ("function", "Maths", CourseColor.teal.tint),
        ("atom", "Science", CourseColor.green.tint),
        ("book.closed.fill", "History", CourseColor.orange.tint)
    ]

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: -10) {
                ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                    VStack(spacing: 8) {
                        Image(systemName: example.0)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 70, height: 70)
                            .background(example.2, in: Circle())
                        Text(example.1)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .scaleEffect(selected == index ? 1.08 : 0.88)
                    .opacity(selected == index ? 1 : 0.58)
                    .zIndex(selected == index ? 2 : 1)
                }
            }

            Image(systemName: "arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(examples[selected].2)

            HStack(spacing: 12) {
                Image(systemName: examples[selected].0)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(examples[selected].2, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("25 minute session")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Saved to \(examples[selected].1)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer()
                Text("+25m")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(examples[selected].2)
            }
            .padding(15)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(20)
        .background(AppTheme.surface.opacity(0.45), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1750))
                withAnimation(.spring(duration: 0.68, bounce: 0.10)) {
                    selected = (selected + 1) % examples.count
                }
            }
        }
    }
}

private struct OnboardingAttentionStory: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focused = false

    private let distractions: [(String, Color, CGFloat, CGFloat)] = [
        ("message.fill", CourseColor.teal.tint, -118, -74),
        ("play.rectangle.fill", CourseColor.red.tint, 118, -68),
        ("bell.fill", CourseColor.orange.tint, -132, 64),
        ("heart.fill", CourseColor.pink.tint, 126, 70),
        ("ellipsis.bubble.fill", CourseColor.purple.tint, 0, -108)
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(CourseColor.purple.tint.opacity(focused ? 0.08 : 0.16))
                .frame(width: focused ? 178 : 220, height: focused ? 178 : 220)

            ForEach(Array(distractions.enumerated()), id: \.offset) { index, item in
                Image(systemName: item.0)
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(item.1)
                    .frame(width: 48, height: 48)
                    .offset(x: item.2, y: item.3)
                    .scaleEffect(focused ? 0.68 : 1)
                    .opacity(focused ? 0.24 : 0.90)
                    .rotationEffect(.degrees(focused ? Double(index - 2) * 5 : 0))
            }

            VStack(spacing: 9) {
                Image(systemName: focused ? "brain.head.profile.fill" : "brain.head.profile")
                    .font(.system(size: 43, weight: .semibold))
                    .foregroundStyle(focused ? CourseColor.green.tint : AppTheme.secondaryInk)
                Text(focused ? "Space to focus" : "Too much noise")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .contentTransition(.opacity)
            }
            .frame(width: 138, height: 138)
            .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 42, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.10), radius: 18, y: 8)
            .scaleEffect(focused ? 1.05 : 0.94)
        }
        .task {
            guard !reduceMotion else { focused = true; return }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.25)) { focused = true }
                try? await Task.sleep(for: .milliseconds(1700))
                withAnimation(.easeInOut(duration: 1.15)) { focused = false }
                try? await Task.sleep(for: .milliseconds(1400))
            }
        }
    }
}

private struct OnboardingGrowthAnimation: View {
    @Binding var level: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particleBurst = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CourseColor.orange.tint.opacity(0.12))
                    .frame(width: 245, height: 245)
                    .scaleEffect(0.78 + CGFloat(level) * 0.045)

                ForEach(0..<8, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: index.isMultiple(of: 2) ? 14 : 9, weight: .bold))
                        .foregroundStyle([CourseColor.orange.tint, CourseColor.green.tint, CourseColor.lemon.tint][index % 3])
                        .offset(x: cos(Double(index) * .pi / 4) * CGFloat(particleBurst ? 126 : 92),
                                y: sin(Double(index) * .pi / 4) * CGFloat(particleBurst ? 102 : 68))
                        .scaleEffect(particleBurst ? 1.15 : 0.45)
                        .opacity(level == 0 ? 0.10 : (particleBurst ? 0.82 : 0.16))
                }

                DishArtworkView(level: level, availableWidth: 300, preferredWidth: CGFloat(150 + level * 18), kind: .teriyaki)
                    .id(level)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
            .frame(height: 255)

            HStack {
                Text("Level \(level)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text(level == 5 ? "Ready to collect" : "Studying…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(level == 5 ? CourseColor.green.tint : AppTheme.secondaryInk)
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(AppTheme.surface)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(CourseColor.orange.tint)
                            .frame(width: geometry.size.width * CGFloat(level) / 5)
                    }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 8)
        .sensoryFeedback(.success, trigger: level)
        .task {
            level = 0
            try? await Task.sleep(for: .milliseconds(900))
            while !Task.isCancelled {
                if level == 5 {
                    try? await Task.sleep(for: .milliseconds(2100))
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.80)) {
                        level = 0
                    }
                    try? await Task.sleep(for: .milliseconds(1300))
                    continue
                }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.48)) { particleBurst = true }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.82)) { level += 1 }
                try? await Task.sleep(for: .milliseconds(820))
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.62)) { particleBurst = false }
                try? await Task.sleep(for: .milliseconds(980))
            }
        }
    }
}

private struct OnboardingStarterCollectionView: View {
    @Binding var isCollected: Bool
    let onCollect: () -> Void
    @State private var collecting = false
    @State private var sparkle = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("My bowls")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Text(isCollected ? "1 / 21" : "0 / 21")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            ZStack {
                if isCollected {
                    HStack(spacing: 12) {
                        collectionTile(kind: .teriyaki, title: "Collected", complete: true)
                        collectionTile(kind: .katsuRamen, title: "Ready to grow", complete: false)
                    }
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
                } else {
                    ZStack {
                        ForEach(0..<7, id: \.self) { index in
                            Image(systemName: "sparkle")
                                .font(.system(size: index.isMultiple(of: 2) ? 14 : 9, weight: .bold))
                                .foregroundStyle([CourseColor.orange.tint, CourseColor.green.tint,
                                                  CourseColor.pink.tint][index % 3])
                                .offset(x: cos(Double(index) * .pi / 3.5) * (sparkle ? 132 : 108),
                                        y: sin(Double(index) * .pi / 3.5) * (sparkle ? 88 : 70))
                        }
                        DishArtworkView(level: 5, availableWidth: 280, preferredWidth: 218, kind: .teriyaki)
                            .scaleEffect(collecting ? 0.38 : (sparkle ? 1.03 : 0.96))
                            .offset(y: collecting ? 72 : 0)
                            .opacity(collecting ? 0 : 1)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 190)

            if isCollected {
                Label("Teriyaki collected · Katsu is next", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CourseColor.green.tint)
            } else {
                Button {
                    guard !collecting else { return }
                    withAnimation(.spring(duration: 0.65, bounce: 0.12)) { collecting = true }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(560))
                        onCollect()
                        try? await Task.sleep(for: .milliseconds(350))
                        if !isCollected {
                            withAnimation(.spring(duration: 0.35)) { collecting = false }
                        }
                    }
                } label: {
                    Label("Collect your first bowl", systemImage: "sparkles")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.paper)
                        .padding(.horizontal, 20)
                        .frame(height: 42)
                        .background(AppTheme.ink, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(collecting)
            }
        }
        .padding(18)
        .background(AppTheme.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .sensoryFeedback(.success, trigger: isCollected)
        .task {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { sparkle = true }
        }
    }

    private func collectionTile(kind: BowlKind, title: String, complete: Bool) -> some View {
        VStack(spacing: 2) {
            DishArtworkView(level: complete ? 5 : 0, availableWidth: 150,
                            preferredWidth: complete ? 126 : 102, kind: kind)
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity, minHeight: 166)
        .background(kind.evolutionColors[1].opacity(0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct OnboardingGrowthAndCollectionView: View {
    @Binding var level: Int
    @Binding var isCollected: Bool
    let onCollect: () -> Bool
    let onOpenCollection: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particleBurst = false
    @State private var isAdvancing = false
    @State private var isCollecting = false
    @State private var collectionGlow = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((level == 5 ? CourseColor.green.tint : CourseColor.orange.tint).opacity(0.12))
                    .frame(width: 238, height: 238)
                    .scaleEffect(0.78 + CGFloat(level) * 0.044)

                ForEach(0..<10, id: \.self) { index in
                    Image(systemName: index.isMultiple(of: 3) ? "star.fill" : "sparkle")
                        .font(.system(size: index.isMultiple(of: 2) ? 13 : 8, weight: .bold))
                        .foregroundStyle([CourseColor.orange.tint, CourseColor.green.tint,
                                          CourseColor.lemon.tint, CourseColor.pink.tint][index % 4])
                        .offset(x: cos(Double(index) * .pi / 5) * CGFloat(particleBurst ? 132 : 88),
                                y: sin(Double(index) * .pi / 5) * CGFloat(particleBurst ? 100 : 64))
                        .scaleEffect(particleBurst ? 1.15 : 0.42)
                        .opacity(level == 0 ? 0.10 : (particleBurst ? 0.18 : 0.74))
                }

                DishArtworkView(level: level, availableWidth: 300,
                                preferredWidth: CGFloat(148 + level * 18), kind: .teriyaki)
                    .id(level)
                    .scaleEffect(isCollecting ? 0.18 : 1)
                    .offset(x: isCollecting ? 122 : 0, y: isCollecting ? 98 : 0)
                    .opacity(isCollecting ? 0.15 : 1)
                    .transition(.scale(scale: 0.76).combined(with: .opacity))

                if isCollected && !isCollecting {
                    VStack(spacing: 7) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(CourseColor.green.tint, in: Circle())
                        Text("Added to My bowls")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .padding(18)
                    .background(AppTheme.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .scaleEffect(collectionGlow ? 1.04 : 0.96)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 238)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCollected ? "Teriyaki collected" : "Teriyaki Bowl · Level \(level)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(statusText)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer()
                Text("\(level) / 5")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(AppTheme.surface)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(level == 5 ? CourseColor.green.tint : CourseColor.orange.tint)
                            .frame(width: geometry.size.width * CGFloat(level) / 5)
                    }
            }
            .frame(height: 9)

            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    Image(systemName: actionIcon)
                    Text(actionTitle)
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.paper)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(level == 5 ? CourseColor.green.deepTint : AppTheme.ink, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isAdvancing || isCollecting)
            .opacity(isAdvancing || isCollecting ? 0.58 : 1)

            Text(level < 5
                 ? "For this walkthrough, each tap represents one focused hour."
                 : "A level 5 bowl becomes part of your permanent collection.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(AppTheme.surface.opacity(0.45), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .sensoryFeedback(.success, trigger: level)
    }

    private var statusText: String {
        if isCollected { return "Opening your real collection…" }
        if level == 5 { return "Fully grown and ready to collect" }
        return "Each focused hour adds a new level"
    }

    private var actionTitle: String {
        if isCollected { return "See my collection" }
        return level == 5 ? "Collect Teriyaki Bowl" : "Study 1 hour"
    }

    private var actionIcon: String {
        if isCollected { return "square.grid.2x2.fill" }
        return level == 5 ? "sparkles" : "timer"
    }

    private func primaryAction() {
        if isCollected {
            onOpenCollection()
        } else if level == 5 {
            collect()
        } else {
            grow()
        }
    }

    private func grow() {
        guard level < 5, !isAdvancing else { return }
        isAdvancing = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { particleBurst = true }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.62, bounce: 0.24)) { level += 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(360))
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.45)) { particleBurst = false }
            isAdvancing = false
        }
    }

    private func collect() {
        guard !isCollecting else { return }
        isCollecting = true
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(duration: 0.72, bounce: 0.08)) {
            particleBurst = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 160 : 620))
            guard onCollect() else {
                isCollecting = false
                particleBurst = false
                return
            }
            withAnimation(.spring(duration: 0.48, bounce: 0.18)) {
                isCollecting = false
                collectionGlow = true
            }
            try? await Task.sleep(for: .milliseconds(850))
            onOpenCollection()
        }
    }
}

private struct OnboardingCollectionJourneyView: View {
    @Binding var isCollected: Bool
    let onCollect: () -> Bool
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var collecting = false
    @State private var finishing = false
    @Namespace private var bowlFlight

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 10) {
                    HStack {
                        Text("My bowls")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Spacer()
                        Text(landed || isCollected ? "1 / 21" : "0 / 21")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    HStack(spacing: 10) {
                        collectionTile(index: 0, highlighted: landed || isCollected)
                        collectionTile(index: 1, highlighted: false)
                        collectionTile(index: 2, highlighted: false)
                    }
                }
                .padding(14)
                .frame(width: geometry.size.width, height: 200)
                .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.61)

                if !landed && !isCollected {
                    DishArtworkView(level: 5, availableWidth: 250, preferredWidth: 190, kind: .teriyaki)
                        .matchedGeometryEffect(id: "onboardingCollectedBowl", in: bowlFlight)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.16)
                        .shadow(color: CourseColor.orange.tint.opacity(0.20), radius: 16, y: 9)
                }

                if landed || isCollected {
                    VStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(CourseColor.orange.tint)
                            .symbolEffect(.bounce, value: landed)
                        Text("Your first bowl!")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                        Text("Teriyaki Bowl is now collected")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.18)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                }

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if collecting {
                            ProgressView()
                                .tint(AppTheme.paper)
                        } else {
                            Image(systemName: landed || isCollected ? "leaf.fill" : "sparkles")
                        }
                        Text(landed || isCollected ? "Start my journey" : "Collect Teriyaki Bowl")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.paper)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.ink, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(collecting || finishing)
                .opacity(collecting ? 0.65 : (finishing ? 0 : 1))
                .padding(.horizontal, 12)
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.90)
            }
            .scaleEffect(finishing ? 0.975 : 1)
            .opacity(finishing ? 0 : 1)
        }
        .onAppear {
            if isCollected {
                landed = true
            }
        }
        .sensoryFeedback(.success, trigger: landed)
    }

    private func primaryAction() {
        if landed || isCollected {
            guard !finishing else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .easeInOut(duration: 0.42)) {
                finishing = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 160 : 390))
                onFinished()
            }
            return
        }
        guard !collecting else { return }
        collecting = true
        Task { @MainActor in
            withAnimation(reduceMotion ? .easeOut(duration: 0.20) : .timingCurve(0.32, 0.02, 0.16, 1, duration: 0.95)) {
                landed = true
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 220 : 980))
            guard onCollect() else {
                withAnimation { landed = false }
                collecting = false
                return
            }
            collecting = false
        }
    }

    private func collectionTile(index: Int, highlighted: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack {
                if index == 0 && (landed || isCollected) {
                    DishArtworkView(level: 5, availableWidth: 124, preferredWidth: 76, kind: .teriyaki)
                        .matchedGeometryEffect(id: "onboardingCollectedBowl", in: bowlFlight)
                } else {
                    AppTheme.muted.opacity(index == 0 ? 0.38 : 0.50)
                        .frame(width: 80, height: 70)
                        .mask {
                            DishArtworkView(level: 5, availableWidth: 124, preferredWidth: 76,
                                            kind: index == 1 ? .katsuRamen : (index == 2 ? .tofuCurry : .teriyaki))
                        }
                }

                if index > 0 {
                    Image(systemName: "questionmark")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.paper)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.ink.opacity(0.78), in: Circle())
                }
            }
            .frame(height: 82)
            .offset(y: 4)
            .padding(.bottom, 7)

            Text(String(format: "%03d", index + 1))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk.opacity(0.75))
                .monospacedDigit()

            Text(index == 0 ? "Teriyaki Bowl" : "???")
                .font(.system(size: 10, weight: highlighted ? .semibold : .medium, design: .rounded))
                .foregroundStyle(highlighted ? AppTheme.ink : AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 25, alignment: .top)
        }
        .frame(maxWidth: .infinity, minHeight: 122)
        .background(highlighted ? CourseColor.orange.tint.opacity(0.13) : AppTheme.paper.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(highlighted ? CourseColor.orange.tint.opacity(0.50) : AppTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityHidden(index > 0)
    }
}
