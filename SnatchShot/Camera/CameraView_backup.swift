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
#endif

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
    @StateObject private var camera = CameraService()

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

    // Advanced controls
    @State private var showAdvancedSettings = false

    // New Professional UI State
    enum LeftTool { case exposure, whiteBalance, night }
    @State private var selectedLeftTool: LeftTool? = nil
    @State private var isFilterDrawerOpen = false
    @State private var focusPoint: CGPoint? = nil
    @State private var isFocusLocked = false
    @State private var brightnessDragValue: Float? = nil
    @State private var zoomBase: CGFloat = 1.0
    @State private var whiteBalanceMode: Int = 0 // 0 = warmth, 1 = tone


    var body: some View {
        ZStack {
            if camera.isConfigured {
                GeometryReader { geo in
                    ZStack {
                        // Full-screen camera preview (background)
                        CameraPreview(
                            session: camera.session,
                            currentFilter: camera.currentFilter,
                            contrast: camera.contrast,
                            brightness: camera.brightness,
                            saturation: camera.saturation
                        )
                        .ignoresSafeArea()

                        // Focus gestures with brightness drag
                        focusGestures(in: geo)

                        // Focus indicator
                        focusIndicator(in: geo)

                        // Brightness slider (appears during drag)
                        brightnessSlider(in: geo)

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

            // ===== LEFT RAIL =====
            leftRail

            // ===== RIGHT CONTROLS =====
            rightControls

            // ===== BOTTOM SHUTTER SEGMENT =====
            bottomShutterSegment

            // ===== FILTER DRAWER =====
            if isFilterDrawerOpen {
                filterDrawer
            }
        }
        .onAppear {
            zoomBase = camera.zoomFactor
        }

    // MARK: - Focus Gestures with Brightness Drag
    @ViewBuilder
    func focusGestures(in geo: GeometryProxy) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    TapGesture()
                        .onEnded {
                            handleFocusTap(at: nil, in: geo) // Use center if no location
                        },
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            camera.toggleAEAFLock()
                            isFocusLocked.toggle()
                            // Haptic feedback for lock
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                )
                .simultaneously(with:
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let location = value.location
                            if focusPoint == nil {
                                // First touch - set focus point
                                handleFocusTap(at: location, in: geo)
                            } else {
                                // Subsequent drag - adjust brightness
                                let deltaY = value.translation.height
                                let sensitivity: CGFloat = 200 // pixels per EV stop
                                let evDelta = Float(deltaY / sensitivity)
                                let newValue = min(camera.maxExposureTargetBias,
                                                 max(camera.minExposureTargetBias,
                                                     (brightnessDragValue ?? Float(camera.evBias)) - evDelta))
                                camera.setExposureBias(CGFloat(newValue))
                                brightnessDragValue = newValue
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.3)) {
                                brightnessDragValue = nil
                            }
                        }
                )
            )
    }

    private func handleFocusTap(at location: CGPoint?, in geo: GeometryProxy) {
        if let location = location {
            focusPoint = location
            let x = max(0, min(1, location.x / geo.size.width))
            let y = max(0, min(1, location.y / geo.size.height))
            camera.focus(at: CGPoint(x: x, y: y))
        } else {
            // Center focus
            focusPoint = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            camera.focus(at: CGPoint(x: 0.5, y: 0.5))
        }

        // Haptic feedback for focus
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Focus Indicator
    @ViewBuilder
    func focusIndicator(in geo: GeometryProxy) -> some View {
        if let focusPoint = focusPoint {
            ZStack {
                // Animated reticle
                Circle()
                    .stroke(isFocusLocked ? Color.red : Color.yellow, lineWidth: 2)
                    .frame(width: isFocusLocked ? 60 : 48, height: isFocusLocked ? 60 : 48)
                    .position(focusPoint)
                    .scaleEffect(isFocusLocked ? 1.2 : 1.0)
                    .opacity(isFocusLocked ? 0.9 : 0.8)

                // Inner circle
                Circle()
                    .fill(isFocusLocked ? Color.red.opacity(0.2) : Color.yellow.opacity(0.2))
                    .frame(width: 12, height: 12)
                    .position(focusPoint)
            }
            .animation(.easeInOut(duration: 0.2), value: isFocusLocked)
            .onAppear {
                // Auto-hide after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.focusPoint = nil
                    }
                }
            }
        }
    }

    // MARK: - Brightness Slider
    @ViewBuilder
    func brightnessSlider(in geo: GeometryProxy) -> some View {
        if let brightnessValue = brightnessDragValue, let focusPoint = focusPoint {
            VStack(spacing: 8) {
                Text(String(format: "%.1f", brightnessValue))
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))

                Slider(value: Binding(
                    get: { brightnessValue },
                    set: { newValue in
                        camera.setExposureBias(CGFloat(newValue))
                        brightnessDragValue = newValue
                    }
                ), in: Float(camera.minExposureTargetBias)...Float(camera.maxExposureTargetBias))
                .frame(width: 200)
                .tint(.yellow)
            }
            .position(x: focusPoint.x, y: focusPoint.y - 60)
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

    // MARK: - Left Rail
    @ViewBuilder
    var leftRail: some View {
        HStack {
            VStack(spacing: 10) {
                // Exposure (EV bias)
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedLeftTool = selectedLeftTool == .exposure ? nil : .exposure
                    }
                    // Haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: "plusminus.circle")
                        .font(.system(size: 24))
                        .foregroundColor(selectedLeftTool == .exposure ? .yellow : .white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                }
                .accessibilityLabel("Exposure compensation")

                // White Balance
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedLeftTool = selectedLeftTool == .whiteBalance ? nil : .whiteBalance
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: "thermometer")
                        .font(.system(size: 24))
                        .foregroundColor(selectedLeftTool == .whiteBalance ? .yellow : .white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                }
                .accessibilityLabel("White balance")

                // Night Mode
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedLeftTool = selectedLeftTool == .night ? nil : .night
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: "moon.circle")
                        .font(.system(size: 24))
                        .foregroundColor(selectedLeftTool == .night ? .yellow : .white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                }
                .accessibilityLabel("Night mode")
            }
            .padding(.leading, 16)
            .padding(.vertical, 20)

            // Slider Panel
            if let selectedTool = selectedLeftTool {
                leftSliderPanel(for: selectedTool)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    func leftSliderPanel(for tool: LeftTool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .frame(width: 72)

            VStack(spacing: 16) {
                switch tool {
                case .exposure:
                    VStack(spacing: 8) {
                        Image(systemName: "plusminus.circle")
                            .foregroundColor(.yellow)
                        Slider(value: Binding(
                            get: { Float(camera.evBias) },
                            set: { camera.setExposureBias(CGFloat($0)) }
                        ), in: Float(camera.minExposureTargetBias)...Float(camera.maxExposureTargetBias))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40, height: 120)
                        .tint(.yellow)
                    }

                case .whiteBalance:
                    VStack(spacing: 8) {
                        Picker("", selection: $whiteBalanceMode) {
                            Text("Warmth").tag(0)
                            Text("Tone").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 60)

                        if whiteBalanceMode == 0 {
                            // Temperature (Warmth)
                            Slider(value: Binding(
                                get: { Float(camera.whiteBalanceTemperature) },
                                set: { camera.setWhiteBalanceTemperature(CGFloat($0), tint: camera.whiteBalanceTint) }
                            ), in: 2000...10000)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 40, height: 120)
                            .tint(.orange)
                        } else {
                            // Tint (Tone)
                            Slider(value: Binding(
                                get: { Float(camera.whiteBalanceTint) },
                                set: { camera.setWhiteBalanceTemperature(camera.whiteBalanceTemperature, tint: CGFloat($0)) }
                            ), in: -50...50)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 40, height: 120)
                            .tint(.blue)
                        }
                    }

                case .night:
                    VStack(spacing: 8) {
                        Image(systemName: "moon.circle")
                            .foregroundColor(.blue)

                        Toggle("", isOn: Binding(
                            get: { camera.nightMode != .off },
                            set: { camera.setNightMode($0 ? .on : .off) }
                        ))
                        .tint(.blue)

                        if camera.nightMode != .off {
                            Slider(value: $camera.nightModeIntensity, in: 0...1)
                                .rotationEffect(.degrees(-90))
                                .frame(width: 40, height: 80)
                                .tint(.blue)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .frame(width: 72, height: 200)
    }

    // MARK: - Right Controls
    @ViewBuilder
    var rightControls: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
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
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                }
                .accessibilityLabel("Flash mode: \(camera.flashMode.rawValue)")

                // Filters drawer toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isFilterDrawerOpen.toggle()
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 24))
                        .foregroundColor(isFilterDrawerOpen ? .green : .white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                }
                .accessibilityLabel("Filters")
            }
            .padding(.trailing, 16)
            .padding(.bottom, 120) // Above shutter segment
        }
    }

    private var flashIcon: String {
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

                // Shutter button (center)
                Button {
                    camera.capturePhoto()
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: 4)
                            .frame(width: 76, height: 76)

                        Circle()
                            .fill(.white)
                            .frame(width: 60, height: 60)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .frame(width: 76, height: 76)
            }
            .frame(height: 140)
            .padding(.bottom, 40)
        }
    }

    private var zoomAngle: Double {
        let zoom = Double(camera.zoomFactor)
        return angleFromZoom(zoom)
    }

    private func angleFromZoom(_ zoom: Double) -> Double {
        let normalizedZoom = (zoom - 1.0) / (10.0 - 1.0) // 1x to 10x
        return 120 + (normalizedZoom * 240) // 120° to 360°
    }

    private func zoomFromAngle(_ angle: Double) -> CGFloat {
        let normalizedAngle = (angle - 120) / 240 // 0 to 1
        let zoom = 1.0 + (normalizedAngle * 9.0) // 1x to 10x
        return max(1.0, min(10.0, CGFloat(zoom)))
    }

    private var zoomTicks: [(value: Double, angle: Double, showLabel: Bool)] {
        let tickValues: [Double] = [1, 2, 3, 5, 10]
        return tickValues.map { value in
            let angle = angleFromZoom(value)
            let showLabel = [1, 2, 3, 5, 10].contains(Int(value))
            return (value, angle, showLabel)
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
                        ForEach(CameraFilter.allCases.filter { $0 != .none }, id: \.self) { filter in
                            Button {
                                camera.setFilter(filter)
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.ultraThinMaterial.opacity(0.8))
                                            .frame(width: 60, height: 60)

                                        Image(systemName: "camera.filters")
                                            .foregroundColor(camera.currentFilter == filter ? .green : .white.opacity(0.7))
                                    }

                                    Text(filter.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(camera.currentFilter == filter ? .green : .white.opacity(0.7))
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
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
