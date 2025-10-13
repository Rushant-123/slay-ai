import SwiftUI

struct CameraTutorialView: View {
    @ObservedObject var viewModel: CameraViewModel
    let geometry: GeometryProxy

    private let tutorialSteps = [
        TutorialStep(
            title: "Take Your First Photo",
            description: "Tap the shutter button to capture your photo",
            highlightArea: .shutter
        ),
        TutorialStep(
            title: "Focus & Zoom",
            description: "Tap anywhere to focus, pinch to zoom in/out",
            highlightArea: .center
        ),
        TutorialStep(
            title: "AI Features",
            description: "AIPose creates pose suggestions, Auto-Cam optimizes your camera",
            highlightArea: .leftToggles
        ),
        TutorialStep(
            title: "Advanced Controls",
            description: "Adjust exposure, white balance, and flash for perfect shots",
            highlightArea: .topControls
        ),
        TutorialStep(
            title: "Quick Settings Access",
            description: "Tap the logo to access settings, subscription, and usage info",
            highlightArea: .logo
        ),
        TutorialStep(
            title: "You're All Set!",
            description: "Take a photo and watch AI create your perfect poses",
            highlightArea: .none
        )
    ]

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                // Tutorial card
                VStack(spacing: 16) {
                    // Progress indicator
                    HStack(spacing: 8) {
                        ForEach(0..<6) { index in
                            Circle()
                                .fill(index <= viewModel.currentTutorialStep ? Color(red: 0.600, green: 0.545, blue: 0.941) : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Content
                    VStack(spacing: 12) {
                        Text(currentStep.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text(currentStep.description)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)

                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: viewModel.skipTutorial) {
                            Text("Skip")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(height: 44)
                                .frame(minWidth: 80)
                        }

                        Button(action: viewModel.advanceTutorial) {
                            Text(viewModel.currentTutorialStep < 5 ? "Next" : "Got it!")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(height: 44)
                                .frame(minWidth: 120)
                                .background(Color(red: 0.600, green: 0.545, blue: 0.941))
                                .cornerRadius(22)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 32)
                .background(Color.black.opacity(0.9))
                .cornerRadius(20)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                // Highlight overlay
                highlightOverlay
            }
        }
    }

    private var currentStep: TutorialStep {
        tutorialSteps[viewModel.currentTutorialStep]
    }

    @ViewBuilder
    private var highlightOverlay: some View {
        switch currentStep.highlightArea {
        case .shutter:
            // Highlight shutter button area
            Circle()
                .stroke(Color(red: 0.600, green: 0.545, blue: 0.941), lineWidth: 3)
                .frame(width: 80, height: 80)
                .position(x: geometry.size.width / 2, y: geometry.size.height - 120)
                .opacity(0.8)

        case .center:
            // Highlight center area for focus
            Circle()
                .stroke(Color(red: 0.600, green: 0.545, blue: 0.941), lineWidth: 3)
                .frame(width: 100, height: 100)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .opacity(0.8)

        case .leftToggles:
            // Highlight left side toggles
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.600, green: 0.545, blue: 0.941), lineWidth: 3)
                .frame(width: 60, height: 120)
                .position(x: 60, y: geometry.size.height - 160)
                .opacity(0.8)

        case .topControls:
            // Highlight top controls
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.600, green: 0.545, blue: 0.941), lineWidth: 3)
                .frame(width: 200, height: 50)
                .position(x: geometry.size.width / 2, y: 80)
                .opacity(0.8)

        case .logo:
            // Highlight logo button
            Circle()
                .stroke(Color(red: 0.600, green: 0.545, blue: 0.941), lineWidth: 3)
                .frame(width: 120, height: 120)
                .position(x: geometry.size.width - 130, y: 80)
                .opacity(0.8)

        case .none:
            EmptyView()
        }
    }
}

struct TutorialStep {
    let title: String
    let description: String
    let highlightArea: HighlightArea
}

enum HighlightArea {
    case shutter, center, leftToggles, topControls, logo, none
}
