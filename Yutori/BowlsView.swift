import SwiftUI

struct BowlsView: View {
    @State private var showSettings = false
    @State private var selectedCollectedBowl: CollectedBowl?
    @State private var store = StudySessionStore.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Button {
                        showSettings = true
                    } label: {
                        ProfileAvatarView(size: 50)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open settings")

                    VStack(alignment: .leading, spacing: 8) {
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

    var body: some View {
        let collectedByKind = Dictionary(grouping: store.collectedBowls, by: \.bowlKind)
        VStack(spacing: 10) {
            ForEach(0..<(BowlCatalog.entries.count / 3), id: \.self) { group in
                let isNextGroup = group * 3 == store.unlockedBowlCount
                let isFirstHiddenGroup = group * 3 == store.unlockedBowlCount + 3
                VStack(spacing: 14) {
                    if isNextGroup, let target = store.nextBowlMilestone {
                        milestone(target: target)
                    }
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(Array(BowlCatalog.entries[(group * 3)..<(group * 3 + 3)])) { entry in
                            let bowls = entry.kind.flatMap { collectedByKind[$0] } ?? []
                            tile(entry, collectedBowl: bowls.first, count: bowls.count,
                                 isUnlocking: isNextGroup)
                        }
                    }
                }
                .padding(isNextGroup ? 14 : 0)
                .background {
                    if isNextGroup {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(colors: [CourseColor.orange.tint.opacity(0.13), AppTheme.surface.opacity(0.45)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(CourseColor.orange.deepTint.opacity(0.28), lineWidth: 1.2)
                            }
                    }
                }
                .padding(.top, isFirstHiddenGroup ? 12 : 0)
            }
        }
    }

    private func milestone(target: Int) -> some View {
        let groupHours = BowlCatalog.hoursPerGroup
        let groupStart = max(0, target - groupHours)
        let secondsIntoGroup = max(0, store.bowlUnlockSeconds - Double(groupStart) * 3600)
        let progress = min(1, secondsIntoGroup / (Double(groupHours) * 3600))
        let studiedHours = min(groupHours, Int(secondsIntoGroup / 3600))
        let remainingHours = max(0, groupHours - studiedHours)
        return VStack(spacing: 11) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.paper)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.darkSurface, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your next bowls")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                        Text("\(remainingHours)h until all three unlock")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
                Spacer(minLength: 8)
                Text("\(studiedHours) / \(groupHours)h")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(CourseColor.orange.deepTint)
            }
            GeometryReader { geometry in
                Capsule()
                    .fill(AppTheme.paper.opacity(0.85))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [CourseColor.orange.tint, CourseColor.red.tint],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * progress)
                    }
            }
            .frame(height: 8)
        }
        .padding(.bottom, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next three bowls unlock progress")
        .accessibilityValue("\(studiedHours) of \(groupHours) hours")
    }

    private func tile(_ entry: BowlCatalogEntry, collectedBowl: CollectedBowl?, count: Int,
                      isUnlocking: Bool) -> some View {
        let unlocked = store.isBowlUnlocked(entry)
        let collected = collectedBowl != nil
        let distant = !collected && entry.id >= store.unlockedBowlCount + 3
        return VStack(spacing: 7) {
            GeometryReader { geometry in
                let width = max(0, min(116, geometry.size.width - 12))
                ZStack {
                    let kind = entry.kind ?? .teriyaki
                    if collected {
                        DishArtworkView(level: 5, availableWidth: width + 48, preferredWidth: width, kind: kind)
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
                                                    preferredWidth: width, kind: kind)
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
            .background(collected ? AppTheme.surface :
                            (isUnlocking ? AppTheme.paper.opacity(0.78) : AppTheme.surface.opacity(0.5)),
                        in: RoundedRectangle(cornerRadius: 16))
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.paper
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
                    .foregroundStyle(AppTheme.paper)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.darkSurface, in: Circle())
                    .overlay {
                        Circle().strokeBorder(AppTheme.paper.opacity(0.72), lineWidth: 1.5)
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
                    .fill(
                        RadialGradient(
                            colors: [
                                colors[4].opacity(0.58),
                                colors[1].opacity(0.22),
                                AppTheme.surface.opacity(0.58)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 142
                        )
                    )
                    .frame(width: 270, height: 270)
                    .shadow(color: colors[0].opacity(0.12), radius: 24)
                Circle()
                    .strokeBorder(colors[0].opacity(0.20), lineWidth: 1.5)
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
                .foregroundStyle(AppTheme.darkSurface)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(AppTheme.ink.opacity(0.10), lineWidth: 1) }
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 8)],
                      alignment: .leading, spacing: 8) {
                ForEach(Array(bowl.bowlKind.ingredients.enumerated()), id: \.element) { index, ingredient in
                    Text(ingredient)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(colors[index % colors.count].opacity(0.24), in: Capsule())
                }
            }
        }
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

private extension BowlKind {
    var bowlDescription: String {
        switch self {
        case .teriyaki:
            return "A colourful Japanese-inspired bowl built around sweet and savoury teriyaki, fresh vegetables and warm rice. Each ingredient represents the focus you brought to the sessions that grew it."
        case .katsuRamen:
            return "A comforting ramen bowl topped with crisp katsu, a soft egg and fresh greens. It grew one focused session at a time until every part of the bowl was complete."
        case .tofuCurry:
            return "A warming Japanese curry filled with tofu and colourful vegetables. Its bright blue bowl and rich golden curry grew fuller with every focused hour."
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
        }
    }
}

#Preview {
    BowlsView()
}
