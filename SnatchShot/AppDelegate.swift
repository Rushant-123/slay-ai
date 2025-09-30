//
//  AppDelegate.swift
//  SnatchShot
//
//  Created by Rushant on 16/09/25.
//

import UIKit
import GoogleSignIn
import SuperwallKit
import AppsFlyerLib
import Mixpanel

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // Configure Google Sign In
        let clientID = Configuration.shared.googleClientID
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        // Configure AppsFlyer
        AppsFlyerLib.shared().appsFlyerDevKey = Configuration.shared.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = Configuration.shared.appleAppID
        AppsFlyerLib.shared().delegate = self
        #if DEBUG
        AppsFlyerLib.shared().isDebug = true
        #endif

        // Configure Mixpanel
        Mixpanel.initialize(token: Configuration.shared.mixpanelToken, trackAutomaticEvents: true)

        // Configure Superwall with purchase controller for forwarding events
        let purchaseController = PurchaseController()
        Superwall.configure(
            apiKey: "pk_zD2e3MR_FLmW0q5mFscV3",
            purchaseController: purchaseController
        )

        // Ensure subscription status is set immediately and also after a short delay
        // in case Superwall initialization is asynchronous
        Superwall.shared.subscriptionStatus = .inactive

        // Identify user with Superwall (use device ID for now)
        let userId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_user"
        Superwall.shared.identify(userId: userId)

        // Set subscription status after identification
        Superwall.shared.subscriptionStatus = .inactive

        // Double-check subscription status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Superwall.shared.subscriptionStatus = .inactive
            print("✅ Superwall subscription status double-checked after identification")
        }

        print("✅ Superwall configured, subscription status and user attributes set")

        // Debug: Print configuration status (remove in production)
        Configuration.shared.printConfiguration()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle Google Sign In URL callback
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - AppsFlyer Delegate
extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        print("📊 AppsFlyer conversion data: \(conversionInfo)")

        // Extract campaign information for Mixpanel user properties
        if let campaign = conversionInfo["campaign"] as? String {
            Mixpanel.mainInstance().people.set(property: "campaign_name", to: campaign)
        }
        if let mediaSource = conversionInfo["media_source"] as? String {
            Mixpanel.mainInstance().people.set(property: "campaign_source", to: mediaSource)
        }
    }

    func onConversionDataFail(_ error: Error) {
        print("❌ AppsFlyer conversion data error: \(error.localizedDescription)")
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        print("📊 AppsFlyer app open attribution: \(attributionData)")
    }

    func onAppOpenAttributionFailure(_ error: Error) {
        print("❌ AppsFlyer app open attribution error: \(error.localizedDescription)")
    }
}
