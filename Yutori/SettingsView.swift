
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
    @State private var showPaywall = false
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
                        .font(.system(size: 26, weight: .bold, design: .rounded))
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationBackground(AppTheme.paper)
                .presentationDragIndicator(.visible)
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
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
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

            }.modifier(AppSheetStyle())
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

            }.modifier(AppSheetStyle())
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
            Button { showPaywall = true } label: {
                Text("Pro Ad")
                    .font(.system(size: 17, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 164)
                    .background(cardColor, in: RoundedRectangle(cornerRadius: 38))
                    .contentShape(RoundedRectangle(cornerRadius: 38))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Pro paywall")

            Text("Restore Purchase")
                .font(.system(size: 12, design: .rounded))
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

            settingsSection("YUTORI") {
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
                    AboutYutoriView()
                } label: {
                    settingsRow("About Yutori", icon: "figure.walk")
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
                .alert("Reset Yutori?", isPresented: $confirmReset) {
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
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .padding(.top, 12)

            VStack(spacing: 2) {
                Text("Made with love by")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                Link(destination: URL(string: "https://x.com/brunogonzalez__")!) {
                    HStack(spacing: 6) {
                        Text("𝕏")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.paper)
                            .frame(width: 24, height: 24)
                            .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 7))
                            .accessibilityHidden(true)
                        Text("Bruno Gonzalez")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
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
                .font(.system(size: 13, weight: .medium, design: .rounded))
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
                .font(.system(size: 19, design: .rounded))
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 18, design: .rounded))
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
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            if !destructive {
                Image(systemName: selection == nil ? "chevron.right" : "chevron.up.chevron.down")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
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
        components.queryItems = [URLQueryItem(name: "subject", value: "Yutori Feedback")]
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
                .font(.system(size: 18, design: .rounded))
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

private struct AboutYutoriView: View {
    @Environment(\.dismiss) private var dismiss

    private let space = Color(red: 0.10, green: 0.075, blue: 0.16)
    private let panel = AppTheme.surface
    private let cream = Color(red: 1.00, green: 0.97, blue: 0.90)
    private let orange = Color(red: 0.85, green: 0.38, blue: 0.16)
    private let muted = Color(red: 0.78, green: 0.74, blue: 0.72)

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    hero

                    storyCard("01 / THE BEGINNING", icon: "sparkles") {
                        storyText("Hi, I’m Bruno. I’m 20 years old and this year I started studying Computer Engineering in Barcelona.")
                        storyText("I’ve wanted to learn how to build apps for a long time, but for some reason I always kept putting it off. I think I was waiting for the “right moment” to start.")
                        shipatonMoment
                    }

                    storyCard("02 / WHY YUTORI", icon: "takeoutbag.and.cup.and.straw.fill") {
                        storyText("The idea for Yutori came from something very simple: **I know how difficult it can be to stay motivated to study.** I wanted to create something that could make the process feel a bit more enjoyable and give you a small reason to come back every day.")
                        storyText("The idea of growing and collecting Japanese bowls felt fun to me. It turns something as simple as sitting down to study into something you can slowly build over time.")
                    }

                    storyCard("03 / THE NAME", icon: "circle.hexagongrid.fill") {
                        HStack(alignment: .top, spacing: 18) {
                            Text("ゆとり")
                                .font(.system(size: 31, weight: .black, design: .rounded))
                                .foregroundStyle(orange)
                                .frame(minWidth: 82)

                            storyText("I also really liked the meaning behind the name **Yutori (ゆとり)**. In Japanese, it can refer to having *space, room, or breathing room*, especially mentally. That idea felt very fitting for something about learning and taking time to grow.")
                        }
                    }

                    storyCard("04 / WHAT CAME NEXT", icon: "arrow.up.right") {
                        storyText("Building Yutori has honestly been one of the most enjoyable things I’ve done. I’ve learned more during this process than I expected, and somewhere along the way I realised that this is what I want to keep doing.")
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(orange)

                        Text("Yutori started as a project for Shipaton, but for me, it became the first step towards the future I want to build.")
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(cream)
                            .lineSpacing(3)

                        Rectangle()
                            .fill(cream.opacity(0.18))
                            .frame(height: 1)

                        HStack {
                            Text("Thanks for being here.")
                            Spacer()
                            Text("— Bruno")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(cream.opacity(0.84))
                    }
                    .padding(24)
                    .background(AppTheme.darkSurface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(orange.opacity(0.45), lineWidth: 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        orbitMark
                            .frame(width: 94, height: 94)
                            .offset(x: 18, y: -22)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 44)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("About Yutori")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.ink)
                }
                .accessibilityLabel("Back")
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                Circle()
                    .fill(orange)
                    .frame(width: 8, height: 8)

                Text("BUILT FOR SHIPATON '26")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(cream.opacity(0.74))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(panel, in: Capsule())
            .overlay(Capsule().stroke(cream.opacity(0.14), lineWidth: 1))

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: -5) {
                    Text("About")
                        .foregroundStyle(cream)
                    Text("Yutori.")
                        .foregroundStyle(orange)
                }
                .font(.system(size: 51, weight: .black, design: .rounded))
                .minimumScaleFactor(0.76)

                Spacer(minLength: 4)

                ZStack {
                    Circle()
                        .stroke(orange.opacity(0.45), lineWidth: 1)
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(cream.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                        .frame(width: 104, height: 104)
                    Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(cream)
                    Circle()
                        .fill(orange)
                        .frame(width: 9, height: 9)
                        .offset(x: 46, y: -24)
                }
                .frame(width: 105, height: 110)
            }

            Text("A little story behind the app, from the first idea to the future I want to build.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background {
            LinearGradient(
                colors: [space, AppTheme.darkSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                ShipatonStarField(accent: orange, light: cream)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(orange.opacity(0.42), lineWidth: 1)
        }
    }

    private var shipatonMoment: some View {
        HStack(spacing: 12) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(space)
                .frame(width: 40, height: 40)
                .background(orange, in: Circle())

            Text("When Shipaton 2026 came around, I decided to stop waiting and actually build something.")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(cream)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppTheme.darkSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func storyCard<Content: View>(
        _ label: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(orange)

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            content()
        }
        .padding(22)
        .background(panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.09), lineWidth: 1)
        }
    }

    private var orbitMark: some View {
        ZStack {
            Circle().stroke(space.opacity(0.28), lineWidth: 1)
            Circle()
                .fill(space)
                .frame(width: 8, height: 8)
                .offset(x: 33, y: -23)
            Image(systemName: "sparkle")
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(orange.opacity(0.7))
        }
    }

    private func storyText(_ markdown: LocalizedStringKey) -> some View {
        Text(markdown)
            .font(.system(size: 17, design: .rounded))
            .foregroundStyle(AppTheme.ink)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ShipatonStarField: View {
    let accent: Color
    let light: Color

    private let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.04, 2), (0.24, 0.12, 1), (0.84, 0.07, 2), (0.94, 0.18, 1),
        (0.12, 0.29, 1), (0.78, 0.34, 1), (0.91, 0.45, 2), (0.05, 0.54, 2),
        (0.27, 0.63, 1), (0.87, 0.70, 1), (0.13, 0.81, 1), (0.72, 0.88, 2),
        (0.96, 0.95, 1), (0.39, 0.97, 1)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.10), lineWidth: 1)
                    .frame(width: 330, height: 330)
                    .offset(x: proxy.size.width * 0.40, y: -140)

                Circle()
                    .stroke(light.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 9]))
                    .frame(width: 270, height: 270)
                    .offset(x: -proxy.size.width * 0.47, y: proxy.size.height * 0.24)

                ForEach(Array(stars.enumerated()), id: \.offset) { index, star in
                    Circle()
                        .fill(index.isMultiple(of: 4) ? accent.opacity(0.48) : light.opacity(0.28))
                        .frame(width: star.2, height: star.2)
                        .position(x: proxy.size.width * star.0, y: proxy.size.height * star.1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
