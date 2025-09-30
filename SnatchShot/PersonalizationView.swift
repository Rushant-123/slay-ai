//
//  PersonalizationView.swift
//  SnatchShot
//
//  Created by Rushant on 16/09/25.
//

#if os(iOS)
import SwiftUI
import AVFoundation
import Photos
import CoreLocation
import StoreKit
#endif

// Analytics
import Foundation

// Simple padlock shape that sits on card edge
struct PadlockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Simple rounded rectangle for the padlock body
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width * 0.2, height: rect.width * 0.2))
        
        return path
    }
}

struct PersonalizationView: View {
    @EnvironmentObject var cameraService: CameraService
    @AppStorage("hasCompletedPersonalization") private var hasCompletedPersonalization = false
    @AppStorage("hasCompletedSignUp") private var hasCompletedSignUp = false
    @State private var showContent = false
    @State private var currentStep = 0

    // Permission handling states
    @State private var isRequestingPermissions = false
    @State private var showPermissionResults = false
    @State private var permissionResults: [String: Bool] = [:]
    @State private var hasShownRating = false

    // MARK: - Permission Request Logic
    private func requestPermissions() {
        isRequestingPermissions = true
        permissionResults = [:]

        Task {
            // Request permissions in parallel
            async let cameraResult = requestCameraPermission()
            async let photoResult = requestPhotoLibraryPermission()
            async let microphoneResult = requestMicrophonePermission()
            async let locationResult = requestLocationPermission()

            let results = await [cameraResult, photoResult, microphoneResult, locationResult]

            await MainActor.run {
                permissionResults = [
                    "Camera": results[0],
                    "Photo Library": results[1],
                    "Microphone": results[2],
                    "Location": results[3]
                ]

                // Initialize camera if permission was granted
                if results[0] { // cameraResult
                    cameraService.initializeCameraAfterPermissions()
                }

                // Enable auto-save to library if photo permission was granted
                if results[1] { // photoResult
                    cameraService.autoSaveToLibrary = true
                }

                isRequestingPermissions = false
                showPermissionResults = true
            }
        }
    }

    private func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestPhotoLibraryPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestLocationPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            let locationManager = CLLocationManager()
            locationManager.requestWhenInUseAuthorization()
            // Note: We can't directly check the result here as iOS shows the dialog
            // We'll assume it's requested and let the user decide
            continuation.resume(returning: true)
        }
    }

    private func proceedToNextStep() {
        if !hasShownRating {
            hasShownRating = true
            // Show Apple's native rating dialog directly
            SKStoreReviewController.requestReview()

            // Proceed to personalization completion after a brief delay
            // to allow the rating dialog to appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.hasCompletedPersonalization = true
                }
            }
        } else {
            // After rating, proceed to personalization completion
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                hasCompletedPersonalization = true
            }
        }
    }

    var body: some View {
        ZStack {
            // Dark background (#13151A)
            Color(red: 0.075, green: 0.082, blue: 0.102)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: {
                        // Go back to sign up
                        hasCompletedSignUp = false
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)

                // Header text area (consistent with onboarding)
                VStack(spacing: 16) {
                    Text("Thank you for trusting us")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)

                    Text("Now let's personalize Slay AI for you")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                }
                .frame(height: 160)
                .padding(.top, 60)

                Spacer()

                // Main Content
                VStack(spacing: 0) {
                    // Privacy & Security Card
                    ZStack {
                        // Single card background
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                            )
                            .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.2), radius: 6, x: 0, y: 2)

                        // Simple padlock sitting on card edge
                        VStack(spacing: 0) {
                            // Padlock positioned on top edge
                            PadlockShape()
                                .fill(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.9))
                                .frame(width: 50, height: 38)
                                .overlay(
                                    PadlockShape()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                                .overlay(
                                    // Lock icon inside the padlock
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                )
                                .offset(y: -15) // Position so it sits on the card edge

                            Spacer()

                            // Card content
                            VStack(spacing: 12) {
                                Text("Your Privacy & Security Matters to Us")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)

                                Text("This is a women-only app. We promise to always keep your personal information private and secure.")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)
                                    .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 30)
                        }
                        .frame(height: 200)
                    }
                    .padding(.horizontal, 40)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
                }

                Spacer()

                // Fixed bottom button area - matching onboarding exactly
                VStack(spacing: 16) {
                    Button(action: {
                        AnalyticsService.shared.trackPersonalizationCompleted()
                        requestPermissions()
                    }) {
                        HStack {
                            Text("Let's Get Started")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.9),
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.7),
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.3), radius: 10, x: 0, y: 5)
                        .opacity(showContent ? 1.0 : 0.0)
                        .scaleEffect(showContent ? 1.0 : 0.9)
                    }
                    .padding(.horizontal, 40)

                    // Additional reassurance
                    Text("✨ Your photos are processed securely and never stored permanently")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 10)
                        .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }

            // Permission Request Loading Overlay
            if isRequestingPermissions {
                Color.black.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(Color(red: 0.600, green: 0.545, blue: 0.941))

                            Text("Setting up permissions...")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)

                            Text("We need access to camera, photos, microphone, and location to provide the best experience")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    )
            }

            // Permission Results Overlay
            if showPermissionResults {
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: 24) {
                            Text("Permissions Setup Complete")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            VStack(spacing: 16) {
                                ForEach(Array(permissionResults.keys.sorted()), id: \.self) { permission in
                                    HStack {
                                        Text(permission)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)

                                        Spacer()

                                        Image(systemName: permissionResults[permission] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(permissionResults[permission] == true ? Color.green : Color.red)
                                            .font(.system(size: 20))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.vertical, 20)

                            if permissionResults.values.contains(false) {
                                Text("Some permissions were denied. You can grant them later in Settings if needed.")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }

                            Button(action: {
                                showPermissionResults = false
                                proceedToNextStep()
                            }) {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.9),
                                                Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.7),
                                                Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 40)
                    )
            }

        }
        .onAppear {
            // Track personalization started
            AnalyticsService.shared.trackPersonalizationStarted()

            // Animate content in
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
}

#Preview {
    PersonalizationView()
}
