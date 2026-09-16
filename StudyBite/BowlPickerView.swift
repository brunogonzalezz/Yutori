import SwiftUI

struct BowlPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StudySessionStore.shared
    @State private var selection = 0
    private let availableBowls = ["Katsu Ramen", "Teriyaki Bowl", "Tofu Curry"]
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
                                                kind: index == 1 ? .teriyaki : .katsuRamen)
                                    .overlay {
                                        if index > 1 {
                                            Color(.systemGray3)
                                                .mask {
                                                    DishArtworkView(level: 0, availableWidth: geometry.size.width,
                                                                    preferredWidth: min(210, geometry.size.height * 0.70), kind: .katsuRamen)
                                                }
                                        }
                                    }
                                    .saturation(index < 2 ? 1 : 0)
                                    .opacity(index < 2 ? 1 : 0.35)
                                    .accessibilityLabel(index < 2 ? availableBowls[index] : "Upcoming bowl")
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
                                Text(availableBowls[index])
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
                        .foregroundStyle(.secondary)
                }

                Button {
                    if selection < 2, store.selectNextBowl(selection == 1 ? .teriyaki : .katsuRamen) {
                        onSelect()
                        dismiss()
                    }
                } label: {
                    Text(selection < 2 ? "Select bowl" : "Coming soon")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(selection < 2 ? Color.black : Color(.systemGray3), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selection > 1 || store.hasActiveBowl || store.collectionLoadFailed)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Choose a bowl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .tint(.primary)
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
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .opacity(available ? 1 : 0.15)
        }
        .disabled(!available)
        .accessibilityLabel(step < 0 ? "Previous bowl" : "Next bowl")
    }
}
