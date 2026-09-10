
import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var profileName = "Bruno Gonzalez"
    @State private var draftName = ""
    @FocusState private var isEditingName: Bool
    @AppStorage("profileAvatarColor") private var avatarColor = "Teal"
    @AppStorage("profilePhoto") private var photoData = Data()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showColors = false
    @State private var photoError = false
    @State private var nameFrame: CGRect = .zero

    private let colors = ProfileAvatarView.colors

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Menu {
                        Button("Choose photo", systemImage: "photo") {
                            isEditingName = false
                            showPhotoPicker = true
                        }
                        Button("Choose avatar color", systemImage: "paintpalette") {
                            isEditingName = false
                            showColors = true
                        }
                        if !photoData.isEmpty {
                            Button("Remove photo", systemImage: "person.crop.circle") {
                                photoData = Data()
                            }
                        }
                    } label: {
                        ProfileAvatarView(size: 132)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit profile picture")
                    .simultaneousGesture(TapGesture().onEnded {
                        isEditingName = false
                    })

                    TextField("Your name", text: $draftName)
                        .textFieldStyle(.plain)
                        .tint(.black)
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($isEditingName)
                        .accessibilityLabel("Your name")
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(key: NameFrameKey.self, value: geometry.frame(in: .named("settings")))
                            }
                        }
                        .onSubmit {
                            saveName()
                            isEditingName = false
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 28)
            }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            saveName()
                            isEditingName = false
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close settings")
                    }
                }
        }
        .coordinateSpace(name: "settings")
        .contentShape(Rectangle())
        .onPreferenceChange(NameFrameKey.self) { nameFrame = $0 }
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .named("settings"))
                .onEnded { tap in
                    if isEditingName && !nameFrame.contains(tap.location) {
                        saveName()
                        isEditingName = false
                    }
                }
        )
        .onAppear {
            avatarColor = ProfileAvatarView.updatedColorName(avatarColor)
            draftName = String(profileName.prefix(40))
            saveName()
        }
        .onChange(of: draftName) { _, name in
            if name.count > 40 {
                draftName = String(name.prefix(40))
            }
        }
        .onChange(of: isEditingName) { _, editing in
            if !editing { saveName() }
        }
        .onDisappear { saveName() }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    photoError = true
                    return
                }
                guard !Task.isCancelled else { return }
                // Store a compact square thumbnail rather than the full original photo.
                let size = CGSize(width: 512, height: 512)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    let scale = max(size.width / image.size.width, size.height / image.size.height)
                    let width = image.size.width * scale
                    let height = image.size.height * scale
                    image.draw(in: CGRect(x: (512 - width) / 2, y: (512 - height) / 2, width: width, height: height))
                }
                if let savedData = thumbnail.jpegData(compressionQuality: 0.85) {
                    photoData = savedData
                } else {
                    photoError = true
                }
            } catch {
                if !Task.isCancelled { photoError = true }
            }
        }
        .sheet(isPresented: $showColors) {
            NavigationStack {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 24) {
                    ForEach(colors, id: \.name) { option in
                        Button {
                            avatarColor = option.name
                            photoData = Data()
                            showColors = false
                        } label: {
                            VStack(spacing: 8) {
                                SettingsAvatar()
                                    .foregroundStyle(option.color)
                                    .frame(width: 84, height: 84)
                                    .background(option.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 32))
                                    .overlay(alignment: .topTrailing) {
                                        if avatarColor == option.name && photoData.isEmpty {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(option.color)
                                        }
                                    }
                                Text(option.name).font(.subheadline).foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .navigationTitle("Avatar color")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .alert("Couldn't load photo", isPresented: $photoError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try selecting another photo.")
        }
    }

    private func saveName() {
        let name = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        if !name.isEmpty { profileName = name }
        draftName = profileName
    }
}

struct SettingsAvatar: Shape {
    func path(in rect: CGRect) -> Path {
        // Proportions from the reference, relative to the rounded background.
        var path = Path()
        path.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.383,
            y: rect.minY + rect.height * 0.274,
            width: rect.width * 0.234,
            height: rect.height * 0.234
        ))
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        path.move(to: point(0.5, 0.56))
        path.addCurve(to: point(0.30, 0.645), control1: point(0.43, 0.56), control2: point(0.35, 0.61))
        path.addCurve(to: point(0.28, 0.735), control1: point(0.27, 0.67), control2: point(0.265, 0.71))
        path.addCurve(to: point(0.5, 0.814), control1: point(0.30, 0.785), control2: point(0.43, 0.814))
        path.addCurve(to: point(0.72, 0.735), control1: point(0.57, 0.814), control2: point(0.70, 0.785))
        path.addCurve(to: point(0.70, 0.645), control1: point(0.735, 0.71), control2: point(0.73, 0.67))
        path.addCurve(to: point(0.5, 0.56), control1: point(0.65, 0.61), control2: point(0.57, 0.56))
        path.closeSubpath()
        return path
    }
}

#Preview {
    SettingsView()
}

private struct NameFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
