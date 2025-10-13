//
//  SignUpView.swift
//  SnatchShot
//
//  Created by Rushant on 16/09/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn
import Foundation
import SuperwallKit

struct SignUpView: View {
    @State private var slideOffset: Double = 0.15
    @AppStorage("hasCompletedSignUp") private var hasCompletedSignUp = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isAuthenticating = false
    @State private var authError: String?

    // Access WebSocket service for early connection
    @EnvironmentObject private var webSocketService: WebSocketService

    var body: some View {
        ZStack {
            // Before/After Background Images
            GeometryReader { geometry in
                ZStack {
                    // Before Image
                    Image("signup_before")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(1.0 - slideOffset)

                    // After Image
                    Image("signup_after")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(slideOffset)
                }
            }
            .edgesIgnoringSafeArea(.all)

            // Semi-transparent overlay for text readability
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: {
                        // Go back to onboarding
                        hasCompletedOnboarding = false
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
                // Title
                VStack(spacing: 16) {
                    Text("Ready to slay?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(height: 100)
                .padding(.top, 10)
                
                Spacer()

                // Background Image Slider
                VStack(spacing: 20) {
                    // Slider track and handle
                    ZStack(alignment: .leading) {
                        // Track
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 2)
                            .frame(width: 280)

                        // Handle
                        Circle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 20, height: 20)
                            .shadow(color: Color.black.opacity(0.2), radius: 3)
                            .offset(x: slideOffset * (280 - 20))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let width = 280.0 - 20 // Track width minus handle width
                                        let newX = min(max(0, value.location.x), width)
                                        slideOffset = newX / width
                                    }
                            )
                    }

                    // Before/After Labels
                    HStack {
                        Text("Before")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))

                        Spacer()

                        Text("After")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: 280)
                }

                Spacer()
                
                // Sign Up Options - Fixed positioning like onboarding
                VStack(spacing: 16) {
                    SignUpOptionsView(
                        isAuthenticating: $isAuthenticating,
                        authError: $authError
                    )
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Track signup page viewed
            AnalyticsService.shared.trackSignupPageViewed()
        }
    }
}

// MARK: - Sign Up Options View
struct SignUpOptionsView: View {
    @Binding var isAuthenticating: Bool
    @Binding var authError: String?
    @EnvironmentObject private var webSocketService: WebSocketService
    @AppStorage("hasCompletedSignUp") private var hasCompletedSignUp = false
    @AppStorage("isGuestMode") private var isGuestMode = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Apple Sign In
            ZStack {
                SignInWithAppleButton(.signIn) { request in
                    AnalyticsService.shared.trackSignupAppleSigninTapped()
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .cornerRadius(16)
                
                if isAuthenticating {
                    Color.black.opacity(0.7)
                        .frame(height: 56)
                        .cornerRadius(16)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
            }
            .padding(.horizontal, 40)
            
            // Google Sign In
            Button(action: {
                AnalyticsService.shared.trackSignupGoogleSigninTapped()
                signUpWithGoogle()
            }) {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                    Text(isAuthenticating ? "Signing in..." : "Continue with Google")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
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
            }
            .padding(.horizontal, 40)
            .disabled(isAuthenticating)

            // Guest/Demo Mode Button
            Button(action: {
                AnalyticsService.shared.trackSignupGuestModeTapped()
                continueAsGuest()
            }) {
                HStack {
                    Image(systemName: "eye")
                        .font(.system(size: 20))
                    Text("Demo Mode")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.horizontal, 40)
            .disabled(isAuthenticating)

            // Error Display
            if let error = authError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
            }
            
            // Terms and Privacy
            HStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Button("Terms") {
                    AnalyticsService.shared.trackSignupTermsLinkTapped()
                    // Open terms
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.9))
                
                Text("and")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Button("Privacy Policy") {
                    AnalyticsService.shared.trackSignupPrivacyLinkTapped()
                    // Open privacy policy
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        isAuthenticating = true
        authError = nil
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Extract user information
                let userId = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                
                print("Apple Sign In Success!")
                print("- Apple User ID: \(userId)")
                print("- Email: \(email ?? "Not provided (privacy)")")
                if let fullName = fullName {
                    let name = "\(fullName.givenName ?? "") \(fullName.familyName ?? "")".trimmingCharacters(in: .whitespaces)
                    print("- Name: \(name.isEmpty ? "Not provided (privacy)" : name)")
                } else {
                    print("- Name: Not provided (privacy)")
                }
                
                // Create user in database using Task
                Task {
                    await createUserInDatabase(with: appleIDCredential)
                }
            }
        case .failure(let error):
            authError = "Apple Sign In failed: \(error.localizedDescription)"
            print("Apple Sign In Error: \(error)")
            isAuthenticating = false
        }
    }
    
    private func signUpWithGoogle() {
        isAuthenticating = true
        authError = nil
        
        // Get the root view controller for presenting the Google Sign In
        guard let presentingViewController = getRootViewController() else {
            authError = "Unable to present Google Sign In"
            isAuthenticating = false
            return
        }
        
        // Google Sign In implementation
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { signInResult, error in
            if let error = error {
                self.authError = "Google Sign In failed: \(error.localizedDescription)"
                print("Google Sign In Error: \(error)")
                self.isAuthenticating = false
                return
            }
            
            if let signInResult = signInResult {
                let user = signInResult.user
                print("Google Sign In Success!")
                print("- User ID: \(user.userID ?? "N/A")")
                print("- Email: \(user.profile?.email ?? "N/A")")
                print("- Name: \(user.profile?.name ?? "N/A")")
                
                // Create user in database using Task
                Task {
                    await self.createUserInDatabase(with: user)
                }
            } else {
                self.authError = "Google Sign In was cancelled"
                self.isAuthenticating = false
            }
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    private func createUserInDatabase(with googleUser: GIDGoogleUser) async {
        guard let email = googleUser.profile?.email else {
            self.authError = "Google account email not available"
            self.isAuthenticating = false
            return
        }
        
        let userId = googleUser.userID ?? UUID().uuidString
        let firstName = googleUser.profile?.givenName
        let lastName = googleUser.profile?.familyName
        
        // Generate OAuth password for Google users
        let password = DatabaseService.shared.generateOAuthPassword(for: userId)
        
        // Create username
        let username = DatabaseService.shared.createUsername(
            from: email,
            firstName: firstName,
            lastName: lastName
        )
        
        do {
            print("📝 Creating user in database...")
            let dbUser = try await DatabaseService.shared.registerUser(
                email: email,
                password: password,
                userId: username,
                firstName: firstName,
                lastName: lastName,
                username: username
            )
            
            print("✅ User created successfully in database:")
            print("- Database User ID: \(dbUser.userId)")
            print("- Email: \(dbUser.email)")
            print("- User ID: \(dbUser.userId)")

            // Store the database user ID for future use
            UserDefaults.standard.set(dbUser.userId, forKey: "database_user_id")

            // Identify user with Superwall
            Superwall.shared.identify(userId: dbUser.userId)

            // Initialize subscription state for new user (Superwall handles status automatically)
            SubscriptionManager.shared.state = SubscriptionState() // Fresh state for new user

            // Complete sign up
            self.completeSignUp()
            
        } catch DatabaseError.serverError(let message) {
            print("❌ Database registration failed: \(message)")
            
            // Check if user already exists (409 Conflict)
            if message.contains("409") || message.contains("already exists") {
                print("ℹ️ User already exists, proceeding with sign up")
                // Store the user ID if available from the error or use Google user ID
                UserDefaults.standard.set(userId, forKey: "database_user_id")

                // Identify user with Superwall
                Superwall.shared.identify(userId: userId)

                self.completeSignUp()
            } else {
                self.authError = "Failed to create account: \(message)"
                self.isAuthenticating = false
            }
            
        } catch {
            print("❌ Unexpected database error: \(error)")
            self.authError = "Database connection failed: \(error.localizedDescription)"
            self.isAuthenticating = false
        }
    }
    
    private func createUserInDatabase(with appleCredential: ASAuthorizationAppleIDCredential) async {
        let appleUserId = appleCredential.user
        
        // Check if this Apple user already exists - if so, sign in immediately
        if let existingDatabaseUserId = UserDefaults.standard.string(forKey: "apple_user_\(appleUserId)") {
            print("✅ Returning Apple user found - User ID: \(existingDatabaseUserId)")
            UserDefaults.standard.set(existingDatabaseUserId, forKey: "database_user_id")

            // Identify user with Superwall
            Superwall.shared.identify(userId: existingDatabaseUserId)

            self.completeSignUp()
            return
        }
        
        // Parse name components properly
        let (firstName, lastName) = parseFullName(appleCredential.fullName)
        
        // For NEW users, Apple Sign In may not provide email on subsequent logins
        // Try backend login with Apple userId if email is missing (no-JWT fallback)
        if appleCredential.email == nil {
            print("ℹ️ Apple email not provided. Attempting backend login with Apple userId...")
            do {
                let user = try await DatabaseService.shared.loginByUserId(userId: appleUserId)
                print("✅ Backend login by Apple userId succeeded: \(user.userId)")

                // Store mapping and database user id
                UserDefaults.standard.set(user.userId, forKey: "apple_user_\(appleUserId)")
                UserDefaults.standard.set(user.userId, forKey: "database_user_id")

                // Identify user with Superwall
                Superwall.shared.identify(userId: user.userId)

                // Proceed as logged-in
                self.completeSignUp()
                return
            } catch DatabaseError.serverError(let message) {
                // If not found or other server error, fall back to email-required path
                print("❌ Backend login by Apple userId failed: \(message)")
                self.authError = "Apple Sign In requires email for new account. Please enter your email to continue."
                self.isAuthenticating = false
                return
            } catch {
                print("❌ Unexpected error during backend login by Apple userId: \(error)")
                self.authError = "Login failed. Please try again or enter your email to create an account."
                self.isAuthenticating = false
                return
            }
        }
        
        // At this point, email is present (first-time or granted), continue with registration
        guard let email = appleCredential.email else { return }
        
        // For Apple Sign In, we need to create a password since Apple doesn't provide one
        let password = DatabaseService.shared.generateOAuthPassword(for: appleUserId)
        
        // Create username
        let username = DatabaseService.shared.createUsername(
            from: email,
            firstName: firstName,
            lastName: lastName
        )
        
        do {
            print("📝 Creating Apple user in database...")
            print("- Apple User ID: \(appleUserId)")
            print("- Parsed Name: \(firstName ?? "N/A") \(lastName ?? "N/A")")
            
            let dbUser = try await DatabaseService.shared.registerUser(
                email: email,
                password: password,
                userId: username,
                firstName: firstName,
                lastName: lastName,
                username: username
            )
            
            print("✅ Apple user created successfully in database:")
            print("- Database User ID: \(dbUser.userId)")
            print("- Email: \(dbUser.email)")
            print("- User ID: \(dbUser.userId)")

            // Store the Apple user ID -> Database user ID mapping
            UserDefaults.standard.set(dbUser.userId, forKey: "apple_user_\(appleUserId)")
            UserDefaults.standard.set(dbUser.userId, forKey: "database_user_id")

            // Identify user with Superwall
            Superwall.shared.identify(userId: dbUser.userId)

            // Initialize subscription state for new user (Superwall handles status automatically)
            SubscriptionManager.shared.state = SubscriptionState() // Fresh state for new user

            // Complete sign up
            self.completeSignUp()
            
        } catch DatabaseError.serverError(let message) {
            print("❌ Apple database registration failed: \(message)")
            
            // Check if user already exists (409 Conflict)
            if message.contains("409") || message.contains("already exists") {
                print("ℹ️ Apple user already exists, attempting to find and link...")
                
                // Try to login with the generated password to get the existing user
                do {
                    let (existingUser, _) = try await DatabaseService.shared.loginUser(email: email, password: password)
                    print("✅ Found existing user for Apple account - User ID: \(existingUser.userId)")

                    // Store the mapping for future sign-ins
                    UserDefaults.standard.set(existingUser.userId, forKey: "apple_user_\(appleUserId)")
                    UserDefaults.standard.set(existingUser.userId, forKey: "database_user_id")

                    // Identify user with Superwall
                    Superwall.shared.identify(userId: existingUser.userId)

                    self.completeSignUp()
                } catch {
                    print("❌ Could not login existing user: \(error)")
                    self.authError = "Account linking failed. Please contact support."
                    self.isAuthenticating = false
                }
            } else {
                self.authError = "Failed to create account: \(message)"
                self.isAuthenticating = false
            }
            
        } catch {
            print("❌ Unexpected Apple database error: \(error)")
            self.authError = "Database connection failed: \(error.localizedDescription)"
            self.isAuthenticating = false
        }
    }
    
    private func parseFullName(_ fullName: PersonNameComponents?) -> (firstName: String?, lastName: String?) {
        guard let fullName = fullName else { return (nil, nil) }
        
        // Use Apple's structured name components first
        if let givenName = fullName.givenName, let familyName = fullName.familyName {
            return (givenName, familyName)
        }
        
        // Fallback: if only one name component is provided, split it
        if let givenName = fullName.givenName, fullName.familyName == nil {
            // Split the given name into first and last
            let nameParts = givenName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if nameParts.count >= 2 {
                return (String(nameParts[0]), String(nameParts[1]))
            } else {
                return (givenName, nil)
            }
        }
        
        return (nil, nil)
    }
    
    private func completeSignUp() {
        isAuthenticating = false

        // Track signup completed
        AnalyticsService.shared.trackSignupCompleted()

        // 🌐 Establish WebSocket connection immediately after signup
        print("🌐 Establishing WebSocket connection after successful signup...")
        webSocketService.connect()

        withAnimation {
            hasCompletedSignUp = true
        }

        print("✅ Signup completed - WebSocket connection initiated for reduced latency")
    }

    private func continueAsGuest() {
        // Track guest mode activation
        AnalyticsService.shared.trackGuestModeActivated()

        // Activate guest mode immediately for UI
        isGuestMode = true

        // Create temporary demo user account
        Task {
            await createDemoUser()
        }
    }

    private func createDemoUser() async {
        let demoEmail = "demo@snatchshot.app"
        let demoUserId = "demo_user_\(UUID().uuidString.prefix(8))"
        let demoPassword = DatabaseService.shared.generateOAuthPassword(for: demoUserId)

        do {
            print("📝 Creating demo user account...")

            let demoUser = try await DatabaseService.shared.registerUser(
                email: demoEmail,
                password: demoPassword,
                userId: demoUserId,
                firstName: "Demo",
                lastName: "User",
                username: "demo_user"
            )

            print("✅ Demo user created successfully:")
            print("- User ID: \(demoUser.userId)")
            print("- Email: \(demoUser.email)")

            // Store the real user ID
            UserDefaults.standard.set(demoUser.userId, forKey: "database_user_id")

            // Initialize user with Superwall (no entitlements)
            Superwall.shared.identify(userId: demoUser.userId)
            SuperwallManager.shared.updateSubscriptionPlan(.none)

            // 🌐 Establish WebSocket connection for guest
            print("🌐 Establishing WebSocket connection for guest mode...")
            webSocketService.connect()

            print("✅ Demo user setup complete - proceeding to camera")

        } catch DatabaseError.serverError(let message) {
            print("❌ Demo user creation failed: \(message)")

            // Fallback: still proceed with dummy ID if user creation fails
            UserDefaults.standard.set("guest_fallback_demo", forKey: "database_user_id")
            Superwall.shared.identify(userId: "guest_fallback_demo")
            SuperwallManager.shared.updateSubscriptionPlan(.none)
            webSocketService.connect()

            print("⚠️ Proceeding with fallback demo mode due to user creation failure")

        } catch {
            print("❌ Unexpected error creating demo user: \(error)")

            // Fallback: still proceed with dummy ID
            UserDefaults.standard.set("guest_fallback_demo", forKey: "database_user_id")
            Superwall.shared.identify(userId: "guest_fallback_demo")
            SuperwallManager.shared.updateSubscriptionPlan(.none)
            webSocketService.connect()

            print("⚠️ Proceeding with fallback demo mode due to unexpected error")
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(WebSocketService())
}

