import Foundation
import SuperwallKit
import StoreKit
import Mixpanel
import AppsFlyerLib

/// Manages all Superwall interactions including paywall presentation, subscription status, and analytics
final class SuperwallManager {
    // MARK: - Singleton
    
    static let shared = SuperwallManager()
    private init() {}
    
    // MARK: - Properties
    
    /// Tracks whether Superwall is ready to present paywalls
    private var isConfigured = false
    
    /// Current subscription state
    private var currentPlan: SubscriptionPlan = .none
    
    /// Current usage stats from WebSocket
    private var usageStats: UsageStats = .init()
    
    // MARK: - Types
    
    /// Available subscription plans
    enum SubscriptionPlan: String {
        case none
        case weekly
        case quarterly
        case yearly
        case yearlyTrial
        
        /// Available upgrade paths for each plan
        var availableUpgrades: [SubscriptionPlan] {
            switch self {
            case .none:
                return [.weekly, .quarterly, .yearly, .yearlyTrial]
            case .weekly:
                return [.quarterly, .yearly]
            case .quarterly:
                return [.yearly]
            case .yearly, .yearlyTrial:
                return [] // No upgrades available
            }
        }
        
        /// Whether this plan includes a trial
        var hasTrial: Bool {
            return self == .yearlyTrial
        }
    }
    
    /// Usage statistics from WebSocket
    struct UsageStats {
        var currentUsage: Int = 0
        var usageLimit: Int = 0
        var isLimitReached: Bool { 
            // Only consider limit reached if we have a valid limit
            usageLimit > 0 && currentUsage >= usageLimit
        }
    }
    
    // MARK: - Configuration
    
    /// Configures Superwall with the provided API key and purchase controller
    func configure() {
        // Create purchase controller for handling transactions
        let purchaseController = SuperwallPurchaseController()
        
        // Configure Superwall
        Superwall.configure(
            apiKey: "pk_zD2e3MR_FLmW0q5mFscV3",
            purchaseController: purchaseController
        )
        
        // Set initial subscription status
        let noEntitlements: Set<Entitlement> = []
        Superwall.shared.subscriptionStatus = .active(noEntitlements)
        print("🔄 Initial Superwall subscription status set to: no active entitlements")
        
        // Set up event handlers
        configureEventHandling()
        
        // Set initial attributes
        updateSuperwallAttributes()
        
        // Mark as configured
        isConfigured = true
        
        print("✅ Superwall configured with subscription status")
    }
    
    // MARK: - Event Handling
    
    private func configureEventHandling() {
        // Register for subscription status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionChange(_:)),
            name: .subscriptionStatusChanged,
            object: nil
        )
        
        // Set up event triggers for paywalls
        registerPaywallTriggers()
    }
    
    private func registerPaywallTriggers() {
        // Register all possible paywall triggers once
        let paywalls = [
            (event: "onboarding", placement: "onboarding_paywall"),
            (event: "trial_ended", placement: "trial_ended_paywall"),
            (event: "upgrade_weekly", placement: "upgrade_weekly_paywall"),
            (event: "upgrade_quarterly", placement: "upgrade_quarterly_paywall"),
            (event: "upgrade_yearly", placement: "upgrade_yearly_paywall")
        ]
        
        // Register each paywall with its event
        for paywall in paywalls {
            print("📝 Registering paywall for event: \(paywall.event)")
            
            // Base params for this paywall
            let params: [String: NSObject] = [
                "event": paywall.event as NSString,
                "placement": paywall.placement as NSString
            ]
            
            // Register the paywall
            Superwall.shared.register(
                placement: paywall.placement,
                params: params
            ) { [weak self] in
                self?.trackEvent("\(paywall.event)_paywall_shown")
            }
        }
        
        print("✅ Superwall paywall triggers registered")
    }
    
    private func triggerPaywall(placement: String, additionalParams: [String: NSObject] = [:]) {
        // Get the available plans for this placement
        let availablePlans: [String]
        switch placement {
        case "onboarding_paywall":
            availablePlans = ["weekly", "quarterly", "yearly", "yearly_trial"]
        case "trial_ended_paywall":
            availablePlans = ["yearly"] // Only upgrade to full yearly
        case "upgrade_weekly_paywall":
            availablePlans = ["quarterly", "yearly"]
        case "upgrade_quarterly_paywall":
            availablePlans = ["yearly"]
        case "upgrade_yearly_paywall":
            availablePlans = ["yearly_premium"]
        default:
            availablePlans = []
        }
        
        // Build the event parameters
        var params: [String: NSObject] = [
            "current_plan": currentPlan.rawValue as NSString,
            "usage_current": usageStats.currentUsage as NSNumber,
            "usage_limit": usageStats.usageLimit as NSNumber,
            "available_plans": availablePlans as NSArray
        ]
        
        // Add any additional parameters
        for (key, value) in additionalParams {
            params[key] = value
        }
        
        print("🎯 Triggering paywall: \(placement)")
        print("📊 Params: \(params)")
        
        // Present the paywall
        Superwall.shared.register(
            placement: placement,
            params: params
        )
    }
    
    // MARK: - Subscription Management
    
    @objc private func handleSubscriptionChange(_ notification: Notification) {
        if let planString = notification.userInfo?["plan"] as? String,
           let plan = SubscriptionPlan(rawValue: planString) {
            currentPlan = plan
            updateSuperwallAttributes()
        }
    }
    
    /// Handle usage updates from WebSocket
    func handleUsageUpdate(currentUsage: Int, limit: Int) {
        let oldStats = usageStats
        usageStats = UsageStats(currentUsage: currentUsage, usageLimit: limit)
        
        print("📊 Usage update - Current: \(currentUsage)/\(limit) (Plan: \(currentPlan.rawValue))")
        
        // Check if we just hit the limit for trial users
        if currentPlan == .yearlyTrial && 
           !oldStats.isLimitReached && 
           usageStats.isLimitReached {
            print("⚠️ Trial usage limit reached - showing upgrade paywall")
            
            // Trigger trial ended paywall
            triggerPaywall(placement: "trial_ended", additionalParams: [
                "usage_current": currentUsage as NSNumber,
                "usage_limit": limit as NSNumber
            ])
        }
        
        // Update attributes to reflect new usage
        updateSuperwallAttributes()
    }
    
    func updateSuperwallAttributes() {
        // Set subscription status based on plan
        let entitlements: Set<Entitlement> = currentPlan != .none ? [.init(id: currentPlan.rawValue)] : []
        Superwall.shared.subscriptionStatus = .active(entitlements)
        print("🔄 Superwall subscription status set to: \(currentPlan.rawValue)")
        
        // Then update other attributes
        let attributes: [String: Any] = [
            "subscription_status": currentPlan != .none ? "active" : "inactive",
            "current_plan": currentPlan.rawValue,
            "has_trial": currentPlan.hasTrial,
            "available_upgrades": currentPlan.availableUpgrades.map { $0.rawValue },
            "usage_current": usageStats.currentUsage,
            "usage_limit": usageStats.usageLimit,
            "usage_limit_reached": usageStats.isLimitReached
        ]
        
        // Set attributes
        Superwall.shared.setUserAttributes(attributes)
        print("🔄 Superwall user attributes set: \(attributes)")
    }
    
    /// Show the appropriate upgrade paywall based on current plan
    func showUpgradePaywall() {
        let placement: String
        switch currentPlan {
        case .weekly:
            placement = "upgrade_weekly"
        case .quarterly:
            placement = "upgrade_quarterly"
        case .yearly:
            placement = "upgrade_yearly"
        case .yearlyTrial, .none:
            placement = "onboarding_paywall" // Fallback to onboarding if no plan
        }
        
        triggerPaywall(placement: placement)
    }
    
    
    // MARK: - Analytics
    
    private func trackEvent(_ event: String, properties: [String: MixpanelType] = [:]) {
        // Track in Mixpanel
        Mixpanel.mainInstance().track(event: event, properties: properties)
        
        // Track in AppsFlyer if needed
        if event.hasPrefix("subscription_") || event.hasPrefix("trial_") {
            // Convert MixpanelType to AppsFlyer format
            let afProperties = properties.mapValues { value -> Any in
                if let bool = value as? Bool {
                    return bool
                } else if let number = value as? NSNumber {
                    return number
                } else if let string = value as? String {
                    return string
                } else {
                    return String(describing: value)
                }
            }
            AppsFlyerLib.shared().logEvent(event, withValues: afProperties)
        }
        
        print("📊 Tracked event: \(event) properties: \(properties)")
    }
    
    // MARK: - Public Interface
    
    /// Triggers a paywall presentation for the given placement
    func triggerPaywall(for placement: String, params: [String: NSObject] = [:]) {
        guard isConfigured else {
            print("⚠️ Superwall not configured")
            return
        }
        
        // Track the attempt
        trackEvent("paywall_trigger_attempted", properties: ["placement": placement as MixpanelType])
        
        // Register the placement with Superwall
        Superwall.shared.register(placement: placement, params: params)
    }
    
    /// Updates the subscription plan
    func updateSubscriptionPlan(_ plan: SubscriptionPlan) {
        currentPlan = plan
        updateSuperwallAttributes()
        
        // Track subscription status change
        trackEvent("subscription_status_changed", properties: [
            "plan": plan.rawValue as MixpanelType,
            "is_trial": plan.hasTrial as MixpanelType,
            "has_subscription": (plan != .none) as MixpanelType
        ])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
