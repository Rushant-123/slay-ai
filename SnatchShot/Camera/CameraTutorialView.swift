import SwiftUI

struct CameraTutorialView: View {
    @ObservedObject var viewModel: CameraViewModel
    let geometry: GeometryProxy
    let buttonPositions: [String: CGRect]

    // Track which step should highlight which button
    var shouldHighlightPoseButton: Bool { viewModel.currentTutorialStep == 0 }
    var shouldHighlightCameraButton: Bool { viewModel.currentTutorialStep == 1 }
    var shouldHighlightFlashButton: Bool { viewModel.currentTutorialStep == 2 }
    var shouldHighlightFilterButton: Bool { viewModel.currentTutorialStep == 3 }
    var shouldHighlightAdvancedButtons: Bool { viewModel.currentTutorialStep == 4 }

    private let tutorialSteps = [
        TutorialStep(
            title: "AI Pose Suggestions",
            description: "This creates personalized pose suggestions after you take a photo",
            highlightArea: .poseSuggestions,
            dialoguePosition: .left
        ),
        TutorialStep(
            title: "Auto Camera Settings",
            description: "This automatically optimizes lighting, focus, and camera angles",
            highlightArea: .cameraSettings,
            dialoguePosition: .left
        ),
        TutorialStep(
            title: "Flash Control",
            description: "Tap to cycle through flash modes: Off → Auto → On",
            highlightArea: .flash,
            dialoguePosition: .right
        ),
        TutorialStep(
            title: "Filter Control",
            description: "Apply beautiful filters to enhance your photos",
            highlightArea: .filter,
            dialoguePosition: .right
        ),
        TutorialStep(
            title: "Advanced Controls",
            description: "Adjust exposure, white balance, and night mode for professional shots",
            highlightArea: .advanced,
            dialoguePosition: .top
        )
    ]

    var body: some View {
        GeometryReader { geo in
            let safeArea = geo.safeAreaInsets

            ZStack {
                // Dark overlay with holes for buttons
                Path { path in
                    // Full screen
                    path.addRect(CGRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height))

                // Subtract CIRCULAR holes for ACTUAL button locations
                switch viewModel.currentTutorialStep {
                case 0: // Pose suggestions
                    if let poseRect = buttonPositions["poseButton"] {
                        path.addEllipse(in: CGRect(x: poseRect.minX, y: poseRect.minY,
                                                 width: poseRect.width, height: poseRect.height))
                    }

                case 1: // Camera settings
                    if let cameraRect = buttonPositions["cameraButton"] {
                        path.addEllipse(in: CGRect(x: cameraRect.minX, y: cameraRect.minY,
                                                 width: cameraRect.width, height: cameraRect.height))
                    }

                case 2: // Flash
                    if let flashRect = buttonPositions["flashButton"] {
                        path.addEllipse(in: CGRect(x: flashRect.minX, y: flashRect.minY,
                                                 width: flashRect.width, height: flashRect.height))
                    }

                case 3: // Filter
                    if let filterRect = buttonPositions["filterButton"] {
                        path.addEllipse(in: CGRect(x: filterRect.minX, y: filterRect.minY,
                                                 width: filterRect.width, height: filterRect.height))
                    }

                case 4: // Advanced controls - perfect circular holes
                    if let exposureRect = buttonPositions["exposureButton"] {
                        // Center a 36x36 circle on the button position, adjusted for proper centering
                        let centerX = exposureRect.midX
                        let centerY = exposureRect.midY - 8 // Adjust up slightly
                        let circleRect = CGRect(x: centerX - 18, y: centerY - 18, width: 36, height: 36)
                        path.addEllipse(in: circleRect)
                    }
                    if let wbRect = buttonPositions["whiteBalanceButton"] {
                        // Center a 36x36 circle on the button position, adjusted for proper centering
                        let centerX = wbRect.midX
                        let centerY = wbRect.midY - 8 // Adjust up slightly
                        let circleRect = CGRect(x: centerX - 18, y: centerY - 18, width: 36, height: 36)
                        path.addEllipse(in: circleRect)
                    }
                    if let nightRect = buttonPositions["nightModeButton"] {
                        // Center a 36x36 circle on the button position, adjusted for proper centering
                        let centerX = nightRect.midX
                        let centerY = nightRect.midY - 8 // Adjust up slightly
                        let circleRect = CGRect(x: centerX - 18, y: centerY - 18, width: 36, height: 36)
                        path.addEllipse(in: circleRect)
                    }

                default:
                    break
                }
                }
                .fill(style: FillStyle(eoFill: true))
                .foregroundColor(Color.black.opacity(0.75))

                // Tutorial dialogue on top
                tutorialDialogue
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    private var tutorialDialogue: some View {
        GeometryReader { geo in
            switch currentStep.dialoguePosition {
            case .left:
                // Positioned to the RIGHT of left side buttons (decreased margin to 240)
                tutorialCard
                    .position(x: 240, y: geo.size.height - 220)

            case .right:
                // Positioned to the LEFT of right side buttons (decreased margin to 240)
                tutorialCard
                    .position(x: geo.size.width - 240, y: geo.size.height - 220)

            case .top:
                // Positioned BELOW the top controls panel (increased margin)
                tutorialCard
                    .position(x: geo.size.width / 2, y: 220)
            }
        }
    }

    private var tutorialCard: some View {
        VStack(spacing: 16) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index <= viewModel.currentTutorialStep ? Color(red: 0.600, green: 0.545, blue: 0.941) : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Content
            VStack(spacing: 12) {
                Text(currentStep.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(currentStep.description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 250)
            }
            .padding(.horizontal, 20)

            // Action buttons
            HStack(spacing: 16) {
                Button(action: viewModel.skipTutorial) {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(height: 36)
                        .frame(minWidth: 70)
                }

                Button(action: viewModel.advanceTutorial) {
                    Text(viewModel.currentTutorialStep < 4 ? "Next" : "Got it!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(height: 36)
                        .frame(minWidth: 100)
                        .background(Color(red: 0.600, green: 0.545, blue: 0.941))
                        .cornerRadius(18)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.9))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
    }

    private var currentStep: TutorialStep {
        tutorialSteps[viewModel.currentTutorialStep]
    }

}

struct TutorialStep {
    let title: String
    let description: String
    let highlightArea: HighlightArea
    let dialoguePosition: DialoguePosition
}

enum HighlightArea {
    case poseSuggestions, cameraSettings, flash, filter, advanced
}

enum DialoguePosition {
    case left, right, top
}
