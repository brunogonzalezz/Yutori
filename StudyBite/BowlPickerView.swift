import SwiftUI

struct BowlPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StudySessionStore.shared
    @State private var selection = 0
    private var availableBowls: [BowlCatalogEntry] {
        Array(BowlCatalog.entries.prefix(store.unlockedBowlCount))
    }
    var dismissOnSelection = true
    let onSelect: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TabView(selection: $selection) {
                    ForEach(availableBowls.indices, id: \.self) { index in
                        GeometryReader { geometry in
                            VStack(spacing: 22) {
                                Spacer(minLength: 0)
                                DishArtworkView(level: 0, availableWidth: geometry.size.width,
                                                preferredWidth: min(210, geometry.size.height * 0.70),
                                                kind: availableBowls[index].kind ?? .katsuRamen)
                                    .overlay {
                                        if availableBowls[index].kind == nil {
                                            AppTheme.muted
                                                .mask {
                                                    DishArtworkView(level: 0, availableWidth: geometry.size.width,
                                                                    preferredWidth: min(210, geometry.size.height * 0.70), kind: .katsuRamen)
                                                }
                                        }
                                    }
                                    .saturation(availableBowls[index].kind != nil ? 1 : 0)
                                    .opacity(availableBowls[index].kind != nil ? 1 : 0.35)
                                    .accessibilityLabel(availableBowls[index].kind != nil ? availableBowls[index].name : "Upcoming bowl")
                                    .frame(maxWidth: .infinity)
                                    .overlay {
                                        HStack {
                                            pageArrow("chevron.left", step: -1)
                                            Spacer()
                                            pageArrow("chevron.right", step: 1)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 16)
                                    }
                                Text(availableBowls[index].name)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if store.collectionLoadFailed {
                    Text("Couldn't load your bowls. Please reopen the app and try again.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Button {
                    if let kind = availableBowls[selection].kind, store.selectNextBowl(kind) {
                        onSelect()
                        if dismissOnSelection { dismiss() }
                    }
                } label: {
                    Text(availableBowls[selection].kind != nil ? "Select bowl" : "Coming soon")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(availableBowls[selection].kind != nil ? AppTheme.ink : AppTheme.muted, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(availableBowls[selection].kind == nil || store.hasActiveBowl || store.collectionLoadFailed)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
            .background(AppTheme.paper)
            .navigationTitle("Choose a bowl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .tint(AppTheme.ink)
                }
            }
        }
    }

    private func pageArrow(_ symbol: String, step: Int) -> some View {
        let next = selection + step
        let available = availableBowls.indices.contains(next)
        return Button {
            guard available else { return }
            withAnimation(.easeInOut(duration: 0.25)) { selection = next }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .opacity(available ? 1 : 0.15)
        }
        .disabled(!available)
        .accessibilityLabel(step < 0 ? "Previous bowl" : "Next bowl")
    }
}
