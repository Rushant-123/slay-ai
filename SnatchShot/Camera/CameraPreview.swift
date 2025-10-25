//
//  CameraPreview.swift
//  SnatchShot
//
//  Created by Rushant on 15/09/25.
//

#if os(iOS)
import SwiftUI
import AVFoundation
import UIKit
import CoreImage
import CoreMedia
import Metal
import MetalKit
#endif

extension AVCaptureVideoPreviewLayer {
    func getCurrentImage() -> CIImage? {
        // Create a CIImage from the current preview layer contents
        guard let contents = self.contents else { return nil }
        let cgImage = contents as! CGImage
        return CIImage(cgImage: cgImage)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let currentFilter: CameraFilter
    let currentPreset: FilterPreset?
    let contrast: CGFloat
    let brightness: CGFloat
    let saturation: CGFloat

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        // Filter processor will be created on-demand when first filter is applied
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        let filterName = currentPreset?.name ?? currentFilter.rawValue
        print("🔧 SwiftUI updateUIView called for filter: \(filterName)")
        uiView.updateFilters(currentFilter: currentFilter, currentPreset: currentPreset, contrast: contrast, brightness: brightness, saturation: saturation)
        print("🔧 SwiftUI updateUIView completed for filter: \(filterName)")
        // Removed ensureFilterProcessorSetup() call - no longer needed with overlay approach
    }

    final class PreviewView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            setupOrientationNotifications()
            updatePreviewOrientation()
        }
        
        private func setupOrientationNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(orientationDidChange),
                name: UIDevice.orientationDidChangeNotification,
                object: nil
            )
        }
        
        @objc private func orientationDidChange() {
            // Throttle orientation updates to prevent hangs during filter operations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updatePreviewOrientation()
            }
        }
        
        private var lastOrientationUpdate: CFTimeInterval = 0
        private let orientationUpdateInterval: CFTimeInterval = 0.5 // Limit to 2 updates per second
        
        private func updatePreviewOrientation() {
            // Throttle orientation updates to prevent hangs
            let now = CACurrentMediaTime()
            guard now - lastOrientationUpdate >= orientationUpdateInterval else {
                print("🔄 Skipping orientation update (throttled)")
                return
            }
            lastOrientationUpdate = now
            
            guard let connection = videoPreviewLayer.connection,
                  connection.isVideoOrientationSupported else { 
                print("🔄 Orientation update skipped (connection not available)")
                return 
            }
            
            let deviceOrientation = UIDevice.current.orientation
            let videoOrientation: AVCaptureVideoOrientation
            
            switch deviceOrientation {
            case .portrait:
                videoOrientation = .portrait
            case .portraitUpsideDown:
                videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                videoOrientation = .landscapeRight // Camera sensor is rotated
            case .landscapeRight:
                videoOrientation = .landscapeLeft // Camera sensor is rotated
            default:
                // For unknown orientations, try to use interface orientation
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    switch windowScene.interfaceOrientation {
                    case .portrait:
                        videoOrientation = .portrait
                    case .portraitUpsideDown:
                        videoOrientation = .portraitUpsideDown
                    case .landscapeLeft:
                        videoOrientation = .landscapeLeft
                    case .landscapeRight:
                        videoOrientation = .landscapeRight
                    default:
                        videoOrientation = .portrait
                    }
                } else {
                    videoOrientation = .portrait
                }
            }
            
            // Only update if orientation actually changed
            if connection.videoOrientation != videoOrientation {
                connection.videoOrientation = videoOrientation
                print("🔄 Updated video orientation to: \(videoOrientation) for device: \(deviceOrientation)")
            } else {
                print("🔄 Orientation unchanged, skipping update")
            }
        }

        // Make filter processor static to persist across view recreations
        private static var sharedFilterProcessor: FilterProcessor?
        private var filterProcessor: FilterProcessor? {
            get { Self.sharedFilterProcessor }
            set { Self.sharedFilterProcessor = newValue }
        }
        private var ciContext: CIContext?
        private var videoDataOutput: AVCaptureVideoDataOutput?

        func setupFilterProcessor() {
            // Avoid re-initializing if already set up
            if filterProcessor != nil {
                print("ℹ️ Filter processor already set up, skipping")
                return
            }

            print("🔧 Setting up filter processor...")
            filterProcessor = FilterProcessor()
            ciContext = CIContext()
            
            // We don't need video data output anymore since we're using overlays
            // This eliminates the source of hangs
            print("✅ Filter processor set up successfully (overlay mode)")
        }

        // Track previous values to prevent unnecessary updates
        private var lastFilter: CameraFilter?
        private var lastPreset: FilterPreset?
        private var lastContrast: CGFloat?
        private var lastBrightness: CGFloat?
        private var lastSaturation: CGFloat?

    // GPU-accelerated preview renderer (like Snappit, LoFiCam, DazzCam, KAPI)
    private var metalPreviewRenderer: MetalPreviewRenderer?

    // Performance optimization: enable GPU effects on capable devices
    private lazy var enableGPUPreviewEffects: Bool = {
        // Get device model identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(cString: ptr)
            }
        }

        // Modern devices with A14/A15/A16/A17 chips (iPhone 12+)
        let gpuCapableModels = [
            "iPhone13", "iPhone14", "iPhone15", "iPhone16", "iPhone17", // iPhone 12+
            "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,5", "iPad8,6", // iPad Pro 4th gen
            "iPad8,7", "iPad8,8", "iPad8,9", "iPad8,10", "iPad8,11", "iPad8,12", // iPad Pro 4th gen
            "iPad13", "iPad14" // iPad Pro 5th/6th gen
        ]
        let hasCapableGPU = gpuCapableModels.contains { modelCode.hasPrefix($0) }

        // Initialize Metal renderer if capable
        if hasCapableGPU, let device = MTLCreateSystemDefaultDevice() {
            metalPreviewRenderer = MetalPreviewRenderer(device: device)
            print("🚀 Initialized GPU-accelerated preview renderer (like professional camera apps)")
            return true
        }

        print("📱 Using CPU Core Image effects (device not GPU-capable for advanced preview)")
        return false
    }()

        func updateFilters(currentFilter: CameraFilter, currentPreset: FilterPreset?, contrast: CGFloat, brightness: CGFloat, saturation: CGFloat) {
            // Check if anything actually changed to prevent unnecessary processing
            let filterChanged = lastFilter != currentFilter
            let presetChanged = lastPreset?.id != currentPreset?.id
            let contrastChanged = lastContrast != contrast
            let brightnessChanged = lastBrightness != brightness
            let saturationChanged = lastSaturation != saturation

            if !filterChanged && !presetChanged && !contrastChanged && !brightnessChanged && !saturationChanged {
                // Nothing changed, skip expensive operations
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let filterName = currentPreset?.name ?? currentFilter.rawValue
            print("⏱️ updateFilters STARTED at \(startTime) - Changes: filter=\(filterChanged), preset=\(presetChanged), contrast=\(contrastChanged), brightness=\(brightnessChanged), saturation=\(saturationChanged)")

            // Ensure filter processor exists but don't recreate if it exists
            if filterProcessor == nil {
                print("🔧 Creating filter processor for first time")
                filterProcessor = FilterProcessor()
            }

            filterProcessor?.currentFilter = currentFilter
            filterProcessor?.setCurrentPreset(currentPreset)
            filterProcessor?.contrast = contrast
            filterProcessor?.brightness = brightness
            filterProcessor?.saturation = saturation

            print("🔄 Filter updated: \(filterName), contrast: \(contrast), brightness: \(brightness), saturation: \(saturation)")

            // Update preview layer if filter or preset changed (most expensive operation)
            if filterChanged || presetChanged {
                updatePreviewLayerFilters(currentFilter: currentFilter, currentPreset: currentPreset)
            }
            
            // Cache current values for next comparison
            lastFilter = currentFilter
            lastPreset = currentPreset
            lastContrast = contrast
            lastBrightness = brightness
            lastSaturation = saturation
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            print("⏱️ updateFilters COMPLETED in \(duration * 1000)ms")
        }

        func ensureFilterProcessorSetup() {
            // Only setup if filterProcessor is nil
            if filterProcessor == nil {
                print("🔧 Setting up filter processor")
                setupFilterProcessor()
            }
        }

        // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Do nothing here - filters are applied directly when changed, not on every frame
            // This prevents the hang and matches iPhone Camera behavior
        }
        
        private func updatePreviewLayerFilters(currentFilter: CameraFilter, currentPreset: FilterPreset?) {
            let filterName = currentPreset?.name ?? currentFilter.rawValue
            print("🎨 Filter changed to: \(filterName) - Using visual overlay approach")

            // Remove existing filter overlay
            videoPreviewLayer.sublayers?.removeAll { $0.name == "FilterOverlay" }

            // Handle preset filters
            if let preset = currentPreset {
                applyPresetOverlay(preset)
                return
            }

            if currentFilter == .none {
                print("🎨 No filter - removed overlay")
                return
            }
            
            // Create a visual overlay that simulates the filter effect
            applyLegacyFilterOverlay(currentFilter)
        }

        private func applyPresetOverlay(_ preset: FilterPreset) {
            // Clear existing filters and indicators
            videoPreviewLayer.filters = nil
            videoPreviewLayer.sublayers?.removeAll(where: { $0.name == "FilterOverlay" || $0.name == "FilterIndicator" || $0.name == "FilterNameLabel" })

            // Add a PROMINENT visible indicator that filters are being processed
            if preset.name != "None" {
                let indicatorLayer = CALayer()
                indicatorLayer.name = "FilterIndicator"
                indicatorLayer.frame = CGRect(x: 20, y: 80, width: 16, height: 16) // Bigger indicator
                indicatorLayer.backgroundColor = UIColor.systemGreen.cgColor
                indicatorLayer.cornerRadius = 8
                indicatorLayer.borderWidth = 2
                indicatorLayer.borderColor = UIColor.white.cgColor
                videoPreviewLayer.addSublayer(indicatorLayer)

                // Add filter name text label
                let textLayer = CATextLayer()
                textLayer.name = "FilterNameLabel"
                textLayer.string = preset.name
                textLayer.fontSize = 14
                textLayer.foregroundColor = UIColor.white.cgColor
                textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
                textLayer.cornerRadius = 4
                textLayer.alignmentMode = .center
                textLayer.frame = CGRect(x: 20, y: 100, width: 120, height: 20)
                videoPreviewLayer.addSublayer(textLayer)
            }

            // Apply CIFilters directly to the camera preview layer for real-time effects
            var filters: [CIFilter] = []

            // Apply basic adjustments with proper intensity scaling
            // Temperature and Tint - skip if LUT is present (LUT handles color grading)
            if (preset.modules.temperature != 0 || preset.modules.tint != 0) && preset.modules.lut == nil {
                let tempFilter = CIFilter.temperatureAndTint()
                let neutralTemp: Float = 6500
                let tempRange: Float = 3000
                // Proper temperature scaling - convert from our range to Core Image values
                let tempOffset = Float((preset.modules.temperature / 40.0) * Double(tempRange))
                let targetTemp = neutralTemp + tempOffset

                let neutralTint: Float = 0
                let tintRange: Float = 50
                // Proper tint scaling - convert from our range to Core Image values
                let tintOffset = Float((preset.modules.tint / 30.0) * Double(tintRange))
                tempFilter.neutral = CIVector(x: CGFloat(neutralTemp), y: CGFloat(neutralTint))
                tempFilter.targetNeutral = CIVector(x: CGFloat(targetTemp), y: CGFloat(tintOffset))
                filters.append(tempFilter)
                print("🎨 Temperature filter: temp=\(targetTemp), tint=\(tintOffset)")
            }

            // Exposure - apply unless LUT specifically handles it
            if preset.modules.exposure != 0 {
                let exposureFilter = CIFilter.exposureAdjust()
                // Proper exposure scaling - direct mapping from our range
                exposureFilter.ev = Float(preset.modules.exposure)
                filters.append(exposureFilter)
                print("🎨 Exposure filter: ev=\(exposureFilter.ev)")
            }

            // Contrast - skip if LUT is present (LUT handles contrast)
            if preset.modules.contrast != 0 && preset.modules.lut == nil {
                let contrastFilter = CIFilter.colorControls()
                // Proper contrast scaling - 1.0 = normal, add our contrast value
                let contrastValue = 1.0 + preset.modules.contrast
                contrastFilter.contrast = Float(max(0.0, min(2.0, contrastValue)))
                filters.append(contrastFilter)
                print("🎨 Contrast filter: contrast=\(contrastFilter.contrast)")
            }

            // Saturation - skip if LUT is present (LUT handles saturation/color grading)
            if preset.modules.saturation != 0 && preset.modules.lut == nil {
                let saturationFilter = CIFilter.colorControls()
                // Proper saturation scaling - 1.0 = normal, add our saturation value
                let saturationValue = 1.0 + preset.modules.saturation
                saturationFilter.saturation = Float(max(0.0, min(2.0, saturationValue)))
                filters.append(saturationFilter)
                print("🎨 Saturation filter: saturation=\(saturationFilter.saturation)")
            }

            // Add real-time creative effects optimized for live preview
            // These are simplified versions for smooth 30fps performance

            // Professional camera app approach: GPU-accelerated effects when available

            // Vignette - always apply to preview for visibility
            if preset.modules.vignette > 0 {
                let vignetteFilter = CIFilter.vignette()
                vignetteFilter.intensity = Float(preset.modules.vignette * 1.8) // Professional strength
                vignetteFilter.radius = Float(1.0 + preset.modules.vignette * 2.8) // Optimized radius
                filters.append(vignetteFilter)
                print("🎨 Vignette applied to preview: intensity=\(vignetteFilter.intensity), radius=\(vignetteFilter.radius)")
            }

            // Grain - always apply to preview for visibility
            if preset.modules.grain > 0 {
                let grainFilter = CIFilter.colorControls()
                grainFilter.contrast = Float(1.0 + preset.modules.grain * 0.22) // Professional contrast
                grainFilter.brightness = Float(preset.modules.grain * 0.025)  // Professional brightness
                grainFilter.saturation = Float(1.0 + preset.modules.grain * 0.06) // Professional saturation
                filters.append(grainFilter)
                print("🎨 Grain applied to preview: contrast=\(grainFilter.contrast), brightness=\(grainFilter.brightness)")
            }

            // LUT effects - apply simplified versions to preview for visibility
            if let lutName = preset.modules.lut {
                switch lutName {
                case "grd_bw":
                    let monoFilter = CIFilter.colorMonochrome()
                    monoFilter.intensity = Float(1.0)
                    monoFilter.color = CIColor(red: 0.65, green: 0.65, blue: 0.65)
                    filters.append(monoFilter)
                    print("🎨 Preview GRD B&W: monochrome applied")

                case "polaroid_fade":
                    let fadeFilter = CIFilter.colorControls()
                    fadeFilter.saturation = Float(0.25)
                    fadeFilter.brightness = Float(0.18)
                    fadeFilter.contrast = Float(0.65)
                    filters.append(fadeFilter)
                    print("🎨 Preview Polaroid: faded look applied")

                case "kodachrome_like", "kodak_gold_like":
                    let punchFilter = CIFilter.colorControls()
                    punchFilter.saturation = Float(1.6)
                    punchFilter.contrast = Float(1.3)
                    filters.append(punchFilter)
                    print("🎨 Preview Kodachrome: punchy colors applied")

                case "portra_like", "portra_warm":
                    let portraFilter = CIFilter.colorControls()
                    portraFilter.saturation = Float(1.25)
                    portraFilter.contrast = Float(1.12)
                    filters.append(portraFilter)
                    print("🎨 Preview Portra: warm natural applied")

                case "bleach_bypass":
                    let bleachFilter = CIFilter.colorControls()
                    bleachFilter.saturation = Float(0.35)
                    bleachFilter.brightness = Float(-0.08)
                    bleachFilter.contrast = Float(1.4)
                    filters.append(bleachFilter)
                    print("🎨 Preview Bleach Bypass: high contrast applied")

                default:
                    let neutralFilter = CIFilter.colorControls()
                    neutralFilter.saturation = Float(1.03)
                    neutralFilter.brightness = Float(0.01)
                    neutralFilter.contrast = Float(1.03)
                    filters.append(neutralFilter)
                    print("🎨 Preview LUT: neutral adjustment applied")
                }
            }

            // Halation - apply bloom effect to preview for visibility
            if preset.modules.halation > 0 {
                let bloomFilter = CIFilter.bloom()
                bloomFilter.intensity = Float(preset.modules.halation * 0.8)
                bloomFilter.radius = Float(6.0 + preset.modules.halation * 3.5)
                filters.append(bloomFilter)
                print("🎨 Halation applied to preview: intensity=\(bloomFilter.intensity), radius=\(bloomFilter.radius)")
            }

            // Chromatic aberration - too complex for real-time preview
            // Full CA effect applied during image capture by ModularFilterProcessor

            // Performance note: This approach mirrors how professional camera apps work:
            // - Basic adjustments (temp/tint/exposure/contrast/saturation) = always in preview
            // - Creative effects (vignette/grain/LUTs/halation) = simplified versions for capable devices
            // - Complex effects (CA, distortion, advanced blending) = applied only during capture
            // This maintains 30fps performance while showing most filter characteristics

            // Apply filters to preview layer
            if !filters.isEmpty {
                videoPreviewLayer.filters = filters
                print("🎨 Applied \(filters.count) real-time filters to camera preview for: \(preset.name)")
                for (index, filter) in filters.enumerated() {
                    print("   Filter \(index + 1): \(filter.name ?? "Unknown")")
                }
            } else {
                print("🎨 No filters to apply for preset: \(preset.name)")
            }
        }

        private func generateFilteredPreviewImage(for preset: FilterPreset, completion: @escaping (UIImage?) -> Void) {
            print("🎨 generateFilteredPreviewImage: Starting for preset '\(preset.name)'")

            // Create a test image instead of trying to capture from live preview
            let testImage = createTestImage()
            print("🎨 generateFilteredPreviewImage: Created test image \(testImage.size)")

            // Apply the preset filter to the test image
            guard let filterProcessor = filterProcessor else {
                print("❌ generateFilteredPreviewImage: No filter processor available")
                completion(nil)
                return
            }

            print("🎨 generateFilteredPreviewImage: Applying preset filter...")
            let filteredImage = filterProcessor.applyPreset(to: testImage, preset: preset)
            print("🎨 generateFilteredPreviewImage: Filter applied, result size: \(filteredImage.size)")

            completion(filteredImage)
        }

        private func createTestImage() -> UIImage {
            // Create a more colorful test image that shows filter effects clearly
            let size = CGSize(width: 300, height: 300)
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)

            let context = UIGraphicsGetCurrentContext()!

            // Create a vibrant background with multiple colors
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor, // Red
                UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0).cgColor, // Green
                UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0).cgColor, // Blue
                UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0).cgColor, // Yellow
            ]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 0.33, 0.66, 1.0])!

            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

            // Add high contrast elements for better filter visibility
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: 50, y: 50, width: 80, height: 80))

            context.setFillColor(UIColor.black.cgColor)
            context.fillEllipse(in: CGRect(x: 170, y: 170, width: 80, height: 80))

            context.setFillColor(UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 100, y: 100, width: 100, height: 60))

            // Add some skin tone colors for portrait filter testing
            context.setFillColor(UIColor(red: 0.96, green: 0.80, blue: 0.69, alpha: 1.0).cgColor) // Light skin
            context.fillEllipse(in: CGRect(x: 200, y: 50, width: 60, height: 60))

            context.setFillColor(UIColor(red: 0.82, green: 0.71, blue: 0.55, alpha: 1.0).cgColor) // Medium skin
            context.fillEllipse(in: CGRect(x: 40, y: 200, width: 60, height: 60))

            let testImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()

            return testImage
        }

        private func applySimplePresetOverlay(_ preset: FilterPreset) {
            // Fallback: simple colored overlay (original implementation)
            let overlay = CALayer()
            overlay.name = "FilterOverlay"
            overlay.frame = videoPreviewLayer.bounds

            // Apply preset-specific visual effects based on main characteristics
            switch preset.id {
            // Dazz Cam presets
            case "dazz_portra_warm":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 0.3).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.4
            case "dazz_kodak_gold":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 0.4).cgColor
                overlay.compositingFilter = "softLightBlendMode"
                overlay.opacity = 0.5
            case "dazz_kodachrome_punch":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 0.3).cgColor
                overlay.compositingFilter = "colorBlendMode"
                overlay.opacity = 0.6
            case "dazz_bleach_bypass":
                overlay.backgroundColor = UIColor(white: 0.9, alpha: 0.8).cgColor
                overlay.compositingFilter = "multiplyBlendMode"
                overlay.opacity = 0.7
            case "dazz_faded_retro":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.85, blue: 0.7, alpha: 0.5).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.4
            case "dazz_grainy_street":
                overlay.backgroundColor = UIColor(white: 0.1, alpha: 0.6).cgColor
                overlay.compositingFilter = "multiplyBlendMode"
                overlay.opacity = 0.5

            // KAPI presets
            case "kapi_nokia_classic":
                overlay.backgroundColor = UIColor.blue.withAlphaComponent(0.4).cgColor
                overlay.compositingFilter = "colorBlendMode"
                overlay.opacity = 0.3
            case "kapi_dv_2003":
                overlay.backgroundColor = UIColor(white: 0.95, alpha: 0.2).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.3
            case "kapi_ccd_warm":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 0.3).cgColor
                overlay.compositingFilter = "softLightBlendMode"
                overlay.opacity = 0.4
            case "kapi_lomo_tilt":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.7, blue: 0.9, alpha: 0.4).cgColor
                overlay.compositingFilter = "hueBlendMode"
                overlay.opacity = 0.5
            case "kapi_vhs_warble":
                overlay.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 0.3).cgColor
                overlay.compositingFilter = "exclusionBlendMode"
                overlay.opacity = 0.4

            // LoFi Cam presets
            case "lofi_t10":
                overlay.backgroundColor = UIColor(white: 0.98, alpha: 0.2).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.3
            case "lofi_f700":
                overlay.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 0.3).cgColor
                overlay.compositingFilter = "softLightBlendMode"
                overlay.opacity = 0.4
            case "lofi_grd_bw":
                overlay.backgroundColor = UIColor(white: 0.0, alpha: 0.8).cgColor
                overlay.compositingFilter = "luminosityBlendMode"
                overlay.opacity = 0.6
            case "lofi_120_film":
                overlay.backgroundColor = UIColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 0.3).cgColor
                overlay.compositingFilter = "multiplyBlendMode"
                overlay.opacity = 0.4
            case "lofi_l80_soft":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 0.4).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.5
            case "lofi_fuji_velvia":
                overlay.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.3).cgColor
                overlay.compositingFilter = "colorBlendMode"
                overlay.opacity = 0.5
            case "lofi_dispo_film":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 0.4).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.5
            case "lofi_classic_lomo":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.9, alpha: 0.4).cgColor
                overlay.compositingFilter = "hueBlendMode"
                overlay.opacity = 0.6
            case "lofi_neon_night":
                overlay.backgroundColor = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.5).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.5
            case "lofi_pastel_film":
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.95, blue: 0.95, alpha: 0.3).cgColor
                overlay.compositingFilter = "saturationBlendMode"
                overlay.opacity = 0.4

            default:
                // Default preset overlay
                overlay.backgroundColor = UIColor.purple.withAlphaComponent(0.2).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.3
            }

            videoPreviewLayer.addSublayer(overlay)
            print("🎨 Applied simple preset overlay for: \(preset.name)")
        }

        private func applyLegacyFilterOverlay(_ currentFilter: CameraFilter) {
            // Create a visual overlay that simulates the filter effect
            let overlay = CALayer()
            overlay.name = "FilterOverlay"
            overlay.frame = videoPreviewLayer.bounds
            
            // Apply filter-specific visual effects - BOLD and VISIBLE
            switch currentFilter {
            case .none:
                break
                
            case .bw, .mono:
                // Strong Black & White effect
                overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
                overlay.compositingFilter = "saturationBlendMode"
                overlay.opacity = 1.0
                print("🎨 Applied STRONG B&W visual overlay")
                
            case .sepia:
                // Strong Sepia effect
                overlay.backgroundColor = UIColor(red: 0.7, green: 0.5, blue: 0.2, alpha: 0.6).cgColor
                overlay.compositingFilter = "colorBurnBlendMode"
                overlay.opacity = 0.8
                print("🎨 Applied STRONG Sepia visual overlay")
                
            case .vintage:
                // Strong Vintage effect with warm tones
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 0.5).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Vintage visual overlay")
                
            case .vivid:
                // Strong Vivid effect (saturated colors)
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.2, blue: 0.8, alpha: 0.3).cgColor
                overlay.compositingFilter = "colorDodgeBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Vivid visual overlay")
                
            case .dramatic:
                // Strong Dramatic effect (high contrast, dark)
                overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
                overlay.compositingFilter = "multiplyBlendMode"
                overlay.opacity = 0.8
                print("🎨 Applied STRONG Dramatic visual overlay")
                
            case .portrait:
                // Portrait effect (warm skin tones)
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.7, blue: 0.6, alpha: 0.4).cgColor
                overlay.compositingFilter = "softLightBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Portrait visual overlay")
                
            case .landscape:
                // Landscape effect (cool tones, enhanced greens/blues)
                overlay.backgroundColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.4).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Landscape visual overlay")
                
            case .cyanotype:
                // Cyanotype effect (blue monochrome)
                overlay.backgroundColor = UIColor(red: 0.0, green: 0.3, blue: 0.7, alpha: 0.7).cgColor
                overlay.compositingFilter = "colorBlendMode"
                overlay.opacity = 0.8
                print("🎨 Applied STRONG Cyanotype visual overlay")
                
            case .hdr:
                // HDR effect (enhanced contrast and colors)
                overlay.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.3).cgColor
                overlay.compositingFilter = "hardLightBlendMode"
                overlay.opacity = 0.5
                print("🎨 Applied STRONG HDR visual overlay")
                
            case .softFocus:
                // Soft Focus effect (dreamy, bright)
                overlay.backgroundColor = UIColor.white.withAlphaComponent(0.4).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Soft Focus visual overlay")
                
            // Enhancement Filters
            case .sharpen:
                // Sharpen effect (high contrast edges)
                overlay.backgroundColor = UIColor.white.withAlphaComponent(0.2).cgColor
                overlay.compositingFilter = "hardLightBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Sharpen visual overlay")
                
            // Color Filters
            case .warmth:
                // Warm effect (orange/red tint)
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.4).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Warmth visual overlay")
                
            case .cool:
                // Cool effect (blue tint)
                overlay.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.4).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Cool visual overlay")
                
            // Film Filters
            case .kodak:
                // Kodak Portra (warm, saturated)
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.7, alpha: 0.4).cgColor
                overlay.compositingFilter = "softLightBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Kodak Portra visual overlay")
                
            case .fuji:
                // Fuji Provia (vivid, cool)
                overlay.backgroundColor = UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.4).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Fuji Provia visual overlay")
                
            case .cinestill:
                // CineStill (cinematic, warm highlights)
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 0.5).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.5
                print("🎨 Applied STRONG CineStill visual overlay")
                
            // Artistic Filters
            case .oilPaint:
                // Oil Paint effect (textured, saturated)
                overlay.backgroundColor = UIColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 0.5).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Oil Paint visual overlay")
                
            case .sketch:
                // Sketch effect (high contrast, desaturated)
                overlay.backgroundColor = UIColor.gray.withAlphaComponent(0.6).cgColor
                overlay.compositingFilter = "hardLightBlendMode"
                overlay.opacity = 0.8
                print("🎨 Applied STRONG Sketch visual overlay")
                
            case .comic:
                // Comic effect (bold colors, high contrast)
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 0.3).cgColor
                overlay.compositingFilter = "hardLightBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Comic visual overlay")
                
            // Effects Filters
            case .crystal:
                // Crystal effect (bright, prismatic)
                overlay.backgroundColor = UIColor(red: 0.8, green: 1.0, blue: 1.0, alpha: 0.4).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Crystal visual overlay")
                
            case .emboss:
                // Emboss effect (raised, gray)
                overlay.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor
                overlay.compositingFilter = "hardLightBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Emboss visual overlay")
                
            case .gaussianBlur:
                // Blur effect (soft, dreamy)
                overlay.backgroundColor = UIColor.white.withAlphaComponent(0.3).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.5
                print("🎨 Applied STRONG Blur visual overlay")
                
            case .vignette:
                // Vignette effect (dark edges)
                overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4).cgColor
                overlay.compositingFilter = "multiplyBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Vignette visual overlay")
                
            case .grain:
                // Film Grain effect (textured, vintage)
                overlay.backgroundColor = UIColor.gray.withAlphaComponent(0.3).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Film Grain visual overlay")
                
            // Special Filters
            case .crossProcess:
                // Cross Process (shifted colors)
                overlay.backgroundColor = UIColor(red: 0.9, green: 1.0, blue: 0.7, alpha: 0.4).cgColor
                overlay.compositingFilter = "colorBurnBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Cross Process visual overlay")
                
            case .glow:
                // Glow effect (bright, soft)
                overlay.backgroundColor = UIColor.white.withAlphaComponent(0.4).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Glow visual overlay")
                
            case .neon:
                // Neon effect (bright, electric)
                overlay.backgroundColor = UIColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 0.5).cgColor
                overlay.compositingFilter = "screenBlendMode"
                overlay.opacity = 0.8
                print("🎨 Applied STRONG Neon visual overlay")
                
            case .posterize:
                // Posterize effect (reduced colors)
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.4).cgColor
                overlay.compositingFilter = "hardLightBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Posterize visual overlay")
                
            case .solarize:
                // Solarize effect (inverted highlights)
                overlay.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 0.5).cgColor
                overlay.compositingFilter = "differenceBlendMode"
                overlay.opacity = 0.7
                print("🎨 Applied STRONG Solarize visual overlay")
                
            // Distortion Filters (visual approximations)
            case .kaleidoscope:
                // Kaleidoscope effect (prismatic colors)
                overlay.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 0.3).cgColor
                overlay.compositingFilter = "colorDodgeBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG Kaleidoscope visual overlay")
                
            case .pinch, .twirl, .bump, .glass:
                // Distortion effects (subtle visual hint)
                overlay.backgroundColor = UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.2).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.4
                print("🎨 Applied STRONG \(currentFilter.rawValue) visual overlay")
                
            // Halftone Filters
            case .dotScreen, .lineScreen:
                // Halftone effects (pattern-like)
                overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.6
                print("🎨 Applied STRONG \(currentFilter.rawValue) visual overlay")
                
            default:
                // Strong generic filter overlay
                overlay.backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 0.3).cgColor
                overlay.compositingFilter = "overlayBlendMode"
                overlay.opacity = 0.5
                print("🎨 Applied STRONG generic visual overlay for \(currentFilter.rawValue)")
            }
            
            // Add the overlay to preview layer
            videoPreviewLayer.addSublayer(overlay)
            print("🎨 Filter overlay added successfully")
        }
        
        // Update overlay frame when preview layer bounds change
        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
            
            // Update filter overlay frame if it exists
            if let filterOverlay = videoPreviewLayer.sublayers?.first(where: { $0.name == "FilterOverlay" }) {
                filterOverlay.frame = videoPreviewLayer.bounds
            }
        }
        
        private func addFilterOverlay(for filter: CameraFilter) {
            print("🎯 Adding overlay for \(filter.rawValue) - starting")
            
            // Remove existing overlay with simple approach
            videoPreviewLayer.sublayers?.removeAll { $0.name == "FilterOverlay" }
            
            // Add a very minimal overlay to indicate filter is active
            let overlay = CALayer()
            overlay.name = "FilterOverlay"
            overlay.frame = videoPreviewLayer.bounds
            
            // Use a very subtle universal tint instead of different colors
            overlay.backgroundColor = UIColor.white.withAlphaComponent(0.01).cgColor
            
            // Add without any transactions or animations
            videoPreviewLayer.addSublayer(overlay)
            
            print("🎯 Adding overlay for \(filter.rawValue) - completed")
        }
        
        private func createOptimizedFilter(for filterType: CameraFilter) -> CIFilter? {
            // Use the most efficient Core Image filters for real-time performance
            switch filterType {
            case .none:
                return nil
                
            // Basic Filters - optimized for real-time preview
            case .vintage:
                return CIFilter.photoEffectInstant()
            case .mono:
                return CIFilter.photoEffectNoir()
            case .vivid:
                return CIFilter.photoEffectChrome()
            case .dramatic:
                return CIFilter.photoEffectFade()
            case .portrait:
                return CIFilter.photoEffectTransfer()
            case .landscape:
                return CIFilter.photoEffectProcess()
            case .bw:
                return CIFilter.photoEffectMono()
            case .sepia:
                return CIFilter.sepiaTone()
            case .cyanotype:
                // Create a blue-tinted monochrome effect
                let filter = CIFilter.photoEffectMono()
                return filter
                
            // Professional Filters - simplified for preview
            case .hdr:
                return CIFilter.photoEffectChrome() // Vivid alternative
            case .softFocus:
                return CIFilter.photoEffectTransfer() // Soft alternative
            default:
                // For any other filters, use a neutral effect
                return CIFilter.photoEffectProcess()
            }
        }

        private func applyBasicAdjustments(to image: CIImage, filterProcessor: FilterProcessor) -> CIImage {
            var adjustedImage = image

            // Apply brightness
            if filterProcessor.brightness != 0.0 {
                let brightnessFilter = CIFilter.colorControls()
                brightnessFilter.inputImage = adjustedImage
                brightnessFilter.brightness = Float(filterProcessor.brightness * 0.5) // Scale down for better control
                if let output = brightnessFilter.outputImage {
                    adjustedImage = output
                }
            }

            // Apply contrast
            if filterProcessor.contrast != 1.0 {
                let contrastFilter = CIFilter.colorControls()
                contrastFilter.inputImage = adjustedImage
                contrastFilter.contrast = Float(filterProcessor.contrast)
                if let output = contrastFilter.outputImage {
                    adjustedImage = output
                }
            }

            // Apply saturation
            if filterProcessor.saturation != 1.0 {
                let saturationFilter = CIFilter.colorControls()
                saturationFilter.inputImage = adjustedImage
                saturationFilter.saturation = Float(filterProcessor.saturation)
                if let output = saturationFilter.outputImage {
                    adjustedImage = output
                }
            }

            return adjustedImage
        }

        private func applyFilter(to image: CIImage, filter: CameraFilter) -> CIImage {
            // Apply the selected filter - simplified version for real-time processing
            switch filter {
            case .none:
                return image
            case .vintage:
                return applyVintageFilter(to: image)
            case .bw:
                return applyBlackAndWhiteFilter(to: image)
            case .sepia:
                return applySepiaFilter(to: image)
            case .vivid:
                return applyVividFilter(to: image)
            default:
                // For complex filters, just return basic adjustments
                return image
            }
        }

        private func applyVintageFilter(to image: CIImage) -> CIImage {
            let filter = CIFilter.sepiaTone()
            filter.inputImage = image
            filter.intensity = Float(0.7)
            return filter.outputImage ?? image
        }

        private func applyBlackAndWhiteFilter(to image: CIImage) -> CIImage {
            let filter = CIFilter.colorMonochrome()
            filter.inputImage = image
            filter.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
            filter.intensity = Float(1.0)
            return filter.outputImage ?? image
        }

        private func applySepiaFilter(to image: CIImage) -> CIImage {
            let filter = CIFilter.sepiaTone()
            filter.inputImage = image
            filter.intensity = Float(1.0)
            return filter.outputImage ?? image
        }

        private func applyVividFilter(to image: CIImage) -> CIImage {
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.saturation = Float(1.5)
            filter.brightness = Float(0.1)
            filter.contrast = Float(1.2)
            return filter.outputImage ?? image
        }

        deinit {
            // Clean up video data output
            if let session = videoPreviewLayer.session,
               let videoOutput = videoDataOutput {
                session.removeOutput(videoOutput)
            }
        }
    }
}

// Enhanced FilterProcessor for real-time processing
class FilterProcessor {
    var currentFilter: CameraFilter = .none
    var currentPreset: FilterPreset?
    var contrast: CGFloat = 1.0
    var brightness: CGFloat = 0.0
    var saturation: CGFloat = 1.0

    private let ciContext: CIContext
    private let device: MTLDevice?
    private let modularProcessor = ModularFilterProcessor()

    init() {
        device = MTLCreateSystemDefaultDevice()

        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .outputColorSpace: CGColorSpaceCreateDeviceRGB()
        ]

        if let metalDevice = device {
            ciContext = CIContext(mtlDevice: metalDevice, options: options)
        } else {
            ciContext = CIContext(options: [.useSoftwareRenderer: true])
        }
    }


    func applyFilter(to image: UIImage, filter: CameraFilter) -> UIImage {
        guard filter != .none else {
            // Apply basic adjustments even with no filter
            return applyBasicAdjustments(to: image)
        }

        guard let ciImage = CIImage(image: image) else { return image }

        let filteredImage: CIImage?

        switch filter {
        // Basic Filters
        case .vintage:
            guard let filter = CIFilter(name: "CIPhotoEffectInstant") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage
        case .mono:
            guard let filter = CIFilter(name: "CIPhotoEffectMono") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage
        case .vivid:
            guard let filter = CIFilter(name: "CIPhotoEffectChrome") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage
        case .dramatic:
            guard let filter = CIFilter(name: "CIPhotoEffectFade") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage
        case .portrait:
            guard let filter = CIFilter(name: "CIPhotoEffectTransfer") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage
        case .landscape:
            guard let filter = CIFilter(name: "CISepiaTone") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(0.8, forKey: kCIInputIntensityKey)
            filteredImage = filter.outputImage
        case .bw:
            guard let filter = CIFilter(name: "CIPhotoEffectNoir") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage
        case .sepia:
            guard let filter = CIFilter(name: "CISepiaTone") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.0, forKey: kCIInputIntensityKey)
            filteredImage = filter.outputImage
        case .cyanotype:
            guard let filter = CIFilter(name: "CIColorMonochrome") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIColor(red: 0.0, green: 0.5, blue: 1.0), forKey: kCIInputColorKey)
            filter.setValue(1.0, forKey: kCIInputIntensityKey)
            filteredImage = filter.outputImage

        // Professional Enhancement Filters
        case .hdr:
            // Use color controls for HDR-like effect
            guard let filter = CIFilter(name: "CIColorControls") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.2, forKey: kCIInputContrastKey)
            filter.setValue(0.1, forKey: kCIInputBrightnessKey)
            filteredImage = filter.outputImage
        case .softFocus:
            guard let filter = CIFilter(name: "CIGaussianBlur") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(2.0, forKey: kCIInputRadiusKey)
            filteredImage = filter.outputImage
        case .sharpen:
            guard let filter = CIFilter(name: "CISharpenLuminance") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(2.0, forKey: kCIInputSharpnessKey)
            filteredImage = filter.outputImage

        // Color Filters
        case .warmth:
            guard let filter = CIFilter(name: "CITemperatureAndTint") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter.setValue(CIVector(x: 5500, y: 0), forKey: "inputTargetNeutral")
            filteredImage = filter.outputImage
        case .cool:
            guard let filter = CIFilter(name: "CITemperatureAndTint") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter.setValue(CIVector(x: 8000, y: 0), forKey: "inputTargetNeutral")
            filteredImage = filter.outputImage

        // Film Emulation Filters
        case .kodak:
            guard let filter = CIFilter(name: "CIColorControls") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.1, forKey: kCIInputSaturationKey)
            filter.setValue(0.05, forKey: kCIInputBrightnessKey)
            filteredImage = filter.outputImage
        case .fuji:
            guard let filter = CIFilter(name: "CIColorControls") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.2, forKey: kCIInputSaturationKey)
            filter.setValue(0.02, forKey: kCIInputBrightnessKey)
            filteredImage = filter.outputImage
        case .cinestill:
            guard let filter = CIFilter(name: "CIColorControls") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.3, forKey: kCIInputSaturationKey)
            filter.setValue(-0.1, forKey: kCIInputBrightnessKey)
            filteredImage = filter.outputImage

        // Artistic Filters
        case .oilPaint:
            guard let filter = CIFilter(name: "CIPixellate") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(8.0, forKey: kCIInputScaleKey)
            filteredImage = filter.outputImage
        case .sketch:
            guard let filter = CIFilter(name: "CILineOverlay") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage
        case .comic:
            guard let filter = CIFilter(name: "CIComicEffect") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage

        // Effect Filters
        case .crystal:
            guard let filter = CIFilter(name: "CICrystallize") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(20.0, forKey: kCIInputRadiusKey)
            filteredImage = filter.outputImage
        case .emboss:
            guard let filter = CIFilter(name: "CIConvolution3X3") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            let weights: [CGFloat] = [2.0, 0.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, -1.0]
            filter.setValue(CIVector(values: weights, count: 9), forKey: "inputWeights")
            filteredImage = filter.outputImage
        case .gaussianBlur:
            guard let filter = CIFilter(name: "CIGaussianBlur") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(5.0, forKey: kCIInputRadiusKey)
            filteredImage = filter.outputImage
        case .vignette:
            guard let filter = CIFilter(name: "CIVignette") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(0.7, forKey: kCIInputIntensityKey)
            filter.setValue(1.5, forKey: kCIInputRadiusKey)
            filteredImage = filter.outputImage
        case .grain:
            // Use random generator for film grain effect instead of noise reduction
            guard let filter = CIFilter(name: "CIRandomGenerator") else { return applyBasicAdjustments(to: image) }
            if let noiseImage = filter.outputImage {
                let blendFilter = CIFilter(name: "CISourceOverCompositing")
                blendFilter?.setValue(noiseImage.cropped(to: ciImage.extent), forKey: kCIInputImageKey)
                blendFilter?.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
                filteredImage = blendFilter?.outputImage
            } else {
                filteredImage = ciImage
            }

        // Special Filters
        case .crossProcess:
            // Use color controls for cross-processing effect
            guard let filter = CIFilter(name: "CIColorControls") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.2, forKey: kCIInputSaturationKey)
            filter.setValue(0.1, forKey: kCIInputBrightnessKey)
            filteredImage = filter.outputImage
        case .glow:
            guard let filter = CIFilter(name: "CIBloom") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.0, forKey: kCIInputIntensityKey)
            filter.setValue(10.0, forKey: kCIInputRadiusKey)
            filteredImage = filter.outputImage
        case .neon:
            guard let filter = CIFilter(name: "CIEdges") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(5.0, forKey: kCIInputIntensityKey)
            filteredImage = filter.outputImage
        case .posterize:
            guard let filter = CIFilter(name: "CIColorPosterize") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(6.0, forKey: "inputLevels")
            filteredImage = filter.outputImage
        case .solarize:
            guard let filter = CIFilter(name: "CIColorInvert") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage

        // Distortion Filters
        case .kaleidoscope:
            guard let filter = CIFilter(name: "CIKaleidoscope") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(6.0, forKey: "inputCount")
            filter.setValue(0.5, forKey: kCIInputAngleKey)
            filteredImage = filter.outputImage
        case .pinch:
            guard let filter = CIFilter(name: "CIPinchDistortion") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(0.5, forKey: kCIInputRadiusKey)
            filter.setValue(-0.5, forKey: kCIInputScaleKey)
            filteredImage = filter.outputImage
        case .twirl:
            guard let filter = CIFilter(name: "CITwirlDistortion") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(300.0, forKey: kCIInputRadiusKey)
            filter.setValue(3.14, forKey: kCIInputAngleKey)
            filteredImage = filter.outputImage
        case .bump:
            guard let filter = CIFilter(name: "CIBumpDistortion") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(300.0, forKey: kCIInputRadiusKey)
            filter.setValue(0.5, forKey: kCIInputScaleKey)
            filteredImage = filter.outputImage
        case .glass:
            // Use bump distortion as alternative to glass distortion
            guard let filter = CIFilter(name: "CIBumpDistortion") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(400.0, forKey: kCIInputRadiusKey)
            filter.setValue(1.0, forKey: kCIInputScaleKey)
            filteredImage = filter.outputImage

        // Halftone Filters
        case .dotScreen:
            guard let filter = CIFilter(name: "CIDotScreen") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(25.0, forKey: kCIInputWidthKey)
            filter.setValue(0.0, forKey: kCIInputAngleKey)
            filteredImage = filter.outputImage
        case .lineScreen:
            guard let filter = CIFilter(name: "CILineScreen") else { return applyBasicAdjustments(to: image) }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(25.0, forKey: kCIInputWidthKey)
            filter.setValue(0.0, forKey: kCIInputAngleKey)
            filteredImage = filter.outputImage

        case .none:
            return applyBasicAdjustments(to: image)
        }

        guard let outputImage = filteredImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return applyBasicAdjustments(to: image)
        }

        // Preserve the original image orientation
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - FilterPreset Support
    func applyPreset(to image: UIImage, preset: FilterPreset) -> UIImage {
        currentPreset = preset

        // Apply the preset using the modular processor
        var processedImage = modularProcessor.applyPreset(preset, to: image)

        // Apply overlays
        processedImage = modularProcessor.applyFrame(preset.modules.frame, to: processedImage)
        processedImage = modularProcessor.applyLightLeak(preset.modules.lightLeak, to: processedImage)
        processedImage = modularProcessor.applyTimestamp(preset.modules.timestamp, to: processedImage)

        // Apply basic adjustments (contrast, brightness, saturation) on top of preset
        processedImage = applyBasicAdjustments(to: processedImage)

        return processedImage
    }

    func setCurrentPreset(_ preset: FilterPreset?) {
        currentPreset = preset
        currentFilter = .none  // Clear legacy filter when using preset
    }

    private func applyBasicAdjustments(to image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        // Apply contrast, brightness, and saturation adjustments
        var adjustedImage = ciImage

        // Contrast
        if contrast != 1.0 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(adjustedImage, forKey: kCIInputImageKey)
                filter.setValue(contrast, forKey: kCIInputContrastKey)
                if let output = filter.outputImage {
                    adjustedImage = output
                }
            }
        }

        // Brightness
        if brightness != 0.0 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(adjustedImage, forKey: kCIInputImageKey)
                filter.setValue(brightness, forKey: kCIInputBrightnessKey)
                if let output = filter.outputImage {
                    adjustedImage = output
                }
            }
        }

        // Saturation
        if saturation != 1.0 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(adjustedImage, forKey: kCIInputImageKey)
                filter.setValue(saturation, forKey: kCIInputSaturationKey)
                if let output = filter.outputImage {
                    adjustedImage = output
                }
            }
        }

        guard let cgImage = ciContext.createCGImage(adjustedImage, from: adjustedImage.extent) else {
            return image
        }

        // Preserve the original image orientation and dimensions
        print("📏 FilterProcessor basic adjustments - Original: \(image.size), Output: \(cgImage.width)x\(cgImage.height)")
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // No duplicate function needed here - it's already in PreviewView class
}

// MARK: - Metal Preview Renderer (Professional Camera App Approach)

/// GPU-accelerated preview renderer using Metal compute shaders
/// This mirrors the implementation used by Snappit, LoFiCam, DazzCam, and KAPI
class MetalPreviewRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var library: MTLLibrary?

    // Compute pipeline states for different effects
    private var grainPipeline: MTLComputePipelineState?
    private var vignettePipeline: MTLComputePipelineState?
    private var halationPipeline: MTLComputePipelineState?

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        setupShaders()
    }

    private func setupShaders() {
        // Load Metal shader source from file (like professional apps do)
        guard let shaderPath = Bundle.main.path(forResource: "Shaders", ofType: "metal"),
              let shaderSource = try? String(contentsOfFile: shaderPath) else {
            print("❌ Failed to load Metal shader source from bundle")
            // Try to compile shaders directly from source string as fallback
            compileShadersFromSource()
            return
        }

        do {
            // Compile shaders at runtime (like professional apps do)
            let options = MTLCompileOptions()
            options.languageVersion = .version2_0

            library = try device.makeLibrary(source: shaderSource, options: options)
            print("✅ Metal shaders compiled from file successfully")

            createComputePipelines()
        } catch {
            print("❌ Failed to compile Metal shaders from file: \(error)")
            // Fallback to compiling from embedded source
            compileShadersFromSource()
        }
    }

    private func compileShadersFromSource() {
        // Embedded shader source (fallback when file loading fails)
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void grainKernel(texture2d<float, access::read> inputTexture [[texture(0)]],
                               texture2d<float, access::write> outputTexture [[texture(1)]],
                               constant float& intensity [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]])
        {
            if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
                return;
            }

            float4 color = inputTexture.read(gid);

            // Generate procedural noise based on position
            float2 uv = float2(gid) / float2(inputTexture.get_width(), inputTexture.get_height());
            float noise = fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);

            // Convert to monochrome noise and apply
            float grain = (noise - 0.5) * 2.0 * intensity;
            color.rgb = color.rgb + grain * (1.0 - color.rgb) * color.rgb;

            outputTexture.write(color, gid);
        }

        kernel void vignetteKernel(texture2d<float, access::read> inputTexture [[texture(0)]],
                                  texture2d<float, access::write> outputTexture [[texture(1)]],
                                  constant float& intensity [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]])
        {
            if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
                return;
            }

            float4 color = inputTexture.read(gid);

            // Calculate vignette
            float2 uv = float2(gid) / float2(inputTexture.get_width(), inputTexture.get_height());
            float2 center = float2(0.5, 0.5);
            float dist = distance(uv, center);

            // Smooth vignette falloff
            float vignette = 1.0 - smoothstep(0.3, 0.8, dist);
            vignette = mix(1.0, vignette, intensity);

            color.rgb *= vignette;

            outputTexture.write(color, gid);
        }

        kernel void halationKernel(texture2d<float, access::read> inputTexture [[texture(0)]],
                                  texture2d<float, access::write> outputTexture [[texture(1)]],
                                  constant float& intensity [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]])
        {
            if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
                return;
            }

            float4 color = inputTexture.read(gid);

            // Simple bloom effect - brighten highlights
            float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));
            float bloom = smoothstep(0.7, 1.0, luminance) * intensity;

            color.rgb += bloom * color.rgb * 0.5;

            outputTexture.write(color, gid);
        }
        """

        do {
            let options = MTLCompileOptions()
            options.languageVersion = .version2_0

            library = try device.makeLibrary(source: shaderSource, options: options)
            print("✅ Metal shaders compiled from embedded source")

            createComputePipelines()
        } catch {
            print("❌ Failed to compile Metal shaders: \(error)")
        }
    }

    private func createComputePipelines() {
        do {
            // Create compute pipelines for each effect
            if let grainFunction = library?.makeFunction(name: "grainKernel") {
                grainPipeline = try device.makeComputePipelineState(function: grainFunction)
                print("✅ Grain compute pipeline created")
            }

            if let vignetteFunction = library?.makeFunction(name: "vignetteKernel") {
                vignettePipeline = try device.makeComputePipelineState(function: vignetteFunction)
                print("✅ Vignette compute pipeline created")
            }

            if let halationFunction = library?.makeFunction(name: "halationKernel") {
                halationPipeline = try device.makeComputePipelineState(function: halationFunction)
                print("✅ Halation compute pipeline created")
            }
        } catch {
            print("❌ Failed to create compute pipelines: \(error)")
        }
    }

    /// Apply GPU-accelerated effects to camera preview (like professional apps)
    func applyEffects(to pixelBuffer: CVPixelBuffer,
                     grain: Float = 0,
                     vignette: Float = 0,
                     halation: Float = 0) -> CVPixelBuffer? {

        guard grain > 0 || vignette > 0 || halation > 0 else {
            return pixelBuffer // No effects to apply
        }

        // Create Metal texture from pixel buffer
        guard let inputTexture = createTexture(from: pixelBuffer) else {
            return pixelBuffer
        }

        // Create output texture with same dimensions
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let outputTexture = createOutputTexture(width: width, height: height) else {
            return pixelBuffer
        }

        // Execute GPU compute passes (like professional camera apps)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return pixelBuffer
        }

        // Apply effects in optimized order (most efficient for GPU)
        var currentInput = inputTexture

        // 1. Grain effect (compute shader)
        if grain > 0, let grainPipeline = grainPipeline {
            currentInput = applyComputeEffect(commandBuffer: commandBuffer,
                                            pipeline: grainPipeline,
                                            input: currentInput,
                                            output: outputTexture,
                                            intensity: grain)
        }

        // 2. Vignette effect (compute shader)
        if vignette > 0, let vignettePipeline = vignettePipeline {
            currentInput = applyComputeEffect(commandBuffer: commandBuffer,
                                            pipeline: vignettePipeline,
                                            input: currentInput,
                                            output: outputTexture,
                                            intensity: vignette)
        }

        // 3. Halation effect (compute shader)
        if halation > 0, let halationPipeline = halationPipeline {
            currentInput = applyComputeEffect(commandBuffer: commandBuffer,
                                            pipeline: halationPipeline,
                                            input: currentInput,
                                            output: outputTexture,
                                            intensity: halation)
        }

        // Execute all compute passes
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Convert back to CVPixelBuffer
        return createPixelBuffer(from: currentInput, original: pixelBuffer)
    }

    private func applyComputeEffect(commandBuffer: MTLCommandBuffer,
                                  pipeline: MTLComputePipelineState,
                                  input: MTLTexture,
                                  output: MTLTexture,
                                  intensity: Float) -> MTLTexture {

        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return input
        }

        // Set compute pipeline
        computeEncoder.setComputePipelineState(pipeline)

        // Bind textures
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)

        // Bind intensity parameter
        var intensity = intensity
        computeEncoder.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)

        // Calculate thread groups (like professional GPU apps)
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (input.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (input.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        // Dispatch compute threads
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()

        return output
    }

    private func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        // Copy pixel buffer data to Metal texture
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            texture.replace(region: MTLRegionMake2D(0, 0, width, height),
                          mipmapLevel: 0,
                          withBytes: baseAddress,
                          bytesPerRow: bytesPerRow)
        }

        return texture
    }

    private func createOutputTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }

    private func createPixelBuffer(from texture: MTLTexture, original: CVPixelBuffer) -> CVPixelBuffer? {
        let width = texture.width
        let height = texture.height

        // Create new pixel buffer with same properties as original
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                       CVPixelBufferGetPixelFormatType(original),
                                       nil, &outputBuffer)

        guard status == kCVReturnSuccess, let outputBuffer = outputBuffer else {
            return original
        }

        // Copy texture data back to pixel buffer
        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }

        if let baseAddress = CVPixelBufferGetBaseAddress(outputBuffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
            texture.getBytes(baseAddress,
                           bytesPerRow: bytesPerRow,
                           from: MTLRegionMake2D(0, 0, width, height),
                           mipmapLevel: 0)
        }

        return outputBuffer
    }
}

