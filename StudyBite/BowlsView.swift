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
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text(store.collectionLoadFailed ? "— / 21" : "\(store.collectedKinds.count) / 21")
                                .font(.system(size: 17, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        Text("Study. Cook. Discover.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    if store.collectionLoadFailed {
                        Text("Couldn't load your collection. Please reopen the app and try again.")
                            .foregroundStyle(AppTheme.secondaryInk)
                    } else {
                        BowlCollectionView(collectedBowls: store.collectedBowls)
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
            }.modifier(FloatingSheet())
        }
        }
    }
}

private struct BowlCollectionView: View {
    let collectedBowls: [CollectedBowl]

    private var completionCounts: [BowlKind: Int] {
        Dictionary(grouping: collectedBowls, by: \.bowlKind).mapValues { $0.count }
    }

    // Future dishes are catalogue placeholders until their artwork is available.
    private let dishes = [
        "Katsu Ramen", "Teriyaki Bowl", "Tofu Curry", "Miso Ramen",
        "Shoyu Ramen", "Spicy Ramen", "Chicken Curry", "Katsu Curry",
        "Salmon Bowl", "Tuna Bowl", "Veggie Bowl", "Beef Bowl",
        "Tempura Bowl", "Bibimbap", "Kimchi Rice", "Fried Rice",
        "Udon Bowl", "Soba Bowl", "Gyoza Bowl", "Mushroom Bowl", "Unagi Bowl"
    ]

    var body: some View {
        let counts = completionCounts
        VStack(alignment: .leading, spacing: 20) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 18) {
                ForEach(dishes.indices, id: \.self) { index in
                    let kind: BowlKind = index == 1 ? .teriyaki : .katsuRamen
                    let count = index < 2 ? counts[kind, default: 0] : 0
                    let unlocked = count > 0
                    VStack(spacing: 7) {
                        GeometryReader { geometry in
                            let width = max(0, min(116, geometry.size.width - 12))
                            ZStack {
                                if unlocked {
                                    DishArtworkView(level: 5, availableWidth: width + 48, preferredWidth: width, kind: kind)
                                } else {
                                    AppTheme.muted
                                        .frame(width: width, height: width)
                                        .mask {
                                            DishArtworkView(level: 5, availableWidth: width + 48, preferredWidth: width, kind: kind)
                                        }
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .background(unlocked ? AppTheme.surface : AppTheme.surface.opacity(0.5),
                                    in: RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .bottomTrailing) {
                            if count > 1 {
                                Text("×\(count)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(AppTheme.paper)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.ink, in: Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(AppTheme.paper, lineWidth: 1.5)
                                    }
                                    .padding(6)
                            }
                        }

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
                    .accessibilityValue(unlocked ? "Completed \(count) times" : "")
                }
            }
        }

    }
}

#Preview {
    BowlsView()
}
