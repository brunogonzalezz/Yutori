import SwiftUI

struct BowlPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StudySessionStore.shared
    @State private var selection = 0
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private var availableBowls: [BowlCatalogEntry] {
        Array(BowlCatalog.entries.prefix(store.unlockedBowlCount))
    }
    private var selectedBowl: BowlCatalogEntry {
        availableBowls.first { $0.id == selection } ?? availableBowls[0]
    }
    private var selectedBowlIsCollected: Bool {
        selectedBowl.kind.map { store.collectedKinds.contains($0) } ?? false
    }
    var dismissOnSelection = true
    let onSelect: () -> Void

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let previewHeight = min(200, max(100, geometry.size.height * 0.36))
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 22) {
                            VStack(spacing: 4) {
                                TabView(selection: $selection) {
                                    ForEach(availableBowls) { entry in
                                        artwork(entry, width: min(220, previewHeight * 1.2))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .tag(entry.id)
                                    }
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                .frame(height: previewHeight)
                                .overlay {
                                    HStack {
                                        pageArrow(step: -1)
                                        Spacer()
                                        pageArrow(step: 1)
                                    }
                                }
                                Text(selectedBowl.kind == nil ? AppLanguage.localized("Coming soon") : selectedBowl.name)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                ZStack {
                                    if selectedBowl.kind == nil {
                                        Label("This bowl is still being prepared", systemImage: "hourglass")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(AppTheme.secondaryInk)
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 5)
                                            .background(AppTheme.surface.opacity(0.85), in: Capsule())
                                    } else if selectedBowlIsCollected {
                                        Label("Already collected", systemImage: "checkmark.seal.fill")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(CourseColor.green.deepTint)
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 5)
                                            .background(CourseColor.green.tint.opacity(0.18), in: Capsule())
                                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                                    }
                                }
                                .frame(height: 27)
                                .animation(.easeInOut(duration: 0.2), value: selectedBowlIsCollected)
                            }
                            .padding(.horizontal, 20)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(availableBowls) { entry in
                                    bowlTile(entry)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)

                            if store.collectionLoadFailed || store.loadFailed {
                                Text("Couldn't load your bowls. Please reopen the app and try again.")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.secondaryInk)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 92)
                    }
                    .scrollIndicators(.hidden)

                    chooseButton
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                        .shadow(color: AppTheme.ink.opacity(0.18), radius: 12, y: 6)
                }
            }
            .foregroundStyle(AppTheme.ink)
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

    private var chooseButton: some View {
        Button {
            if let kind = selectedBowl.kind, store.selectNextBowl(kind) {
                onSelect()
                if dismissOnSelection { dismiss() }
            }
        } label: {
            Text(AppLanguage.localized(selectedBowl.kind == nil ? "Coming soon" :
                    (selectedBowlIsCollected ? "Grow this bowl again" : "Select bowl")))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.paper)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(selectedBowl.kind != nil ? AppTheme.ink : AppTheme.muted, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(selectedBowl.kind == nil || store.hasActiveBowl
                  || store.collectionLoadFailed || store.loadFailed)
    }

    private func pageArrow(step: Int) -> some View {
        let current = availableBowls.firstIndex { $0.id == selectedBowl.id } ?? 0
        let next = current + step
        let enabled = availableBowls.indices.contains(next)
        return Button {
            guard enabled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                selection = availableBowls[next].id
            }
        } label: {
            Image(systemName: step < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 44, height: 44)
                .background(AppTheme.surface.opacity(0.8), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
        .accessibilityLabel(AppLanguage.localized(step < 0 ? "Previous bowl" : "Next bowl"))
    }

    private func bowlTile(_ entry: BowlCatalogEntry) -> some View {
        let isSelected = entry.id == selectedBowl.id
        let isCollected = entry.kind.map { store.collectedKinds.contains($0) } ?? false
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selection = entry.id
            }
        } label: {
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    artwork(entry, width: max(0, min(78, geometry.size.width - 8)))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .frame(height: 60)
                Text(entry.kind == nil ? AppLanguage.localized("Coming soon") : entry.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 28)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? AppTheme.surface :
                            AppTheme.surface.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? AppTheme.ink : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCollected ? "\(entry.name), \(AppLanguage.localized("collected"))" : entry.name)
        .accessibilityHint(AppLanguage.localized(entry.kind == nil ? "Coming soon" : "Preview this bowl"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func artwork(_ entry: BowlCatalogEntry, width: CGFloat) -> some View {
        if let kind = entry.kind {
            DishArtworkView(level: 0, availableWidth: width + 48, preferredWidth: width, kind: kind)
        } else if let previewImageName = entry.previewImageName {
            AppTheme.muted
                .frame(width: width, height: width)
                .mask {
                    Image(previewImageName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: width, height: width)
                }
                .accessibilityHidden(true)
        } else {
            AppTheme.muted
                .frame(width: width, height: width * 0.72)
                .mask {
                    DishArtworkView(level: 0, availableWidth: width + 48, preferredWidth: width, kind: .teriyaki)
                }
        }
    }
}
