//
//  FullBodyPhotoView.swift
//  SnatchShot
//
//  Created by Rushant on 23/09/25.
//

import SwiftUI
import PhotosUI
import SuperwallKit

struct FullBodyPhotoView: View {
    @AppStorage("hasCompletedUserVerification") private var hasCompletedUserVerification = false
    @AppStorage("hasCompletedFacePhoto") private var hasCompletedFacePhoto = false

    @State private var fullBodyPhoto: UIImage? = nil
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showContent = false
    @State private var selectedItems: [PhotosPickerItem] = []

    // Body photo upload states
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var showSuccessPopup = false
    @State private var uploadError: String? = nil


    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.075, green: 0.082, blue: 0.102)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: {
                        // Go back to face photo
                        hasCompletedFacePhoto = false
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
                    Text("Full Body Photo")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Show off the whole vibe. One full-body snap lets our AI tailor pose tips to your unique shape and style")
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
                    Text("📸 Take Full Body Photo")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Choose how to add your photo")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Photo area - shows buttons when no photo, photo when taken
                    ZStack {
                        if let photo = fullBodyPhoto {
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
                                                fullBodyPhoto = nil // Clear photo to show buttons again
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
                        // Only complete verification if photo is uploaded successfully
                        if uploadSuccess {
                            // Show onboarding paywall (yearly plan selection)
                            Superwall.shared.register(placement: "onboarding")
                            print("💰 Superwall register called with placement: onboarding")
                            // Complete verification - paywall shows but doesn't block the flow
                            hasCompletedUserVerification = true
                        }
                    }) {
                        HStack {
                            if isUploading {
                                Text("Uploading...")
                                    .font(.system(size: 18, weight: .semibold))
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(uploadSuccess ? "Complete Verification" : fullBodyPhoto != nil ? "Uploading..." : "Take Full Body Photo First")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(uploadSuccess ? 0.9 : 0.4),
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(uploadSuccess ? 0.7 : 0.3),
                                    Color(red: 0.600, green: 0.545, blue: 0.941).opacity(uploadSuccess ? 0.8 : 0.4)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(uploadSuccess ? 0.3 : 0.1), radius: 10, x: 0, y: 5)
                    }
                    .disabled(!uploadSuccess || isUploading)

                    // Show error message if upload failed
                    if let error = uploadError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60) // Match PersonalizationView button position exactly
            }

            // Upload loading overlay
            if isUploading {
                ZStack {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("Uploading your photo...")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("This may take a few seconds")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            // Success popup
            if showSuccessPopup {
                ZStack {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 80, height: 80)

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Photo Uploaded! 🎉")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                        Text("Your full body photo has been uploaded successfully. You're all set to start creating amazing poses!")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Button(action: {
                            showSuccessPopup = false

                            // Show onboarding paywall (yearly plan selection)
                            Superwall.shared.register(placement: "onboarding")
                            print("💰 Superwall register called with placement: onboarding (success popup)")
                            // Complete verification - paywall shows but doesn't block the flow
                            hasCompletedUserVerification = true
                        }) {
                            Text("Start Creating Poses")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 0.600, green: 0.545, blue: 0.941))
                                .cornerRadius(16)
                        }
                    }
                    .padding(32)
                    .background(Color(red: 0.075, green: 0.082, blue: 0.102))
                    .cornerRadius(24)
                    .padding(.horizontal, 20)
                }
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
                    fullBodyPhoto = sampleImage
                    showCamera = false
                    // Start upload process
                    Task {
                        await uploadBodyPhoto(sampleImage)
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
                    fullBodyPhoto = image
                    // Start upload process
                    await uploadBodyPhoto(image)
                }
            }

            // Clear selection and dismiss picker
            selectedItems.removeAll()
            showPhotoPicker = false
        }
    }

    private func uploadBodyPhoto(_ image: UIImage) async {
        isUploading = true
        uploadError = nil

        // Get user ID from UserDefaults (stored during signup)
        guard let userId = UserDefaults.standard.string(forKey: "database_user_id") else {
            uploadError = "User ID not found. Please restart the app."
            isUploading = false
            return
        }

        do {
            print("📤 Starting body photo upload...")
            let (reference, _) = try await DatabaseService.shared.uploadReferenceImage(
                image: image,
                referenceType: "body",
                userId: userId,
                tags: [],
                categories: []
            )

            print("✅ Body photo uploaded successfully: \(reference._id)")
            uploadSuccess = true
            showSuccessPopup = true

        } catch DatabaseError.serverError(let message) {
            uploadError = "Upload failed: \(message)"
            print("❌ Body photo upload server error: \(message)")
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
            print("❌ Body photo upload error: \(error)")
        }

        isUploading = false
    }
}

#Preview {
    FullBodyPhotoView()
}
