//
//  FacePhotoView.swift
//  SnatchShot
//
//  Created by Rushant on 23/09/25.
//

import SwiftUI
import PhotosUI

// Database service for API calls
private let facePhotoDatabaseService = DatabaseService.shared

struct FacePhotoView: View {
    @EnvironmentObject var webSocketService: WebSocketService

    @AppStorage("hasCompletedFacePhoto") private var hasCompletedFacePhoto = false
    @AppStorage("hasCompletedPersonalization") private var hasCompletedPersonalization = false

    @State private var facePhoto: UIImage? = nil
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showContent = false
    @State private var selectedItems: [PhotosPickerItem] = []

    // Face verification states
    @State private var isVerifying = false
    @State private var verificationResult: GenderDetectionResult? = nil
    @State private var showVerificationPopup = false
    @State private var verificationError: String? = nil

    // Computed property to determine if user can proceed
    private var canProceed: Bool {
        if let result = verificationResult {
            return result.decision != "reject"
        }
        return false
    }

    var body: some View {
        ZStack {
                // Dark background
                Color(red: 0.075, green: 0.082, blue: 0.102)
                    .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: {
                        // Go back to personalization
                        hasCompletedPersonalization = false
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

                // Header text area
                VStack(spacing: 16) {
                    Text("Ready for Your Close-Up?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("A quick gender check keeps our community women-only, so you can pose and post with total confidence")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(height: 160)
                .padding(.top, 60)

                Spacer()

                // Main content area
                VStack(spacing: 20) {
                    Text("📸 Take Face Photo")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Choose how to add your photo")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Photo area - shows buttons when no photo, photo when taken
                    ZStack {
                        if let photo = facePhoto {
                            // Show uploaded photo
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    // Retake button overlay
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                facePhoto = nil // Clear photo to show buttons again
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white.opacity(0.8))
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())
                                            }
                                            .padding(8)
                                        }
                                        Spacer()
                                    }
                                )
                        } else {
                            // Show camera and gallery buttons
                            HStack(spacing: 20) {
                                Button(action: { showCamera = true }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.white)

                                        Text("Camera")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(width: 100, height: 100)
                                    .background(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }

                                Button(action: { showPhotoPicker = true }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 32))
                                            .foregroundColor(.white)

                                        Text("Gallery")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(width: 100, height: 100)
                                    .background(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                    }
                    .frame(height: 120) // Fixed height to prevent layout shifts
                }

                Spacer()

                // Bottom buttons
                VStack(spacing: 16) {
                    Button(action: {
                        // Only advance if face photo is verified and not rejected
                        if let result = verificationResult, result.decision != "reject" {
                            hasCompletedFacePhoto = true
                        }
                    }) {
                        HStack {
                            if isVerifying {
                                Text("Verifying...")
                                    .font(.system(size: 18, weight: .semibold))
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if let result = verificationResult {
                                Text(result.decision == "reject" ? "Verification Failed" : "Next: Full Body Photo")
                                    .font(.system(size: 18, weight: .semibold))

                                if result.decision != "reject" {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            } else {
                                Text(facePhoto != nil ? "Verifying Photo..." : "Take Face Photo First")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(canProceed ? 0.9 : 0.4),
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(canProceed ? 0.7 : 0.3),
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(canProceed ? 0.8 : 0.4)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(canProceed ? 0.3 : 0.1), radius: 10, x: 0, y: 5)
                    }
                    .disabled(!canProceed || isVerifying)

                    // Show error message if verification failed
                    if let error = verificationError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60) // Match PersonalizationView button position exactly (40 + 20 for reassurance text)
            }

            // Loading overlay during verification
            if isVerifying {
                ZStack {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("Verifying your photo...")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("This may take a few seconds")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            // Face Verification Popup
            if showVerificationPopup, let result = verificationResult {
                FaceVerificationPopup(
                    result: result,
                    onContinue: {
                        showVerificationPopup = false
                        // Allow progression for pass/review, block for reject
                        if result.decision != "reject" {
                            hasCompletedFacePhoto = true
                        }
                    },
                    onRetry: {
                        showVerificationPopup = false
                        verificationResult = nil
                        facePhoto = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showCamera) {
            // Camera view placeholder - simulate taking a photo
            VStack(spacing: 20) {
                Text("Camera View")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("This is a placeholder for the camera view.\nIn a real app, this would show the camera interface.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    // Simulate taking a photo
                    let sampleImage = UIImage(systemName: "person.fill") ?? UIImage()
                    facePhoto = sampleImage
                    showCamera = false
                    // Start verification process
                    Task {
                        await verifyFacePhoto(sampleImage)
                    }
                }) {
                    Text("Take Sample Photo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .presentationDetents([.height(300)])
            .presentationBackground(Color(red: 0.075, green: 0.082, blue: 0.102))
        }
        .sheet(isPresented: $showPhotoPicker) {
            // Photo picker
            VStack {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                    Text("Select Photo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding()
                }
            }
            .presentationDetents([.height(200)])
            .presentationBackground(Color(red: 0.075, green: 0.082, blue: 0.102))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
        .onChange(of: selectedItems) { oldItems, newItems in
            // Handle photo selection
            guard let item = newItems.first else { return }

            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    facePhoto = image
                        // Start verification process
                    await verifyFacePhoto(image)
                }
            }

            // Clear selection and dismiss picker
            selectedItems.removeAll()
            showPhotoPicker = false
        }
    }

    private func verifyFacePhoto(_ image: UIImage) async {
        isVerifying = true
        verificationError = nil

        // Get user ID from UserDefaults (stored during signup)
        guard let userId = UserDefaults.standard.string(forKey: "database_user_id") else {
            verificationError = "User ID not found. Please restart the app."
            isVerifying = false
            return
        }

        do {
            print("🔍 Starting face photo verification...")
            let (reference, genderResult) = try await facePhotoDatabaseService.uploadReferenceImage(
                image: image,
                referenceType: "face",
                userId: userId
            )

            // Check if verification was successful
            if let genderResult = genderResult {
                verificationResult = genderResult
                showVerificationPopup = true
                print("✅ Face verification complete: \(genderResult.decision ?? "unknown")")

                // TODO: Track the verification result
                // AnalyticsService.shared.trackFaceVerificationResult(decision: genderResult.decision ?? "unknown")
            } else {
                // No gender detection result (shouldn't happen for face photos)
                verificationError = "Verification failed: No gender detection result received"
                print("❌ Face verification failed: No gender detection result")
            }

        } catch DatabaseError.serverError(let message) {
            verificationError = "Verification failed: \(message)"
            print("❌ Face verification server error: \(message)")
        } catch {
            // Handle NSError from DatabaseService (which includes backend error messages)
            if let nsError = error as? NSError,
               let errorMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                verificationError = "Verification failed: \(errorMessage)"
                print("❌ Face verification backend error: \(errorMessage)")
            } else {
                verificationError = "Verification failed: \(error.localizedDescription)"
                print("❌ Face verification error: \(error)")
            }
        }

        isVerifying = false
    }
}

// MARK: - Face Verification Popup
struct FaceVerificationPopup: View {
    let result: GenderDetectionResult
    let onContinue: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                // Icon based on result
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 80, height: 80)

                    Image(systemName: iconName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }

                // Title
                Text(titleText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                // Message
                Text(messageText)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)


                // Buttons
                VStack(spacing: 12) {
                    if result.decision != "reject" {
                        // Continue button for pass/review
                        Button(action: onContinue) {
                            Text(continueButtonText)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 0.600, green: 0.545, blue: 0.941))
                                .cornerRadius(16)
                        }
                    }

                    // Retry button (always available)
                    Button(action: onRetry) {
                        Text("Try Different Photo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(32)
            .background(Color(red: 0.075, green: 0.082, blue: 0.102))
            .cornerRadius(24)
            .padding(.horizontal, 20)
            }
        }

    private var iconName: String {
        switch result.decision {
        case "pass": return "checkmark.circle.fill"
        case "review": return "clock.circle.fill"
        case "reject": return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var iconBackgroundColor: Color {
        switch result.decision {
        case "pass": return Color.green
        case "review": return Color.orange
        case "reject": return Color.red
        default: return Color.gray
        }
    }

    private var titleText: String {
        switch result.decision {
        case "pass": return "Verified! ✅"
        case "review": return "Under Review"
        case "reject": return "Verification Failed"
        default: return "Verification Complete"
        }
    }

    private var messageText: String {
        switch result.decision {
        case "pass": return "Your face photo has been verified successfully. Welcome to our women-only community!"
        case "review": return "We've received your application and your account is currently under manual review. You'll be notified once the review is complete."
        case "reject": return "We're sorry, but your photo doesn't meet our community guidelines. Please try uploading a different photo."
        default: return "Face verification complete."
        }
    }

    private var continueButtonText: String {
        switch result.decision {
        case "pass": return "Continue to Body Photo"
        case "review": return "Continue to Body Photo"
        default: return "Continue"
        }
    }
}

#Preview {
    FacePhotoView()
}
