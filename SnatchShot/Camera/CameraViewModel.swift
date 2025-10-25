import SwiftUI
import AVFoundation
import UIKit
import Foundation

// MARK: - UIImage Extension for Rotation
extension UIImage {
    func rotated(by radians: CGFloat) -> UIImage? {
        // Calculate new size after rotation
        let newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        // Ensure positive dimensions
        let finalSize = CGSize(width: abs(newSize.width), height: abs(newSize.height))

        UIGraphicsBeginImageContextWithOptions(finalSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Save context state
        context.saveGState()

        // Move to center of new size
        context.translateBy(x: finalSize.width / 2, y: finalSize.height / 2)

        // Apply rotation
        context.rotate(by: radians)

        // Flip Y axis for UIKit coordinate system and draw
        context.scaleBy(x: 1.0, y: -1.0)

        // Draw the image centered
        let drawRect = CGRect(
            x: -self.size.width / 2,
            y: -self.size.height / 2,
            width: self.size.width,
            height: self.size.height
        )
        context.draw(self.cgImage!, in: drawRect)

        // Restore context and get image
        context.restoreGState()
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage
    }
}

// MARK: - Camera View Model
@MainActor
class CameraViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var focusPoint: CGPoint?
    @Published var isFocusLocked = false
    @Published var brightnessDragValue: Float?
    @Published var showZoomArc = false
    @Published var isFilterDrawerOpen = false
    
    // Camera state
    @Published var poseSuggestionsEnabled = true  // Default to on
    @Published var cameraSettingsEnabled = true   // Default to on
    @Published var isProcessingImage = false
    @Published var showPoseSuggestions = false
    @Published var isOverlayMinimized = false
    @Published var showGallery = false
    @Published var capturedForReview: UIImage?
    @Published var lastTakenPhoto: UIImage?
    
    // UI configuration
    @Published var useOverlayVersion = true
    @Published var photosTaken = 0

    // Tutorial state
    @AppStorage("hasCompletedCameraTutorial") private var hasCompletedCameraTutorial = false
    @Published var showCameraTutorial = false
    @Published var currentTutorialStep = 0
    
    // Horizontal panels state
    @Published var showExposurePanel = false
    @Published var showWhiteBalancePanel = false
    @Published var showFilterPresets = false
    
    
    // Error handling and retry
    @Published var showProcessingError = false
    @Published var processingErrorMessage = "Processing timed out"
    
    // Camera settings only overlay (when pose suggestions off but camera settings on)
    @Published var showCameraSettingsOverlay = false
    
    
    // Performance optimization
    private var lastBrightnessUpdate: Date = Date()
    private var lastZoomUpdate: Date = Date()
    private let updateThrottle: TimeInterval = 0.008
    private let brightnessThrottle: TimeInterval = 0.008
    
    // Zoom handling
    private var zoomBase: CGFloat = 1.0
    
    // Dependencies (will be injected)
    private weak var camera: CameraService?
    private weak var webSocketService: WebSocketService?
    private var isVerificationMode = false
    private var dismiss: DismissAction?
    
    // MARK: - Setup
    func setup(camera: CameraService, webSocketService: WebSocketService, isVerificationMode: Bool, dismiss: DismissAction) {
        self.camera = camera
        self.webSocketService = webSocketService
        self.isVerificationMode = isVerificationMode
        self.dismiss = dismiss
        self.zoomBase = camera.zoomFactor

        // Show tutorial only if not completed yet
        if !isVerificationMode && !hasCompletedCameraTutorial {
            showCameraTutorial = true
            currentTutorialStep = 0
        }
    }

    // MARK: - Tutorial Methods
    func advanceTutorial() {
        if currentTutorialStep < 4 {
            currentTutorialStep += 1
        } else {
            completeTutorial()
        }
    }

    func skipTutorial() {
        showCameraTutorial = false
        hasCompletedCameraTutorial = true
    }

    private func completeTutorial() {
        showCameraTutorial = false
        hasCompletedCameraTutorial = true
    }
    
    // MARK: - Computed Properties
    
    var brightnessSliderHeight: Double {
        guard let brightnessValue = brightnessDragValue,
              let camera = camera else { return 8.0 }
        
        let minBias = Double(camera.minExposureTargetBias)
        let maxBias = Double(camera.maxExposureTargetBias)
        let clampedValue = max(minBias, min(maxBias, Double(brightnessValue)))
        let progress = (clampedValue - minBias) / (maxBias - minBias)
        return max(8.0, progress * 120.0)
    }
    
    var showGalleryBinding: Binding<Bool> {
        Binding(
            get: { self.showGallery },
            set: { self.showGallery = $0 }
        )
    }
    
    var showPoseSuggestionsBinding: Binding<Bool> {
        Binding(
            get: { self.showPoseSuggestions && !self.useOverlayVersion },
            set: { self.showPoseSuggestions = $0 }
        )
    }
    
    // MARK: - Focus Handling
    func handleFocusTap(at location: CGPoint, in geometry: GeometryProxy, camera: CameraService) {
        focusPoint = location
        let x = max(0, min(1, location.x / geometry.size.width))
        let y = max(0, min(1, location.y / geometry.size.height))
        
        // Perform focus operation on background thread
        Task.detached {
            camera.focus(at: CGPoint(x: x, y: y))
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Auto-hide focus point
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if self.brightnessDragValue == nil {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.focusPoint = nil
                    self.isFocusLocked = false
                }
            }
        }
    }
    
    // MARK: - Gesture Handling
    func handleDragGesture(value: DragGesture.Value, in geometry: GeometryProxy, camera: CameraService) {
        let location = value.location
        
        if focusPoint == nil {
            // First touch - set focus point
            handleFocusTap(at: location, in: geometry, camera: camera)
        } else {
            // Subsequent drag - adjust brightness
            handleBrightnessAdjustment(value: value, camera: camera)
        }
    }
    
    private func handleBrightnessAdjustment(value: DragGesture.Value, camera: CameraService) {
        let now = Date()
        guard now.timeIntervalSince(lastBrightnessUpdate) >= brightnessThrottle else { return }
        
        guard let focusPoint = focusPoint else { return }
        
        let startY = focusPoint.y
        let currentY = value.location.y
        let rawDeltaY = startY - currentY // Inverted for natural feel
        
        // Calculate new brightness value
        let currentValue = Float(camera.evBias)
        let minValue = Float(camera.minExposureTargetBias)
        let maxValue = Float(camera.maxExposureTargetBias)
        
        let evRange = maxValue - minValue
        let normalizedDelta = rawDeltaY / 300.0
        let evDelta = Float(normalizedDelta) * evRange * 0.05
        
        let newValue = min(maxValue, max(minValue, currentValue + evDelta))
        
        lastBrightnessUpdate = now
        
        // Update camera
        camera.setExposureBias(CGFloat(newValue))
        
        // Update UI state with slight delay to prevent conflicts
        Task {
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            self.brightnessDragValue = newValue
        }
    }
    
    func handleDragEnd() {
        Task {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            withAnimation(.easeOut(duration: 0.3)) {
                self.brightnessDragValue = nil
                self.focusPoint = nil
            }
        }
    }
    
    // MARK: - Zoom Handling
    func handleZoomGesture(scale: CGFloat, camera: CameraService) {
        let now = Date()
        guard now.timeIntervalSince(lastZoomUpdate) >= updateThrottle else { return }
        
        let newZoom = zoomBase * scale
        lastZoomUpdate = now
        
        camera.setZoom(factor: min(max(1.0, newZoom), 10.0))
        showZoomArc = true
    }
    
    func handleZoomEnd(camera: CameraService) {
        zoomBase = camera.zoomFactor
        
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            withAnimation(.easeOut(duration: 0.3)) {
                self.showZoomArc = false
            }
        }
    }
    
    func zoomAngle(for zoomFactor: CGFloat) -> Double {
        let zoom = Double(zoomFactor)
        let normalizedZoom = (zoom - 1.0) / (10.0 - 1.0)
        return 120 + (normalizedZoom * 240)
    }
    
    // MARK: - Panel Handling
    func toggleExposurePanel() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showExposurePanel.toggle()
            if showExposurePanel {
                showWhiteBalancePanel = false // Close other panel
            }
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func toggleWhiteBalancePanel() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showWhiteBalancePanel.toggle()
            if showWhiteBalancePanel {
                showExposurePanel = false // Close other panel
            }
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Flash Handling
    func toggleFlash(camera: CameraService) {
        print("🔦 Flash button tapped! Current mode: \(camera.flashMode)")
        
        let oldMode = camera.flashMode
        
        // Update flash mode synchronously for immediate UI response
        switch camera.flashMode {
        case .off:
            camera.flashMode = .auto
        case .auto:
            camera.flashMode = .on
        case .on:
            camera.flashMode = .off
        @unknown default:
            camera.flashMode = .off
        }
        print("🔦 Flash mode changed from \(oldMode) to \(camera.flashMode)")
        
        // Force UI refresh by triggering objectWillChange
        camera.objectWillChange.send()
        
        // Also trigger our own objectWillChange for the ViewModel
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func flashIcon(for flashMode: AVCaptureDevice.FlashMode) -> String {
        let icon = switch flashMode {
        case .off: "bolt.slash"
        case .auto: "bolt.badge.a"
        case .on: "bolt.fill"
        @unknown default: "bolt.slash"
        }
        print("🔦 flashIcon called with mode: \(flashMode.rawValue) -> \(icon)")
        return icon
    }
    
    // MARK: - Shutter Handling
    func handleShutterTap(camera: CameraService, isVerificationMode: Bool, dismiss: DismissAction) {
        // Start processing
        isProcessingImage = true
        print("🚀 Starting image processing - main loader activated")
        
        camera.capturePhoto { [weak self] image in
            guard let self = self, let image = image else {
                Task { @MainActor in
                    self?.isProcessingImage = false
                }
                return
            }
            
            Task { @MainActor in
                self.handleCapturedImage(image, camera: camera, isVerificationMode: isVerificationMode, dismiss: dismiss)
            }
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func applyCorrectOrientation(to image: UIImage, deviceOrientation: UIDeviceOrientation, isFrontCamera: Bool) -> UIImage {
        print("🔄 applyCorrectOrientation: device=\(deviceOrientation.rawValue), front=\(isFrontCamera)")
        print("🔄 Image size: \(image.size)")
        print("🔄 Image orientation: \(image.imageOrientation.rawValue)")

        // iOS camera already handles orientation, but let's ensure proper rotation
        // The key insight: device orientation tells us how the device is held,
        // and we need to rotate the image to match natural viewing orientation

        var correctedImage = image

        // Apply rotation based on device orientation when needed
        // iOS camera captures in landscape by default, so we need to rotate to match device orientation
        switch deviceOrientation {
        case .portrait:
            // Portrait: rotate 90 degrees counter-clockwise to match portrait viewing
            correctedImage = image.rotated(by: -.pi/2) ?? image
        case .portraitUpsideDown:
            // Upside down: rotate 90 degrees clockwise
            correctedImage = image.rotated(by: .pi/2) ?? image
        case .landscapeLeft:
            // Landscape left (home button left): no rotation needed (natural camera orientation)
            correctedImage = image
        case .landscapeRight:
            // Landscape right (home button right): rotate 180 degrees
            correctedImage = image.rotated(by: .pi) ?? image
        default:
            // Face up/down or unknown: assume portrait and rotate 90 degrees counter-clockwise
            correctedImage = image.rotated(by: -.pi/2) ?? image
        }

        print("🔄 Corrected image size: \(correctedImage.size)")
        print("🔄 Corrected image orientation: \(correctedImage.imageOrientation.rawValue)")
        return correctedImage
    }

    private func handleCapturedImage(_ image: UIImage, camera: CameraService, isVerificationMode: Bool, dismiss: DismissAction) {
        print("🎯 Received image in completion handler")
        print("🎯 Image size: \(image.size)")
        print("🎯 Image orientation: \(image.imageOrientation.rawValue)")
        print("🎯 Device orientation: \(UIDevice.current.orientation.rawValue)")
        
        let isFrontCamera = camera.currentCameraPosition == .front
        print("📷 Camera position: \(camera.currentCameraPosition?.rawValue ?? -1)")
        print("📷 isFrontCamera: \(isFrontCamera)")

        // Apply correct orientation based on device orientation
        let deviceOrientation = UIDevice.current.orientation
        print("📱 Device orientation: \(deviceOrientation.rawValue)")

        let orientedImage = applyCorrectOrientation(to: image, deviceOrientation: deviceOrientation, isFrontCamera: isFrontCamera)
        capturedForReview = orientedImage
        print("📏 CameraViewModel: Original captured image size: \(image.size), oriented image size: \(orientedImage.size)")
        
        // Track photo captured
        AnalyticsService.shared.trackPhotoCaptured(
            filter: camera.currentFilter.rawValue,
            aspectRatio: nil,
            hasPoseSuggestions: poseSuggestionsEnabled
        )
        
        // Reset loading states based on current settings
        showPoseSuggestions = false
        showCameraSettingsOverlay = false
        isProcessingImage = false

        // Increment photo count
        photosTaken += 1
        print("📸 Photos taken this session: \(photosTaken)")

        if !isVerificationMode && poseSuggestionsEnabled {
            showPoseSuggestions = true
            AnalyticsService.shared.trackPoseSuggestionRequested()
            print("🎯 Set showPoseSuggestions to true (pose suggestions enabled)")
            // Store the photo for gallery button preview
            lastTakenPhoto = orientedImage
        } else if !isVerificationMode && !poseSuggestionsEnabled && cameraSettingsEnabled {
            print("🎯 Camera settings only mode - showing overlay and sending image for processing")
            // Show overlay for camera settings processing
            showCameraSettingsOverlay = true

            // Send image for camera settings analysis
            if let webSocketService = webSocketService {
                let userId = UserDefaults.standard.string(forKey: "database_user_id")
                webSocketService.sendImage(orientedImage, poseSuggestionsEnabled: false, cameraSettingsEnabled: true, userId: userId)
                print("📤 Image sent for camera settings analysis only")
            } else {
                print("❌ WebSocket service not available for camera settings")
                showCameraSettingsOverlay = false
            }

            // Store the photo for gallery button preview
            lastTakenPhoto = orientedImage
            AnalyticsService.shared.trackPhotoCaptured(
                filter: camera.currentFilter.rawValue,
                aspectRatio: nil,
                hasPoseSuggestions: false
            )
        } else if !isVerificationMode && !poseSuggestionsEnabled {
            print("🎯 No pose suggestions or camera settings - staying in camera with photo preview")
            // Store the photo for gallery button preview
            lastTakenPhoto = orientedImage
            AnalyticsService.shared.trackPhotoCaptured(
                filter: camera.currentFilter.rawValue,
                aspectRatio: nil,
                hasPoseSuggestions: false
            )
        }
        
        if isVerificationMode {
            print("🎯 Verification mode - skipping pose suggestions")
            print("📸 Setting camera.lastPhoto with oriented image")
            // In verification mode, just store the photo and dismiss
            camera.lastPhoto = orientedImage
            print("📸 camera.lastPhoto is now set: \(camera.lastPhoto != nil)")
            // Dismiss the camera view immediately
            dismiss()
        }
    }
    
    // MARK: - Error Handling
    func showProcessingTimeout() {
        isProcessingImage = false
        showCameraSettingsOverlay = false // Hide camera settings overlay on timeout
        processingErrorMessage = "Processing timed out after 35 seconds"
        showProcessingError = true
    }
    
    func retryProcessing() {
        showProcessingError = false
        // This will be called when user taps "Try Again"
    }
    
    func hideCameraSettingsOverlay() {
        showCameraSettingsOverlay = false
    }
    
    func resetCameraState() {
        isProcessingImage = false
        showPoseSuggestions = false
        capturedForReview = nil
        showCameraSettingsOverlay = false
        showProcessingError = false
    }
    
}

// MARK: - Extensions for UI Helpers
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(UnevenRoundedRectangle(cornerRadii: .init(
            topLeading: corners.contains(.topLeft) ? radius : 0,
            bottomLeading: corners.contains(.bottomLeft) ? radius : 0,
            bottomTrailing: corners.contains(.bottomRight) ? radius : 0,
            topTrailing: corners.contains(.topRight) ? radius : 0
        )))
    }
}
