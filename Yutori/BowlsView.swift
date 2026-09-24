import SwiftUI

struct BowlsView: View {
    @State private var showSettings = false
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
                        BowlCollectionView(store: store)
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
        }
    }
}

private struct BowlCollectionView: View {
    let store: StudySessionStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        let counts = Dictionary(grouping: store.collectedBowls, by: \.bowlKind).mapValues { $0.count }
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
                            tile(entry, count: entry.kind.map { counts[$0, default: 0] } ?? 0)
                        }
                    }
                }
                .padding(isNextGroup ? 12 : 0)
                .background {
                    if isNextGroup {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(LinearGradient(colors: [AppTheme.surface.opacity(0.85), AppTheme.surface.opacity(0.3)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(AppTheme.ink.opacity(0.22), lineWidth: 1)
                            }
                    }
                }
                .padding(.top, isFirstHiddenGroup ? 12 : 0)
            }
        }
    }

    private func milestone(target: Int) -> some View {
        let progress = min(1, max(0, store.bowlUnlockSeconds / (Double(target) * 3600)))
        return VStack(spacing: 8) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.paper)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.darkSurface, in: RoundedRectangle(cornerRadius: 9))
                    Text("Next to unlock")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer(minLength: 8)
                Text("\(Int(store.bowlUnlockSeconds / 3600)) / \(target)h")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.paper.opacity(0.8), in: Capsule())
            }
            GeometryReader { geometry in
                Capsule()
                    .fill(AppTheme.surface)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.ink)
                            .frame(width: geometry.size.width * progress)
                    }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next three bowls unlock progress")
        .accessibilityValue("\(Int(store.bowlUnlockSeconds / 3600)) of \(target) hours")
    }

    private func tile(_ entry: BowlCatalogEntry, count: Int) -> some View {
        let unlocked = store.isBowlUnlocked(entry)
        let collected = count > 0
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
                                DishArtworkView(level: 5, availableWidth: width + 48, preferredWidth: width, kind: kind)
                            }
                    }
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .padding(8)
                            .background(AppTheme.paper, in: Circle())
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .aspectRatio(1, contentMode: .fit)
            .background(collected ? AppTheme.surface : AppTheme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
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
                .foregroundStyle(collected ? AppTheme.ink : AppTheme.secondaryInk)
                .multilineTextAlignment(.center).lineLimit(2)
                .frame(height: 30, alignment: .top)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(distant ? "Mystery bowl" : entry.name), \(collected ? "collected" : (unlocked ? "unlocked" : "locked"))")
        .accessibilityValue(collected ? "Completed \(count) times" : (unlocked && entry.kind == nil ? "Coming soon" : ""))
    }
}

#Preview {
    BowlsView()
}
