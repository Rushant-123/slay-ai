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

        // Configure Google Sign In (critical - needs to be immediate)
        let clientID = Configuration.shared.googleClientID
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        // Initialize critical SDKs immediately on main thread
        initializeCriticalSDKs()

        // Initialize remaining third-party SDKs in background (non-blocking)
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.initializeRemainingSDKs()
        }

        return true
    }

    private func initializeCriticalSDKs() {
        // Mixpanel is now initialized in SnatchShotApp.init()
    }

    private func initializeRemainingSDKs() {
        // Configure AppsFlyer (properties set on main thread)
        let appsFlyerKey = Configuration.shared.appsFlyerDevKey
        let appleAppID = Configuration.shared.appleAppID

        DispatchQueue.main.async {
            AppsFlyerLib.shared().appsFlyerDevKey = appsFlyerKey
            AppsFlyerLib.shared().appleAppID = appleAppID
            AppsFlyerLib.shared().delegate = self
            #if DEBUG
            AppsFlyerLib.shared().isDebug = true
            #endif
        }

        // Start AppsFlyer in background after a short delay to ensure configuration is set
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {
            DispatchQueue.main.async {
                AppsFlyerLib.shared().start()
            }
        }

        // Superwall is configured in SnatchShotApp.init()

        print("✅ Remaining third-party SDKs initialized in background")

        // Debug: Print configuration status (only in debug builds)
        #if DEBUG
        Configuration.shared.printConfiguration()
        #endif
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
