
import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("profileName") private var profileName = "Bruno Gonzalez"
    @State private var draftName = ""
    @FocusState private var isEditingName: Bool
    @AppStorage("profileAvatarColor") private var avatarColor = "Teal"
    @AppStorage("profilePhoto") private var photoData = Data()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showColors = false
    @State private var showAppIcons = false
    @State private var photoError = false
    @State private var feedbackError = false
    @State private var nameFrame: CGRect = .zero
    @State private var selectedLanguage = "English"
    @State private var confirmReset = false
    @State private var isResetting = false

    private let colors = ProfileAvatarView.colors

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
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
                        .tint(AppTheme.ink)
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
                    settingsContent
                        .padding(.horizontal, 12)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
            }
                .background(AppTheme.paper)
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
                guard !Task.isCancelled, !isResetting else { return }
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
            Group {
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
                                    .background(option.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 32))
                                    .overlay(alignment: .topTrailing) {
                                        if ProfileAvatarView.updatedColorName(avatarColor) == option.name && photoData.isEmpty {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(option.color)
                                        }
                                    }
                                Text(option.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.ink)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(height: 32)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(AppTheme.paper.ignoresSafeArea())
                .navigationTitle("Avatar color")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])

            }.modifier(FloatingSheet())
        }
        .sheet(isPresented: $showAppIcons) {
            Group {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 24) {
                        ForEach(0..<9) { index in
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(AppTheme.muted)
                                .frame(width: 84, height: 84)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(AppTheme.ink.opacity(0.05), lineWidth: 1)
                                }
                                .accessibilityLabel("App icon placeholder \(index + 1)")
                        }
                    }
                    .padding(24)
                }
                .background(AppTheme.paper.ignoresSafeArea())
                .navigationTitle("App Icon")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)

            }.modifier(FloatingSheet())
        }
        .alert("Couldn't open email", isPresented: $feedbackError) {
            Button("Copy email address") {
                UIPasteboard.general.string = "brunoogonzalezcano@gmail.com"
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please configure an email app or email brunoogonzalezcano@gmail.com directly.")
        }
        .alert("Couldn't load photo", isPresented: $photoError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try selecting another photo.")
        }
    }

    private let cardColor = AppTheme.surface

    private var settingsContent: some View {
        VStack(spacing: 0) {
            Text("Pro Ad")
                .font(.system(size: 17))
                .frame(maxWidth: .infinity)
                .frame(height: 164)
                .background(cardColor, in: RoundedRectangle(cornerRadius: 38))

            Text("Restore Purchase")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryInk)
                .padding(.top, 10)
                .padding(.bottom, 28)

            CoursesSettingsSection()
                .padding(.bottom, 24)

            settingsSection("CUSTOMIZE") {
                Menu {
                    Picker("Language", selection: $selectedLanguage) {
                        Label {
                            Text("English")
                        } icon: {
                            Image(uiImage: Self.englishFlag)
                                .renderingMode(.original)
                        }.tag("English")
                        Label {
                            Text("Español")
                        } icon: {
                            Image(uiImage: Self.spanishFlag)
                                .renderingMode(.original)
                        }.tag("Español")
                        Label {
                            Text("Català")
                        } icon: {
                            Image(uiImage: Self.circularCatalanFlag)
                                .renderingMode(.original)
                        }
                        .tag("Català")
                    }
                } label: {
                    settingsRow("Language", icon: "character.bubble", selection: selectedLanguage, flag: selectedLanguageFlag)
                        .transaction { $0.animation = nil }
                }
                .buttonStyle(.plain)
                settingsDivider
                Button {
                    isEditingName = false
                    showAppIcons = true
                } label: {
                    settingsRow("App Icon", icon: "app.dashed")
                }
                .buttonStyle(.plain)
            }

            settingsSection("ONBOARDING") {
                settingsRow("Show Onboarding", icon: "rectangle.on.rectangle")
            }

            settingsSection("STUDYBITE") {
                settingsRow("Write a Review", icon: "star.fill")
                settingsDivider
                Button {
                    isEditingName = false
                    sendFeedback()
                } label: {
                    settingsRow("Send Feedback", icon: "envelope.fill")
                }
                .buttonStyle(.plain)
                settingsDivider
                NavigationLink {
                    AboutStudyBiteView()
                } label: {
                    settingsRow("About StudyBite", icon: "figure.walk")
                }
                .buttonStyle(.plain)
            }

            settingsSection("LEGAL") {
                settingsRow("Terms of Use", icon: "list.clipboard.fill")
                settingsDivider
                settingsRow("Privacy Policy", icon: "lock.shield.fill")
            }

            Button {
                isEditingName = false
                confirmReset = true
            } label: {
                settingsRow("Delete account", icon: "trash", destructive: true)
                    .contentShape(Rectangle())
            }
                .buttonStyle(.plain)
                .background(cardColor, in: RoundedRectangle(cornerRadius: 22))
                .padding(.top, 8)
                .alert("Reset StudyBite?", isPresented: $confirmReset) {
                    Button("Delete everything", role: .destructive) {
                        isResetting = true
                        selectedPhoto = nil
                        isEditingName = false
                        AppReset.shared.reset()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This deletes all local sessions, courses, collected bowls, progress, profile and settings. You'll start from zero. This cannot be undone.")
                }

            ResetStudySessionsButton()
                .background(cardColor, in: RoundedRectangle(cornerRadius: 22))
                .padding(.top, 12)

            StudyTestDateSettings()
                .padding(16)
                .background(cardColor, in: RoundedRectangle(cornerRadius: 22))
                .padding(.top, 12)

            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryInk)
                .padding(.top, 12)

            VStack(spacing: 2) {
                Text("Made with love by")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryInk)
                Link(destination: URL(string: "https://x.com/brunogonzalez__")!) {
                    HStack(spacing: 6) {
                        Text("Bruno Gonzalez")
                            .font(.system(size: 19, weight: .semibold))
                        Text("𝕏")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 24, height: 24)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(AppTheme.ink)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Bruno Gonzalez's profile on X")
            }
            .padding(.top, 34)
        }
        .foregroundStyle(AppTheme.ink)
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryInk)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0, content: content)
                .background(cardColor, in: RoundedRectangle(cornerRadius: 22))
        }
        .padding(.bottom, 20)
    }

    // Visual placeholders until these settings have their own screens.
    private func settingsRow(_ title: String, icon: String, destructive: Bool = false, selection: String? = nil, flag: UIImage? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 18))
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                if let flag {
                    Image(uiImage: flag)
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                }
                if let selection {
                    Text(selection)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            if !destructive {
                Image(systemName: selection == nil ? "chevron.right" : "chevron.up.chevron.down")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(destructive ? Color.red : AppTheme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, minHeight: 53)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(AppTheme.ink.opacity(0.055))
            .frame(height: 0.5)
    }

    private static func circularFlag(_ image: UIImage) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 26, height: 26)).image { _ in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 26, height: 26)).addClip()
            guard image.size.height > 0 else { return }
            let width = 26 * image.size.width / image.size.height
            image.draw(in: CGRect(x: (26 - width) / 2, y: 0, width: width, height: 26))
        }
    }

    private var selectedLanguageFlag: UIImage {
        switch selectedLanguage {
        case "Español": return Self.spanishFlag
        case "Català": return Self.circularCatalanFlag
        default: return Self.englishFlag
        }
    }

    // Reuse the same images when scrolling updates the name field's geometry.
    private static let englishFlag = circularFlag(UIImage(named: "Flag-gb") ?? UIImage())
    private static let spanishFlag = circularFlag(UIImage(named: "Flag-es") ?? UIImage())
    private static let circularCatalanFlag = circularFlag(catalanFlag)

    // Render the Senyera with the same image treatment as the other flags.
    private static let catalanFlag: UIImage = UIGraphicsImageRenderer(
        size: CGSize(width: 27, height: 18)
    ).image { context in
        UIColor.systemYellow.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 27, height: 18))
        UIColor.systemRed.setFill()
        for stripe in 0..<4 {
            context.fill(CGRect(x: 0, y: 2 + stripe * 4, width: 27, height: 2))
        }
    }

    private func sendFeedback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "brunoogonzalezcano@gmail.com"
        components.queryItems = [URLQueryItem(name: "subject", value: "StudyBite Feedback")]
        guard let url = components.url else {
            feedbackError = true
            return
        }
        openURL(url) { accepted in
            if !accepted { feedbackError = true }
        }
    }

    private func saveName() {
        guard !isResetting else { return }
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

private struct StudyTestDateSettings: View {
    @Bindable private var clock = StudyTestClock.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Test date (temporary)", isOn: $clock.enabled)
            if clock.enabled {
                DatePicker("App date", selection: $clock.selectedDay, displayedComponents: .date)
                Text("Used for weekly stats and new sessions. The timer runs normally.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }
}

private struct ResetStudySessionsButton: View {
    @State private var showConfirmation = false

    var body: some View {
        Button(role: .destructive) {
            showConfirmation = true
        } label: {
            Label("Delete all study sessions", systemImage: "trash")
                .font(.system(size: 18))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert("Delete all study sessions?", isPresented: $showConfirmation) {
            Button("Delete all sessions", role: .destructive) {
                StudySessionStore.shared.deleteAllSessions()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone. Your dish will return to level 0. Your courses and profile will be kept.")
        }
    }
}

private struct NameFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct AboutStudyBiteView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppTheme.paper
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(AppTheme.ink)
                    }
                    .accessibilityLabel("Back")
                }
            }
    }
}
