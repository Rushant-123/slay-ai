#if os(iOS)
import SwiftUI
import AVFoundation
import UIKit
import Foundation

// MARK: - Button Position Tracking
struct ButtonPositionKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Main Camera View
struct CameraView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var webSocketService: WebSocketService
    var isVerificationMode: Bool = false
    
    // MARK: - State Management
    @StateObject private var viewModel = CameraViewModel()
    @State private var buttonPositions: [String: CGRect] = [:]
    
    var body: some View {
        ZStack {
            if camera.isConfigured {
                cameraContent
            } else {
                loadingView
            }
        }
        .overlay(overlayContent)
        .overlay(
            // Simple horizontal panels below buttons
            VStack {
                VStack(spacing: 0) {
                    // Space for top controls (EV, WB, Night buttons)
                    Spacer()
                        .frame(height: 20) // Much closer to buttons
                    
                    // Both panels appear at the exact same location using consistent alignment
                    HStack {
                        if viewModel.showExposurePanel {
                            ExposurePanelView(camera: camera, viewModel: viewModel)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else if viewModel.showWhiteBalancePanel {
                            WhiteBalancePanelView(camera: camera, viewModel: viewModel)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Spacer()
                    }
                }
                
                Spacer() // Fill remaining space
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        )
        .fullScreenCover(isPresented: viewModel.showGalleryBinding) {
            GalleryView().preferredColorScheme(.dark)
        }
        .overlay(
            // Camera settings overlay (when pose suggestions off but camera settings on)
            Group {
                if viewModel.showCameraSettingsOverlay {
                    cameraSettingsOverlay
                }
            }
        )
        .fullScreenCover(isPresented: viewModel.showPoseSuggestionsBinding) {
            poseSuggestionsFullScreen
        }
        .overlay(
            // Feature status indicators - positioned just above shutter, below side controls
            featureStatusOverlay
        )
        .overlay(
            // Camera tutorial overlay
            Group {
                if viewModel.showCameraTutorial {
                    ZStack {
                        // Tutorial dialogue overlay (background)
                        GeometryReader { geometry in
                            CameraTutorialView(viewModel: viewModel, geometry: geometry, buttonPositions: buttonPositions)
                        }

                    }
                }
            }
        )
        .onPreferenceChange(ButtonPositionKey.self) { positions in
            self.buttonPositions = positions
        }
        .alert("Processing Error", isPresented: $viewModel.showProcessingError) {
            Button("Try Again") {
                viewModel.retryProcessing()
            }
            Button("Cancel", role: .cancel) {
                viewModel.showProcessingError = false
            }
        } message: {
            Text(viewModel.processingErrorMessage)
        }
        .onAppear {
            AnalyticsService.shared.trackCameraOpened()
            viewModel.setup(camera: camera, webSocketService: webSocketService, isVerificationMode: isVerificationMode, dismiss: dismiss)

            // Connect view model to WebSocket service
            webSocketService.setCameraViewModel(viewModel)

            // Initialize camera if not already configured
            initializeCameraIfNeeded()
        }
    }

    private func initializeCameraIfNeeded() {
        // Check if camera is already configured
        guard !camera.isConfigured else { return }

        // Check camera permission status
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Permission granted, initialize camera
            camera.initializeCameraAfterPermissions()
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.camera.initializeCameraAfterPermissions()
                    }
                } else {
                    print("Camera permission denied")
                }
            }
        case .denied, .restricted:
            print("Camera permission denied or restricted")
        @unknown default:
            print("Unknown camera authorization status")
        }
    }

}

// MARK: - Camera Content
extension CameraView {
    private var cameraContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera Preview Layer
                CameraPreviewLayer(camera: camera, viewModel: viewModel, geometry: geometry)

                // Background Panels (behind UI controls)
                ZStack {
                    // Top background panel
                    VStack {
                        ZStack {
                            Color(red: 0.075, green: 0.082, blue: 0.102).opacity(0.7) // Onboarding background color with reduced opacity
                            // Logo in top-right corner
                            Image("Logo") // Your logo asset name
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                                .offset(x: 130, y: 30) // Adjusted positioning for larger logo
                        }
                        .frame(height: 100) // Reduced height
                        .edgesIgnoringSafeArea(.top)
                        Spacer()
                    }

                    // Bottom background panel - precisely positioned at bottom edge
                    GeometryReader { geo in
                        Color(red: 0.075, green: 0.082, blue: 0.102).opacity(0.7) // Onboarding background color with reduced opacity
                            .frame(width: geo.size.width, height: 280)
                            .position(x: geo.size.width / 2, y: geo.size.height - 0)
                            .edgesIgnoringSafeArea(.bottom)
                    }
                }

                // UI Controls Layer (on top of background panels)
                CameraControlsLayer(camera: camera, viewModel: viewModel, geometry: geometry, isVerificationMode: isVerificationMode, dismiss: dismiss)
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(1.5)
    }

    private var featureStatusOverlay: some View {
        Group {
            // Show indicators when overlay is not expanded (no overlay OR overlay minimized)
            // Also hide when there's a captured image (overlay should be showing)
            if (!viewModel.showPoseSuggestions || viewModel.isOverlayMinimized) && viewModel.capturedForReview == nil {
                GeometryReader { geo in
                    let safeArea = geo.safeAreaInsets
                    HStack(spacing: 12) {
                        // Always show AIPose status
                        statusIndicatorText("AIPose: \(viewModel.poseSuggestionsEnabled ? "On" : "Off")")
                        // Always show Auto-Cam status
                        statusIndicatorText("Auto-Cam: \(viewModel.cameraSettingsEnabled ? "On" : "Off")")
                    }
                    .multilineTextAlignment(.center)
                    .position(
                        x: geo.size.width / 2, // Center horizontally
                        y: geo.size.height - 80 - safeArea.bottom
                    )
                }
            }
        }
    }


    private var tutorialHighlights: some View {
        GeometryReader { geo in
            let safeArea = geo.safeAreaInsets

            ZStack {
                // Clear areas (holes) where buttons should be completely visible
                switch viewModel.currentTutorialStep {
                case 0: // Pose suggestions
                    Circle()
                        .fill(Color.white.opacity(0.01)) // Nearly transparent to create hole
                        .frame(width: 50, height: 50)
                        .position(x: 50 + safeArea.leading, y: geo.size.height - 160 - safeArea.bottom - 26)

                case 1: // Camera settings
                    Circle()
                        .fill(Color.white.opacity(0.01)) // Nearly transparent to create hole
                        .frame(width: 50, height: 50)
                        .position(x: 50 + safeArea.leading, y: geo.size.height - 160 - safeArea.bottom + 26)

                case 2: // Flash
                    Circle()
                        .fill(Color.white.opacity(0.01)) // Nearly transparent to create hole
                        .frame(width: 50, height: 50)
                        .position(x: geo.size.width - 50 - safeArea.trailing, y: geo.size.height - 160 - safeArea.bottom - 26)

                case 3: // Filter
                    Circle()
                        .fill(Color.white.opacity(0.01)) // Nearly transparent to create hole
                        .frame(width: 50, height: 50)
                        .position(x: geo.size.width - 50 - safeArea.trailing, y: geo.size.height - 160 - safeArea.bottom + 26)

                case 4: // Advanced controls
                    Circle()
                        .fill(Color.white.opacity(0.01)) // Nearly transparent to create hole
                        .frame(width: 50, height: 50)
                        .position(x: 34, y: 34)  // Exposure

                    Circle()
                        .fill(Color.white.opacity(0.01)) // Nearly transparent to create hole
                        .frame(width: 50, height: 50)
                        .position(x: 86, y: 34)  // White balance

                    Circle()
                        .fill(Color.white.opacity(0.01)) // Nearly transparent to create hole
                        .frame(width: 50, height: 50)
                        .position(x: 138, y: 34) // Night mode

                default:
                    EmptyView()
                }
            }
        }
    }

    private func statusIndicatorText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium)) // Increased from 12 to 14
            .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0)) // Lavender color
            .multilineTextAlignment(.center)
    }
    
    private var overlayContent: some View {
        Group {
            if viewModel.showPoseSuggestions && viewModel.useOverlayVersion {
                if let image = viewModel.capturedForReview {
                    let userId = UserDefaults.standard.string(forKey: "database_user_id")
                    PoseSuggestionsOverlayView(
                        capturedImage: image,
                        startWithLoader: viewModel.isProcessingImage,
                        poseSuggestionsEnabled: viewModel.poseSuggestionsEnabled,
                        cameraSettingsEnabled: viewModel.cameraSettingsEnabled,
                        userId: userId
                    ) { isMinimized in
                        viewModel.isOverlayMinimized = isMinimized
                    }
                    .id("pose-suggestions-overlay") // Stable ID to prevent aggressive recreation
                    .preferredColorScheme(.dark)
                    .onDisappear {
                        viewModel.resetCameraState()
                    }
                }
            }
        }
    }
    
    private var poseSuggestionsFullScreen: some View {
        Group {
            if let image = viewModel.capturedForReview {
                let userId = UserDefaults.standard.string(forKey: "database_user_id")
                PoseSuggestionsView(
                    capturedImage: image,
                    poseSuggestionsEnabled: viewModel.poseSuggestionsEnabled,
                    cameraSettingsEnabled: viewModel.cameraSettingsEnabled,
                    userId: userId
                )
                .preferredColorScheme(.dark)
            }
        }
    }
    
    private var cameraSettingsOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Loading spinner
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                // Loading text
                Text("Optimizing camera settings...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("AI is analyzing your photo for the best camera settings")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showCameraSettingsOverlay)
    }
}

// MARK: - Camera Preview Layer
struct CameraPreviewLayer: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Main camera preview
                        CameraPreview(
                            session: camera.session,
                            currentFilter: camera.currentFilter,
                            contrast: camera.contrast,
                            brightness: camera.brightness,
                            saturation: camera.saturation
                            )
                            .ignoresSafeArea()
            // Removed forced re-render - was causing 9+ second hangs when filter changed
            
            // Gesture handling
            CameraGestureHandler(camera: camera, viewModel: viewModel, geometry: geometry)
            
            // Focus and brightness indicators
            CameraIndicators(viewModel: viewModel, geometry: geometry)
        }
    }
}

// MARK: - Camera Controls Layer
struct CameraControlsLayer: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    let geometry: GeometryProxy
    let isVerificationMode: Bool
    let dismiss: DismissAction
    
    var body: some View {
        ZStack {
            // Top controls
            TopControlsView(camera: camera, viewModel: viewModel, geometry: geometry)
            
            // Bottom controls
            BottomControlsView(camera: camera, viewModel: viewModel, geometry: geometry, isVerificationMode: isVerificationMode, dismiss: dismiss)
            
            // Verification mode close button
            if isVerificationMode {
                VerificationCloseButton(dismiss: dismiss)
            }
            
            // Filter drawer
            if viewModel.isFilterDrawerOpen {
                FilterDrawerView(camera: camera, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Camera Gesture Handler
struct CameraGestureHandler: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    let geometry: GeometryProxy
    
    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(tapGesture)
            .gesture(dragGesture)
            .gesture(magnificationGesture)
    }
    
    private var tapGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded { _ in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                viewModel.handleFocusTap(at: center, in: geometry, camera: camera)
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                viewModel.handleDragGesture(value: value, in: geometry, camera: camera)
                                    }
                                    .onEnded { _ in
                viewModel.handleDragEnd()
                                        }
                                    }
    
    private var magnificationGesture: some Gesture {
                                MagnificationGesture()
                                    .onChanged { scale in
                viewModel.handleZoomGesture(scale: scale, camera: camera)
                                    }
                                    .onEnded { _ in
                viewModel.handleZoomEnd(camera: camera)
            }
    }
}

// MARK: - Camera Indicators
struct CameraIndicators: View {
    @ObservedObject var viewModel: CameraViewModel
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
                        // Focus indicator
            if let focusPoint = viewModel.focusPoint {
                FocusIndicatorView(focusPoint: focusPoint, isLocked: viewModel.isFocusLocked)
            }
            
            // Brightness slider
            if viewModel.brightnessDragValue != nil, let focusPoint = viewModel.focusPoint {
                BrightnessSliderView(
                    focusPoint: focusPoint,
                    brightnessValue: viewModel.brightnessDragValue,
                    viewModel: viewModel
                )
                        }

        }
    }
}

// MARK: - Top Controls View
struct TopControlsView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    let geometry: GeometryProxy
    
    var body: some View {
                VStack {
            HStack(spacing: 16) {
                // Exposure control
                ControlButton(
                    icon: "plusminus.circle",
                    label: "",
                    isActive: viewModel.showExposurePanel
                ) {
                    // Add haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                    viewModel.toggleExposurePanel()
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ButtonPositionKey.self, value: ["exposureButton": geo.frame(in: .global)])
                    }
                )

                // White balance control
                ControlButton(
                    icon: "thermometer",
                    label: "",
                    isActive: viewModel.showWhiteBalancePanel
                ) {
                    // Add haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    viewModel.toggleWhiteBalancePanel()
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ButtonPositionKey.self, value: ["whiteBalanceButton": geo.frame(in: .global)])
                    }
                )

                // Night mode control
                ControlButton(
                    icon: camera.nightMode != .off ? "moon.circle.fill" : "moon.circle",
                    label: "",
                    isActive: camera.nightMode != .off,
                    activeColor: Color(red: 0.600, green: 0.545, blue: 0.941)
                ) {
                    camera.setNightMode(camera.nightMode != .off ? .off : .on)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ButtonPositionKey.self, value: ["nightModeButton": geo.frame(in: .global)])
                    }
                )
            }
            .padding(.leading, 16)
            .padding(.top, 16)
            
                    Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bottom Controls View
struct BottomControlsView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    let geometry: GeometryProxy
    let isVerificationMode: Bool
    let dismiss: DismissAction
    
    var body: some View {
        GeometryReader { geo in
            let safeArea = geo.safeAreaInsets
            
            ZStack {
                // Main shutter controls - centered at bottom
                ShutterControlsView(
                    camera: camera,
                    viewModel: viewModel,
                    isVerificationMode: isVerificationMode,
                    dismiss: dismiss
                )
                
                // Left side toggles - closer to edge and higher up
                LeftSideTogglesView(viewModel: viewModel)
                    .position(
                        x: 50 + safeArea.leading,
                        y: geo.size.height - 160 - safeArea.bottom
                    )
                
                // Right side controls - closer to edge and higher up
                RightSideControlsView(camera: camera, viewModel: viewModel)
                    .position(
                        x: geo.size.width - 50 - safeArea.trailing,
                        y: geo.size.height - 160 - safeArea.bottom
                    )
            }
        }
    }
}

// MARK: - Shutter Controls View
struct ShutterControlsView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    let isVerificationMode: Bool
    let dismiss: DismissAction
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 80) {
                // Gallery button
                GalleryButtonView(viewModel: viewModel)
                
                // Main shutter button with zoom arc
                ShutterButtonView(
                    camera: camera,
                    viewModel: viewModel,
                    isVerificationMode: isVerificationMode,
                    dismiss: dismiss
                )
                
                // Camera flip button
                CameraFlipButtonView(camera: camera)
            }
            .frame(height: 140)
            .offset(y: 20)
        }
    }
}

// MARK: - Reusable Components

// Control Button Component
struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    init(icon: String, label: String, isActive: Bool, activeColor: Color = Color(red: 0.600, green: 0.545, blue: 0.941), action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.activeColor = activeColor
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isActive ? activeColor.opacity(0.9) : .white.opacity(0.9))
                }
            }
            .frame(width: 36, height: 36)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive ? activeColor.opacity(0.8) : .white.opacity(0.7))
        }
    }
}

// Focus Indicator Component
struct FocusIndicatorView: View {
    let focusPoint: CGPoint
    let isLocked: Bool
    
    var body: some View {
                ZStack {
                    Circle()
                        .stroke(Color.yellow.opacity(0.8), lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .position(focusPoint)
                .scaleEffect(isLocked ? 1.1 : 1.0)
                .opacity(isLocked ? 0.9 : 0.7)

                    Circle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .position(focusPoint)

            if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                            .position(x: focusPoint.x, y: focusPoint.y - 30)
                    }
                }
                .transition(.opacity)
    }
}

// Brightness Slider Component
struct BrightnessSliderView: View {
    let focusPoint: CGPoint
    let brightnessValue: Float?
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text("☀️")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                
                // Brightness track
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                    .frame(width: 6, height: 120)

                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                            .fill(Color.yellow.opacity(0.9))
                            .frame(width: 6, height: max(8, viewModel.brightnessSliderHeight))
                    }
                }
                
                Text("🌙")
                    .font(.system(size: 14))
                    .foregroundColor(.blue.opacity(0.7))
            }
            
            if let value = brightnessValue {
            VStack(spacing: 2) {
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))

                Text("EV")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
                }
                .position(x: focusPoint.x + 40, y: focusPoint.y)
                .transition(.opacity)
            }
        }
        

// Gallery Button Component
struct GalleryButtonView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        Button {
            print("📸 Gallery button tapped!")
            viewModel.showGallery = true
                    } label: {
                        ZStack {
                            Circle()
                    .fill(.ultraThinMaterial.opacity(0.8))
                    .frame(width: 65, height: 65)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                
                if let lastPhoto = viewModel.lastTakenPhoto {
                    Image(uiImage: lastPhoto)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 65, height: 65)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }
}

// Shutter Button Component
struct ShutterButtonView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    let isVerificationMode: Bool
    let dismiss: DismissAction
    
    var body: some View {
        ZStack {
            // Zoom arc (if visible)
            if viewModel.showZoomArc {
                ZoomArcView(camera: camera, viewModel: viewModel)
            }
            
            // Main shutter button
                    Button {
                viewModel.handleShutterTap(camera: camera, isVerificationMode: isVerificationMode, dismiss: dismiss)
                    } label: {
                        ZStack {
                            Circle()
                        .stroke(.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 76, height: 76)
                    
                           Circle()
                               .fill(Color(red: 0.600, green: 0.545, blue: 0.941))
                               .frame(width: 62, height: 62)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.showZoomArc.toggle()
                        }
                    }
            )
        }
    }
}

// Camera Flip Button Component
struct CameraFlipButtonView: View {
    let camera: CameraService
    
    var body: some View {
                    Button {
            camera.switchCamera()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial.opacity(0.8))
                    .frame(width: 65, height: 65)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                
                Image(systemName: "camera.rotate")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}

// Left Side Toggles Component
struct LeftSideTogglesView: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
                    VStack(spacing: 16) {
                        // Pose Suggestions toggle
                        Button {
                // Add haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                viewModel.poseSuggestionsEnabled.toggle()
                if viewModel.poseSuggestionsEnabled {
                                AnalyticsService.shared.trackPoseSuggestionsToggledOn()
                            } else {
                                AnalyticsService.shared.trackPoseSuggestionsToggledOff()
                            }
                        } label: {
                Image(systemName: viewModel.poseSuggestionsEnabled ? "figure.walk.circle.fill" : "figure.walk.circle")
                                .font(.system(size: 18))
                    .foregroundColor(viewModel.poseSuggestionsEnabled ? Color(red: 0.600, green: 0.545, blue: 0.941) : .white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ButtonPositionKey.self, value: ["poseButton": geo.frame(in: .global)])
                            }
                        )

                        // Camera Settings toggle
                        Button {
                // Add haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                viewModel.cameraSettingsEnabled.toggle()
                if viewModel.cameraSettingsEnabled {
                                AnalyticsService.shared.trackCameraSettingsToggledOn()
                            } else {
                                AnalyticsService.shared.trackCameraSettingsToggledOff()
                            }
                        } label: {
                Image(systemName: viewModel.cameraSettingsEnabled ? "gearshape.fill" : "gearshape")
                                .font(.system(size: 18))
                    .foregroundColor(viewModel.cameraSettingsEnabled ? Color(red: 0.600, green: 0.545, blue: 0.941) : .white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ButtonPositionKey.self, value: ["cameraButton": geo.frame(in: .global)])
                            }
                        )
                    }
    }
}

// Right Side Controls Component
struct RightSideControlsView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    @State private var forceUpdate: Bool = false
    
    var body: some View {
                    VStack(spacing: 16) {
                        // Flash toggle
                        Button {
                print("🔦 Flash button UI tapped!")

                // Add immediate haptic feedback for better responsiveness
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()

                viewModel.toggleFlash(camera: camera)

                // Force UI update by toggling state
                forceUpdate.toggle()
                        } label: {
                Image(systemName: viewModel.flashIcon(for: camera.flashMode))
                                .font(.system(size: 18))
                    .foregroundColor(camera.flashMode != .off ? Color(red: 0.600, green: 0.545, blue: 0.941) : .white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                        }
            .buttonStyle(PlainButtonStyle()) // Ensure button responds immediately
            .animation(.easeInOut(duration: 0.2), value: camera.flashMode) // Smooth animation for state changes
            .id("flash-button-\(camera.flashMode.rawValue)-\(forceUpdate)") // Force re-render when either changes
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ButtonPositionKey.self, value: ["flashButton": geo.frame(in: .global)])
                }
            )

                        // Filter button
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.isFilterDrawerOpen.toggle()
                                }
                        } label: {
                            Image(systemName: "camera.filters")
                                .font(.system(size: 18))
                    .foregroundColor(camera.currentFilter != .none ? Color(red: 0.600, green: 0.545, blue: 0.941) : .white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial.opacity(0.8), in: Circle())
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ButtonPositionKey.self, value: ["filterButton": geo.frame(in: .global)])
                }
            )
        }
    }
}

// Verification Close Button Component
struct VerificationCloseButton: View {
    let dismiss: DismissAction
    
    var body: some View {
        VStack {
            HStack {
            Spacer()
                Button {
                    dismiss()
                } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.top, 50)
                .padding(.trailing, 20)
            }
            Spacer()
        }
    }
}

// Zoom Arc Component
struct ZoomArcView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
            VStack {
                                // Semi-circular zoom arc
                                Path { path in
                                    path.addArc(center: CGPoint(x: 100, y: 100),
                                              radius: 85,
                           startAngle: .degrees(-60),
                                              endAngle: .degrees(240),
                                              clockwise: true)
                                }
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 200, height: 200)
                                .offset(y: 20)

                                // Current zoom indicator
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: -82))
                                    path.addLine(to: CGPoint(x: 0, y: -88))
                                }
                                .stroke(Color.yellow, lineWidth: 2)
            .rotationEffect(.degrees(-viewModel.zoomAngle(for: camera.zoomFactor)))

                                // Zoom value label
                                Text(String(format: "%.1f×", camera.zoomFactor))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.yellow)
                                    .offset(y: -50)
                            }
                        }
}

// Exposure Panel Component - Horizontal Dropdown
struct ExposurePanelView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        HStack {
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    // EV Icon
                        Image(systemName: "plusminus.circle")
                            .foregroundColor(Color(red: 0.600, green: 0.545, blue: 0.941))
                            .font(.system(size: 18))
                        
                        // Horizontal Slider
                        Slider(value: Binding(
                            get: { Float(camera.evBias) },
                            set: { camera.setExposureBias(CGFloat($0)) }
                        ), in: Float(camera.minExposureTargetBias)...Float(camera.maxExposureTargetBias))
                        .frame(width: 200) // Increased width to prevent text wrapping
                        .tint(Color(red: 0.600, green: 0.545, blue: 0.941))
                        
                        // Current Value
                        Text(String(format: "%.1f EV", camera.evBias))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 60)
                    }
                    
                    // Quick presets
                    HStack(spacing: 8) {
                        ForEach([-1.0, -0.5, 0.0, 0.5, 1.0], id: \.self) { value in
                            Button {
                                camera.setExposureBias(CGFloat(value))
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                            } label: {
                                Text(value == 0 ? "0" : String(format: "%.1f", value))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(abs(camera.evBias - CGFloat(value)) < 0.1 ? Color(red: 0.600, green: 0.545, blue: 0.941) : .white.opacity(0.7))
                                    .fixedSize(horizontal: true, vertical: false) // Prevent text wrapping
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(abs(camera.evBias - CGFloat(value)) < 0.1 ? Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.2) : .clear)
                                            .stroke(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .frame(minWidth: 300) // Ensure panel has enough width for horizontal text
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial.opacity(0.95))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.top, 80) // Drop down from EV button
            
            Spacer()
        }
    }

// White Balance Panel Component - Horizontal Dropdown
struct WhiteBalancePanelView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    @State private var whiteBalanceMode: Int = 0 // 0 = warmth, 1 = tone
    
    var body: some View {
        HStack {
            VStack(spacing: 8) {
                // Mode Selector
                    Picker("", selection: $whiteBalanceMode) {
                        Text("Temp").tag(0)
                        Text("Tint").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180) // Increased width as requested
                    
                    HStack(spacing: 16) {
                        // WB Icon
                        Image(systemName: "thermometer")
                            .foregroundColor(Color(red: 0.600, green: 0.545, blue: 0.941))
                            .font(.system(size: 18))
                        
                        // Horizontal Slider
                        if whiteBalanceMode == 0 {
                            // Temperature (Warmth)
                            Slider(value: Binding(
                                get: { Float(camera.whiteBalanceTemperature) },
                                set: { camera.setWhiteBalanceTemperature(CGFloat($0), tint: camera.whiteBalanceTint) }
                            ), in: 2000...10000)
                            .frame(width: 180) // Increased width as requested
                            .tint(Color(red: 0.600, green: 0.545, blue: 0.941))
                            
                            // Current Value
                            Text(String(format: "%.0fK", camera.whiteBalanceTemperature))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 60)
                                } else {
                            // Tint (Tone)
                            Slider(value: Binding(
                                get: { Float(camera.whiteBalanceTint) },
                                set: { camera.setWhiteBalanceTemperature(camera.whiteBalanceTemperature, tint: CGFloat($0)) }
                            ), in: -50...50)
                            .frame(width: 180) // Increased width as requested
                            .tint(Color(red: 0.600, green: 0.545, blue: 0.941))
                            
                            // Current Value
                            Text(String(format: "%.0f", camera.whiteBalanceTint))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 60)
                        }
                    }
                    
                    // Quick presets
                    HStack(spacing: 8) {
                        if whiteBalanceMode == 0 {
                            // Temperature presets
                            ForEach([2700, 3200, 5500, 6500, 7500], id: \.self) { temp in
                                Button {
                                    camera.setWhiteBalanceTemperature(CGFloat(temp), tint: camera.whiteBalanceTint)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                                } label: {
                                    Text("\(temp)K")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(abs(camera.whiteBalanceTemperature - CGFloat(temp)) < 100 ? Color(red: 0.600, green: 0.545, blue: 0.941) : .white.opacity(0.7))
                                        .fixedSize(horizontal: true, vertical: false) // Prevent text wrapping
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(abs(camera.whiteBalanceTemperature - CGFloat(temp)) < 100 ? Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.2) : .clear)
                                                .stroke(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        } else {
                            // Tint presets
                            ForEach([-20, -10, 0, 10, 20], id: \.self) { tint in
                    Button {
                                    camera.setWhiteBalanceTemperature(camera.whiteBalanceTemperature, tint: CGFloat(tint))
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                                    Text(tint == 0 ? "0" : String(format: "%+d", tint))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(abs(camera.whiteBalanceTint - CGFloat(tint)) < 2 ? Color(red: 0.600, green: 0.545, blue: 0.941) : .white.opacity(0.7))
                                        .fixedSize(horizontal: true, vertical: false) // Prevent text wrapping
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(abs(camera.whiteBalanceTint - CGFloat(tint)) < 2 ? Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.2) : .clear)
                                                .stroke(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 300) // Ensure panel has enough width for horizontal text
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial.opacity(0.95))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Spacer()
            }
            .padding(.leading, 16) // Same position as EV panel
            .padding(.top, 80) // Drop down from WB button
            
            Spacer()
        }
    }

// Filter Drawer Component
struct FilterDrawerView: View {
    let camera: CameraService
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Filter thumbnails
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                        ForEach(CameraFilter.allCases, id: \.self) { filter in
                                Button {
                                // Safely apply filter on main thread
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                    camera.setFilter(filter)
                                        viewModel.isFilterDrawerOpen = false // Close drawer after selection
                                    }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.ultraThinMaterial.opacity(0.8))
                                                .frame(width: 60, height: 60)
                                            
                                        // Filter preview thumbnail
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(filterPreviewColor(for: filter))
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(camera.currentFilter == filter ? Color(red: 0.600, green: 0.545, blue: 0.941) : .clear, lineWidth: 2)
                                            )
                                        }
                                        
                                        Text(filter.rawValue)
                                            .font(.caption2)
                                        .foregroundColor(camera.currentFilter == filter ? Color(red: 0.600, green: 0.545, blue: 0.941) : .white.opacity(0.7))
                                            .lineLimit(1)
                                            .frame(width: 60)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                .background(.ultraThinMaterial.opacity(0.9))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(radius: 10)
            .transition(.opacity)
        }
    }
    
    // MARK: - Filter Preview Colors
    private func filterPreviewColor(for filter: CameraFilter) -> LinearGradient {
        switch filter {
        case .none:
            return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Basic Filters
        case .bw, .mono:
            return LinearGradient(colors: [.black, .gray, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sepia:
            return LinearGradient(colors: [Color(red: 0.7, green: 0.5, blue: 0.2), Color(red: 0.5, green: 0.3, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vintage:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.8, blue: 0.4), Color(red: 0.8, green: 0.6, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vivid:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.2, blue: 0.8), Color(red: 0.8, green: 0.0, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dramatic:
            return LinearGradient(colors: [.black, Color(red: 0.3, green: 0.3, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .portrait:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.7, blue: 0.6), Color(red: 0.9, green: 0.6, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .landscape:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.7, blue: 1.0), Color(red: 0.1, green: 0.5, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cyanotype:
            return LinearGradient(colors: [Color(red: 0.0, green: 0.3, blue: 0.7), Color(red: 0.0, green: 0.5, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Enhancement Filters
        case .hdr:
            return LinearGradient(colors: [Color(red: 1.0, green: 1.0, blue: 0.0), Color(red: 0.8, green: 0.8, blue: 0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .softFocus:
            return LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sharpen:
            return LinearGradient(colors: [.white, Color(red: 0.9, green: 0.9, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Color Filters
        case .warmth:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.9, green: 0.4, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cool:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Film Filters
        case .kodak:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.8, blue: 0.7), Color(red: 0.9, green: 0.7, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fuji:
            return LinearGradient(colors: [Color(red: 0.7, green: 0.9, blue: 1.0), Color(red: 0.6, green: 0.8, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cinestill:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.9, blue: 0.6), Color(red: 0.9, green: 0.8, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Artistic Filters
        case .oilPaint:
            return LinearGradient(colors: [Color(red: 0.8, green: 0.7, blue: 0.5), Color(red: 0.6, green: 0.5, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sketch:
            return LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .comic:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.0, blue: 0.5), Color(red: 0.8, green: 0.0, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Effects Filters
        case .crystal:
            return LinearGradient(colors: [Color(red: 0.8, green: 1.0, blue: 1.0), Color(red: 0.6, green: 0.9, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .emboss:
            return LinearGradient(colors: [.gray, Color.gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gaussianBlur:
            return LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vignette:
            return LinearGradient(colors: [.black, .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .grain:
            return LinearGradient(colors: [.gray.opacity(0.8), .gray.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Special Filters
        case .crossProcess:
            return LinearGradient(colors: [Color(red: 0.9, green: 1.0, blue: 0.7), Color(red: 0.7, green: 0.8, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .glow:
            return LinearGradient(colors: [.white, Color(red: 0.9, green: 0.9, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .neon:
            return LinearGradient(colors: [Color(red: 0.0, green: 1.0, blue: 0.8), Color(red: 0.0, green: 0.8, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .posterize:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.0), Color(red: 0.8, green: 0.3, blue: 0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .solarize:
            return LinearGradient(colors: [Color(red: 1.0, green: 1.0, blue: 0.5), Color(red: 0.8, green: 0.8, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Distortion Filters
        case .kaleidoscope:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.0, blue: 1.0), Color(red: 0.8, green: 0.0, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pinch, .twirl, .bump, .glass:
            return LinearGradient(colors: [Color(red: 0.5, green: 0.8, blue: 1.0), Color(red: 0.3, green: 0.6, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        // Halftone Filters
        case .dotScreen, .lineScreen:
            return LinearGradient(colors: [.black.opacity(0.8), .black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
        default:
            return LinearGradient(colors: [Color(red: 0.8, green: 0.8, blue: 1.0), Color(red: 0.6, green: 0.6, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

#Preview {
    CameraView()
        .environmentObject(CameraService())
}

#endif
