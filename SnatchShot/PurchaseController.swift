//
//  PurchaseController.swift
//  SnatchShot
//
//  Created by AI Assistant on 22/09/25.
//

import SuperwallKit
import StoreKit
import AppsFlyerLib
import Mixpanel

/// Purchase controller that forwards Superwall events to AppsFlyer and Mixpanel
class PurchaseController: NSObject, SuperwallKit.PurchaseController {
    func purchase(product: StoreProduct) async -> SuperwallKit.PurchaseResult {
        print("🛒 Processing purchase for product: \(product.productIdentifier)")

        // TODO: Implement actual StoreKit purchase flow
        // For now, simulate a successful purchase
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
            return SuperwallKit.PurchaseResult.purchased
        } catch {
            return SuperwallKit.PurchaseResult.failed(error)
        }
    }

    func restorePurchases() async -> SuperwallKit.RestorationResult {
        print("🔄 Restoring purchases")
        
        // TODO: Implement actual StoreKit restore logic
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
            return SuperwallKit.RestorationResult.restored
        } catch {
            return SuperwallKit.RestorationResult.failed(error)
        }
    }

    // MARK: - Event Forwarding

    func didPurchase(product: StoreProduct, result: SuperwallKit.PurchaseResult) {
        // Forward purchase events to AppsFlyer and Mixpanel
        switch result {
        case .purchased:
            // Update subscription manager with purchase
            SubscriptionManager.shared.handlePurchase(productId: product.productIdentifier)

            // AppsFlyer purchase tracking
            AppsFlyerLib.shared().logEvent("af_purchase", withValues: [
                AFEventParamContentId: product.productIdentifier,
                AFEventParamRevenue: product.price,
                AFEventParamCurrency: product.currencyCode ?? "USD",
                AFEventParamContentType: "subscription"
            ])

            // Mixpanel purchase tracking
            let purchaseProperties: [String: MixpanelType] = [
                "product_id": product.productIdentifier,
                "amount": NSDecimalNumber(decimal: product.price).doubleValue,
                "currency": product.currencyCode ?? "USD"
            ]
            Mixpanel.mainInstance().track(event: "subscription_purchased", properties: purchaseProperties)

            // Update user properties
            Mixpanel.mainInstance().people.set(properties: [
                "subscription_status": "premium",
                "subscription_product_id": product.productIdentifier
            ])

            print("✅ Purchase completed and tracked: \(product.productIdentifier)")

        case .failed(let error):
            // Track failed purchases
            let failureProperties: [String: MixpanelType] = [
                "product_id": product.productIdentifier,
                "error": error.localizedDescription
            ]
            Mixpanel.mainInstance().track(event: "purchase_failed", properties: failureProperties)
            print("❌ Purchase failed: \(error.localizedDescription)")

        case .cancelled:
            let cancelProperties: [String: MixpanelType] = [
                "product_id": product.productIdentifier
            ]
            Mixpanel.mainInstance().track(event: "purchase_cancelled", properties: cancelProperties)
            print("🚫 Purchase cancelled")
            
        case .pending:
            let pendingProperties: [String: MixpanelType] = [
                "product_id": product.productIdentifier
            ]
            Mixpanel.mainInstance().track(event: "purchase_pending", properties: pendingProperties)
            print("⏳ Purchase pending: \(product.productIdentifier)")
        }
    }

    func didRestore(result: SuperwallKit.RestorationResult) {
        switch result {
        case .restored:
            // Mark user as paid subscriber (product details will come from backend)
            SubscriptionManager.shared.state.isPaidSubscriber = true

            // Update user properties for restored subscription
            Mixpanel.mainInstance().people.set(properties: [
                "subscription_status": "premium"
            ])
            Mixpanel.mainInstance().track(event: "subscription_restored", properties: [:])
            print("✅ Subscription restored")

        case .failed(let error):
            let restoreFailProperties: [String: MixpanelType] = [
                "error": error?.localizedDescription ?? "Unknown restore error"
            ]
            Mixpanel.mainInstance().track(event: "restore_failed", properties: restoreFailProperties)
            print("❌ Restore failed: \(error?.localizedDescription ?? "Unknown restore error")")
        }
    }

    // MARK: - Trial Tracking

    func trackTrialStarted(productId: String, price: Double, currency: String) {
        // AppsFlyer trial tracking
        AppsFlyerLib.shared().logEvent("af_trial_started", withValues: [
            AFEventParamContentId: productId,
            AFEventParamRevenue: price,
            AFEventParamCurrency: currency,
            AFEventParamContentType: "trial"
        ])

        // Mixpanel trial tracking
        let trialProperties: [String: MixpanelType] = [
            "product_id": productId,
            "trial_price": price,
            "currency": currency
        ]
        Mixpanel.mainInstance().track(event: "trial_started", properties: trialProperties)

        // Update user properties
        Mixpanel.mainInstance().people.set(properties: [
            "subscription_status": "trial",
            "trial_start_date": Date()
        ])

        print("🎯 Trial started and tracked: \(productId)")
    }

    // MARK: - Paywall Events

    func trackPaywallShown(placement: String) {
        let paywallShownProperties: [String: MixpanelType] = [
            "placement": placement,
            "source": "superwall"
        ]
        Mixpanel.mainInstance().track(event: "paywall_shown", properties: paywallShownProperties)
        print("💰 Paywall shown: \(placement)")
    }

    func trackPaywallDismissed(placement: String) {
        let paywallDismissedProperties: [String: MixpanelType] = [
            "placement": placement,
            "source": "superwall"
        ]
        Mixpanel.mainInstance().track(event: "paywall_dismissed", properties: paywallDismissedProperties)
        print("🚪 Paywall dismissed: \(placement)")
    }
}
