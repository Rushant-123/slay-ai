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
        print("🔧 SwiftUI updateUIView called for filter: \(currentFilter.rawValue)")
        uiView.updateFilters(currentFilter: currentFilter, contrast: contrast, brightness: brightness, saturation: saturation)
        print("🔧 SwiftUI updateUIView completed for filter: \(currentFilter.rawValue)")
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
        private var lastContrast: CGFloat?
        private var lastBrightness: CGFloat?
        private var lastSaturation: CGFloat?
        
        func updateFilters(currentFilter: CameraFilter, contrast: CGFloat, brightness: CGFloat, saturation: CGFloat) {
            // Check if anything actually changed to prevent unnecessary processing
            let filterChanged = lastFilter != currentFilter
            let contrastChanged = lastContrast != contrast
            let brightnessChanged = lastBrightness != brightness
            let saturationChanged = lastSaturation != saturation
            
            if !filterChanged && !contrastChanged && !brightnessChanged && !saturationChanged {
                // Nothing changed, skip expensive operations
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            print("⏱️ updateFilters STARTED at \(startTime) - Changes: filter=\(filterChanged), contrast=\(contrastChanged), brightness=\(brightnessChanged), saturation=\(saturationChanged)")
            
            // Ensure filter processor exists but don't recreate if it exists
            if filterProcessor == nil {
                print("🔧 Creating filter processor for first time")
                filterProcessor = FilterProcessor()
            }
            
            filterProcessor?.currentFilter = currentFilter
            filterProcessor?.contrast = contrast
            filterProcessor?.brightness = brightness
            filterProcessor?.saturation = saturation

            print("🔄 Filter updated: \(currentFilter.rawValue), contrast: \(contrast), brightness: \(brightness), saturation: \(saturation)")
            
            // Only update preview layer if filter actually changed (most expensive operation)
            if filterChanged {
                updatePreviewLayerFilters(currentFilter: currentFilter)
            }
            
            // Cache current values for next comparison
            lastFilter = currentFilter
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
        
        private func updatePreviewLayerFilters(currentFilter: CameraFilter) {
            print("🎨 Filter changed to: \(currentFilter.rawValue) - Using visual overlay approach")
            
            // Remove existing filter overlay
            videoPreviewLayer.sublayers?.removeAll { $0.name == "FilterOverlay" }
            
            if currentFilter == .none {
                print("🎨 No filter - removed overlay")
                return
            }
            
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
    var contrast: CGFloat = 1.0
    var brightness: CGFloat = 0.0
    var saturation: CGFloat = 1.0

    private let ciContext: CIContext
    private let device: MTLDevice?

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

        // Preserve the original image orientation
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // No duplicate function needed here - it's already in PreviewView class
}

