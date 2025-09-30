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
#endif

@main
struct SnatchShotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedSignUp") private var hasCompletedSignUp = false
    @AppStorage("hasCompletedPersonalization") private var hasCompletedPersonalization = false
    @AppStorage("hasCompletedFacePhoto") private var hasCompletedFacePhoto = false
    @AppStorage("hasCompletedUserVerification") private var hasCompletedUserVerification = false

    // Shared services for the entire app
    @StateObject private var cameraService = CameraService()
    @StateObject private var webSocketService = WebSocketService()

    init() {
        // 🔄 Reset for testing - uncomment to reset all flags and test full flow
        // resetAppStateForTesting() // COMMENTED OUT - direct start

        // Start AppsFlyer tracking
        AppsFlyerLib.shared().start()

        // Check database connection on app start
        Task {
            await Self.checkDatabaseConnection()
        }
    }

    private func resetAppStateForTesting() {
        hasCompletedOnboarding = false
        hasCompletedSignUp = false
        hasCompletedPersonalization = false
        hasCompletedFacePhoto = false
        hasCompletedUserVerification = false
        print("🔄 App state reset for testing - will show full flow")
    }

    private static func checkDatabaseConnection() async {
        do {
            let isHealthy = try await DatabaseService.shared.healthCheck()
            if isHealthy {
                print("🗄️ Database connection: ✅ Healthy")
            } else {
                print("🗄️ Database connection: ❌ Unhealthy")
            }
        } catch {
            print("🗄️ Database connection: ❌ Failed to check - \(error.localizedDescription)")
            print("ℹ️ Make sure your database server is running on http://13.221.107.42:4000")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Always show full flow for testing (onboarding -> signup -> personalization -> verification -> camera) - Slay AI
            // Remove the .onAppear modifiers in OnboardingView and SignUpView for production
            ZStack {
                if !hasCompletedOnboarding {
                    OnboardingView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else if !hasCompletedSignUp {
                    SignUpView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else if !hasCompletedPersonalization {
                    PersonalizationView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else if !hasCompletedFacePhoto {
                    FacePhotoView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else if !hasCompletedUserVerification {
                    FullBodyPhotoView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
                } else {
                    CameraView()
                        .environmentObject(cameraService)
                        .environmentObject(webSocketService)
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
