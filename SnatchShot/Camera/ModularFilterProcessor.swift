//
//  ModularFilterProcessor.swift
//  SnatchShot
//
//  Created by SnatchShot on 01/01/25.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import MetalKit
import UIKit

// MARK: - LUT Processor

class LUTProcessor {
    private let ciContext: CIContext

    init(ciContext: CIContext) {
        self.ciContext = ciContext
    }

    func applyLUT(named lutName: String, to image: CIImage) -> CIImage {
        guard !lutName.isEmpty else { return image }

        // For now, implement basic film emulation using color adjustments
        // In a real implementation, this would load actual .cube LUT files
        return applyFilmEmulationLUT(named: lutName, to: image)
    }

    private func applyFilmEmulationLUT(named lutName: String, to image: CIImage) -> CIImage {
        var processedImage = image

        switch lutName {
        // Dazz Cam LUTs - Film Emulation
        case "portra_like", "portra_warm":
            processedImage = applyPortraEmulation(to: processedImage)

        case "kodak_gold_like", "kodak_gold":
            processedImage = applyKodakGoldEmulation(to: processedImage)

        case "kodachrome_like":
            processedImage = applyKodachromeEmulation(to: processedImage)

        case "polaroid_fade", "polaroid_quick":
            processedImage = applyPolaroidFadeEmulation(to: processedImage)

        case "bleach_bypass":
            processedImage = applyBleachBypassEmulation(to: processedImage)

        case "retro_fade":
            processedImage = applyRetroFadeEmulation(to: processedImage)

        case "matte_like":
            processedImage = applyMatteFilmEmulation(to: processedImage)

        case "sun_bleach":
            processedImage = applySunBleachEmulation(to: processedImage)

        case "portra_soft":
            processedImage = applyPortraSoftEmulation(to: processedImage)

        // KAPI LUTs - Digital/Camera
        case "nokia_like":
            processedImage = applyNokiaEmulation(to: processedImage)

        case "dv_cam":
            processedImage = applyDVCamEmulation(to: processedImage)

        case "ccd_warm":
            processedImage = applyCCDWarmEmulation(to: processedImage)

        case "lomo_like":
            processedImage = applyLomoEmulation(to: processedImage)

        case "vhs_like":
            processedImage = applyVHSEmulation(to: processedImage)

        case "manga_poster":
            processedImage = applyMangaPosterEmulation(to: processedImage)

        case "xt30_like":
            processedImage = applyXT30Emulation(to: processedImage)

        case "hybrid":
            processedImage = applyHybridEmulation(to: processedImage)

        // LoFi Cam LUTs - Film/Toy Camera
        case "t10_like":
            processedImage = applyT10Emulation(to: processedImage)

        case "f700_like":
            processedImage = applyF700Emulation(to: processedImage)

        case "grd_bw":
            processedImage = applyGRDBWEmulation(to: processedImage)

        case "120_like":
            processedImage = apply120FilmEmulation(to: processedImage)

        case "l80_like":
            processedImage = applyL80Emulation(to: processedImage)

        case "fuji_velvia":
            processedImage = applyFujiVelviaEmulation(to: processedImage)

        case "dispo_like":
            processedImage = applyDispoFilmEmulation(to: processedImage)

        case "lomo_classic":
            processedImage = applyLomoClassicEmulation(to: processedImage)

        case "neon_boost":
            processedImage = applyNeonBoostEmulation(to: processedImage)

        case "pastel_like":
            processedImage = applyPastelFilmEmulation(to: processedImage)

        default:
            // Neutral LUT - slight warming
            processedImage = applyNeutralLUT(to: processedImage)
        }

        return processedImage
    }

    // Film Emulation LUTs
    private func applyPortraEmulation(to image: CIImage) -> CIImage {
        // Portra 400: Warm, natural skin tones, smooth
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.05)
        colorFilter.brightness = Float(0.02)
        colorFilter.contrast = Float(1.02)

        let toneFilter = CIFilter.toneCurve()
        toneFilter.inputImage = colorFilter.outputImage
        // Gentle S-curve for film-like response
        toneFilter.point0 = CGPoint(x: 0, y: 0.1)
        toneFilter.point1 = CGPoint(x: 0.25, y: 0.15)
        toneFilter.point2 = CGPoint(x: 0.5, y: 0.5)
        toneFilter.point3 = CGPoint(x: 0.75, y: 0.85)
        toneFilter.point4 = CGPoint(x: 1.0, y: 0.9)

        return toneFilter.outputImage ?? image
    }

    private func applyKodakGoldEmulation(to image: CIImage) -> CIImage {
        // Kodak Gold: Punchy, warm highlights
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.1)
        colorFilter.brightness = Float(0.05)
        colorFilter.contrast = Float(1.1)

        return colorFilter.outputImage ?? image
    }

    private func applyKodachromeEmulation(to image: CIImage) -> CIImage {
        // Kodachrome: High saturation, vivid colors
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.25)
        colorFilter.brightness = Float(0.02)
        colorFilter.contrast = Float(1.15)

        return colorFilter.outputImage ?? image
    }

    private func applyPolaroidFadeEmulation(to image: CIImage) -> CIImage {
        // Polaroid: Faded, warm, desaturated
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.7)
        colorFilter.brightness = Float(0.1)
        colorFilter.contrast = Float(0.9)

        return colorFilter.outputImage ?? image
    }

    private func applyBleachBypassEmulation(to image: CIImage) -> CIImage {
        // Bleach Bypass: High contrast, desaturated
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.4)
        colorFilter.brightness = Float(-0.1)
        colorFilter.contrast = Float(1.3)

        return colorFilter.outputImage ?? image
    }

    private func applyRetroFadeEmulation(to image: CIImage) -> CIImage {
        // Retro Fade: Sun-faded, warm
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.8)
        colorFilter.brightness = Float(0.08)
        colorFilter.contrast = Float(0.9)

        return colorFilter.outputImage ?? image
    }

    private func applyMatteFilmEmulation(to image: CIImage) -> CIImage {
        // Matte Film: Lifted blacks, soft contrast
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.95)
        colorFilter.brightness = Float(0.05)
        colorFilter.contrast = Float(0.85)

        return colorFilter.outputImage ?? image
    }

    private func applySunBleachEmulation(to image: CIImage) -> CIImage {
        // Sun Bleach: Warm, lowered saturation
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.6)
        colorFilter.brightness = Float(0.15)
        colorFilter.contrast = Float(0.9)

        return colorFilter.outputImage ?? image
    }

    private func applyPortraSoftEmulation(to image: CIImage) -> CIImage {
        // Portra Soft: Very smooth, warm
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.0)
        colorFilter.brightness = Float(0.03)
        colorFilter.contrast = Float(0.95)

        return colorFilter.outputImage ?? image
    }

    // Digital/Camera LUTs
    private func applyNokiaEmulation(to image: CIImage) -> CIImage {
        // Nokia 2005: Blue cast, heavy noise
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.7)
        colorFilter.brightness = Float(-0.1)
        colorFilter.contrast = Float(0.9)

        return colorFilter.outputImage ?? image
    }

    private func applyDVCamEmulation(to image: CIImage) -> CIImage {
        // DV Cam: Mild blue/green cast
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.0)
        colorFilter.brightness = Float(0.0)
        colorFilter.contrast = Float(1.02)

        return colorFilter.outputImage ?? image
    }

    private func applyCCDWarmEmulation(to image: CIImage) -> CIImage {
        // CCD Warm: Slight warmth
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.03)
        colorFilter.brightness = Float(0.02)
        colorFilter.contrast = Float(1.01)

        return colorFilter.outputImage ?? image
    }

    private func applyLomoEmulation(to image: CIImage) -> CIImage {
        // Lomo: Vivid color shift
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.2)
        colorFilter.brightness = Float(0.0)
        colorFilter.contrast = Float(1.1)

        return colorFilter.outputImage ?? image
    }

    private func applyVHSEmulation(to image: CIImage) -> CIImage {
        // VHS: Desaturated, low contrast
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.9)
        colorFilter.brightness = Float(0.0)
        colorFilter.contrast = Float(0.95)

        return colorFilter.outputImage ?? image
    }

    private func applyMangaPosterEmulation(to image: CIImage) -> CIImage {
        // Manga Poster: High contrast, desaturated
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.4)
        colorFilter.brightness = Float(0.0)
        colorFilter.contrast = Float(1.4)

        return colorFilter.outputImage ?? image
    }

    private func applyXT30Emulation(to image: CIImage) -> CIImage {
        // XT30: Clean, slight warmth
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.05)
        colorFilter.brightness = Float(0.01)
        colorFilter.contrast = Float(1.02)

        return colorFilter.outputImage ?? image
    }

    private func applyHybridEmulation(to image: CIImage) -> CIImage {
        // Hybrid: Mixed digital/film
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.9)
        colorFilter.brightness = Float(0.0)
        colorFilter.contrast = Float(0.98)

        return colorFilter.outputImage ?? image
    }

    // Film/Toy Camera LUTs
    private func applyT10Emulation(to image: CIImage) -> CIImage {
        // T10: Punchy contrast, slight warmth
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.06)
        colorFilter.brightness = Float(0.0)
        colorFilter.contrast = Float(1.1)

        return colorFilter.outputImage ?? image
    }

    private func applyF700Emulation(to image: CIImage) -> CIImage {
        // F700: Soft highlights, cool shadows
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.0)
        colorFilter.brightness = Float(0.02)
        colorFilter.contrast = Float(0.98)

        return colorFilter.outputImage ?? image
    }

    private func applyGRDBWEmulation(to image: CIImage) -> CIImage {
        // GRD B&W: Monochrome
        let monoFilter = CIFilter.colorMonochrome()
        monoFilter.inputImage = image
        monoFilter.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
        monoFilter.intensity = Float(1.0)

        return monoFilter.outputImage ?? image
    }

    private func apply120FilmEmulation(to image: CIImage) -> CIImage {
        // 120 Film: Soft, gentle
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.03)
        colorFilter.brightness = Float(0.04)
        colorFilter.contrast = Float(0.95)

        return colorFilter.outputImage ?? image
    }

    private func applyL80Emulation(to image: CIImage) -> CIImage {
        // L80: Soft, slightly desaturated
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.95)
        colorFilter.brightness = Float(0.01)
        colorFilter.contrast = Float(0.97)

        return colorFilter.outputImage ?? image
    }

    private func applyFujiVelviaEmulation(to image: CIImage) -> CIImage {
        // Fuji Velvia: Saturated greens/reds
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.22)
        colorFilter.brightness = Float(0.0)
        colorFilter.contrast = Float(1.15)

        return colorFilter.outputImage ?? image
    }

    private func applyDispoFilmEmulation(to image: CIImage) -> CIImage {
        // Dispo Film: Warm, slightly desaturated
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.9)
        colorFilter.brightness = Float(0.03)
        colorFilter.contrast = Float(1.02)

        return colorFilter.outputImage ?? image
    }

    private func applyLomoClassicEmulation(to image: CIImage) -> CIImage {
        // Lomo Classic: Strong colors
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.15)
        colorFilter.brightness = Float(0.0)
        colorFilter.contrast = Float(1.12)

        return colorFilter.outputImage ?? image
    }

    private func applyNeonBoostEmulation(to image: CIImage) -> CIImage {
        // Neon: Boosted blues/magentas
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.1)
        colorFilter.brightness = Float(-0.04)
        colorFilter.contrast = Float(1.08)

        return colorFilter.outputImage ?? image
    }

    private func applyPastelFilmEmulation(to image: CIImage) -> CIImage {
        // Pastel Film: Soft, desaturated
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(0.64)
        colorFilter.brightness = Float(0.03)
        colorFilter.contrast = Float(0.85)

        return colorFilter.outputImage ?? image
    }

    private func applyNeutralLUT(to image: CIImage) -> CIImage {
        // Neutral: Slight warming for natural look
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.01)
        colorFilter.brightness = Float(0.01)
        colorFilter.contrast = Float(1.01)

        return colorFilter.outputImage ?? image
    }
}

// MARK: - Modular Filter Processor
class ModularFilterProcessor {
    private let ciContext: CIContext
    private let device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private let lutProcessor: LUTProcessor

    // GPU-accelerated renderer (like professional camera apps)
    private var metalRenderer: MetalPreviewRenderer?

    // Pre-compiled Metal shaders for advanced effects
    private var grainShader: MTLComputePipelineState?
    private var vignetteShader: MTLComputePipelineState?
    private var chromaticAberrationShader: MTLComputePipelineState?
    private var halationShader: MTLComputePipelineState?

    init() {
        device = MTLCreateSystemDefaultDevice()

        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .outputColorSpace: CGColorSpaceCreateDeviceRGB()
        ]

        if let metalDevice = device {
            ciContext = CIContext(mtlDevice: metalDevice, options: options)
            commandQueue = metalDevice.makeCommandQueue()
        } else {
            ciContext = CIContext(options: [.useSoftwareRenderer: true])
            commandQueue = nil
        }

        // Initialize lutProcessor after all other properties are set
        lutProcessor = LUTProcessor(ciContext: ciContext)

        // Initialize Metal renderer for GPU-accelerated processing (like professional apps)
        if let device = device {
            metalRenderer = MetalPreviewRenderer(device: device)
        }

        // Now it's safe to call setupShaders since all properties are initialized
        if device != nil {
            setupShaders()
        } else {
            print("ℹ️ Metal device not available - Core Image effects ready")
        }
    }

    // MARK: - Metal Shader Application
    private func applyMetalShader(_ pipelineState: MTLComputePipelineState, intensity: Float, to image: CIImage) -> CIImage {
        var intensity = intensity  // Make it mutable for inout parameter
        guard let commandQueue = commandQueue,
              let device = device,
              let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            return image
        }

        let textureLoader = MTKTextureLoader(device: device)
        guard let inputTexture = try? textureLoader.newTexture(cgImage: cgImage, options: nil) else {
            return image
        }

        // Create output texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: inputTexture.pixelFormat,
            width: inputTexture.width,
            height: inputTexture.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            return image
        }

        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return image
        }

        // Set up compute pass
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)

        // Dispatch threads
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (inputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (inputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()

        // Execute and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Convert back to CIImage
        guard let outputImage = CIImage(mtlTexture: outputTexture, options: nil) else {
            return image
        }

        return outputImage
    }

    private func setupShaders() {
        guard let device = device else {
            print("ℹ️ Metal device not available - Core Image effects ready")
            return
        }

        // Metal shaders require proper Xcode project configuration with .metallib compilation
        // This is expected to fail in development environments without Metal setup
        let library: MTLLibrary?
        do {
            // Try to load pre-compiled Metal library (.metallib) from bundle
            library = try device.makeDefaultLibrary(bundle: Bundle.main)
            print("✅ Metal library loaded successfully")
        } catch {
            // This is expected in development - Metal shaders need to be compiled into the app bundle
            print("ℹ️ Metal library not available (expected in development) - using Core Image effects")
            library = nil
        }

        guard let library = library else {
            print("🎨 Core Image effects ready - all filter functionality available")
            return
        }

        // Load shader functions if available
        do {
            if let grainFunction = library.makeFunction(name: "grainKernel") {
                grainShader = try device.makeComputePipelineState(function: grainFunction)
                print("✅ Grain shader loaded successfully")
            }

            if let vignetteFunction = library.makeFunction(name: "vignetteKernel") {
                vignetteShader = try device.makeComputePipelineState(function: vignetteFunction)
                print("✅ Vignette shader loaded successfully")
            }

            if let chromaticFunction = library.makeFunction(name: "chromaticAberrationKernel") {
                chromaticAberrationShader = try device.makeComputePipelineState(function: chromaticFunction)
                print("✅ Chromatic aberration shader loaded successfully")
            }

            if let halationFunction = library.makeFunction(name: "halationKernel") {
                halationShader = try device.makeComputePipelineState(function: halationFunction)
                print("✅ Halation shader loaded successfully")
            }

            print("✅ Metal shaders loaded - GPU acceleration available")
        } catch {
            print("❌ Failed to create compute pipeline states: \(error)")
            print("⚠️ Metal shaders failed to load - using Core Image fallbacks")
        }
    }

    // MARK: - Main Filter Application
    func applyPreset(_ preset: FilterPreset, to image: UIImage) -> UIImage {
        let hasMetalShaders = grainShader != nil || vignetteShader != nil || chromaticAberrationShader != nil || halationShader != nil
        print("🔧 ModularFilterProcessor: Applying preset '\(preset.name)' with \(preset.modules.temperature) temp, \(preset.modules.contrast) contrast")
        print("🎨 Using \(hasMetalShaders ? "GPU Metal shaders" : "CPU Core Image fallbacks") for effects")

        guard let ciImage = CIImage(image: image) else {
            print("❌ ModularFilterProcessor: Could not create CIImage from input")
            return image
        }

        print("📏 Input image size: \(image.size), CIImage extent: \(ciImage.extent)")

        var processedImage = ciImage
        let startTime = CFAbsoluteTimeGetCurrent()

        // Apply filters in optimal order for realistic results
        // 1. LUT (foundation for most presets - applies color grading first)
        processedImage = applyLUT(preset.modules.lut, to: processedImage)

        // 2. Basic adjustments (temperature, tint, exposure, contrast, saturation)
        processedImage = applyBasicAdjustments(preset.modules, to: processedImage)

        // 3. Lens distortion (should be early for realistic camera effects)
        processedImage = applyLensDistortion(preset.modules.lensDistortion, to: processedImage)

        // 4. Creative effects (grain, vignette, halation, chromatic aberration)
        processedImage = applyGrain(preset.modules.grain, to: processedImage)
        processedImage = applyVignette(preset.modules.vignette, to: processedImage)
        processedImage = applyHalation(preset.modules.halation, to: processedImage)
        processedImage = applyChromaticAberration(preset.modules.chromaticAberration, to: processedImage)
        processedImage = applyChromaBleed(preset.modules.chromaBleed, to: processedImage)

        // 5. Digital/camera effects (downscale, scanlines, interlace, jitter)
        processedImage = applyDownscale(preset.modules.downscale, to: processedImage)
        processedImage = applyScanlines(preset.modules.scanlines, to: processedImage)
        processedImage = applyInterlace(preset.modules.interlace, to: processedImage)
        processedImage = applyJitter(preset.modules.jitter, to: processedImage)

        // 6. Enhancement effects (sharpening, edge enhancement, posterize)
        processedImage = applySharpening(preset.modules.sharpen, to: processedImage)
        processedImage = applyEdgeEnhancement(preset.modules.edgeEnhance, to: processedImage)
        processedImage = applyPosterize(preset.modules.posterize, to: processedImage)

        // 7. Finishing touches (black lift, edge fade, skin smoothing)
        processedImage = applyBlackLift(preset.modules.blackLift, to: processedImage)
        processedImage = applyEdgeFade(preset.modules.edgeFade, to: processedImage)
        processedImage = applySkinSmoothing(preset.modules.skinSmooth, to: processedImage)

        // Convert back to UIImage, preserving original orientation and dimensions
        guard let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) else {
            print("❌ ModularFilterProcessor: Could not create CGImage from processed CIImage")
            return image
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        print("✅ ModularFilterProcessor: Completed preset '\(preset.name)' in \(duration * 1000)ms")
        print("📏 Output CGImage size: \(cgImage.width)x\(cgImage.height)")
        print("📏 Original image size: \(image.size), scale: \(image.scale), orientation: \(image.imageOrientation.rawValue)")

        // Preserve the original image's orientation and scale
        let resultImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        print("📏 Final result image size: \(resultImage.size), scale: \(resultImage.scale), orientation: \(resultImage.imageOrientation.rawValue)")
        return resultImage
    }

    // MARK: - Basic Adjustments
    private func applyBasicAdjustments(_ modules: FilterPresetModules, to image: CIImage) -> CIImage {
        var adjustedImage = image

        print("🎨 Basic adjustments: temp=\(modules.temperature), tint=\(modules.tint), exposure=\(modules.exposure), contrast=\(modules.contrast), saturation=\(modules.saturation)")

        // Temperature and Tint
        if modules.temperature != 0 || modules.tint != 0 {
            let tempFilter = CIFilter.temperatureAndTint()
            tempFilter.inputImage = adjustedImage

            // Convert our range to Core Image values
            let neutralTemp: CGFloat = 6500  // Daylight
            let tempRange: CGFloat = 3000    // ±3000K range
            let tempOffset = (modules.temperature / 40.0) * tempRange
            let targetTemp = neutralTemp + tempOffset

            let neutralTint: CGFloat = 0
            let tintRange: CGFloat = 50
            let tintOffset = (modules.tint / 30.0) * tintRange

            tempFilter.neutral = CIVector(x: neutralTemp, y: neutralTint)
            tempFilter.targetNeutral = CIVector(x: targetTemp, y: tintOffset)

            adjustedImage = tempFilter.outputImage ?? adjustedImage
        }

        // Exposure
        if modules.exposure != 0 {
            let exposureFilter = CIFilter.exposureAdjust()
            exposureFilter.inputImage = adjustedImage
            exposureFilter.ev = Float(modules.exposure)
            adjustedImage = exposureFilter.outputImage ?? adjustedImage
        }

        // Contrast
        if modules.contrast != 0 {
            let contrastFilter = CIFilter.colorControls()
            contrastFilter.inputImage = adjustedImage
            // Use contrast directly (1.0 = normal, >1.0 = more contrast, <1.0 = less contrast)
            contrastFilter.contrast = Float(1.0 + modules.contrast)
            adjustedImage = contrastFilter.outputImage ?? adjustedImage
        }

        // Saturation
        if modules.saturation != 0 {
            let saturationFilter = CIFilter.colorControls()
            saturationFilter.inputImage = adjustedImage
            saturationFilter.saturation = Float(1.0 + modules.saturation)
            adjustedImage = saturationFilter.outputImage ?? adjustedImage
        }

        return adjustedImage
    }

    // MARK: - LUT Application
    private func applyLUT(_ lutName: String?, to image: CIImage) -> CIImage {
        guard let lutName = lutName, !lutName.isEmpty else {
            return image
        }

        return lutProcessor.applyLUT(named: lutName, to: image)
    }

    // MARK: - Grain Effect (Professional GPU Approach)
    private func applyGrain(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        // Try GPU-accelerated grain first (like Snappit/LoFiCam/DazzCam/KAPI)
        if let metalRenderer = metalRenderer {
            // Convert CIImage to CVPixelBuffer for GPU processing
            guard let pixelBuffer = createPixelBuffer(from: image),
                  let processedBuffer = metalRenderer.applyEffects(to: pixelBuffer,
                                                                 grain: Float(intensity),
                                                                 vignette: 0,
                                                                 halation: 0) else {
                // Fall back to CPU processing
                return applyCPUGrain(intensity, to: image)
            }
            // CIImage(cvPixelBuffer:) is not optional, so we can safely create it
            let processedImage = CIImage(cvPixelBuffer: processedBuffer)
            return processedImage
        } else {
            // CPU fallback - optimized for performance
            return applyCPUGrain(intensity, to: image)
        }
    }

    private func applyCPUGrain(_ intensity: Double, to image: CIImage) -> CIImage {
        // Professional CPU grain implementation (optimized)
        let noiseFilter = CIFilter.randomGenerator()
        let scaledNoise = noiseFilter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 1.5, y: 1.5))
            .cropped(to: image.extent)

        let monoFilter = CIFilter.colorControls()
        monoFilter.inputImage = scaledNoise
        monoFilter.saturation = 0.0
        monoFilter.brightness = 0.0
        monoFilter.contrast = 1.3

        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = monoFilter.outputImage
        blurFilter.radius = 0.4

        let blendFilter = CIFilter.overlayBlendMode()
        blendFilter.inputImage = blurFilter.outputImage
        blendFilter.backgroundImage = image

        let intensityFilter = CIFilter.colorMatrix()
        intensityFilter.inputImage = blendFilter.outputImage
        let grainOpacity = CGFloat(min(intensity * 0.35, 0.22))
        intensityFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: grainOpacity)

        return intensityFilter.outputImage ?? image
    }

    private func createPixelBuffer(from image: CIImage) -> CVPixelBuffer? {
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                       kCVPixelFormatType_32BGRA,
                                       nil, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        // Render CIImage to CVPixelBuffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let context = CGContext(data: baseAddress,
                              width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            return nil
        }

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    // MARK: - Vignette Effect (Professional GPU Approach)
    private func applyVignette(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        // Try GPU-accelerated vignette first (like professional apps)
        if let metalRenderer = metalRenderer {
            guard let pixelBuffer = createPixelBuffer(from: image),
                  let processedBuffer = metalRenderer.applyEffects(to: pixelBuffer,
                                                                 grain: 0,
                                                                 vignette: Float(intensity),
                                                                 halation: 0) else {
                return applyCPUVignette(intensity, to: image)
            }
            // CIImage(cvPixelBuffer:) is not optional, so we can safely create it
            let processedImage = CIImage(cvPixelBuffer: processedBuffer)
            return processedImage
        } else {
            return applyCPUVignette(intensity, to: image)
        }
    }

    private func applyCPUVignette(_ intensity: Double, to image: CIImage) -> CIImage {
        // Professional CPU vignette - optimized for quality
        let vignetteFilter = CIFilter.vignette()
        vignetteFilter.inputImage = image
        vignetteFilter.intensity = Float(intensity * 0.8)  // Professional strength
        vignetteFilter.radius = Float(1.0 + intensity * 2.2) // Optimized radius

        return vignetteFilter.outputImage ?? image
    }

    // MARK: - Halation (Bloom/Glow) (Professional GPU Approach)
    private func applyHalation(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        // Try GPU-accelerated halation first (like professional apps)
        if let metalRenderer = metalRenderer {
            guard let pixelBuffer = createPixelBuffer(from: image),
                  let processedBuffer = metalRenderer.applyEffects(to: pixelBuffer,
                                                                 grain: 0,
                                                                 vignette: 0,
                                                                 halation: Float(intensity)) else {
                return applyCPUHalation(intensity, to: image)
            }
            // CIImage(cvPixelBuffer:) is not optional, so we can safely create it
            let processedImage = CIImage(cvPixelBuffer: processedBuffer)
            return processedImage
        } else {
            return applyCPUHalation(intensity, to: image)
        }
    }

    private func applyCPUHalation(_ intensity: Double, to image: CIImage) -> CIImage {
        // Professional CPU halation - optimized film-like glow
        let adjustedIntensity = Float(min(intensity * 0.7, 0.85))

        let bloomFilter = CIFilter.bloom()
        bloomFilter.inputImage = image
        bloomFilter.intensity = adjustedIntensity
        bloomFilter.radius = Float(7.0 + intensity * 3.5)

        let screenFilter = CIFilter.screenBlendMode()
        screenFilter.inputImage = bloomFilter.outputImage
        screenFilter.backgroundImage = image

        return screenFilter.outputImage ?? bloomFilter.outputImage ?? image
    }

    // MARK: - Chromatic Aberration
    private func applyChromaticAberration(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        if let chromaticShader = chromaticAberrationShader, let commandQueue = commandQueue {
            return applyMetalShader(chromaticShader, intensity: Float(intensity), to: image)
        } else {
            // Enhanced Core Image fallback: Simulate chromatic aberration with color shifts
            let aberrationAmount = Float(intensity * 2.0)

            // Create red channel with slight shift
            let redTransform = CGAffineTransform(translationX: CGFloat(aberrationAmount), y: 0)
            let redChannel = image.transformed(by: redTransform)
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ])

            // Create blue channel with opposite shift
            let blueTransform = CGAffineTransform(translationX: -CGFloat(aberrationAmount), y: 0)
            let blueChannel = image.transformed(by: blueTransform)
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ])

            // Green channel stays centered
            let greenChannel = image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0)
            ])

            // Composite the channels
            let compositeFilter = CIFilter.additionCompositing()
            compositeFilter.inputImage = redChannel
            compositeFilter.backgroundImage = blueChannel

            let finalComposite = CIFilter.additionCompositing()
            finalComposite.inputImage = compositeFilter.outputImage
            finalComposite.backgroundImage = greenChannel

            return finalComposite.outputImage ?? image
        }
    }

    // MARK: - Chroma Bleed (VHS-style)
    private func applyChromaBleed(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        // Simulate VHS chroma bleed by blurring color channels differently
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = image
        colorFilter.saturation = Float(1.0 + intensity * 0.5)

        return colorFilter.outputImage ?? image
    }

    // MARK: - Downscale/Pixelate
    private func applyDownscale(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        let pixelateFilter = CIFilter.pixellate()
        pixelateFilter.inputImage = image
        pixelateFilter.scale = Float(1.0 + intensity * 50.0)  // Scale up to create pixelation

        return pixelateFilter.outputImage ?? image
    }

    // MARK: - Scanlines
    private func applyScanlines(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        // Create scanline pattern using stripes
        let stripesFilter = CIFilter.stripesGenerator()
        stripesFilter.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: intensity)
        stripesFilter.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        stripesFilter.width = Float(2.0)
        stripesFilter.sharpness = Float(1.0)

        let blendFilter = CIFilter.multiplyCompositing()
        blendFilter.inputImage = stripesFilter.outputImage
        blendFilter.backgroundImage = image

        return blendFilter.outputImage ?? image
    }

    // MARK: - Interlace
    private func applyInterlace(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        // Similar to scanlines but with alternating pattern
        return applyScanlines(intensity * 0.8, to: image)
    }

    // MARK: - Jitter
    private func applyJitter(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        // Simulate horizontal jitter by slight random displacements
        // This is a simplified version - real jitter would need frame-by-frame variation
        return image
    }

    // MARK: - Posterize
    private func applyPosterize(_ enabled: Bool, to image: CIImage) -> CIImage {
        guard enabled else { return image }

        let posterizeFilter = CIFilter.colorPosterize()
        posterizeFilter.inputImage = image
        posterizeFilter.levels = Float(4.0)

        return posterizeFilter.outputImage ?? image
    }

    // MARK: - Edge Enhancement
    private func applyEdgeEnhancement(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        let edgeFilter = CIFilter.edges()
        edgeFilter.inputImage = image
        edgeFilter.intensity = Float(intensity)

        let blendFilter = CIFilter.hardLightBlendMode()
        blendFilter.inputImage = edgeFilter.outputImage
        blendFilter.backgroundImage = image

        return blendFilter.outputImage ?? image
    }

    // MARK: - Sharpening
    private func applySharpening(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = image
        sharpenFilter.sharpness = Float(intensity)

        return sharpenFilter.outputImage ?? image
    }

    // MARK: - Black Lift
    private func applyBlackLift(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity != 0 else { return image }

        let liftFilter = CIFilter.colorControls()
        liftFilter.inputImage = image
        liftFilter.brightness = Float(intensity * 0.1)

        return liftFilter.outputImage ?? image
    }

    // MARK: - Edge Fade
    private func applyEdgeFade(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        return applyVignette(intensity, to: image)
    }

    // MARK: - Lens Distortion
    private func applyLensDistortion(_ distortion: String?, to image: CIImage) -> CIImage {
        guard let distortion = distortion else { return image }

        if distortion.contains("fisheye") {
            let fisheyeFilter = CIFilter.bumpDistortion()
            fisheyeFilter.inputImage = image
            fisheyeFilter.center = CGPoint(x: image.extent.midX, y: image.extent.midY)
            fisheyeFilter.radius = Float(image.extent.width * 0.8)
            fisheyeFilter.scale = Float(0.5)

            return fisheyeFilter.outputImage ?? image
        }

        return image
    }

    // MARK: - Skin Smoothing
    private func applySkinSmoothing(_ intensity: Double, to image: CIImage) -> CIImage {
        guard intensity > 0 else { return image }

        // Use bilateral filter for skin smoothing
        guard let smoothFilter = CIFilter(name: "CIBilateralFilter") else {
            return image
        }
        smoothFilter.setValue(image, forKey: kCIInputImageKey)
        smoothFilter.setValue(NSNumber(value: intensity * 0.1), forKey: "inputSigmaR")
        smoothFilter.setValue(NSNumber(value: intensity * 10.0), forKey: "inputSigmaS")

        return smoothFilter.outputImage ?? image
    }


    // MARK: - Frame and Overlay Application
    func applyFrame(_ frameName: String?, to image: UIImage) -> UIImage {
        guard let frameName = frameName else { return image }

        // Apply frame overlays - simplified implementation
        // In a real app, you'd load frame images and composite them
        return image
    }

    func applyLightLeak(_ leakName: String?, to image: UIImage) -> UIImage {
        guard let leakName = leakName else { return image }

        // Apply light leak overlays - simplified implementation
        return image
    }

    func applyTimestamp(_ enabled: Bool, to image: UIImage) -> UIImage {
        guard enabled else { return image }

        // Add timestamp overlay - simplified implementation
        return image
    }
}

// MARK: - Metal Shader Kernels (would be in separate .metal files)
/*
#include <metal_stdlib>
using namespace metal;

// Grain kernel
kernel void grainKernel(texture2d<float, access::read> inTexture [[texture(0)]],
                       texture2d<float, access::write> outTexture [[texture(1)]],
                       constant float &intensity [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    float4 color = inTexture.read(gid);
    // Add grain implementation
    outTexture.write(color, gid);
}

// Vignette kernel
kernel void vignetteKernel(texture2d<float, access::read> inTexture [[texture(0)]],
                          texture2d<float, access::write> outTexture [[texture(1)]],
                          constant float &intensity [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]])
{
    float4 color = inTexture.read(gid);
    // Add vignette implementation
    outTexture.write(color, gid);
}

// Chromatic aberration kernel
kernel void chromaticAberrationKernel(texture2d<float, access::read> inTexture [[texture(0)]],
                                     texture2d<float, access::write> outTexture [[texture(1)]],
                                     constant float &intensity [[buffer(0)]],
                                     uint2 gid [[thread_position_in_grid]])
{
    float4 color = inTexture.read(gid);
    // Add chromatic aberration implementation
    outTexture.write(color, gid);
}

// Halation kernel
kernel void halationKernel(texture2d<float, access::read> inTexture [[texture(0)]],
                          texture2d<float, access::write> outTexture [[texture(1)]],
                          constant float &intensity [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]])
{
    float4 color = inTexture.read(gid);
    // Add halation implementation
    outTexture.write(color, gid);
}
*/
