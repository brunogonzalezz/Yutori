import SwiftUI

struct BowlsView: View {
    @State private var showSettings = false
    @State private var store = StudySessionStore.shared

    var body: some View {
        NavigationStack {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    showSettings = true
                } label: {
                    ProfileAvatarView(size: 50)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")

                HStack(alignment: .center, spacing: 10) {
                    Text("My bowls")
                        .font(.system(size: 28, weight: .bold))
                    if !store.collectedBowls.isEmpty {
                        Text(store.collectedBowls.count.formatted())
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.surface, in: Capsule())
                    }
                }

                if store.collectionLoadFailed {
                    Text("Couldn't load your bowls. Please reopen the app and try again.")
                        .foregroundStyle(AppTheme.secondaryInk)
                } else if store.collectedBowls.isEmpty {
                    Text("Your completed bowls will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 14)],
                              alignment: .leading, spacing: 22) {
                        ForEach(store.collectedBowls) { bowl in
                            VStack(alignment: .leading, spacing: 9) {
                                DishArtworkView(level: 5, availableWidth: 180, preferredWidth: 106, kind: bowl.bowlKind)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 126)
                                    .background(AppTheme.surface.opacity(0.65),
                                                in: RoundedRectangle(cornerRadius: 20))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(AppTheme.ink.opacity(0.035), lineWidth: 1)
                                    }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bowl.bowlKind.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(bowl.collectedAt, format: .dateTime.day().month(.abbreviated).year())
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }
                                .padding(.horizontal, 4)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                NavigationLink {
                    BowlCollectionPage()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 24, weight: .medium))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Collection")
                                .font(.system(size: 21, weight: .semibold, design: .rounded))
                            Text(store.collectionLoadFailed ? "Discover all bowls" :
                                    "\(store.collectedKinds.count) of 20 discovered")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .foregroundStyle(AppTheme.ink)
                    .padding(22)
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 25)
            .padding(.bottom, 100)
        }
        .background(AppTheme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        }
    }
}

private struct BowlCollectionPage: View {
    @State private var store = StudySessionStore.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            BowlCollectionView(collectedKinds: store.collectedKinds,
                               loadFailed: store.collectionLoadFailed)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
        }
        .background(AppTheme.paper)
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct BowlCollectionView: View {
    let collectedKinds: Set<BowlKind>
    let loadFailed: Bool

    // Future dishes are catalogue placeholders until their artwork is available.
    private let dishes = [
        "Katsu Ramen", "Teriyaki Bowl", "Tofu Curry", "Miso Ramen",
        "Shoyu Ramen", "Spicy Ramen", "Chicken Curry", "Katsu Curry",
        "Salmon Bowl", "Tuna Bowl", "Veggie Bowl", "Beef Bowl",
        "Tempura Bowl", "Bibimbap", "Kimchi Rice", "Fried Rice",
        "Udon Bowl", "Soba Bowl", "Gyoza Bowl", "Mushroom Bowl"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collection")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Study. Cook. Discover.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer()
                Text(loadFailed ? "— / 20" : "\(collectedKinds.count) / 20")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 18) {
                ForEach(dishes.indices, id: \.self) { index in
                    let kind: BowlKind = index == 1 ? .teriyaki : .katsuRamen
                    let unlocked = index < 2 && collectedKinds.contains(kind)
                    VStack(spacing: 7) {
                        ZStack {
                            if unlocked {
                                DishArtworkView(level: 5, availableWidth: 130, preferredWidth: 68, kind: kind)
                            } else {
                                AppTheme.muted
                                    .frame(width: 68, height: 68)
                                    .mask {
                                        DishArtworkView(level: 5, availableWidth: 130, preferredWidth: 68, kind: kind)
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 82)
                        .background(unlocked ? AppTheme.paper : AppTheme.ink.opacity(0.025),
                                    in: RoundedRectangle(cornerRadius: 16))

                        Text(String(format: "%03d", index + 1))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.secondaryInk.opacity(0.75))
                        Text(dishes[index])
                            .font(.system(size: 11, weight: unlocked ? .semibold : .medium))
                            .foregroundStyle(unlocked ? AppTheme.ink : AppTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(height: 30, alignment: .top)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(dishes[index]), \(unlocked ? "collected" : "not collected")")
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(AppTheme.ink.opacity(0.05), lineWidth: 1)
        }
    }
}

#Preview {
    BowlsView()
}
