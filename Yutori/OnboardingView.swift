import SwiftUI

struct OnboardingView: View {
    let allowsDismiss: Bool
    let onComplete: () -> Void

    @State private var page = 0
    @State private var name = String((UserDefaults.standard.string(forKey: "profileName") ?? "").prefix(20))
    @State private var course = StudyCourse(name: "", color: .orange, icon: "book.fill")
    @State private var errorMessage: String?
    @State private var courseStore = CourseStore.shared
    @State private var sessionStore = StudySessionStore.shared
    @State private var starterBowlCollected = StudySessionStore.shared.collectedKinds.contains(.teriyaki)
    @State private var onboardingBowlLevel = 0
    @State private var movesForward = true
    @State private var courseNameExample = AppLanguage.localized("Maths")
    @State private var completionTransition = false
    @AppStorage("profileAvatarColor") private var avatarColor = "Jade Teal"
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field { case name, course }
    private let pageCount = 8
    private let icons = CourseIconCatalog.icons

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Capsule()
                            .fill(index <= page ? AppTheme.ink : AppTheme.muted.opacity(0.45))
                            .frame(width: index == page ? 28 : 8, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)

                if allowsDismiss {
                    HStack {
                        Spacer()
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
                Text(AppLanguage.localized(errorMessage))
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
                    .allowsHitTesting(page < pageCount - 1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        .overlay {
            if completionTransition {
                AppTheme.paper
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }
        }
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
        case 2: studyProblemPage
        case 3: storyPage
        case 4: coursesExplanationPage
        case 5: coursePage
        case 6: growthPage
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
                Text("Make your study time come to life")
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

    private var studyProblemPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(CourseColor.lemon.deepTint)
                    Text("Showing up is the hard part.")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("According to various studies on university students,")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                }

                OnboardingConsistencyVisual()
                    .frame(maxWidth: .infinity)

                VStack(spacing: 7) {
                    Text("Starting is easy.\nShowing up again tomorrow is harder.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var storyPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(CourseColor.purple.tint)
                    Text("That’s why we made Yutori.")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Studying can feel repetitive. You put in the hours, but the progress can be hard to feel.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 340)
                }

                OnboardingStudyStory()
                    .frame(height: 245)

                VStack(spacing: 14) {
                    Text("We wanted to make the effort itself feel rewarding.")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Something small to look forward to. Something that makes you want to come back tomorrow.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
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
                                 text: "Choose one active bowl. Time from every completed session moves it forward: one focused hour, one new level.")

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
                                 text: "Reach level 5 and the finished bowl joins My bowls. Your next bowl then takes its place, ready to grow from future sessions.")

                OnboardingCollectionJourneyView(isCollected: $starterBowlCollected,
                                                 onCollect: collectStarterBowl,
                                                 onFinished: finishInCollection)
                    .frame(height: 470)

                Text(AppLanguage.localized(starterBowlCollected
                     ? "Your Teriyaki Bowl is now part of My bowls."
                     : "Tap Collect when you are ready to add your first bowl."))
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
                    Text("We’ll use your name to make Yutori feel like your own. Tap the avatar to find a colour you like.")
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
                        if value.count > 20 { name = String(value.prefix(20)) }
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

    private func animateCourseNameExamples() async {
        let examples = ["Maths", "Science", "History", "Languages", "Design"].map(AppLanguage.localized)
        guard !reduceMotion else {
            courseNameExample = examples[0]
            return
        }
        do {
            while !Task.isCancelled && page == 5 && course.name.isEmpty && focusedField != .course {
                for example in examples {
                    try Task.checkCancellation()
                    courseNameExample = ""
                    for letter in example {
                        try Task.checkCancellation()
                        courseNameExample.append(letter)
                        try await Task.sleep(for: .milliseconds(75))
                    }
                    try await Task.sleep(for: .seconds(1.5))
                    while !courseNameExample.isEmpty {
                        try Task.checkCancellation()
                        courseNameExample.removeLast()
                        try await Task.sleep(for: .milliseconds(35))
                    }
                    try await Task.sleep(for: .milliseconds(220))
                }
            }
        } catch {
            courseNameExample = AppLanguage.localized("Maths")
        }
    }

    private func storyReason(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(AppLanguage.localized(title)).font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(AppLanguage.localized(text))
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
                onboardingHeader(icon: "book.closed.fill", color: CourseColor.indigo.tint,
                                 title: courseStore.courses.isEmpty ? "Create your first course" : "Your course is ready",
                                 text: courseStore.courses.isEmpty
                                    ? "Give your first subject a name and a look you can spot at a glance. You can add more courses whenever you need them."
                                    : "Everything is set. Sessions for this subject will stay together in its history and statistics.")

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
                        TextField("Course name", text: $course.name, prompt: Text(courseNameExample))
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .course)
                            .onChange(of: course.name) { _, value in
                                if value.count > 60 { course.name = String(value.prefix(60)) }
                            }
                            .task(id: page == 5 && course.name.isEmpty && focusedField != .course) {
                                await animateCourseNameExamples()
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
                                .accessibilityLabel(Text(AppLanguage.localized(label)))
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
        if page == 5 && courseStore.courses.isEmpty {
            return !course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func advance() {
        guard page < pageCount - 1 else { return }
        errorMessage = nil
        focusedField = nil
        if page == 1 {
            UserDefaults.standard.set(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20)),
                                      forKey: "profileName")
        }
        if page == 5 && courseStore.courses.isEmpty {
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
        CollectionSound.shared.play()
        starterBowlCollected = true
        return true
    }

    private func finishInCollection() {
        withAnimation(.easeInOut(duration: 0.42)) {
            completionTransition = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 560))
            sessionStore.clearActiveBowlSelection()
            if UserDefaults.standard.object(forKey: "appFirstUseTimestamp") == nil {
                UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "appFirstUseTimestamp")
            }
            UserDefaults.standard.removeObject(forKey: "openBowlsAfterOnboarding")
            NotificationCenter.default.post(name: Notification.Name("OpenHomeFromOnboarding"), object: nil)
            onComplete()
        }
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
            Text(AppLanguage.localized(title))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(AppLanguage.localized(text))
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
            Text(AppLanguage.localized(title)).font(.system(size: 15, weight: .bold, design: .rounded))
            Text(AppLanguage.localized(text))
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
                Text(AppLanguage.localized(title)).font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(AppLanguage.localized(text)).font(.system(size: 13, design: .rounded)).foregroundStyle(AppTheme.secondaryInk)
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
                        Text(AppLanguage.localized(step.1))
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

            Text(AppLanguage.localized(["Pick what matters now", "Give it your attention", "Keep the progress you made"][activeStep]))
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
                        Text(AppLanguage.localized(example.1))
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

private struct OnboardingConsistencyVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completedDays = 0
    @State private var breakVisible = false

    private var days: [String] {
        AppLanguage.selected == .spanish
            ? ["L", "M", "X", "J", "V", "S", "D"]
            : ["M", "T", "W", "T", "F", "S", "S"]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("88%")
                    .font(.system(size: 62, weight: .bold, design: .rounded))
                    .foregroundStyle(CourseColor.red.deepTint)
                Text("of university students struggle to study consistently\nfor more than a week.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()
                .frame(height: 38)

            VStack(spacing: 11) {
                HStack(spacing: 0) {
                    ForEach(days.indices, id: \.self) { index in
                        Text(days[index])
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(index <= 3 ? AppTheme.secondaryInk : AppTheme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }

                ZStack {
                    GeometryReader { geometry in
                        Capsule()
                            .fill(AppTheme.muted.opacity(0.22))
                            .frame(width: max(0, geometry.size.width - 42), height: 5)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                        Capsule()
                            .fill(CourseColor.green.tint.opacity(0.72))
                            .frame(width: max(0, geometry.size.width - 42) * CGFloat(completedDays) / 6,
                                   height: 5)
                            .position(x: 21 + max(0, geometry.size.width - 42) * CGFloat(completedDays) / 12,
                                      y: geometry.size.height / 2)
                    }

                    HStack(spacing: 0) {
                        ForEach(days.indices, id: \.self) { index in
                            ZStack {
                                Circle()
                                    .fill(dayColor(at: index))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(AppTheme.ink.opacity(index > 3 ? 0.07 : 0), lineWidth: 1)
                                    }

                                if index < completedDays {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(.white)
                                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                                } else if index == 3 && breakVisible {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(.white)
                                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                                } else {
                                    Circle()
                                        .fill(AppTheme.muted.opacity(0.34))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .scaleEffect((index < completedDays || (index == 3 && breakVisible)) ? 1 : 0.88)
                        }
                    }
                }
                .frame(height: 38)
                .accessibilityHidden(true)

                HStack {
                    Label("A good start", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(CourseColor.green.deepTint)
                    Spacer()
                    Label("Routine breaks", systemImage: "xmark.circle.fill")
                        .foregroundStyle(CourseColor.red.deepTint)
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .background(AppTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: AppTheme.ink.opacity(0.08), radius: 16, y: 8)
        .task {
            if reduceMotion {
                completedDays = 3
                breakVisible = true
            } else {
                do {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 0.42)) {
                            completedDays = 0
                            breakVisible = false
                        }
                        try await Task.sleep(for: .milliseconds(700))

                        for day in 1...3 {
                            withAnimation(.spring(duration: 0.58, bounce: 0.18)) {
                                completedDays = day
                            }
                            try await Task.sleep(for: .milliseconds(650))
                        }

                        withAnimation(.spring(duration: 0.62, bounce: 0.20)) {
                            breakVisible = true
                        }
                        try await Task.sleep(for: .seconds(5))
                    }
                } catch {
                    return
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("88 percent of university students struggle to study consistently for more than a week")
    }

    private func dayColor(at index: Int) -> Color {
        if index < completedDays { return CourseColor.green.tint }
        if index == 3 && breakVisible { return CourseColor.red.tint }
        return AppTheme.paper
    }
}

private struct OnboardingStudyStory: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completedLines = 0
    @State private var writingLine = 0
    @State private var lineProgress: CGFloat = 0
    @State private var pageAlive = false
    @State private var pencilVisible = true
    @State private var cycleOpacity = 0.0

    private let lineWidths: [CGFloat] = [126, 164, 142, 98]
    private let accents: [(String, Color, CGFloat, CGFloat, Double)] = [
        ("sparkle", CourseColor.orange.tint, -126, -70, -12),
        ("leaf.fill", CourseColor.green.tint, 126, -58, 20),
        ("sparkle", CourseColor.pink.tint, -132, 54, 8),
        ("circle.fill", CourseColor.teal.tint, 132, 62, 0),
        ("sparkle", CourseColor.lemon.tint, 92, -96, -8),
        ("circle.fill", CourseColor.red.tint, -92, 98, 0)
    ]

    var body: some View {
        ZStack {
            Ellipse()
                .fill(CourseColor.orange.tint.opacity(pageAlive ? 0.12 : 0.05))
                .frame(width: 286, height: 204)

            ForEach(accents.indices, id: \.self) { index in
                let accent = accents[index]
                Image(systemName: accent.0)
                    .font(.system(size: index.isMultiple(of: 2) ? 22 : 17, weight: .bold))
                    .foregroundStyle(accent.1)
                    .offset(x: accent.2, y: accent.3)
                    .rotationEffect(.degrees(pageAlive ? accent.4 : 0))
                    .scaleEffect(pageAlive ? 1 : 0.15)
                    .opacity(pageAlive ? (index.isMultiple(of: 2) ? 0.82 : 0.62) : 0)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.paper)
                    .shadow(color: AppTheme.ink.opacity(0.12), radius: 18, y: 10)

                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(CourseColor.orange.tint)
                    Text("Enjoy the little wins")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                .frame(width: 182, alignment: .leading)
                .offset(x: 24, y: 20)

                ForEach(lineWidths.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == 3 ? CourseColor.orange.tint.opacity(0.72) : AppTheme.ink.opacity(0.22))
                        .frame(width: lineWidth(at: index), height: 4)
                        .offset(x: 24, y: 58 + CGFloat(index) * 17)
                }

                Label("Come back tomorrow", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(CourseColor.green.deepTint)
                    .frame(width: 182, alignment: .leading)
                    .offset(x: 24, y: 126)
                    .scaleEffect(pageAlive ? 1 : 0.82)
                    .opacity(pageAlive ? 1 : 0)

                Image(systemName: "pencil")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(CourseColor.orange.tint)
                    .rotationEffect(.degrees(-42))
                    .offset(pencilOffset)
                    .opacity(pencilVisible ? 1 : 0)
            }
            .frame(width: 230, height: 168)
            .rotationEffect(.degrees(-2))
        }
        .opacity(cycleOpacity)
        .task {
            if reduceMotion {
                completedLines = lineWidths.count
                writingLine = lineWidths.count - 1
                lineProgress = 1
                pageAlive = true
                pencilVisible = false
                cycleOpacity = 1
                return
            }

            do {
                while !Task.isCancelled {
                    completedLines = 0
                    writingLine = 0
                    lineProgress = 0
                    pageAlive = false
                    pencilVisible = true
                    cycleOpacity = 0
                    withAnimation(.easeInOut(duration: 0.35)) { cycleOpacity = 1 }
                    try await Task.sleep(for: .milliseconds(360))

                    for line in lineWidths.indices {
                        if line == 0 {
                            writingLine = line
                            lineProgress = 0
                        } else {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                writingLine = line
                                lineProgress = 0
                            }
                            try await Task.sleep(for: .milliseconds(240))
                        }
                        withAnimation(.easeInOut(duration: 0.72)) { lineProgress = 1 }
                        try await Task.sleep(for: .milliseconds(760))
                        completedLines = line + 1
                    }

                    withAnimation(.easeOut(duration: 0.24)) { pencilVisible = false }
                    withAnimation(.spring(duration: 0.88, bounce: 0.20)) { pageAlive = true }
                    try await Task.sleep(for: .seconds(4.2))

                    withAnimation(.easeInOut(duration: 0.46)) { cycleOpacity = 0 }
                    try await Task.sleep(for: .milliseconds(500))
                }
            } catch {
                return
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Enjoy the little wins. Come back tomorrow.")
    }

    private func lineWidth(at index: Int) -> CGFloat {
        if index < completedLines { return lineWidths[index] }
        if index == writingLine { return lineWidths[index] * lineProgress }
        return 0
    }

    private var pencilOffset: CGSize {
        let safeLine = min(writingLine, lineWidths.count - 1)
        let drawnWidth = safeLine < completedLines
            ? lineWidths[safeLine]
            : lineWidths[safeLine] * lineProgress
        return CGSize(width: 17 + drawnWidth,
                      height: 34 + CGFloat(safeLine) * 17)
    }
}

private struct OnboardingGrowthAnimation: View {
    @Binding var level: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particlesVisible = false
    @State private var particlesExpanded = false
    @State private var particleOrbit = 0.0
    @State private var particleSeed = 0

    private let artworkWidths: [CGFloat] = [150, 114, 176, 208, 240, 266]

    private var artworkWidth: CGFloat {
        artworkWidths[min(max(level, 0), artworkWidths.count - 1)]
    }

    private var effectDiameter: CGFloat {
        min(292, max(202, artworkWidth + 32))
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CourseColor.orange.tint.opacity(0.12))
                    .frame(width: effectDiameter, height: effectDiameter)
                    .animation(.easeInOut(duration: 0.65), value: effectDiameter)

                ForEach(0..<14, id: \.self) { index in
                    let baseAngle = Double(index) * .pi * 2 / 14 - .pi / 2
                    let angle = baseAngle + particleVariation(index, salt: 3) * 0.22
                    let radiusVariation = CGFloat(particleVariation(index, salt: 7)) * 14
                    let radius = particlesExpanded
                        ? effectDiameter / 2 + 4 + radiusVariation
                        : effectDiameter * 0.27 + radiusVariation * 0.25
                    Image(systemName: "sparkle")
                        .font(.system(size: 9 + CGFloat(particleVariation(index, salt: 11) + 1) * 3.1,
                                      weight: .semibold, design: .rounded))
                        .foregroundStyle(CourseColor.lemon.tint.opacity(index.isMultiple(of: 2) ? 0.94 : 0.72))
                        .rotationEffect(.degrees(-particleOrbit))
                        .offset(x: cos(angle) * radius,
                                y: sin(angle) * radius)
                        .rotationEffect(.degrees(particleOrbit))
                        .scaleEffect(particlesExpanded ? 1 : 0.45)
                        .opacity(particlesVisible && !reduceMotion ? 1 : 0)
                        .animation(.easeOut(duration: 0.95).delay(Double(index) * 0.025),
                                   value: particlesExpanded)
                        .accessibilityHidden(true)
                }

                DishArtworkView(level: level, availableWidth: 300,
                                preferredWidth: artworkWidths[min(level, 5)], kind: .teriyaki)
                    .id(level)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
            .frame(height: 255)

            HStack {
                Text("Level \(level)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text(AppLanguage.localized(level == 5 ? "Ready to collect" : "Studying…"))
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
                    try? await Task.sleep(for: .milliseconds(2800))
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.00)) {
                        level = 0
                    }
                    particlesVisible = false
                    particlesExpanded = false
                    particleOrbit = 0
                    particleSeed += 1
                    try? await Task.sleep(for: .milliseconds(1600))
                    continue
                }
                var resetTransaction = Transaction()
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    particlesExpanded = false
                    particleOrbit = 0
                    particleSeed += 1
                }
                withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) {
                    particlesVisible = true
                }
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 1.05)) {
                    particlesExpanded = true
                    particleOrbit = 48
                }
                try? await Task.sleep(for: .milliseconds(1200))
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) { level += 1 }
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.55)) {
                    particlesVisible = false
                }
                try? await Task.sleep(for: .milliseconds(1650))
            }
        }
    }

    private func particleVariation(_ index: Int, salt: Int) -> Double {
        let value = (index * 47 + particleSeed * 31 + salt * 19) % 101
        return Double(value) / 100 - 0.5
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
                        collectionTile(kind: .chirashi, title: "Ready to grow", complete: false)
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
            Text(AppLanguage.localized(title))
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
                    Text(isCollected
                         ? AppLanguage.localized("Teriyaki collected")
                         : AppLanguage.formatted("Teriyaki Bowl · Level %lld", Int64(level)))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(AppLanguage.localized(statusText))
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
                    Text(AppLanguage.localized(actionTitle))
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

            Text(AppLanguage.localized(level < 5
                 ? "For this walkthrough, each tap represents one focused hour."
                 : "A level 5 bowl becomes part of your permanent collection."))
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
    @State private var launchVisible = false
    @Namespace private var bowlFlight

    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                        Text(AppLanguage.localized(landed || isCollected ? "Start my journey" : "Collect Teriyaki Bowl"))
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
                .scaleEffect(finishing ? 1.06 : 1)
                .opacity(finishing ? 0 : 1)

                if launchVisible {
                    ZStack {
                        Circle()
                            .fill(AppTheme.paper)
                            .frame(width: 120, height: 120)
                            .shadow(color: CourseColor.orange.tint.opacity(finishing ? 0 : 0.20), radius: 30)
                            .scaleEffect(finishing ? 8.2 : 0.22)

                        ForEach(0..<18, id: \.self) { index in
                            let angle = Double(index) * .pi * 2 / 18
                            Image(systemName: index.isMultiple(of: 3) ? "leaf.fill" : "sparkle")
                                .font(.system(size: index.isMultiple(of: 2) ? 15 : 10, weight: .bold))
                                .foregroundStyle([
                                    CourseColor.orange.tint, CourseColor.green.tint,
                                    CourseColor.pink.tint, CourseColor.teal.tint
                                ][index % 4])
                                .offset(x: cos(angle) * (finishing ? geometry.size.width * 0.62 : 28),
                                        y: sin(angle) * (finishing ? geometry.size.height * 0.48 : 22))
                                .rotationEffect(.degrees(finishing ? Double(index) * 28 : 0))
                                .scaleEffect(finishing ? 1.4 : 0.35)
                                .opacity(finishing ? 0 : 1)
                        }

                        Image(systemName: "leaf.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(CourseColor.green.tint)
                            .scaleEffect(finishing ? 1 : 0.45)
                            .opacity(finishing ? 1 : 0)
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.57)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
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
            Task { @MainActor in
                launchVisible = true
                try? await Task.sleep(for: .milliseconds(30))
                withAnimation(reduceMotion ? .easeOut(duration: 0.22) : .timingCurve(0.22, 0.72, 0.18, 1, duration: 0.96)) {
                    finishing = true
                }
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 240 : 1040))
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
                                            kind: index == 1 ? .chirashi : (index == 2 ? .katsuRamen : .teriyaki))
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

            Text(index == 0 ? BowlKind.teriyaki.name : "???")
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
