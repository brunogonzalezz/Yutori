import SwiftUI

struct BowlsView: View {
    @State private var showSettings = false
    @State private var selectedCollectedBowl: CollectedBowl?
    @State private var store = StudySessionStore.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    Button {
                        showSettings = true
                    } label: {
                        ProfileAvatarView(size: 50)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open settings")

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("My bowls")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text(store.collectionLoadFailed ? "— / 21" : "\(store.collectedKinds.count) / 21")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        Text("\(store.unlockedBowlCount) unlocked · \(store.collectedKinds.count) collected")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    if store.collectionLoadFailed {
                        Text("Couldn't load your collection. Please reopen the app and try again.")
                            .foregroundStyle(AppTheme.secondaryInk)
                    } else {
                        BowlCollectionView(store: store) { bowl in
                            selectedCollectedBowl = bowl
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 25)
                .padding(.bottom, 100)
            }
            .background(AppTheme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
            Group { SettingsView()
            }.presentationBackground(AppTheme.paper)
            }
            .fullScreenCover(item: $selectedCollectedBowl) { bowl in
                CollectedBowlDetailView(bowl: bowl, sessions: store.sessions)
            }
        }
    }
}

private struct BowlCollectionView: View {
    let store: StudySessionStore
    let onOpenCollectedBowl: (CollectedBowl) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    @State private var isUnlockingNextBowl = false

    var body: some View {
        let collectedByKind = Dictionary(grouping: store.collectedBowls, by: \.bowlKind)
        let unlockedEntries = Array(BowlCatalog.entries.prefix(store.unlockedBowlCount))
        let nextEntry = BowlCatalog.entries.indices.contains(store.unlockedBowlCount)
            ? BowlCatalog.entries[store.unlockedBowlCount] : nil
        let futureStart = min(store.unlockedBowlCount + (nextEntry == nil ? 0 : 1), BowlCatalog.entries.count)
        let futureEntries = Array(BowlCatalog.entries.dropFirst(futureStart))

        return VStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(unlockedEntries) { entry in
                    let bowls = entry.kind.flatMap { collectedByKind[$0] } ?? []
                    tile(entry, collectedBowl: bowls.first, count: bowls.count, isUnlocking: false)
                        .transition(.scale(scale: 0.72).combined(with: .opacity))
                }
            }

            if let nextEntry, let target = store.nextBowlMilestone {
                milestone(target: target, entry: nextEntry)
            }

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(futureEntries) { entry in
                    let bowls = entry.kind.flatMap { collectedByKind[$0] } ?? []
                    tile(entry, collectedBowl: bowls.first, count: bowls.count, isUnlocking: false)
                }
            }
        }
        .padding(.top, 2)
        .animation(.spring(duration: 0.62, bounce: 0.18), value: store.unlockedBowlCount)
    }

    private func milestone(target: Int, entry: BowlCatalogEntry) -> some View {
        let requiredHours = BowlCatalog.hoursPerBowl
        let milestoneStart = max(0, target - requiredHours)
        let secondsIntoMilestone = max(0, store.bowlUnlockSeconds - Double(milestoneStart) * 3600)
        let progress = min(1, secondsIntoMilestone / (Double(requiredHours) * 3600))
        let percentage = min(100, max(0, Int((progress * 100).rounded(.down))))
        let remainingSeconds = max(0, Double(requiredHours) * 3600 - secondsIntoMilestone)
        let ready = store.canUnlockNextBowl
        return ZStack(alignment: .topLeading) {
            HStack(alignment: .center, spacing: 10) {
                milestoneInformation(percentage: percentage,
                                     remainingText: unlockTimeRemaining(remainingSeconds),
                                     progress: progress)
                    .padding(.top, 35)
                milestoneBowl(entry, ready: ready)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 9) {
                Image(systemName: ready ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.paper)
                    .frame(width: 31, height: 31)
                    .background(AppTheme.darkSurface, in: Circle())

                Text("YOUR NEXT BOWL")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.05)
                    .foregroundStyle(AppTheme.darkSurface)
            }
        }
        .padding(14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.78))
                LockMosaic()
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(AppTheme.ink.opacity(0.10), lineWidth: 1)
            }
        }
        .overlay {
            if ready {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(isUnlockingNextBowl ? 0.42 : 0.72)

                    if !isUnlockingNextBowl {
                        Button {
                            unlock()
                        } label: {
                            Label("Unlock", systemImage: "lock.open.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.paper)
                                .padding(.horizontal, 22)
                                .frame(height: 44)
                                .background(AppTheme.ink.opacity(0.96), in: Capsule())
                                .overlay { Capsule().strokeBorder(AppTheme.paper.opacity(0.72), lineWidth: 1) }
                                .shadow(color: AppTheme.ink.opacity(0.22), radius: 9, y: 4)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.86).combined(with: .opacity))
                    }
                }
            }
        }
        .accessibilityElement(children: store.canUnlockNextBowl ? .contain : .ignore)
        .accessibilityLabel("Next bowl unlock progress")
        .accessibilityValue("\(percentage) percent, \(unlockTimeRemaining(remainingSeconds))")
    }

    private func milestoneBowl(_ entry: BowlCatalogEntry, ready: Bool) -> some View {
        VStack(spacing: 2) {
            milestoneArtwork(entry, ready: ready)
                .scaleEffect(isUnlockingNextBowl ? 1.12 : 1)
                .offset(y: isUnlockingNextBowl ? -8 : 0)
                .opacity(isUnlockingNextBowl ? 0.15 : 1)
            Text(entry.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 138, height: 30, alignment: .top)
        }
    }

    private func milestoneInformation(percentage: Int, remainingText: String,
                                      progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(percentage)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .monospacedDigit()
                Text("progress")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.paper.opacity(0.92))
                        .overlay {
                            Capsule()
                                .strokeBorder(CourseColor.teal.tint.opacity(0.18), lineWidth: 1)
                        }

                    GoldenStripedProgress()
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 13)

            Label(remainingText, systemImage: "clock.fill")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func unlockTimeRemaining(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(ceil(seconds / 60)))
        guard totalMinutes > 0 else { return "Ready to unlock" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m remaining" : "\(hours)h remaining"
        }
        return "\(minutes)m remaining"
    }

    private func milestoneArtwork(_ entry: BowlCatalogEntry, ready: Bool) -> some View {
        let kind = entry.kind ?? .teriyaki
        return ZStack {
            AppTheme.muted
                .frame(width: 132, height: 116)
                .mask {
                    if let previewImageName = entry.previewImageName {
                        Image(previewImageName)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 130, height: 114)
                    } else {
                        DishArtworkView(level: 5, availableWidth: 176,
                                        preferredWidth: 126, kind: kind)
                    }
                }

            Image(systemName: ready ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.paper)
                .frame(width: 34, height: 34)
                .background(AppTheme.darkSurface.opacity(0.94), in: Circle())
                .overlay {
                    Circle().strokeBorder(AppTheme.paper.opacity(0.58), lineWidth: 1)
                }
        }
        .frame(width: 136, height: 116)
        .accessibilityHidden(true)
    }

    private func unlock() {
        guard store.canUnlockNextBowl, !isUnlockingNextBowl else { return }
        withAnimation(.spring(duration: 0.42, bounce: 0.28)) {
            isUnlockingNextBowl = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(430))
            withAnimation(.spring(duration: 0.62, bounce: 0.18)) {
                _ = store.unlockNextBowl()
                isUnlockingNextBowl = false
            }
        }
    }

    private func tile(_ entry: BowlCatalogEntry, collectedBowl: CollectedBowl?, count: Int,
                      isUnlocking: Bool) -> some View {
        let unlocked = store.isBowlUnlocked(entry)
        let collected = collectedBowl != nil
        let distant = !collected && entry.id > store.unlockedBowlCount
        return VStack(spacing: 7) {
            GeometryReader { geometry in
                let width = max(0, min(120, geometry.size.width - 4))
                let knownBowlWidth = width * 0.94
                ZStack {
                    let kind = entry.kind ?? .teriyaki
                    if collected {
                        DishArtworkView(level: 5, availableWidth: width + 48,
                                        preferredWidth: knownBowlWidth, kind: kind)
                    } else {
                        AppTheme.muted
                            .frame(width: width, height: width)
                            .mask {
                                if let previewImageName = entry.previewImageName {
                                    Image(previewImageName)
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: width, height: width)
                                } else {
                                    DishArtworkView(level: 5, availableWidth: width + 48,
                                                    preferredWidth: knownBowlWidth, kind: kind)
                                }
                            }
                    }
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(isUnlocking ? AppTheme.paper : AppTheme.ink)
                            .padding(8)
                            .background(isUnlocking ? AppTheme.darkSurface : AppTheme.paper, in: Circle())
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .aspectRatio(1, contentMode: .fit)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isUnlocking ? AppTheme.paper.opacity(0.78) : AppTheme.surface.opacity(collected ? 1 : 0.5))
                    .overlay {
                        if collected, let kind = entry.kind {
                            LinearGradient(colors: [bowlColor(kind).opacity(0.52),
                                                    bowlColor(kind).opacity(0.25),
                                                    bowlColor(kind).opacity(0.07)],
                                           startPoint: .top,
                                           endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
            }
            .overlay {
                if isUnlocking {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(CourseColor.orange.tint.opacity(0.28), lineWidth: 1)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if count > 1 {
                    Text("×\(count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.paper)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.ink, in: Capsule())
                        .overlay { Capsule().strokeBorder(AppTheme.paper, lineWidth: 1.5) }
                        .padding(6)
                }
            }
            Text(String(format: "%03d", entry.id + 1))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk.opacity(0.75))
            Text(distant ? "???" : entry.name)
                .font(.system(size: 11, weight: collected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(collected || isUnlocking ? AppTheme.ink : AppTheme.secondaryInk)
                .multilineTextAlignment(.center).lineLimit(2)
                .frame(height: 30, alignment: .top)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(distant ? "Mystery bowl" : entry.name), \(collected ? "collected" : (unlocked ? "unlocked" : "locked"))")
        .accessibilityValue(collected ? "Completed \(count) times" : (unlocked && entry.kind == nil ? "Coming soon" : ""))
        .accessibilityAddTraits(collected ? .isButton : [])
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            if let collectedBowl { onOpenCollectedBowl(collectedBowl) }
        }
    }

    private func bowlColor(_ kind: BowlKind) -> Color {
        switch kind {
        case .teriyaki: CourseColor.red.tint
        case .katsuRamen: CourseColor.lemon.tint
        case .tofuCurry: CourseColor.sky.tint
        case .chirashi: CourseColor.blue.tint
        }
    }
}

private struct GoldenStripedProgress: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(CourseColor.lemon.tint))
            var stripes = Path()
            for startX in stride(from: -size.height, through: size.width + size.height, by: 9) {
                stripes.move(to: CGPoint(x: startX, y: size.height))
                stripes.addLine(to: CGPoint(x: startX + size.height, y: 0))
            }
            context.stroke(stripes,
                           with: .color(AppTheme.paper.opacity(0.42)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .butt))
        }
        .clipShape(Capsule())
    }
}

private struct LockMosaic: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30,
                                paused: reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let spacing: CGFloat = 34
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let offset = CGFloat(time * 3.2).truncatingRemainder(dividingBy: spacing)
                context.opacity = 0.055
                var lock = context.resolve(Image(systemName: "lock.fill").renderingMode(.template))
                lock.shading = .color(AppTheme.ink)

                for row in -2...Int(size.height / spacing + 2) {
                    for column in -2...Int(size.width / spacing + 2) {
                        context.draw(lock, in: CGRect(x: CGFloat(column) * spacing + offset,
                                                     y: CGFloat(row) * spacing + offset,
                                                     width: 13, height: 15))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CollectedBowlDetailView: View {
    let bowl: CollectedBowl
    let sessions: [StudySession]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: StudySession?

    private var bowlSessions: [StudySession] {
        guard let ids = bowl.sourceSessionIDs else { return [] }
        let idSet = Set(ids)
        return sessions.filter { idSet.contains($0.id) }.sorted { $0.endedAt < $1.endedAt }
    }

    private var colors: [Color] { bowl.bowlKind.evolutionColors }
    private var containerColor: Color {
        switch bowl.bowlKind {
        case .teriyaki: CourseColor.red.tint
        case .katsuRamen: CourseColor.lemon.tint
        case .tofuCurry: CourseColor.sky.tint
        case .chirashi: CourseColor.blue.tint
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [containerColor.opacity(0.31),
                                    containerColor.opacity(0.12),
                                    AppTheme.paper],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    hero
                    story
                    ingredients
                    journey
                }
                .padding(.horizontal, 24)
                .padding(.top, 52)
                .padding(.bottom, 42)
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.surface, in: Circle())
                    .overlay {
                        Circle().strokeBorder(AppTheme.ink.opacity(0.08), lineWidth: 1)
                    }
                    .contentShape(Circle())
                    .shadow(color: AppTheme.ink.opacity(0.14), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close bowl details")
                .padding(.top, 10)
                .padding(.trailing, 20)
                .zIndex(10)
        }
        .sheet(item: $selectedSession) { session in
            Group {
                SessionSummaryView(course: session.course, measuredDuration: session.duration,
                                   startingSeconds: session.startingDishSeconds ?? 0,
                                   bowlKind: session.bowlKind ?? .teriyaki,
                                   pauseCount: session.pauseCount ?? 0,
                                   endedAt: session.endedAt, onDiscard: {}, onSave: { _ in },
                                   savedSession: session)
            }
            .presentationBackground(AppTheme.paper)
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(containerColor.opacity(0.14))
                    .frame(width: 270, height: 270)
                    .shadow(color: containerColor.opacity(0.13), radius: 24)
                Circle()
                    .strokeBorder(containerColor.opacity(0.22), lineWidth: 1.5)
                    .frame(width: 230, height: 230)
                DishArtworkView(level: 5, availableWidth: 340, preferredWidth: 268, kind: bowl.bowlKind)
                    .shadow(color: AppTheme.ink.opacity(0.12), radius: 18, y: 12)
            }
            .frame(height: 278)

            Text(bowl.bowlKind.name)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Label("Collected \(bowl.collectedAt.formatted(date: .abbreviated, time: .omitted))",
                  systemImage: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CourseColor.green.deepTint)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(CourseColor.green.tint.opacity(0.18), in: Capsule())
                .overlay { Capsule().strokeBorder(CourseColor.green.tint.opacity(0.28), lineWidth: 1) }
        }
        .padding(.top, 8)
    }

    private var story: some View {
        detailSection(title: "About this bowl", icon: "text.book.closed.fill", accent: colors[0]) {
            Text(bowl.bowlKind.bowlDescription)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ingredients: some View {
        detailSection(title: "Ingredients", icon: "carrot.fill", accent: colors[1]) {
            IngredientFlowLayout(spacing: 8) {
                ForEach(bowl.bowlKind.ingredients, id: \.self) { ingredient in
                    let color = ingredientColor(ingredient)
                    Text(ingredient)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(color.deepTint)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(color.tint.opacity(0.34), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(color.tint.opacity(0.18), lineWidth: 1)
                        }
                }
            }
        }
    }

    private func ingredientColor(_ ingredient: String) -> CourseColor {
        let name = ingredient.lowercased()
        if name.contains("avocado") || name.contains("edamame") || name.contains("broccoli")
            || name.contains("cucumber") || name.contains("greens")
            || name.contains("onion") { return .green }
        if name.contains("salmon") || name.contains("prawn") || name.contains("ikura")
            || name.contains("cabbage") { return .pink }
        if name.contains("tuna") { return .red }
        if name.contains("egg") || name.contains("tamago") || name.contains("sweetcorn") { return .lemon }
        if name.contains("mushroom") { return .moss }
        if name.contains("rice") || name.contains("tofu") || name.contains("ramen") { return .sand }
        if name.contains("curry") || name.contains("carrot") || name.contains("katsu")
            || name.contains("teriyaki") || name.contains("broth") { return .orange }
        return .teal
    }

    private var journey: some View {
        detailSection(title: "Study journey", icon: "clock.arrow.circlepath", accent: colors[3],
                      trailing: bowlSessions.isEmpty ? nil : sessionCountText) {
            if bowl.isStarterGift == true {
                emptyJourney(icon: "gift.fill", title: "Your starter bowl",
                             text: "This Teriyaki Bowl joined your collection when you began your Yutori journey.")
            } else if bowl.sourceSessionIDs == nil {
                emptyJourney(icon: "archivebox.fill", title: "Earlier collection",
                             text: "Detailed session history was not recorded when this bowl was collected.")
            } else if bowlSessions.isEmpty {
                emptyJourney(icon: "clock.fill", title: "No sessions available",
                             text: "The sessions connected to this bowl are no longer in your history.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bowlSessions.enumerated()), id: \.element.id) { index, session in
                        if index > 0 { Divider().opacity(0.55) }
                        Button {
                            selectedSession = session
                        } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open session summary")
                    }
                }
            }
        }
    }

    private var sessionCountText: String {
        "\(bowlSessions.count) \(bowlSessions.count == 1 ? "session" : "sessions")"
    }

    private func sessionRow(_ session: StudySession) -> some View {
        HStack(spacing: 12) {
            CourseBadge(course: session.course)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.course.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                if !session.blockDescription.isEmpty {
                    Text(session.blockDescription)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                }
                Text(session.endedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk.opacity(0.82))
            }
            Spacer(minLength: 8)
            Text(formatted(session.dishDuration))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.darkSurface)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.secondaryInk.opacity(0.72))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func emptyJourney(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(AppTheme.secondaryInk)
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func detailSection<Content: View>(title: String, icon: String, accent: Color,
                                               trailing: String? = nil,
                                               @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .symbolRenderingMode(.hierarchical)
                    .tint(accent)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.surface.opacity(0.68))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AppTheme.ink.opacity(0.09), lineWidth: 1)
                }
        }
    }

    private func formatted(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }
}

private struct IngredientFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                     cache: inout ()) -> CGSize {
        let maximumWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maximumWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: proposal.width ?? max(0, x - spacing), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension BowlKind {
    var bowlDescription: String {
        switch self {
        case .teriyaki:
            return "A colourful Japanese-inspired bowl built around sweet and savoury teriyaki, fresh vegetables and warm rice. Each ingredient represents the focus you brought to the sessions that grew it."
        case .katsuRamen:
            return "A comforting ramen bowl topped with crisp katsu, a soft egg and fresh greens. It grew one focused session at a time until every part of the bowl was complete."
        case .tofuCurry:
            return "A warming Japanese curry filled with tofu and colourful vegetables. Its bright blue bowl and rich golden curry grew fuller with every focused hour."
        case .chirashi:
            return "A vibrant chirashi bowl layered with salmon, tuna, prawns, egg and fresh vegetables over rice. Every focused session adds another colourful part to the finished bowl."
        }
    }

    var ingredients: [String] {
        switch self {
        case .teriyaki:
            return ["Teriyaki", "Rice", "Edamame", "Avocado", "Sweetcorn", "Pickled cabbage", "Spring onion"]
        case .katsuRamen:
            return ["Chicken katsu", "Ramen", "Egg", "Broth", "Greens", "Spring onion"]
        case .tofuCurry:
            return ["Tofu", "Japanese curry", "Broccoli", "Carrot", "Mushrooms", "Green onion"]
        case .chirashi:
            return ["Salmon", "Tuna", "Prawns", "Tamago", "Avocado", "Cucumber", "Ikura", "Rice"]
        }
    }
}

#Preview {
    BowlsView()
}
