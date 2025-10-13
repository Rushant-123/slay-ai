import Foundation
import SuperwallKit
import StoreKit
import Mixpanel

/// Handles purchase-related interactions for Superwall
final class SuperwallPurchaseController: NSObject, SuperwallKit.PurchaseController {
    // MARK: - Purchase Flow
    
    func purchase(product: StoreProduct) async -> SuperwallKit.PurchaseResult {
        print("🛒 Processing purchase for product: \(product.productIdentifier)")
        
        do {
            // Request payment from StoreKit
            let result = try await purchaseProduct(product.productIdentifier)
            
            // Handle the result
            switch result {
            case .success:
                handleSuccessfulPurchase(product)
                return SuperwallKit.PurchaseResult.purchased
                
            case .pending:
                handlePendingPurchase(product)
                return SuperwallKit.PurchaseResult.pending
                
            case .cancelled:
                handleCancelledPurchase(product)
                return SuperwallKit.PurchaseResult.cancelled
                
            case .failed(let error):
                handleFailedPurchase(product, error: error)
                return SuperwallKit.PurchaseResult.failed(error)
            }
        } catch {
            handleFailedPurchase(product, error: error)
            return SuperwallKit.PurchaseResult.failed(error)
        }
    }
    
    func restorePurchases() async -> SuperwallKit.RestorationResult {
        print("🔄 Restoring purchases")
        
        do {
            // Attempt to restore purchases through StoreKit
            try await AppStore.sync()
            
            // Check if we have any active subscriptions
            let subscriptionStatus = try await checkSubscriptionStatus()
            
            if subscriptionStatus.isSubscribed {
                handleSuccessfulRestore()
                return SuperwallKit.RestorationResult.restored
            } else {
                return SuperwallKit.RestorationResult.failed(nil)
            }
        } catch {
            handleFailedRestore(error: error)
            return SuperwallKit.RestorationResult.failed(error)
        }
    }
    
    // MARK: - StoreKit Integration
    
    private func purchaseProduct(_ productId: String) async throws -> PurchaseResult {
        // Get the product from StoreKit
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            throw StoreKitError.productNotFound
        }
        
        // Purchase the product
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify the transaction
            switch verification {
            case .verified(let transaction):
                // Handle verified transaction
                await transaction.finish()
                return .success
                
            case .unverified:
                throw StoreKitError.verificationFailed
            }
            
        case .pending:
            return .pending
            
        case .userCancelled:
            return .cancelled
            
        @unknown default:
            return .failed(StoreKitError.unknown)
        }
    }
    
    private func checkSubscriptionStatus() async throws -> SubscriptionStatus {
        // Implement subscription status check
        // This should verify active subscriptions through StoreKit
        // For now, return a placeholder
        return SubscriptionStatus(isSubscribed: false)
    }
    
    // MARK: - Purchase Result Handling
    
    private func handleSuccessfulPurchase(_ product: StoreProduct) {
        // Update subscription state
        SubscriptionManager.shared.handlePurchase(productId: product.productIdentifier)
        
        // Track purchase in analytics
        let purchaseProperties: [String: MixpanelType] = [
            "product_id": product.productIdentifier,
            "price": NSDecimalNumber(decimal: product.price).doubleValue,
            "currency": product.currencyCode ?? "USD"
        ]
        Mixpanel.mainInstance().track(event: "subscription_purchased", properties: purchaseProperties)
        
        print("✅ Purchase completed: \(product.productIdentifier)")
    }
    
    private func handlePendingPurchase(_ product: StoreProduct) {
        // Track pending purchase
        Mixpanel.mainInstance().track(event: "purchase_pending", properties: [
            "product_id": product.productIdentifier
        ])
        
        print("⏳ Purchase pending: \(product.productIdentifier)")
    }
    
    private func handleCancelledPurchase(_ product: StoreProduct) {
        // Track cancelled purchase
        Mixpanel.mainInstance().track(event: "purchase_cancelled", properties: [
            "product_id": product.productIdentifier
        ])
        
        print("🚫 Purchase cancelled: \(product.productIdentifier)")
    }
    
    private func handleFailedPurchase(_ product: StoreProduct, error: Error) {
        // Track failed purchase
        Mixpanel.mainInstance().track(event: "purchase_failed", properties: [
            "product_id": product.productIdentifier,
            "error": error.localizedDescription
        ])
        
        print("❌ Purchase failed: \(error.localizedDescription)")
    }
    
    private func handleSuccessfulRestore() {
        // Update subscription state
        SubscriptionManager.shared.state.isPaidSubscriber = true
        
        // Track restore in analytics
        Mixpanel.mainInstance().track(event: "subscription_restored")
        
        print("✅ Subscription restored")
    }
    
    private func handleFailedRestore(error: Error) {
        // Track failed restore
        Mixpanel.mainInstance().track(event: "restore_failed", properties: [
            "error": error.localizedDescription
        ])
        
        print("❌ Restore failed: \(error.localizedDescription)")
    }
}

// MARK: - Supporting Types

struct SubscriptionStatus {
    let isSubscribed: Bool
}

enum StoreKitError: Error {
    case productNotFound
    case verificationFailed
    case unknown
}

enum PurchaseResult {
    case success
    case pending
    case cancelled
    case failed(Error)
}
