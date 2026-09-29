
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
    @State private var showOnboarding = false
    @State private var purchaseManager = PurchaseManager.shared
    @State private var isRestoringPurchases = false
    @State private var restorePurchasesMessage: String?
    @State private var showColors = false
    @State private var showAppIcons = false
    @State private var photoError = false
    @State private var feedbackError = false
    @State private var showReviewNotice = false
    @State private var nameFrame: CGRect = .zero
    @State private var selectedLanguage = "English"
    @State private var confirmReset = false
    @State private var isResetting = false
    @State private var showDeleteChallenge = false
    @State private var deletionBowl: BowlKind = .teriyaki
    @State private var proBowlIsFloating = false

    private let colors = ProfileAvatarView.colors

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
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

                    VStack(spacing: 0) {
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
                            .accessibilityHint("Tap to edit your name")
                            .overlay(alignment: .bottom) {
                                Capsule()
                                    .fill(AppTheme.secondaryInk.opacity(isEditingName ? 0.72 : 0.42))
                                    .frame(width: min(230, max(56, CGFloat(max(1, draftName.count)) * 13)), height: 1.5)
                                    .offset(y: 1)
                            }
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
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationBackground(AppTheme.paper)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showDeleteChallenge) {
            AccountDeletionChallengeView(kind: deletionBowl) {
                showDeleteChallenge = false
            } onDestroyed: {
                isResetting = true
                selectedPhoto = nil
                isEditingName = false
                AppReset.shared.reset()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(allowsDismiss: true) {
                showOnboarding = false
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
            profileName = String(profileName.prefix(20))
            draftName = profileName
            saveName()
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                proBowlIsFloating = true
            }
        }
        .onChange(of: draftName) { _, name in
            if name.count > 20 {
                draftName = String(name.prefix(20))
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
            AppIconPickerView()
                .presentationDetents([.fraction(0.67)])
                .presentationDragIndicator(.visible)
                .modifier(AppSheetStyle())
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
        .alert("Reviews are coming soon", isPresented: $showReviewNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This option will work as soon as Yutori is available on the App Store.")
        }
        .alert(
            "Restore Purchases",
            isPresented: Binding(
                get: { restorePurchasesMessage != nil },
                set: { if !$0 { restorePurchasesMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { restorePurchasesMessage = nil }
        } message: {
            Text(restorePurchasesMessage ?? "")
        }
    }

    private let cardColor = AppTheme.surface

    private var settingsContent: some View {
        VStack(spacing: 0) {
            Button { showPaywall = true } label: {
                ZStack(alignment: .leading) {
                    LinearGradient(colors: [AppTheme.surface,
                                            CourseColor.pink.tint.opacity(0.14),
                                            CourseColor.orange.tint.opacity(0.12)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)

                    Circle()
                        .fill(Color(red: 215 / 255, green: 127 / 255, blue: 154 / 255).opacity(0.15))
                        .frame(width: 124, height: 124)
                        .offset(x: 248, y: -52)

                    Circle()
                        .fill(Color(red: 113 / 255, green: 138 / 255, blue: 82 / 255).opacity(0.13))
                        .frame(width: 76, height: 76)
                        .offset(x: 302, y: 62)

                    Circle()
                        .fill(Color(red: 197 / 255, green: 160 / 255, blue: 68 / 255).opacity(0.14))
                        .frame(width: 54, height: 54)
                        .offset(x: 164, y: 70)

                    Circle()
                        .fill(Color(red: 217 / 255, green: 132 / 255, blue: 75 / 255).opacity(0.12))
                        .frame(width: 40, height: 40)
                        .offset(x: 118, y: -58)

                    Circle()
                        .fill(CourseColor.teal.tint.opacity(0.10))
                        .frame(width: 30, height: 30)
                        .offset(x: 208, y: 10)

                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .bold))

                                Text("YUTORI PRO")
                            }
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(1.1)
                                .foregroundStyle(Color(red: 173 / 255, green: 82 / 255, blue: 117 / 255))

                            Text("Upgrade to Pro")
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            Text("Create unlimited courses")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.secondaryInk)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(colors: [CourseColor.lemon.tint.opacity(0.28),
                                                            CourseColor.orange.tint.opacity(0.13),
                                                            .clear],
                                                   center: .center,
                                                   startRadius: 12,
                                                   endRadius: 76)
                                )
                                .frame(width: 152, height: 152)

                            Circle()
                                .stroke(CourseColor.pink.tint.opacity(0.18), lineWidth: 1.5)
                                .frame(width: 126, height: 126)

                            Image("TeriyakiLevel5")
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 112, height: 112)
                                .offset(y: proBowlIsFloating ? -4 : 7)
                                .rotationEffect(.degrees(proBowlIsFloating ? 1.0 : -1.0))
                                .shadow(color: CourseColor.orange.tint.opacity(0.22), radius: 12, y: 7)
                        }
                        .frame(width: 132, height: 152)
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 14)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 164)
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .strokeBorder(AppTheme.ink.opacity(0.10), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Upgrade to Yutori Pro")

            Button {
                restorePurchases()
            } label: {
                if isRestoringPurchases {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Restore Purchases")
                        .font(.system(size: 12, design: .rounded))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.secondaryInk)
            .disabled(isRestoringPurchases || purchaseManager.isBusy)
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
                Button {
                    isEditingName = false
                    showOnboarding = true
                } label: {
                    settingsRow("Show Onboarding", icon: "rectangle.on.rectangle")
                }
                .buttonStyle(.plain)
            }

            settingsSection("YUTORI") {
                Button {
                    isEditingName = false
                    showReviewNotice = true
                } label: {
                    settingsRow("Write a Review", icon: "star.fill")
                }
                .buttonStyle(.plain)
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
                    Shipaton2026View()
                } label: {
                    settingsRow("Shipaton 2026", icon: "sparkles")
                }
                .buttonStyle(.plain)
            }

            settingsSection("LEGAL") {
                NavigationLink {
                    LegalDocumentView(document: .terms)
                } label: {
                    settingsRow("Terms of Use", icon: "list.clipboard.fill")
                }
                .buttonStyle(.plain)
                settingsDivider
                NavigationLink {
                    LegalDocumentView(document: .privacy)
                } label: {
                    settingsRow("Privacy Policy", icon: "lock.shield.fill")
                }
                .buttonStyle(.plain)
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
                    Button("Continue", role: .destructive) {
                        let collectedBowls = StudySessionStore.shared.collectedBowls.map(\.bowlKind)
                        if let collectedBowl = collectedBowls.randomElement() {
                            deletionBowl = collectedBowl
                            showDeleteChallenge = true
                        } else {
                            isResetting = true
                            selectedPhoto = nil
                            isEditingName = false
                            AppReset.shared.reset()
                        }
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

#if DEBUG
            Button {
                purchaseManager.setDebugPro(!purchaseManager.isPro)
            } label: {
                settingsRow(
                    "Yutori Pro testing",
                    icon: "hammer.fill",
                    selection: purchaseManager.isPro ? "Premium" : "Free"
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(cardColor, in: RoundedRectangle(cornerRadius: 22))
            .padding(.top, 12)
#endif

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

    private func restorePurchases() {
        guard !isRestoringPurchases, !purchaseManager.isBusy else { return }
        isRestoringPurchases = true
        Task {
            defer { isRestoringPurchases = false }
            do {
                let restored = try await purchaseManager.restorePurchases()
                restorePurchasesMessage = restored
                    ? "Yutori Pro has been restored."
                    : "No active Yutori Pro purchase was found."
            } catch {
                restorePurchasesMessage = error.localizedDescription
            }
        }
    }

    private var selectedLanguageFlag: UIImage {
        switch selectedLanguage {
        case "Español": return Self.spanishFlag
        default: return Self.englishFlag
        }
    }

    // Reuse the same images when scrolling updates the name field's geometry.
    private static let englishFlag = circularFlag(UIImage(named: "Flag-gb") ?? UIImage())
    private static let spanishFlag = circularFlag(UIImage(named: "Flag-es") ?? UIImage())

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
        let name = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
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

private struct LegalDocumentView: View {
    enum Document {
        case terms
        case privacy

        var title: String {
            switch self { case .terms: "Terms of Use"; case .privacy: "Privacy Policy" }
        }
        var icon: String {
            switch self { case .terms: "list.clipboard.fill"; case .privacy: "lock.shield.fill" }
        }
        var introduction: String {
            switch self {
            case .terms: "These terms explain the simple rules for using Yutori."
            case .privacy: "Yutori is designed to keep your study information private and under your control."
            }
        }
        var sections: [(String, String)] {
            switch self {
            case .terms:
                [
                    ("Using Yutori", "Yutori is a study companion for personal use. You are responsible for how you use the app and for the study information you add."),
                    ("Yutori Pro", "Optional Pro subscriptions are handled by RevenueCat and the store used for the purchase. Prices, renewal periods and cancellation options are shown before you confirm a purchase. You can restore eligible purchases from Settings."),
                    ("Availability", "Yutori is provided as available. Features may change as the app improves, and uninterrupted availability cannot be guaranteed."),
                    ("Your data", "You can edit or delete your local courses and sessions in the app. Deleting your account removes Yutori data stored locally on that device."),
                    ("Contact", "Questions about these terms can be sent to brunoogonzalezcano@gmail.com.")
                ]
            case .privacy:
                [
                    ("Data stored on your device", "Your profile, courses, study sessions, bowl progress and preferences are stored locally on your device. Yutori does not require an account or ask you to sign in."),
                    ("Purchases", "RevenueCat processes subscription status and anonymous purchase information needed to unlock Yutori Pro. Yutori does not receive or store your payment card details."),
                    ("Photos", "If you choose a profile photo, Yutori only accesses the image you select and stores a smaller copy locally for your avatar."),
                    ("Sharing", "Yutori does not sell your personal information. Study data is not sent to an advertising service."),
                    ("Your choices", "You can remove sessions individually, clear study history or delete all local Yutori data from Settings."),
                    ("Contact", "Privacy questions can be sent to brunoogonzalezcano@gmail.com.")
                ]
            }
        }
    }

    let document: Document

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: document.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(CourseColor.teal.tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text(document.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(document.introduction)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(section.0)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(section.1)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(AppTheme.secondaryInk)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text("Last updated: September 25, 2026")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AccountDeletionChallengeView: View {
    let kind: BowlKind
    let onCancel: () -> Void
    let onDestroyed: () -> Void

    private let requiredHits = 10
    @State private var hitCount = 0
    @State private var bowlScale: CGFloat = 1
    @State private var bowlRotation = 0.0
    @State private var fragmentsVisible = false
    @State private var fragmentsExpanded = false

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel account deletion")
                    Spacer()
                }

                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    Text("Break the bowl to continue")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("Tap the bowl until it breaks. Your Yutori data will then be deleted permanently.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 310)
                }

                Spacer(minLength: 0)

                Button(action: strikeBowl) {
                    ZStack {
                        if fragmentsVisible {
                            DeletionBowlFragments(kind: kind, expanded: fragmentsExpanded)
                        }

                        DishArtworkView(level: 5, availableWidth: 320, preferredWidth: 258, kind: kind)
                            .scaleEffect(bowlScale)
                            .rotationEffect(.degrees(bowlRotation))
                            .overlay {
                                DeletionCracks(progress: Double(hitCount) / Double(requiredHits))
                                    .stroke(AppTheme.ink.opacity(0.88),
                                            style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                                    .frame(width: 202, height: 148)
                                    .opacity(hitCount == 0 ? 0 : 1)
                            }
                            .opacity(fragmentsVisible ? 0 : 1)

                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 290)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(fragmentsVisible)
                .accessibilityLabel("Break (kind.name)")
                .accessibilityValue("\(hitCount) of \(requiredHits) hits")

                Text(hitCount == 0 ? "Tap to begin" : "\(requiredHits - hitCount) taps remaining")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .monospacedDigit()

                Spacer()
            }
            .padding(24)
        }
        .foregroundStyle(AppTheme.ink)
        .interactiveDismissDisabled()
        .sensoryFeedback(.impact(weight: .heavy), trigger: hitCount)
        .onAppear {
            BowlBreakSound.shared.prepare()
        }
    }

    private func strikeBowl() {
        guard hitCount < requiredHits else { return }
        BowlBreakSound.shared.play()
        hitCount += 1

        if hitCount == requiredHits {
            fragmentsVisible = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(55))
                BowlBreakSound.shared.playCompletion()
                withAnimation(.timingCurve(0.20, 0.72, 0.24, 1, duration: 0.78)) {
                    fragmentsExpanded = true
                }
                try? await Task.sleep(for: .milliseconds(820))
                onDestroyed()
            }
        } else {
            let direction = hitCount.isMultiple(of: 2) ? -1.0 : 1.0
            withAnimation(.spring(duration: 0.18, bounce: 0.65)) {
                bowlScale = max(0.90, 0.97 - CGFloat(hitCount) * 0.006)
                bowlRotation = direction * (3.2 + Double(hitCount) * 0.34)
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(130))
                withAnimation(.spring(duration: 0.22, bounce: 0.45)) {
                    bowlScale = 1
                    bowlRotation = 0
                }
            }
        }
    }
}

private struct DeletionBowlFragments: View {
    let kind: BowlKind
    let expanded: Bool

    private let offsets: [CGSize] = [
        CGSize(width: -118, height: -92), CGSize(width: -18, height: -132),
        CGSize(width: 116, height: -78), CGSize(width: -105, height: 108),
        CGSize(width: 12, height: 142), CGSize(width: 122, height: 96)
    ]
    private let rotations = [-24.0, -8.0, 27.0, -19.0, 11.0, 25.0]

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                DishArtworkView(level: 5, availableWidth: 320, preferredWidth: 258, kind: kind)
                    .frame(width: 280, height: 240)
                    .mask {
                        DeletionBowlShard(index: index)
                            .fill(.black)
                    }
                    .offset(expanded ? offsets[index] : .zero)
                    .rotationEffect(.degrees(expanded ? rotations[index] : 0))
                    .scaleEffect(expanded ? 0.90 : 1)
                    .opacity(expanded ? 0 : 1)
            }
        }
        .frame(width: 280, height: 240)
        .accessibilityHidden(true)
    }
}

private struct DeletionBowlShard: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let points: [[CGPoint]] = [
            [.init(x: 0, y: 0), .init(x: 0.36, y: 0), .init(x: 0.31, y: 0.51), .init(x: 0, y: 0.47)],
            [.init(x: 0.36, y: 0), .init(x: 0.69, y: 0), .init(x: 0.73, y: 0.48), .init(x: 0.31, y: 0.51)],
            [.init(x: 0.69, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 0.53), .init(x: 0.73, y: 0.48)],
            [.init(x: 0, y: 0.47), .init(x: 0.31, y: 0.51), .init(x: 0.36, y: 1), .init(x: 0, y: 1)],
            [.init(x: 0.31, y: 0.51), .init(x: 0.73, y: 0.48), .init(x: 0.68, y: 1), .init(x: 0.36, y: 1)],
            [.init(x: 0.73, y: 0.48), .init(x: 1, y: 0.53), .init(x: 1, y: 1), .init(x: 0.68, y: 1)]
        ]
        let polygon = points[index]
        var path = Path()
        path.move(to: CGPoint(x: polygon[0].x * rect.width, y: polygon[0].y * rect.height))
        for point in polygon.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * rect.width, y: point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

private struct DeletionCracks: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if progress > 0.15 {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + 10))
            path.addLine(to: CGPoint(x: rect.midX - 13, y: rect.midY - 12))
            path.addLine(to: CGPoint(x: rect.midX + 5, y: rect.midY + 5))
            path.addLine(to: CGPoint(x: rect.midX - 10, y: rect.maxY - 12))
        }
        if progress > 0.45 {
            path.move(to: CGPoint(x: rect.midX - 13, y: rect.midY - 12))
            path.addLine(to: CGPoint(x: rect.minX + 24, y: rect.midY - 28))
            path.move(to: CGPoint(x: rect.midX + 5, y: rect.midY + 5))
            path.addLine(to: CGPoint(x: rect.maxX - 24, y: rect.midY - 5))
        }
        if progress > 0.72 {
            path.move(to: CGPoint(x: rect.midX - 10, y: rect.maxY - 12))
            path.addLine(to: CGPoint(x: rect.minX + 34, y: rect.maxY - 28))
            path.move(to: CGPoint(x: rect.midX + 5, y: rect.midY + 5))
            path.addLine(to: CGPoint(x: rect.midX + 32, y: rect.maxY - 20))
        }
        return path
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
            Text("This cannot be undone. Bowl progress, collected bowls and unlock progress earned from these sessions will be removed. Your courses and profile will be kept.")
        }
    }
}

private struct NameFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct Shipaton2026View: View {
    @Environment(\.dismiss) private var dismiss

    private let night = Color(red: 0.29, green: 0.20, blue: 0.39)
    private let dusk = Color(red: 0.48, green: 0.34, blue: 0.55)
    private let lavenderMist = Color(red: 0.73, green: 0.63, blue: 0.72)
    private let cream = Color(red: 1.00, green: 0.97, blue: 0.90)
    private let orange = Color(red: 217 / 255, green: 132 / 255, blue: 75 / 255)

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    LinearGradient(
                        stops: [
                            .init(color: night, location: 0),
                            .init(color: night, location: 0.10),
                            .init(color: dusk, location: 0.36),
                            .init(color: lavenderMist, location: 0.65),
                            .init(color: AppTheme.paper, location: 0.94),
                            .init(color: AppTheme.paper, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 450)

                    AboutYutoriStarField(accent: orange, light: cream)
                        .frame(height: 300)

                    VStack(alignment: .leading, spacing: 0) {
                        hero

                        VStack(alignment: .leading, spacing: 18) {
                            storyText("Hi, I’m Bruno. I’m 20 years old, and this year I started studying Computer Engineering in Barcelona.")
                            storyText("I joined Shipaton with a pretty simple goal: **finally build something.**")
                            storyText("I had wanted to learn how to make apps for a long time, but I kept putting it off. I was always waiting for the right moment, or until I felt ready enough to start.")
                            storyText("Shipaton gave me the push I needed to stop waiting.")
                            storyText("I wanted to make something that was actually mine, learn as much as possible along the way, and see what I could build in a limited amount of time. That’s how Yutori started.")
                            storyText("The idea came from something very familiar to me: studying. I wanted to experiment with making the process feel a little more rewarding and give people a reason to come back every day. The idea of growing and collecting Japanese bowls felt simple, but fun enough to turn studying into something you could actually look forward to.")
                            storyText("The name came from the Japanese word **Yutori (ゆとり)**, which can mean *space, room, or breathing room*, especially mentally. I liked the idea of connecting that feeling with learning, growth, and taking the time to improve.")
                            storyText("But more than the app itself, what I’ll take away from Shipaton is the process of building it. There were plenty of things I didn’t know how to do, and a lot of moments where I wasn’t sure I would manage to finish. Figuring things out one by one and watching Yutori slowly become real has been one of the most rewarding things I’ve done.")

                            Text("Shipaton made me realise that building apps is something I genuinely want to keep doing.")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.ink)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 16)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(orange)
                                        .frame(width: 4)
                                }
                                .padding(.vertical, 4)

                            storyText("So wherever Yutori goes from here, it will always be the app that made me start.")

                            Rectangle()
                                .fill(AppTheme.ink.opacity(0.13))
                                .frame(height: 1)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Thanks for being here.")
                                Text("— Bruno")
                                    .fontWeight(.bold)
                                    .foregroundStyle(orange)
                            }
                            .font(.system(size: 17, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.bold)
                        .foregroundStyle(cream)
                }
                .accessibilityLabel("Back")
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(orange)
                    .frame(width: 8, height: 8)

                Text("THE STORY OF SHIPATON '26")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(cream.opacity(0.74))
            }

            VStack(alignment: .leading, spacing: -5) {
                Text("Shipaton")
                    .foregroundStyle(cream)
                Text("2026.")
                    .foregroundStyle(orange)
            }
            .font(.system(size: 50, weight: .black, design: .rounded))
            .minimumScaleFactor(0.8)

            Text("The challenge that turned Yutori from an idea into a real app.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(cream.opacity(0.72))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 86)
        .padding(.bottom, 70)
    }

    private func storyText(_ markdown: LocalizedStringKey) -> some View {
        Text(markdown)
            .font(.system(size: 17, design: .rounded))
            .foregroundStyle(AppTheme.ink)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private enum JapaneseIconBackgroundStyle: String, CaseIterable, Identifiable {
    case original = "Original"
    case shippoBlue = "ShippoBlue"
    case asanoha = "Asanoha"
    case kikkoLavender = "KikkoLavender"
    case yagasuriRose = "YagasuriRose"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: "Original cream"
        case .shippoBlue: "Shippo blue"
        case .asanoha: "Sage asanoha"
        case .kikkoLavender: "Kikko lavender"
        case .yagasuriRose: "Yagasuri rose"
        }
    }

    var baseColor: Color {
        switch self {
        case .original: Color(red: 247 / 255, green: 244 / 255, blue: 237 / 255)
        case .shippoBlue: Color(red: 221 / 255, green: 231 / 255, blue: 236 / 255)
        case .asanoha: Color(red: 228 / 255, green: 232 / 255, blue: 222 / 255)
        case .kikkoLavender: Color(red: 226 / 255, green: 221 / 255, blue: 230 / 255)
        case .yagasuriRose: Color(red: 247 / 255, green: 240 / 255, blue: 227 / 255)
        }
    }

}

private extension BowlKind {
    var appIconToken: String {
        switch self {
        case .teriyaki: "Teriyaki"
        case .chirashi: "Chirashi"
        case .katsuRamen: "Katsu"
        case .tofuCurry: "Tofu"
        }
    }

}

private struct AppIconPickerView: View {
    @State private var store = StudySessionStore.shared
    @State private var purchaseManager = PurchaseManager.shared
    @State private var selectedBackground: JapaneseIconBackgroundStyle = .original
    @State private var selectedBowl: BowlKind?
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var showPaywall = false

    private var availableBowls: [BowlKind] {
        BowlCatalog.entries
            .compactMap(\.kind)
            .filter { store.collectedKinds.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Group {
                        if let selectedBowl {
                            AppIconPreview(background: selectedBackground, bowl: selectedBowl)
                        } else {
                            RoundedRectangle(cornerRadius: 42, style: .continuous)
                                .fill(AppTheme.surface.opacity(0.72))
                                .overlay {
                                    VStack(spacing: 10) {
                                        Image(systemName: "takeoutbag.and.cup.and.straw")
                                            .font(.system(size: 34, weight: .medium))
                                        Text("Collect a bowl first")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(AppTheme.secondaryInk)
                                }
                        }
                    }
                    .frame(width: 184, height: 184)
                    .shadow(color: AppTheme.ink.opacity(0.18), radius: 18, y: 10)
                    .padding(.top, 2)

                    Menu {
                        ForEach(JapaneseIconBackgroundStyle.allCases) { background in
                            Button {
                                chooseBackground(background)
                            } label: {
                                if selectedBackground == background {
                                    Label(background.title, systemImage: "checkmark")
                                } else if !purchaseManager.isPro {
                                    Label(background.title, systemImage: "lock.fill")
                                } else {
                                    Text(background.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            JapaneseIconBackground(style: selectedBackground)
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Background")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.secondaryInk)
                                Text(selectedBackground.title)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.ink)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(AppTheme.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Menu {
                        ForEach(availableBowls, id: \.self) { bowl in
                            Button {
                                chooseBowl(bowl)
                            } label: {
                                if selectedBowl == bowl {
                                    Label(bowl.name, systemImage: "checkmark")
                                } else if !purchaseManager.isPro {
                                    Label(bowl.name, systemImage: "lock.fill")
                                } else {
                                    Text(bowl.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if let selectedBowl {
                                DishArtworkView(
                                    level: 3,
                                    availableWidth: 96,
                                    preferredWidth: 48,
                                    kind: selectedBowl
                                )
                                .frame(width: 48, height: 42)
                            } else {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(AppTheme.secondaryInk)
                                    .frame(width: 48, height: 42)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedBowl == nil ? "No collected bowls" : "Collected")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(selectedBowl == nil ? AppTheme.secondaryInk : CourseColor.green.deepTint)
                                Text(selectedBowl?.name ?? "Choose a bowl")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.ink)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(AppTheme.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text("Collect more bowls to unlock more personalized app icons.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(CourseColor.red.deepTint)
                            .multilineTextAlignment(.center)
                    }

                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: applyIcon) {
                    Group {
                        if isApplying {
                            ProgressView().tint(.white)
                        } else {
                            Label("Use this icon", systemImage: "app.badge.checkmark.fill")
                        }
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppTheme.ink, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isApplying || selectedBowl == nil)
                .opacity(selectedBowl == nil ? 0.45 : 1)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadCurrentSelection)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .modifier(AppSheetStyle())
        }
    }

    private var alternateIconName: String? {
        guard let selectedBowl else { return nil }
        return "AppIcon-\(selectedBackground.rawValue)-\(selectedBowl.appIconToken)"
    }

    private func loadCurrentSelection() {
        guard let name = UIApplication.shared.alternateIconName else {
            selectedBackground = .original
            selectedBowl = availableBowls.first
            return
        }
        let parts = name.split(separator: "-").map(String.init)
        if parts.count == 3, let background = JapaneseIconBackgroundStyle(rawValue: parts[1]) {
            selectedBackground = background
            selectedBowl = availableBowls.first(where: { $0.appIconToken == parts[2] })
                ?? availableBowls.first
        }
    }

    private func applyIcon() {
        guard let alternateIconName else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "Alternate app icons are not available on this device."
            return
        }
        isApplying = true
        errorMessage = nil
        UIApplication.shared.setAlternateIconName(alternateIconName) { error in
            Task { @MainActor in
                isApplying = false
                if let error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func chooseBackground(_ background: JapaneseIconBackgroundStyle) {
        guard background != selectedBackground else { return }
        guard purchaseManager.isPro else {
            showPaywall = true
            return
        }
        withAnimation(.spring(duration: 0.32, bounce: 0.16)) {
            selectedBackground = background
        }
    }

    private func chooseBowl(_ bowl: BowlKind) {
        guard bowl != selectedBowl else { return }
        guard purchaseManager.isPro else {
            showPaywall = true
            return
        }
        withAnimation(.spring(duration: 0.32, bounce: 0.16)) {
            selectedBowl = bowl
        }
    }
}

private struct AppIconPreview: View {
    let background: JapaneseIconBackgroundStyle
    let bowl: BowlKind

    var body: some View {
        ZStack {
            JapaneseIconBackground(style: background)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 146, height: 146)
                .blur(radius: 5)
            DishArtworkView(
                level: 3,
                availableWidth: 224,
                preferredWidth: 160,
                kind: bowl
            )
                .shadow(color: AppTheme.ink.opacity(0.28), radius: 7, y: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.10), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview: \(bowl.name) with \(background.title) background")
    }
}

private struct JapaneseIconBackground: View {
    let style: JapaneseIconBackgroundStyle

    var body: some View {
        ZStack {
            style.baseColor
            switch style {
            case .original:
                Image("AppIconBackgroundOriginal")
                    .resizable()
                    .scaledToFill()
            case .shippoBlue:
                Image("AppIconBackgroundShippoBlue")
                    .resizable()
                    .scaledToFill()
            case .asanoha:
                Image("AppIconBackgroundAsanoha")
                    .resizable()
                    .scaledToFill()
            case .kikkoLavender:
                Image("AppIconBackgroundKikkoLavender")
                    .resizable()
                    .scaledToFill()
            case .yagasuriRose:
                Image("AppIconBackgroundYagasuriRose")
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
    }

}

private struct AboutYutoriStarField: View {
    let accent: Color
    let light: Color

    private let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (0.05, 0.04, 1), (0.16, 0.10, 2), (0.29, 0.04, 1), (0.43, 0.13, 3),
        (0.58, 0.06, 1.5), (0.72, 0.15, 2), (0.86, 0.05, 3.5), (0.96, 0.18, 1),
        (0.10, 0.25, 3), (0.23, 0.34, 1), (0.36, 0.23, 2), (0.51, 0.31, 1.5),
        (0.65, 0.25, 2.5), (0.80, 0.36, 1), (0.93, 0.29, 3), (0.03, 0.46, 1.5),
        (0.15, 0.56, 2), (0.31, 0.45, 3.5), (0.47, 0.58, 1), (0.61, 0.48, 2),
        (0.75, 0.57, 3), (0.89, 0.47, 1.5), (0.98, 0.61, 2), (0.08, 0.71, 1),
        (0.25, 0.78, 2.5), (0.40, 0.69, 1.5), (0.55, 0.82, 3), (0.70, 0.72, 1),
        (0.84, 0.84, 2), (0.95, 0.75, 3.5), (0.14, 0.92, 2), (0.35, 0.90, 1),
        (0.62, 0.95, 2.5), (0.78, 0.91, 1.5), (0.92, 0.97, 2)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(stars.enumerated()), id: \.offset) { index, star in
                Circle()
                    .fill(index.isMultiple(of: 4) ? accent.opacity(0.52) : light.opacity(0.36))
                    .frame(width: star.2, height: star.2)
                    .position(x: proxy.size.width * star.0, y: proxy.size.height * star.1)
            }
        }
        .allowsHitTesting(false)
    }
}
