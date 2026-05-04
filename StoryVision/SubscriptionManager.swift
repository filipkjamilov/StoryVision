import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    private(set) var customerInfo: CustomerInfo?
    private(set) var packages: [Package] = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    var errorMessage: String?

    var hasProAccess: Bool {
        customerInfo?.entitlements[Config.RevenueCat.proEntitlementID]?.isActive == true
    }

    var monthlyPackage: Package? {
        package(for: Config.RevenueCat.ProductID.monthly)
    }

    var yearlyPackage: Package? {
        package(for: Config.RevenueCat.ProductID.yearly)
    }

    func start() {
        Task {
            await refreshCustomerInfo()
            await loadOfferings()
            await listenForCustomerInfoUpdates()
        }
    }

    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            errorMessage = "Could not refresh subscription status: \(error.localizedDescription)"
        }
    }

    func updateCustomerInfo(_ customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            packages = offerings.current?.availablePackages ?? []
        } catch {
            errorMessage = "Could not load subscription products: \(error.localizedDescription)"
        }
    }

    func purchase(_ package: Package) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return }
            customerInfo = result.customerInfo
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            customerInfo = try await Purchases.shared.restorePurchases()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func listenForCustomerInfoUpdates() async {
        do {
            for try await updatedInfo in Purchases.shared.customerInfoStream {
                customerInfo = updatedInfo
            }
        } catch {
            errorMessage = "Subscription updates stopped: \(error.localizedDescription)"
        }
    }

    private func package(for productID: String) -> Package? {
        packages.first { package in
            package.storeProduct.productIdentifier == productID
        }
    }
}
