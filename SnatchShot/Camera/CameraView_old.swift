//
//  CameraView.swift
//  SnatchShot
//
//  Created by Rushant on 15/09/25.
//

#if os(iOS)
import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMedia
import SuperwallKit
import Foundation

// MARK: - Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct CameraView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var camera: CameraService
    var isVerificationMode: Bool = false // When true, disables automatic pose generation
    
    // MARK: - Enums (removed unused LeftTool)
    
    @State private var showPreview = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showAdvancedControls = false
    
    // Grid + Guides + Gestures
    @State private var showGrid = false
    @State private var baseZoom: CGFloat = 1.0
    
    // Review sheet
    @State private var showReview = false
    @State private var capturedForReview: UIImage?
    @State private var showPoseSuggestions = false
    @State private var useOverlayVersion = true // Testing overlay version - set to true to force overlay
    @State private var isProcessingImage = false // Controls main loader display
    @State private var showGallery = false // Controls gallery presentation
    @State private var lastTakenPhoto: UIImage? // Last photo taken for gallery button preview
    
    // Superwall Paywall State
    @State private var photosTaken = 0 // Track number of photos taken in session
    @State private var shouldShowPaywallAfterPoseSuggestions = false // Flag to show paywall after pose suggestions
    @State private var isPaywallScheduled = false // Flag to prevent multiple paywall schedules
    
    // Advanced controls
    @State private var showAdvancedSettings = false
    
    // Left-side toggle buttons
    @State private var poseSuggestionsEnabled = false
    @State private var cameraSettingsEnabled = false
    
    // Professional UI State (removed selectedLeftTool)
    @State private var isFilterDrawerOpen = false
    @State private var focusPoint: CGPoint? = nil
    @State private var isFocusLocked = false
    @State private var brightnessDragValue: Float? = nil
    @State private var zoomBase: CGFloat = 1.0
    @State private var whiteBalanceMode: Int = 0 // 0 = warmth, 1 = tone
    @State private var showZoomArc: Bool = false
    
    // Tab navigation
    enum Tab { case camera, gallery }
    @State private var selectedTab: Tab = .camera
    
    // Performance optimization: throttle rapid updates (less aggressive for better responsiveness)
    @State private var lastBrightnessUpdate: Date = Date()
    @State private var lastZoomUpdate: Date = Date()
    private let updateThrottle: TimeInterval = 0.008 // ~120fps for smoother feel
    private let brightnessThrottle: TimeInterval = 0.008 // Consistent 120fps for smooth, stable updates
    
    
    var body: some View {
        cameraTab
            .onAppear {
                AnalyticsService.shared.trackCameraOpened()
            }
    }
    
    private var cameraTab: some View {
        ZStack {
            VStack {
            if camera.isConfigured {
                GeometryReader { geo in
                    ZStack {
                // Full-screen camera preview (background) - rotates automatically with device
                CameraPreview(
                    session: camera.session,
                    currentFilter: camera.currentFilter,
                    contrast: camera.contrast,
                    brightness: camera.brightness,
                    saturation: camera.saturation
                    )
                    .ignoresSafeArea()
                    .id("camera-preview-\(camera.currentFilter.rawValue)") // Force re-render on filter change
                        
                // Focus, brightness, and zoom gestures
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        TapGesture(count: 1)
                            .onEnded { _ in
                                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                        handleFocusTap(at: center, in: geo)
                            }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 8) // Slightly lower for better responsiveness
                            .onChanged { value in
                                let location = value.location
                                if focusPoint == nil {
                                    // First touch - set focus point
                                            handleFocusTap(at: location, in: geo)
                                } else {
                                    // Vertical drag for brightness - Apple-like responsiveness
                                    let now = Date()
                                    guard now.timeIntervalSince(lastBrightnessUpdate) >= brightnessThrottle else { return }
                                    
                                    let startY = focusPoint!.y
                                    let currentY = location.y
                                    let rawDeltaY = startY - currentY // Inverted for natural feel
                                    
                                    // Optimized brightness calculation for better performance
                                    let currentValue = Float(camera.evBias)
                                    let minValue = Float(camera.minExposureTargetBias)
                                    let maxValue = Float(camera.maxExposureTargetBias)
                                    
                                    // Simplified sensitivity calculation
                                    let evRange = maxValue - minValue
                                    let normalizedDelta = rawDeltaY / 300.0 // Fixed sensitivity for consistency
                                    let evDelta = Float(normalizedDelta) * evRange * 0.05 // Balanced multiplier
                                    
                                    let newValue = min(maxValue, max(minValue, currentValue + evDelta))
                                    
                                    lastBrightnessUpdate = now
                                    
                                    // Update camera immediately, then update UI state for consistency
                                    camera.setExposureBias(CGFloat(newValue))
                                    // Small delay for UI state to prevent animation conflicts
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                                        self.brightnessDragValue = newValue
                                    }
                                }
                            }
                            .onEnded { _ in
                                // Simplified cleanup for better performance
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    self.brightnessDragValue = nil
                                    self.focusPoint = nil
                                }
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                let now = Date()
                                guard now.timeIntervalSince(lastZoomUpdate) >= updateThrottle else { return }
                                
                                let newZoom = zoomBase * scale
                                lastZoomUpdate = now
                                
                                // Simplified zoom handling for better performance
                                camera.setZoom(factor: min(max(1.0, newZoom), 10.0))
                                showZoomArc = true
                            }
                            .onEnded { _ in
                                zoomBase = camera.zoomFactor
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    self.showZoomArc = false
                                }
                            }
                    )
                
                        // Focus indicator
                        focusIndicator(in: geo)
                        
                        // Brightness slider (appears during drag)
                        if brightnessDragValue != nil {
                            brightnessSlider(in: geo)
                        }
                        
                        // Active settings indicator
                        activeSettingsIndicator
                    }
                }
            } else {
                // Loading screen
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Setting up camera...")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.headline)
                    }
                }
            }
            
            // ===== TOP-LEFT CONTROLS =====
            topLeftControls
            
            // ===== BOTTOM CENTER CONTROLS =====
            bottomCenterControls
            
            // ===== VERIFICATION MODE CLOSE BUTTON =====
            if isVerificationMode {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            // Dismiss the camera view without taking a photo
                            dismiss()
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
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
            
            // ===== SLIDER PANEL (Removed) =====
            // Panel functionality removed for simplified UI
            
            // ===== FILTER DRAWER =====
            if isFilterDrawerOpen {
                filterDrawer
            }
        }
        // Removed animations to prevent conflicts - let individual components handle their own transitions
        .onAppear {
            zoomBase = camera.zoomFactor
        }
        .fullScreenCover(isPresented: Binding(
            get: { showPoseSuggestions && !useOverlayVersion },
            set: { showPoseSuggestions = $0 }
        )) {
            if let image = capturedForReview {
                // Get user ID from UserDefaults
                let userId = UserDefaults.standard.string(forKey: "database_user_id")
                PoseSuggestionsView(capturedImage: image, poseSuggestionsEnabled: poseSuggestionsEnabled, cameraSettingsEnabled: cameraSettingsEnabled, userId: userId)
                    .preferredColorScheme(.dark)
            }
        }
        .overlay(
            // Overlay version - shows on top of camera view
            Group {
                if showPoseSuggestions && useOverlayVersion {
                    if let image = capturedForReview {
                        // Get user ID from UserDefaults
                        let userId = UserDefaults.standard.string(forKey: "database_user_id")
                        PoseSuggestionsOverlayView(capturedImage: image, startWithLoader: isProcessingImage, poseSuggestionsEnabled: poseSuggestionsEnabled, cameraSettingsEnabled: cameraSettingsEnabled, userId: userId)
                            .preferredColorScheme(.dark)
                            .onDisappear {
                                // Reset processing state when overlay disappears
                                isProcessingImage = false
                            }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView()
                .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Focus Gestures with Brightness Drag
    private func handleFocusTap(at location: CGPoint, in geo: GeometryProxy) {
        focusPoint = location
        let x = max(0, min(1, location.x / geo.size.width))
        let y = max(0, min(1, location.y / geo.size.height))
        
        // Perform focus operation on background thread to avoid UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            self.camera.focus(at: CGPoint(x: x, y: y))
        }
        
        // Haptic feedback for focus
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    // MARK: - Focus Indicator
    @ViewBuilder
    func focusIndicator(in geo: GeometryProxy) -> some View {
        if let focusPoint = focusPoint {
            ZStack {
                // Outer circle with smooth animation
                Circle()
                    .stroke(Color.yellow.opacity(0.8), lineWidth: 2)
                    .frame(width: 50, height: 50)
                    .position(focusPoint)
                    .scaleEffect(isFocusLocked ? 1.1 : 1.0)
                    .opacity(isFocusLocked ? 0.9 : 0.7)
                
                // Inner focus point
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .position(focusPoint)
                
                // Focus lock indicator
                if isFocusLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                        .position(x: focusPoint.x, y: focusPoint.y - 30)
                }
            }
            .transition(.opacity)
            .onAppear {
                // Auto-hide after 2 seconds unless brightness slider is active
                if brightnessDragValue == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        // Clear focus point without animation to avoid conflicts
                        self.focusPoint = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Brightness Slider Helper Properties (Optimized)
    private func getBrightnessProgress() -> Double {
        guard let brightnessValue = brightnessDragValue else { return 0.5 }
        let minBias = Double(camera.minExposureTargetBias)
        let maxBias = Double(camera.maxExposureTargetBias)
        let clampedValue = max(minBias, min(maxBias, Double(brightnessValue)))
        return (clampedValue - minBias) / (maxBias - minBias)
    }
    
    private func getBrightnessSliderHeight() -> Double {
        let progress = getBrightnessProgress()
        return max(8.0, progress * 120.0)
    }
    
    // MARK: - Brightness Slider Components
    @ViewBuilder
    private func brightnessTrack() -> some View {
        ZStack {
            // Background track with subtle gradient
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.3)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            
            // Active track with smooth animation
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.yellow.opacity(0.9),
                                Color.yellow.opacity(0.7)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 6, height: getBrightnessSliderHeight())
                    .shadow(color: Color.yellow.opacity(0.3), radius: 2, x: 0, y: 0)
            }
        }
        .frame(width: 6, height: 120)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func brightnessValueDisplay() -> some View {
        VStack(spacing: 2) {
            if let brightnessValue = brightnessDragValue {
                Text(String(format: "%.1f", brightnessValue))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    )
                    .transition(.opacity)
            }
            
            Text("EV")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Brightness Slider
    @ViewBuilder
    func brightnessSlider(in geo: GeometryProxy) -> some View {
        if brightnessDragValue != nil, let focusPoint = focusPoint {
            HStack(spacing: 8) {
                // Vertical slider
                VStack(spacing: 4) {
                    Text("☀️")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    
                    brightnessTrack()
                    
                    Text("🌙")
                        .font(.system(size: 14))
                        .foregroundColor(.blue.opacity(0.7))
                }
                .frame(width: 20)
                
                brightnessValueDisplay()
            }
            .position(x: focusPoint.x + 40, y: focusPoint.y)
            .transition(.opacity)
        }
    }
    
    // MARK: - Active Settings Indicator
    @ViewBuilder
    var activeSettingsIndicator: some View {
        if camera.currentFilter != .none || camera.contrast != 1.0 || camera.brightness != 0.0 || camera.saturation != 1.0 {
            VStack {
                HStack(spacing: 12) {
                    if camera.currentFilter != .none {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.filters")
                                .font(.caption)
                            Text(camera.currentFilter.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                    }
                    
                    if camera.contrast != 1.0 || camera.brightness != 0.0 || camera.saturation != 1.0 {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                            Text("Adjusted")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 60)
        }
    }
    // MARK: - Top-Left Controls
    @ViewBuilder
    var topLeftControls: some View {
        VStack {
            HStack(spacing: 16) {
                // Exposure (EV bias)
                VStack(spacing: 4) {
                    Button {
                        // Exposure control - simplified (no toggle state)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            Image(systemName: "plusminus.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .frame(width: 44, height: 44)
                    
                    Text("EV")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // White Balance
                VStack(spacing: 4) {
                    Button {
                        // White balance control - simplified (no toggle state)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            Image(systemName: "thermometer")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .frame(width: 44, height: 44)
                    
                    Text("WB")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Night Mode - Direct Toggle
                VStack(spacing: 4) {
                    Button {
                        // Direct toggle - no popup needed
                        camera.setNightMode(camera.nightMode != .off ? .off : .on)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        ZStack {
                            // Beautiful lavender ring when night mode is active
                            if camera.nightMode != .off {
                                Circle()
                                    .stroke(Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.9), lineWidth: 3)
                                    .frame(width: 50, height: 50)
                                    .blur(radius: 1) // Soft lavender glow effect
                            }
                            
                            Circle()
                                .fill(.ultraThinMaterial.opacity(0.8))
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            Image(systemName: camera.nightMode != .off ? "moon.circle.fill" : "moon.circle")
                                .font(.system(size: 22))
                                .foregroundColor(camera.nightMode != .off ? Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.9) : .white.opacity(0.8))
                        }
                    }
                    .frame(width: 44, height: 44)
                    
                    Text("Night")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(camera.nightMode != .off ? Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8) : .white.opacity(0.7))
                }
            }
            .padding(.leading, 16)
            .padding(.top, 16)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Bottom Center Controls
    @ViewBuilder
    var bottomCenterControls: some View {
        GeometryReader { geo in
            let safeArea = geo.safeAreaInsets
            
            // Controls that stay fixed to device edges
            ZStack {
                // Shutter button - stays with bottom/right edge
                bottomShutterSegment
                    .position(x: geo.size.width - 70 - safeArea.trailing,
                             y: geo.size.height - 70 - safeArea.bottom)

                // Left/bottom edge controls
                VStack(spacing: 16) {
                        // Pose Suggestions toggle
                        Button {
                            poseSuggestionsEnabled.toggle()
                            if poseSuggestionsEnabled {
                                AnalyticsService.shared.trackPoseSuggestionsToggledOn()
                            } else {
                                AnalyticsService.shared.trackPoseSuggestionsToggledOff()
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            Image(systemName: poseSuggestionsEnabled ? "figure.walk.circle.fill" : "figure.walk.circle")
                                .font(.system(size: 22))
                                .foregroundColor(poseSuggestionsEnabled ? .green : .white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                        }

                        // Camera Settings toggle
                        Button {
                            cameraSettingsEnabled.toggle()
                            if cameraSettingsEnabled {
                                AnalyticsService.shared.trackCameraSettingsToggledOn()
                            } else {
                                AnalyticsService.shared.trackCameraSettingsToggledOff()
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            Image(systemName: cameraSettingsEnabled ? "gearshape.fill" : "gearshape")
                                .font(.system(size: 22))
                                .foregroundColor(cameraSettingsEnabled ? .green : .white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                        }
                    }
                }
                .position(x: 70 + safeArea.leading,
                         y: geo.size.height - 120 - safeArea.bottom)

                // Right/bottom edge controls
                VStack(spacing: 16) {
                    // Flash toggle
                    Button {
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
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        Image(systemName: flashIcon)
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                    }

                    // Filter button
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFilterDrawerOpen.toggle()
                            if isFilterDrawerOpen {
                                AnalyticsService.shared.trackFilterDrawerOpened()
                            }
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        Image(systemName: "camera.filters")
                            .font(.system(size: 22))
                            .foregroundColor(isFilterDrawerOpen ? .green : .white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                    }
                }
                .position(x: geo.size.width - 70 - safeArea.trailing,
                         y: geo.size.height - 120 - safeArea.bottom)
            }
        }
    }
    
    // MARK: - Conditional Zoom Arc
    @ViewBuilder
    var zoomArc: some View {
        VStack {
            Spacer()
            
            ZStack {
                // Zoom arc background
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.8))
                    .frame(width: 200, height: 200)
                    .offset(y: 20)
                
                // Zoom ticks
                ForEach(zoomTicks, id: \.value) { tick in
                    VStack {
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .offset(y: -85)
                        
                        if tick.showLabel {
                            Text("\(Int(tick.value))×")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .offset(y: -95)
                        }
                    }
                    .rotationEffect(.degrees(tick.angle))
                }
                
                // Zoom thumb (draggable)
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                    .shadow(radius: 4)
                    .offset(y: -85)
                    .rotationEffect(.degrees(zoomAngle))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let center = CGPoint(x: 100, y: 100)
                                let touchPoint = CGPoint(x: 100 + value.location.x, y: 120 + value.location.y)
                                let angle = atan2(touchPoint.y - center.y, touchPoint.x - center.x) * 180 / .pi
                                let normalizedAngle = (angle + 180).truncatingRemainder(dividingBy: 360)
                                let zoomFactor = zoomFromAngle(normalizedAngle)
                                camera.setZoom(factor: zoomFactor)
                            }
                    )
            }
            .frame(height: 140)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Flash Icon Helper
    
    
    var flashIcon: String {
        switch camera.flashMode {
        case .off: return "bolt.slash"
        case .auto: return "bolt.badge.a"
        case .on: return "bolt.fill"
        @unknown default: return "bolt.slash"
        }
    }
    
    // MARK: - Bottom Shutter Segment
    @ViewBuilder
    var bottomShutterSegment: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 80) {
                // Gallery button (left side)
                Button {
                    // Present gallery as full screen cover
                    showGallery = true
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.8))
                            .frame(width: 65, height: 65)
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        
                        // Show last taken photo as thumbnail, or icon if no photo
                        if let lastPhoto = lastTakenPhoto {
                            Image(uiImage: lastPhoto)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 65, height: 65)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                
                // Shutter button (center) with zoom arc
                ZStack {
                    VStack {
                    Group {
                        if showZoomArc {
                            // Semi-circular zoom arc
                            Path { path in
                                path.addArc(center: CGPoint(x: 100, y: 100),
                                            radius: 85,
                                            startAngle: .degrees(-60), // Rotated 180 degrees
                                            endAngle: .degrees(240),
                                            clockwise: true)
                            }
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 200, height: 200)
                            .offset(y: 20)
                            
                            // Zoom ticks and labels
                            ForEach(zoomTicks, id: \.value) { tick in
                                VStack(spacing: 2) {
                                    // Tick mark
                                    Rectangle()
                                        .fill(Color.white.opacity(0.6))
                                        .frame(width: 1, height: tick.showLabel ? 6 : 4)
                                        .offset(y: -85)
                                    
                                    if tick.showLabel {
                                        Text("\(String(format: "%.1f", tick.value))×")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                            .offset(y: -90)
                                    }
                                }
                                .rotationEffect(.degrees(-tick.angle)) // Inverted angle
                            }
                            
                            // Current zoom indicator
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: -82))
                                path.addLine(to: CGPoint(x: 0, y: -88))
                            }
                            .stroke(Color.yellow, lineWidth: 2)
                            .offset(y: 0)
                            .rotationEffect(.degrees(-zoomAngle)) // Inverted angle
                            
                            // Zoom value label
                            Text(String(format: "%.1f×", camera.zoomFactor))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow)
                                .offset(y: -50)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Center the gesture on the shutter button (center of screen)
                                let center = CGPoint(x: 0, y: 0) // Center relative to the ZStack
                                let touchPoint = CGPoint(x: value.location.x, y: value.location.y)
                                let angle = atan2(touchPoint.y - center.y, touchPoint.x - center.x) * 180 / .pi
                                let normalizedAngle = (angle + 180).truncatingRemainder(dividingBy: 360)
                                let zoomFactor = zoomFromAngle(normalizedAngle)
                                camera.setZoom(factor: zoomFactor)
                            }
                    )
                    
                    // Shutter button
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: 3)
                            .frame(width: 76, height: 76)
                        
                        Circle()
                            .fill(Color(red: 0.8, green: 0.7, blue: 1.0))
                            .frame(width: 62, height: 62)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .frame(width: 76, height: 76)
                    .contentShape(Circle())
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showZoomArc.toggle()
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                    )
                    .onTapGesture {
                        // Check for paywall on subsequent photos (4th photo and beyond)
                        if photosTaken >= 3 && !isUserOnPaidPlan() {
                            Superwall.shared.register(placement: "camera_usage_paywall")
                            print("💰 Showing paywall on shutter click (photo \(photosTaken + 1))")
                        }
                        
                        // Start processing immediately - show main loader
                        isProcessingImage = true
                        print("🚀 Starting image processing - main loader activated")
                        
                        camera.capturePhoto { [self] image in
                            print("🎯 Received image in completion handler: \(image != nil)")
                            if let image = image {
                                print("🎯 Image size: \(image.size)")
                                print("🎯 Image orientation: \(image.imageOrientation.rawValue) (\(image.imageOrientation))")
                                print("🎯 Device orientation: \(UIDevice.current.orientation.rawValue) (\(UIDevice.current.orientation))")
                                let isFrontCamera = camera.currentCameraPosition == .front
                                print("📷 Camera position: \(camera.currentCameraPosition?.rawValue ?? -1) (\(camera.currentCameraPosition.map { $0 == .front ? "front" : "back" } ?? "unknown"))")
                                print("📷 isFrontCamera: \(isFrontCamera)")
                                capturedForReview = image.rotateToCorrectOrientation(isFrontCamera: isFrontCamera)
                                
                                // Track photo captured
                                AnalyticsService.shared.trackPhotoCaptured(
                                    filter: camera.currentFilter.rawValue,
                                    aspectRatio: nil, // TODO: Add aspect ratio tracking if available
                                    hasPoseSuggestions: poseSuggestionsEnabled
                                )
                                
                                // Increment photo count on main thread
                                DispatchQueue.main.async {
                                    photosTaken += 1
                                    print("📸 Photos taken this session: \(photosTaken)")
                                    
                                    if !isVerificationMode && poseSuggestionsEnabled {
                                        showPoseSuggestions = true
                                        AnalyticsService.shared.trackPoseSuggestionRequested()
                                        print("🎯 Set showPoseSuggestions to true (pose suggestions enabled)")
                                        
                                        // Check if we should show paywall after pose suggestions
                                        if photosTaken >= 3 && !isUserOnPaidPlan() {
                                            shouldShowPaywallAfterPoseSuggestions = true
                                            print("💰 Will show paywall after pose suggestions")
                                            // Schedule paywall to show after pose suggestions with delay
                                            showPaywallAfterPoseSuggestions()
                                        }
                                    } else if !isVerificationMode && !poseSuggestionsEnabled {
                                        print("🎯 Pose suggestions disabled - staying in camera with photo preview")
                                        // Store the photo for gallery button preview (with rotation correction)
                                        let isFrontCamera = camera.currentCameraPosition == .front
                                        lastTakenPhoto = image.rotateToCorrectOrientation(isFrontCamera: isFrontCamera)
                                        AnalyticsService.shared.trackPhotoCaptured(
                                            filter: camera.currentFilter.rawValue,
                                            aspectRatio: nil,
                                            hasPoseSuggestions: false
                                        )
                                    }
                                    
                                    if isVerificationMode {
                                        print("🎯 Verification mode - skipping pose suggestions")
                                        print("📸 Setting camera.lastPhoto with image: \(image != nil)")
                                        // In verification mode, just store the photo and dismiss
                                        let isFrontCamera = camera.currentCameraPosition == .front
                                        let correctedImage = image.rotateToCorrectOrientation(isFrontCamera: isFrontCamera)
                                        camera.lastPhoto = correctedImage
                                        print("📸 camera.lastPhoto is now set: \(camera.lastPhoto != nil)")
                                        // Dismiss the camera view immediately
                                        dismiss()
                                    }
                                    }
                                } else {
                                    print("🎯 No image received")
                                    isProcessingImage = false // Stop loader if no image
                                }
                            }
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }
                    
                    // Flip camera button (right side)
                    Button {
                        camera.switchCamera()
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
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
                .frame(height: 140)
                .offset(y: 20) // Normal position
            }
        }
    
    // MARK: - Zoom Helper Functions
    var zoomAngle: Double {
        let zoom = Double(camera.zoomFactor)
        return angleFromZoom(zoom)
    }
    
    func angleFromZoom(_ zoom: Double) -> Double {
        let normalizedZoom = (zoom - 1.0) / (10.0 - 1.0) // 1x to 10x
        return 120 + (normalizedZoom * 240) // 120° to 360°
    }
    
    func zoomFromAngle(_ angle: Double) -> CGFloat {
        let normalizedAngle = (angle - 120) / 240 // 0 to 1
        let zoom = 1.0 + (normalizedAngle * 9.0) // 1x to 10x
        return max(1.0, min(10.0, CGFloat(zoom)))
    }
    
    var zoomTicks: [(value: Double, angle: Double, showLabel: Bool)] {
        var ticks: [(Double, Bool)] = []
        // Main ticks with labels
        ticks.append((0.5, true))
        ticks.append((1.0, true))
        ticks.append((2.0, true))
        ticks.append((5.0, true))
        // Minor ticks without labels
        for value in stride(from: 0.6, through: 0.9, by: 0.1) { ticks.append((value, false)) }
        for value in stride(from: 1.2, through: 1.8, by: 0.2) { ticks.append((value, false)) }
        for value in stride(from: 2.5, through: 4.5, by: 0.5) { ticks.append((value, false)) }
        
        return ticks.map { value, showLabel in
            let angle = angleFromZoom(value)
            return (value, angle, showLabel)
        }.sorted(by: { $0.value < $1.value })
    }
    
    // MARK: - Superwall Helper Functions
    private func isUserOnPaidPlan() -> Bool {
        // TODO: Implement logic to check if user has active paid subscription
        // For now, return false to show paywalls during testing
        // This should check your subscription status from your backend
        return false
    }
    
    // MARK: - Paywall Helper Functions
    private func showPaywallAfterPoseSuggestions() {
        guard !isPaywallScheduled else { return } // Prevent multiple schedules
        isPaywallScheduled = true
        
        // Show paywall 2-3 seconds after pose suggestions are displayed
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if shouldShowPaywallAfterPoseSuggestions {
                Superwall.shared.register(placement: "camera_usage_paywall")
                print("💰 Showing paywall after pose suggestions delay")
                shouldShowPaywallAfterPoseSuggestions = false // Reset flag
            }
            isPaywallScheduled = false // Reset schedule flag
        }
    }
    
    // MARK: - Filter Drawer
    @ViewBuilder
    var filterDrawer: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Intensity slider (optional)
                HStack {
                    Text("Intensity")
                        .font(.caption)
                        .foregroundColor(.white)
                    Slider(value: .constant(1.0), in: 0...1)
                        .tint(.green)
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Filter thumbnails
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        VStack {
                        ForEach(CameraFilter.allCases.filter { $0 != .none }, id: \.self) { filter in
                            Button {
                                self.camera.setFilter(filter)
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.ultraThinMaterial.opacity(0.8))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "camera.filters")
                                            .foregroundColor(self.camera.currentFilter == filter ? .green : .white.opacity(0.7))
                                    }
                                    
                                    Text(filter.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(self.camera.currentFilter == filter ? .green : .white.opacity(0.7))
                                        .lineLimit(1)
                                        .frame(width: 60)
                                }
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
            .transition(.opacity) // Simplified to prevent animation conflicts
    }
}
}
#endif
