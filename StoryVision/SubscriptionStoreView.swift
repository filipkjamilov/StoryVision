import SwiftUI
import RevenueCat
import RevenueCatUI

#if os(iOS)
struct SubscriptionStoreView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var showRevenueCatPaywall = false
    @State private var showCustomerCenter = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        packageButtons
                        managementButtons

                        if let errorMessage = subscriptions.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "F87171"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("StoryVision Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .task {
                await subscriptions.refreshCustomerInfo()
                await subscriptions.loadOfferings()
            }
            .sheet(isPresented: $showRevenueCatPaywall, onDismiss: {
                Task { await subscriptions.refreshCustomerInfo() }
            }) {
                PaywallView()
            }
            .sheet(isPresented: $showCustomerCenter, onDismiss: {
                Task { await subscriptions.refreshCustomerInfo() }
            }) {
                CustomerCenterView()
                    .onCustomerCenterRestoreCompleted { customerInfo in
                        subscriptions.updateCustomerInfo(customerInfo)
                    }
                    .onCustomerCenterRestoreFailed { error in
                        subscriptions.errorMessage = "Restore failed: \(error.localizedDescription)"
                    }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(subscriptions.hasProAccess ? "Pro is active" : "Unlock unlimited story generation")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("StoryVision Pro unlocks image generation and keeps your subscription status synced across restores and purchases.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var packageButtons: some View {
        VStack(spacing: 12) {
            if subscriptions.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                purchaseButton(title: "Yearly", package: subscriptions.yearlyPackage)
                purchaseButton(title: "Monthly", package: subscriptions.monthlyPackage)
            }

            Button {
                showRevenueCatPaywall = true
            } label: {
                Label("Open Paywall", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient.storyPurple))
            }
        }
    }

    private var managementButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await subscriptions.restorePurchases() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }

            Button {
                showCustomerCenter = true
            } label: {
                Label("Manage Subscription", systemImage: "person.crop.circle")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .tint(.white)
        .disabled(subscriptions.isPurchasing)
    }

    private func purchaseButton(title: String, package: Package?) -> some View {
        Button {
            guard let package else { return }
            Task { await subscriptions.purchase(package) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(package?.storeProduct.localizedTitle ?? "Product not found")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()

                if subscriptions.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(package?.storeProduct.localizedPriceString ?? "--")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Color.white.opacity(package == nil ? 0.05 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .disabled(package == nil || subscriptions.isPurchasing || subscriptions.hasProAccess)
    }
}

#Preview {
    SubscriptionStoreView()
        .environment(SubscriptionManager())
}
#endif
