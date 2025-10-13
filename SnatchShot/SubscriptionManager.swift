import Foundation
#if canImport(SuperwallKit)
import SuperwallKit
#endif
#if canImport(Combine)
import Combine
#endif

/// Subscription plans available in the app
enum AppSubscriptionPlan: String, Codable {
    case yearly = "com.rushant.snatchshotapp.pro.yearly"           // With 3-day trial
    case yearlynt = "com.rushant.snatchshotapp.pro.yearlynt"       // No trial, immediate payment
    case quarterly = "com.rushant.snatchshotapp.pro.quaterly"      // Quarterly billing (matches App Store Connect)
    case weekly = "com.rushant.snatchshotapp.pro.weekly"           // Weekly billing
}

// Simplified names for internal use
extension AppSubscriptionPlan {
    var displayName: String {
        switch self {
        case .yearly: return "yearly"
        case .yearlynt: return "yearlynt"
        case .quarterly: return "quarterly"  // Still display as "quarterly" for UI
        case .weekly: return "weekly"
        }
    }
}

/// Trial status for users
enum TrialStatus: String, Codable {
    case none = "none"               // No trial available/used
    case active = "active"           // Currently in trial
    case expired = "expired"         // Trial ended, payment pending
    case cancelled = "cancelled"     // Trial cancelled by user
}

/// Overall subscription state combining trial, payment, and usage
struct SubscriptionState: Codable {
    var trialStatus: TrialStatus = .none
    var isPaidSubscriber: Bool = false
    var currentPlan: AppSubscriptionPlan? = nil
    var trialStartDate: Date? = nil
    var trialEndDate: Date? = nil
    var usageCount: Int = 0
    var usageLimit: Int = 0
    var daysRemainingInTrial: Int = 0

    /// Computed properties for easy state checking
    var isTrialActive: Bool {
        trialStatus == .active && daysRemainingInTrial > 0
    }

    var isTrialExpired: Bool {
        trialStatus == .expired || (trialStatus == .active && daysRemainingInTrial <= 0)
    }

    var hasExceededUsage: Bool {
        usageCount >= usageLimit && usageLimit > 0
    }

    var shouldBlockAccess: Bool {
        if isTrialActive {
            return hasExceededUsage
        } else if isPaidSubscriber {
            return hasExceededUsage
        } else {
            // Not in trial and not paid = block access
            return true
        }
    }

    /// Determine which paywall to show based on current state
    var requiredPaywall: PaywallType {
        if trialStatus == .none && !isPaidSubscriber {
            // New user onboarding
            return .onboarding
        } else if isTrialExpired && !isPaidSubscriber {
            // Trial completed, needs upgrade
            return .trialExpired
        } else if isPaidSubscriber && hasExceededUsage {
            // Paid user hit limits
            return .normalUpgrade
        } else {
            return .none
        }
    }
}

/// Paywall types corresponding to different user states
enum PaywallType: String {
    case none = "none"
    case onboarding = "onboarding"           // yearly, quarterly, weekly
    case trialExpired = "trial_expired"      // yearlynt only
    case normalUpgrade = "normal_upgrade"    // yearlynt, quarterly, weekly
}

/// Central subscription management service
class SubscriptionManager {
    static let shared = SubscriptionManager()

    var state: SubscriptionState

    // private var cancellables = Set<AnyCancellable>()

    private init() {
        state = SubscriptionState()
        setupSuperwallObservers()
        loadPersistedState()
        // Check actual subscription status from StoreKit
        checkSubscriptionStatus()
    }

    /// Check actual subscription status from StoreKit
    private func checkSubscriptionStatus() {
        // TODO: Implement actual StoreKit subscription verification
        // For now, we assume users are free (not subscribed)
        print("📱 Subscription status: FREE (no StoreKit integration yet)")
    }

    // MARK: - Superwall Integration

    private func setupSuperwallObservers() {
        // Listen for subscription status changes from Superwall
        // Note: This assumes Superwall 4.8.2 has these capabilities
        // We'll implement fallback logic if methods don't exist

        // Observe subscription status changes (if available)
        observeSubscriptionStatus()

        // Observe purchase events
        observePurchases()
    }

    private func observeSubscriptionStatus() {
        // Set initial subscription status for Superwall
        updateSuperwallSubscriptionStatus()

        // Observe state changes to update Superwall
        // Note: In a real implementation, you'd set up proper observers here
        print("🎯 Setting up Superwall subscription status observer")
    }

    /// Update Superwall with current subscription status
    private func updateSuperwallSubscriptionStatus() {
        #if canImport(SuperwallKit)
        // Determine subscription status for Superwall
        let isSubscribed = state.isPaidSubscriber || state.isTrialActive

        // Set user attributes - Superwall uses these to determine subscription status
        let attributes: [String: Any] = [
            "is_subscribed": isSubscribed,
            "subscription_status": isSubscribed ? "active" : "inactive",
            "has_active_subscription": isSubscribed,
            "premium": isSubscribed
        ]
        Superwall.shared.setUserAttributes(attributes)
        print("🔄 Superwall user attributes set: \(attributes)")

        // For Superwall, also try to set entitlements if the user is subscribed
        if isSubscribed {
            // Try to call setEntitlements method if it exists
            let entitlements: Set<String> = ["premium", "pro"]
            let entitlementsMethod = NSSelectorFromString("setEntitlements:")
            if Superwall.shared.responds(to: entitlementsMethod) {
                Superwall.shared.perform(entitlementsMethod, with: entitlements)
                print("🔄 Superwall entitlements set: \(entitlements)")
            } else {
                print("ℹ️ Superwall entitlements method not available, using user attributes only")
            }
        } else {
            // Clear entitlements for free users
            let entitlementsMethod = NSSelectorFromString("setEntitlements:")
            if Superwall.shared.responds(to: entitlementsMethod) {
                Superwall.shared.perform(entitlementsMethod, with: Set<String>())
                print("🔄 Superwall entitlements cleared for free user")
            }
        }
        #endif
    }

    private func observePurchases() {
        // Observe purchase completions to update state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePurchaseNotification(_:)),
            name: Notification.Name("SuperwallPurchaseCompleted"),
            object: nil
        )
    }

    @objc private func handlePurchaseNotification(_ notification: Notification) {
        if let productId = notification.userInfo?["productId"] as? String {
            handlePurchase(productId: productId)
        }
    }

    // MARK: - State Management

    func updateTrialStatus(_ status: TrialStatus, startDate: Date? = nil, endDate: Date? = nil) {
        state.trialStatus = status
        state.trialStartDate = startDate
        state.trialEndDate = endDate

        if let endDate = endDate {
            state.daysRemainingInTrial = max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
        }

        persistState()
        updateSuperwallSubscriptionStatus() // Update Superwall with new status
        print("🎯 Trial status updated: \(status.rawValue), days remaining: \(state.daysRemainingInTrial)")
    }

    func updateUsage(current: Int, limit: Int) {
        state.usageCount = current
        state.usageLimit = limit
        persistState()
        print("📊 Usage updated: \(current)/\(limit)")
    }

    func handlePurchase(productId: String) {
        // Map product ID to subscription plan
        if let plan = AppSubscriptionPlan(rawValue: productId) {
            state.currentPlan = plan
            state.isPaidSubscriber = true

            // If purchasing yearlynt during trial, end trial
            if plan == .yearlynt && state.isTrialActive {
                updateTrialStatus(.cancelled)
            }

            persistState()
            updateSuperwallSubscriptionStatus() // Update Superwall with new status
            print("💰 Purchase completed: \(plan.rawValue)")
        }
    }

    func updateFromWebSocket(data: [String: Any]) {
        // Update state from WebSocket messages
        if let trialStatus = data["trial_status"] as? String {
            if let status = TrialStatus(rawValue: trialStatus) {
                var startDate: Date? = nil
                var endDate: Date? = nil

                if let startTimestamp = data["trial_start"] as? Double {
                    startDate = Date(timeIntervalSince1970: startTimestamp)
                }
                if let endTimestamp = data["trial_end"] as? Double {
                    endDate = Date(timeIntervalSince1970: endTimestamp)
                }

                updateTrialStatus(status, startDate: startDate, endDate: endDate)
            }
        }

        if let usage = data["usage_count"] as? Int,
           let limit = data["usage_limit"] as? Int {
            updateUsage(current: usage, limit: limit)
        }

        if let isPaid = data["is_paid_subscriber"] as? Bool {
            state.isPaidSubscriber = isPaid
        }

        if let planString = data["current_plan"] as? String,
           let plan = AppSubscriptionPlan(rawValue: planString) {
            state.currentPlan = plan
        }

        // Update Superwall with the new state
        updateSuperwallSubscriptionStatus()
    }

    // MARK: - Paywall Logic

    func shouldShowPaywall() -> PaywallType {
        return state.requiredPaywall
    }

    func getPaywallProducts(for type: PaywallType) -> [String] {
        switch type {
        case .onboarding:
            return ["yearly", "quarterly", "weekly"]
        case .trialExpired:
            return ["yearlynt"]
        case .normalUpgrade:
            return ["yearlynt", "quarterly", "weekly"]
        case .none:
            return []
        }
    }

    /// Get the appropriate paywall placement based on user state
    func getPaywallPlacement() -> String {
        let paywallType = shouldShowPaywall()

        // For normal upgrade, use specific paywall based on current plan
        if paywallType == .normalUpgrade, let currentPlan = state.currentPlan {
            return "normal_upgrade_\(currentPlan.rawValue)" // normal_upgrade_quarterly, etc.
        }

        // For other cases, use the standard placement
        return paywallType.rawValue
    }

    /// Get paywall configuration with current plan context
    func getPaywallConfig(for type: PaywallType) -> PaywallConfig {
        let products = getPaywallProducts(for: type)

        return PaywallConfig(
            type: type,
            products: products,
            currentPlan: state.currentPlan,
            isPaidUser: state.isPaidSubscriber,
            trialStatus: state.trialStatus,
            usageCount: state.usageCount,
            usageLimit: state.usageLimit
        )
    }

    // MARK: - Persistence

    private func persistState() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(state)
            UserDefaults.standard.set(data, forKey: "subscription_state")
        } catch {
            print("❌ Failed to encode subscription state: \(error)")
        }
    }

    private func loadPersistedState() {
        guard let data = UserDefaults.standard.data(forKey: "subscription_state") else {
            return
        }

        let decoder = JSONDecoder()
        do {
            let loadedState = try decoder.decode(SubscriptionState.self, from: data)
            state = loadedState
            print("📱 Loaded persisted subscription state")
        } catch {
            print("❌ Failed to decode subscription state: \(error)")
        }
    }

    // MARK: - Testing Helpers (Development Only)

    /// Temporarily bypass Superwall for testing (development only)
    func enableTestingMode() {
        #if DEBUG
        print("🧪 TESTING MODE: Bypassing Superwall paywalls")

        // Set user as active subscriber for testing
        state.isPaidSubscriber = true
        state.currentPlan = .yearly
        persistState()
        updateSuperwallSubscriptionStatus()

        print("✅ Testing mode enabled - user marked as premium subscriber")
        #endif
    }

    /// Disable testing mode (development only)
    func disableTestingMode() {
        #if DEBUG
        print("🔄 Disabling testing mode")

        // Reset to inactive state
        state.isPaidSubscriber = false
        state.currentPlan = nil
        persistState()
        updateSuperwallSubscriptionStatus()

        print("✅ Testing mode disabled - user marked as free")
        #endif
    }

    // MARK: - Reset (for testing/logout)

    func reset() {
        state = SubscriptionState()
        UserDefaults.standard.removeObject(forKey: "subscription_state")
        print("🔄 Subscription state reset")
    }
}

/// Configuration data to pass to Superwall paywalls
struct PaywallConfig {
    let type: PaywallType
    let products: [String]
    let currentPlan: AppSubscriptionPlan?
    let isPaidUser: Bool
    let trialStatus: TrialStatus
    let usageCount: Int
    let usageLimit: Int

    /// The default product ID to preselect (for Superwall's selectedIndex)
    var defaultProductId: String {
        // For normal upgrade paywall, preselect the current plan
        if type == .normalUpgrade, let plan = currentPlan {
            return plan.rawValue
        }
        // For other paywalls, no default selection
        return ""
    }

    /// Convert to dictionary for Superwall custom properties
    var customProperties: [String: Any] {
        return [
            "paywall_type": type.rawValue,
            "products": products,
            "current_plan": currentPlan?.rawValue ?? "",
            "default_product_id": defaultProductId,  // Superwall uses this for selectedIndex
            "is_paid_user": isPaidUser,
            "trial_status": trialStatus.rawValue,
            "usage_count": usageCount,
            "usage_limit": usageLimit,
            "should_preselect_current": type == .normalUpgrade && currentPlan != nil
        ]
    }
}