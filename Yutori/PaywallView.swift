import RevenueCat
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var purchaseManager = PurchaseManager.shared
    @State private var selectedProductIdentifier = PurchaseManager.monthlyProductIdentifier
    @State private var isLoadingOfferings = true
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var showCongratulations = false
    @State private var bowlIsFloating = false

    var onPurchased: (() -> Void)?

    private var monthlyPackage: Package? {
        purchaseManager.packages.first {
            $0.packageType == .monthly ||
            $0.storeProduct.productIdentifier == PurchaseManager.monthlyProductIdentifier
        }
    }

    private var yearlyPackage: Package? {
        purchaseManager.packages.first {
            $0.packageType == .annual ||
            $0.storeProduct.productIdentifier == PurchaseManager.yearlyProductIdentifier
        }
    }

    private var selectedPackage: Package? {
        purchaseManager.packages.first {
            $0.storeProduct.productIdentifier == selectedProductIdentifier
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(CourseColor.orange.tint.opacity(0.17))
                                .frame(width: 152, height: 152)
                            Circle()
                                .fill(CourseColor.pink.tint.opacity(0.13))
                                .frame(width: 82, height: 82)
                                .offset(x: 70, y: -40)
                            Circle()
                                .fill(CourseColor.teal.tint.opacity(0.18))
                                .frame(width: 48, height: 48)
                                .offset(x: -86, y: 40)
                            Circle()
                                .fill(CourseColor.lemon.tint.opacity(0.20))
                                .frame(width: 30, height: 30)
                                .offset(x: -62, y: -64)
                            Circle()
                                .fill(CourseColor.green.tint.opacity(0.15))
                                .frame(width: 38, height: 38)
                                .offset(x: 90, y: 52)
                            DishArtworkView(level: 5, availableWidth: 210, preferredWidth: 168, kind: .teriyaki)
                                .offset(y: bowlIsFloating ? -6 : 5)
                                .rotationEffect(.degrees(bowlIsFloating ? 1.2 : -1.2))
                        }
                        .frame(height: 164)

                        Text("Yutori Pro")
                            .font(.system(size: 35, weight: .bold, design: .rounded))

                        Text("More room for every subject you want to learn.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 0) {
                        benefitRow(icon: "books.vertical.fill", color: CourseColor.orange.tint,
                                   title: "Unlimited courses",
                                   detail: "Create a course for every subject and project.")
                        divider
                        benefitRow(icon: "square.grid.2x2.fill", color: CourseColor.teal.tint,
                                   title: "Keep learning organised",
                                   detail: "Separate your sessions and progress with ease.")
                        divider
                        benefitRow(icon: "brain.head.profile", color: CourseColor.indigo.tint,
                                   title: "Made for student habits",
                                   detail: "A calm system built around focus, consistency and visible progress.")
                        divider
                        benefitRow(icon: "heart.fill", color: CourseColor.pink.tint,
                                   title: "Support a student builder",
                                   detail: "Yutori is made independently by a Computer Engineering student.")
                    }
                    .background(AppTheme.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(AppTheme.ink.opacity(0.08), lineWidth: 1)
                    }

                    if purchaseManager.isPro {
                        Label("Yutori Pro is active", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(CourseColor.green.tint)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                purchaseControls
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .tint(AppTheme.ink)
        .task {
            await loadPlans()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                bowlIsFloating = true
            }
        }
        .fullScreenCover(isPresented: $showCongratulations, onDismiss: {
            dismiss()
        }) {
            ProCongratulationsView {
                showCongratulations = false
            }
        }
    }

    private func planButton(package: Package, title: String, detail: String, accent: Color) -> some View {
        let identifier = package.storeProduct.productIdentifier
        let isSelected = selectedProductIdentifier == identifier
        return Button {
            selectedProductIdentifier = identifier
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : AppTheme.muted)

                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(AppTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .leading)
            .background(isSelected ? accent.opacity(0.16) : AppTheme.surface,
                        in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? accent : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(purchaseManager.isBusy)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var purchaseControls: some View {
        VStack(spacing: 12) {
            if !purchaseManager.isPro {
                if isLoadingOfferings {
                    ProgressView("Loading plans…")
                        .font(.system(size: 14, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 112)
                } else {
                    HStack(spacing: 10) {
                        if let monthlyPackage {
                            planButton(package: monthlyPackage, title: "Monthly",
                                       detail: monthlyPackage.storeProduct.localizedPriceString,
                                       accent: CourseColor.blue.tint)
                        }
                        if let yearlyPackage {
                            planButton(package: yearlyPackage, title: "Yearly",
                                       detail: yearlyPackage.storeProduct.localizedPriceString,
                                       accent: CourseColor.purple.tint)
                        }
                    }

                    if purchaseManager.packages.isEmpty {
                        Text("Monthly and Yearly are not available in the default offering.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Button(action: buySelectedPlan) {
                    Group {
                        if isPurchasing { ProgressView().tint(.white) }
                        else { Text("Continue with Pro") }
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppTheme.ink, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedPackage == nil || isPurchasing || isRestoring || purchaseManager.isBusy)
                .opacity(selectedPackage == nil || isPurchasing || isRestoring || purchaseManager.isBusy ? 0.45 : 1)
            }

            Button(action: restore) {
                if isRestoring { ProgressView() }
                else { Text("Restore Purchases").font(.system(size: 14, weight: .semibold, design: .rounded)) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.ink)
            .disabled(isPurchasing || isRestoring || purchaseManager.isBusy)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.ink.opacity(0.08)).frame(height: 0.5)
        }
    }

    private func benefitRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.paper)
                .frame(width: 40, height: 40)
                .background(color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.ink.opacity(0.09))
            .frame(height: 1)
            .padding(.leading, 70)
    }

    private func loadPlans() async {
        isLoadingOfferings = true
        errorMessage = nil
        do {
            try await purchaseManager.loadOfferings()
            if selectedPackage == nil {
                if let monthlyPackage {
                    selectedProductIdentifier = monthlyPackage.storeProduct.productIdentifier
                } else if let yearlyPackage {
                    selectedProductIdentifier = yearlyPackage.storeProduct.productIdentifier
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingOfferings = false
    }

    private func buySelectedPlan() {
        guard let selectedPackage, !isPurchasing, !isRestoring, !purchaseManager.isBusy else { return }
        isPurchasing = true
        errorMessage = nil
        Task {
            defer { isPurchasing = false }
            do {
                if try await purchaseManager.purchase(selectedPackage) {
                    onPurchased?()
                    showCongratulations = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        guard !isPurchasing, !isRestoring, !purchaseManager.isBusy else { return }
        isRestoring = true
        errorMessage = nil
        Task {
            defer { isRestoring = false }
            do {
                let restored = try await purchaseManager.restorePurchases()
                if restored {
                    onPurchased?()
                    dismiss()
                } else {
                    errorMessage = "No active Yutori Pro purchase was found."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ProCongratulationsView: View {
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let accents: [(Color, CGFloat, CGFloat, CGFloat)] = [
        (CourseColor.pink.tint, 52, -142, -250),
        (CourseColor.orange.tint, 24, 136, -218),
        (CourseColor.teal.tint, 34, -155, -74),
        (CourseColor.lemon.tint, 18, 154, 12),
        (CourseColor.indigo.tint, 28, -122, 154),
        (CourseColor.green.tint, 44, 145, 190)
    ]

    var body: some View {
        ZStack {
            AppTheme.paper.ignoresSafeArea()

            ForEach(Array(accents.enumerated()), id: \.offset) { _, accent in
                Circle()
                    .fill(accent.0.opacity(0.20))
                    .frame(width: accent.1, height: accent.1)
                    .offset(x: accent.2, y: accent.3)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 34)

                Text("YUTORI PRO")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(CourseColor.indigo.tint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(CourseColor.pink.tint.opacity(0.16), in: Capsule())

                ZStack {
                    Circle()
                        .fill(AppTheme.surface.opacity(0.82))
                        .frame(width: 224, height: 224)

                    Image("TeriyakiLevel5")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 198, height: 198)
                }
                .scaleEffect(appeared ? 1 : 0.78)
                .opacity(appeared ? 1 : 0)
                .padding(.top, 20)

                VStack(spacing: 9) {
                    Text("Congratulations!")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)

                    Text("You're Pro now")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(CourseColor.orange.deepTint)

                    Text("Create all the courses you need and keep growing your collection without limits.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 30)
                        .padding(.top, 4)
                }

                Spacer(minLength: 28)

                Button(action: onContinue) {
                    Text("Start studying")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.paper)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(AppTheme.ink, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.75, bounce: 0.18)) {
                appeared = true
            }
        }
    }
}
