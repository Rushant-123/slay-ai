//
//  OnboardingView.swift
//  SnatchShot
//
//  Created by Rushant on 16/09/25.
//

import SwiftUI

// Analytics
import Foundation

struct OnboardingView: View {
    @State private var currentSlide = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    let slides = [
        OnboardingSlide(
            heading: "Turn ordinary into unforgettable",
            subline: "Watch everyday moments become scroll-stoppers",
            imageName: "onboarding_slide1" // Pink dress image
        ),
        OnboardingSlide(
            heading: "Serve Main-Character Energy",
            subline: "Personalised poses that truly capture your vibe.",
            imageName: "onboarding_slide2" // Gate pose image
        ),
        OnboardingSlide(
            heading: "Your AI Glam Squad",
            subline: "Auto-tunes lighting, angles, and focus for you",
            imageName: "onboarding_slide3" // Walking image
        )
    ]
    
    var body: some View {
        ZStack {
            // Dark background (#13151A)
            Color(red: 0.075, green: 0.082, blue: 0.102)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Fixed height for top text area to prevent card movement
                VStack(spacing: 16) {
                    Text(slides[currentSlide].heading)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .animation(.easeInOut(duration: 0.3), value: currentSlide)
                    
                    Text(slides[currentSlide].subline)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .animation(.easeInOut(duration: 0.3), value: currentSlide)
                }
                .frame(height: 160) // Fixed height to prevent card movement and ensure text fits
                .padding(.top, 60)
                
                Spacer()
                
                // Carousel container - Fixed position
                VStack(spacing: 0) {
                    // Main carousel content area
                    TabView(selection: $currentSlide) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            // Onboarding image
                            Image(slides[index].imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .never))
                    .padding(.horizontal, 40)  // Match button padding
                    .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.2), radius: 10, x: 0, y: 4)
                    
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentSlide ? Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8) : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentSlide ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentSlide)
                        }
                    }
                    .padding(.top, 20)
                }
                
                Spacer()
                
                    // Next button
                VStack(spacing: 16) {
                    Button(action: {
                        if currentSlide < slides.count - 1 {
                            // Track next button tap
                            AnalyticsService.shared.trackOnboardingSlideViewed(slideNumber: currentSlide + 1, slideName: slides[currentSlide + 1].heading)

                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentSlide += 1
                            }
                        } else {
                            // Complete onboarding
                            AnalyticsService.shared.trackOnboardingCompleted()

                            withAnimation {
                                hasCompletedOnboarding = true
                            }
                        }
                    }) {
                        HStack {
                            Text(currentSlide < slides.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
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
                    
                    // Terms and Privacy links
                    HStack(spacing: 20) {
                    Button("Terms of Use") {
                        AnalyticsService.shared.trackSignupTermsLinkTapped()
                        if let url = URL(string: "https://www.getslayai.com/terms-of-service") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                    Button("Privacy Policy") {
                        AnalyticsService.shared.trackSignupPrivacyLinkTapped()
                        if let url = URL(string: "https://www.getslayai.com/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Track onboarding started and first slide view
            AnalyticsService.shared.trackOnboardingStarted()
            AnalyticsService.shared.trackOnboardingSlideViewed(slideNumber: 1, slideName: slides[0].heading)

            // Reset onboarding state for testing
            hasCompletedOnboarding = false
        }
    }
}

struct OnboardingSlide {
    let heading: String
    let subline: String
    let imageName: String
}

#Preview {
    OnboardingView()
}