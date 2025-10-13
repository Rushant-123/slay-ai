//
//  SnatchShotApp.swift
//  SnatchShot
//
//  Created by Rushant on 14/09/25.
//

#if os(iOS)
import SwiftUI
import GoogleSignIn
import SuperwallKit
import AppsFlyerLib
import Mixpanel
#endif

@main
struct SnatchShotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedSignUp") private var hasCompletedSignUp = false
    @AppStorage("hasCompletedPersonalization") private var hasCompletedPersonalization = false
    @AppStorage("hasCompletedFacePhoto") private var hasCompletedFacePhoto = false
    @AppStorage("hasCompletedUserVerification") private var hasCompletedUserVerification = false
    @AppStorage("isGuestMode") private var isGuestMode = false

    // Shared services for the entire app
    @StateObject private var cameraService = CameraService()
    @StateObject private var webSocketService = WebSocketService()

    init() {
        // Initialize Mixpanel first since other SDKs depend on it
        Mixpanel.initialize(token: "d41d8cd98f00b204e9800998ecf8427e", trackAutomaticEvents: true)
        print("✅ Mixpanel initialized on main thread")
        
        // Configure Superwall after analytics are ready
        SuperwallManager.shared.configure()
        
        // Initialize subscription state
        SuperwallManager.shared.updateSubscriptionPlan(.none)
        
        // AppsFlyer is now started in AppDelegate (background initialization)
    }

    private func resetAppStateForTesting() {
        hasCompletedOnboarding = false
        hasCompletedSignUp = false
        hasCompletedPersonalization = false
        hasCompletedFacePhoto = false
        hasCompletedUserVerification = false
        print("🔄 App state reset for testing - will show full flow")
    }


    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasCompletedOnboarding {
                    OnboardingView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else if !hasCompletedSignUp && !isGuestMode {
                    SignUpView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else if !hasCompletedPersonalization && !isGuestMode {
                    PersonalizationView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else if !hasCompletedFacePhoto && !isGuestMode {
                    FacePhotoView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else if !hasCompletedUserVerification && !isGuestMode {
                    FullBodyPhotoView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else {
                    CameraView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                }
            }
            .onAppear {
                // Handle scene lifecycle for Superwall
                NotificationCenter.default.addObserver(forName: UIScene.willConnectNotification, object: nil, queue: .main) { _ in
                    SuperwallManager.shared.updateSuperwallAttributes()
                }
                NotificationCenter.default.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { _ in
                    SuperwallManager.shared.updateSuperwallAttributes()
                }
            }
            .task {
                // 🌐 Establish WebSocket connection early for reduced latency
                await connectWebSocketEarly(webSocketService)
            }
        }
    }

    private func connectWebSocketEarly(_ webSocketService: WebSocketService) async {
        print("🌐 Establishing early WebSocket connection for reduced latency...")

        // WebSocket will be connected after user authentication in SignUpView
        await MainActor.run {
            // Connect the camera service to WebSocket service for AI settings
            webSocketService.setCameraService(cameraService)
        }

        print("✅ Camera service connected to WebSocket service (connection will happen after authentication)")
    }
}
