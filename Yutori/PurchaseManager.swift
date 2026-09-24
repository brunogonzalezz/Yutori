import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    static let entitlementIdentifier = "studybite_pro"
    static let offeringIdentifier = "default"
    static let monthlyProductIdentifier = "monthly"
    static let yearlyProductIdentifier = "yearly"

    enum Operation: Equatable {
        case idle
        case purchasing(productIdentifier: String)
        case restoring
    }

    private(set) var isPro = false
    private(set) var isConfigured = false
    private(set) var packages: [Package] = []
    private(set) var configurationMessage: String?
    private(set) var operation: Operation = .idle

#if DEBUG
    private let debugProOverrideKey = "debug.yutoriProOverride"
    private var debugProOverride: Bool?
#endif

    var isBusy: Bool { operation != .idle }

    var isPurchasing: Bool {
        if case .purchasing = operation { return true }
        return false
    }

    var isRestoring: Bool { operation == .restoring }

    private var customerInfoTask: Task<Void, Never>?

    private init() {
#if DEBUG
        if UserDefaults.standard.object(forKey: debugProOverrideKey) != nil {
            let override = UserDefaults.standard.bool(forKey: debugProOverrideKey)
            debugProOverride = override
            isPro = override
        }
#endif
    }

#if DEBUG
    func setDebugPro(_ enabled: Bool) {
        debugProOverride = enabled
        UserDefaults.standard.set(enabled, forKey: debugProOverrideKey)
        isPro = enabled
    }

    private func clearDebugProOverride() {
        debugProOverride = nil
        UserDefaults.standard.removeObject(forKey: debugProOverrideKey)
    }
#endif

    func configure() {
        guard !isConfigured else { return }
        guard let apiKey = Self.testStoreAPIKey else {
            configurationMessage = "RevenueCat Test Store is not configured for this Debug build."
            return
        }

#if DEBUG
        Purchases.logLevel = .debug
#endif
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
        configurationMessage = nil

        customerInfoTask = Task { [weak self] in
            guard let self else { return }
            for await customerInfo in Purchases.shared.customerInfoStream {
                self.update(with: customerInfo)
            }
        }

        Task { [weak self] in
            await self?.refresh()
        }
    }

    private static var testStoreAPIKey: String? {
#if DEBUG
        if let url = Bundle.main.url(forResource: "RevenueCatSecrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = values["REVENUECAT_API_KEY"] as? String {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty { return trimmedKey }
        }

        if let key = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty { return trimmedKey }
        }
        return nil
#else
        // A Test Store key must never be used in an App Store build.
        return nil
#endif
    }

    func refresh() async {
        guard isConfigured else { return }
        do {
            async let customerInfo = Purchases.shared.customerInfo()
            async let offerings = Purchases.shared.offerings()
            let (newCustomerInfo, newOfferings) = try await (customerInfo, offerings)
            update(with: newCustomerInfo)
            updatePackages(from: newOfferings)
        } catch {
            configurationMessage = error.localizedDescription
        }
    }

    func loadOfferings() async throws {
        guard isConfigured else {
            throw PurchaseManagerError.notConfigured
        }
        let offerings = try await Purchases.shared.offerings()
        updatePackages(from: offerings)
    }

    func purchase(_ package: Package) async throws -> Bool {
        guard isConfigured else {
            throw PurchaseManagerError.notConfigured
        }
        guard operation == .idle else {
            throw PurchaseManagerError.operationInProgress
        }

#if DEBUG
        clearDebugProOverride()
#endif

        operation = .purchasing(productIdentifier: package.storeProduct.productIdentifier)
        defer { operation = .idle }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            update(with: result.customerInfo)
            return !result.userCancelled && isPro
        } catch {
            if Self.isOperationAlreadyInProgress(error) {
                await refreshCustomerInfo()
                throw PurchaseManagerError.operationInProgress
            }
            throw error
        }
    }

    @discardableResult
    func restorePurchases() async throws -> Bool {
        guard isConfigured else {
            throw PurchaseManagerError.notConfigured
        }
        guard operation == .idle else {
            throw PurchaseManagerError.operationInProgress
        }

#if DEBUG
        clearDebugProOverride()
#endif

        operation = .restoring
        defer { operation = .idle }

        let customerInfo = try await Purchases.shared.restorePurchases()
        update(with: customerInfo)
        return isPro
    }

    private func update(with customerInfo: CustomerInfo) {
        let revenueCatIsPro = customerInfo.entitlements.all[Self.entitlementIdentifier]?.isActive == true
#if DEBUG
        isPro = debugProOverride ?? revenueCatIsPro
#else
        isPro = revenueCatIsPro
#endif
    }

    private func updatePackages(from offerings: Offerings) {
        guard let offering = offerings.all[Self.offeringIdentifier] else {
            packages = []
            return
        }

        // Prefer RevenueCat's standard package types so a product can be replaced
        // in the dashboard without requiring an app update. The identifier lookup
        // keeps compatibility with the current Test Store configuration.
        let monthly = offering.monthly ?? offering.availablePackages.first {
            $0.storeProduct.productIdentifier == Self.monthlyProductIdentifier
        }
        let yearly = offering.annual ?? offering.availablePackages.first {
            $0.storeProduct.productIdentifier == Self.yearlyProductIdentifier
        }
        packages = [monthly, yearly].compactMap { $0 }
    }

    private func refreshCustomerInfo() async {
        guard let customerInfo = try? await Purchases.shared.customerInfo() else { return }
        update(with: customerInfo)
    }

    private static func isOperationAlreadyInProgress(_ error: Error) -> Bool {
        (error as NSError).asErrorCode == .operationAlreadyInProgressForProductError
    }
}

enum PurchaseManagerError: LocalizedError {
    case notConfigured
    case operationInProgress

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Add REVENUECAT_API_KEY to the Yutori Run scheme or RevenueCatSecrets.plist for Debug builds."
        case .operationInProgress:
            "A purchase is already being processed. Finish or cancel it, then try again."
        }
    }
}
