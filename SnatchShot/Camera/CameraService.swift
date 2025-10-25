//
//  CameraService.swift
//  SnatchShot
//
//  Created by Rushant on 15/09/25.
//

#if os(iOS)
import SwiftUI
import AVFoundation
import Photos
import Combine
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import CoreMedia
import CoreLocation
import LocalAuthentication
import ImageIO
import ARKit
#endif

// Import for shared types and services
import Foundation

// MARK: - Enums

enum AspectRatio: String, CaseIterable, Identifiable {
    case full = "Full"
    case oneOne = "1:1"
    case fourFive = "4:5"
    case threeFour = "3:4"
    case nineSixteen = "9:16"

    var id: String { rawValue }
}

enum WBPreset: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case sunny = "Sunny"
    case cloudy = "Cloudy"
    case shade = "Shade"
    case tungsten = "Tungsten"
    case fluorescent = "Fluorescent"

    var id: String { rawValue }
}

enum CaptureTimer: String, CaseIterable, Identifiable {
    case off = "Off"
    case three = "3s"
    case five = "5s"
    case ten = "10s"

    var id: String { rawValue }

    var seconds: Int {
        switch self {
        case .off: return 0
        case .three: return 3
        case .five: return 5
        case .ten: return 10
        }
    }
}

enum CameraFilter: String, CaseIterable, Identifiable {
    // Basic Filters
    case none = "None"
    case vintage = "Vintage"
    case mono = "Mono"
    case vivid = "Vivid"
    case dramatic = "Dramatic"
    case portrait = "Portrait"
    case landscape = "Landscape"
    case bw = "B&W"
    case sepia = "Sepia"
    case cyanotype = "Cyanotype"

    // Professional Filters
    case hdr = "HDR"
    case softFocus = "Soft Focus"
    case sharpen = "Sharpen"
    case warmth = "Warmth"
    case cool = "Cool"
    case kodak = "Kodak Portra"
    case fuji = "Fuji Provia"
    case cinestill = "CineStill"
    case oilPaint = "Oil Paint"
    case sketch = "Sketch"
    case comic = "Comic"
    case crystal = "Crystal"
    case emboss = "Emboss"
    case gaussianBlur = "Blur"
    case vignette = "Vignette"
    case grain = "Film Grain"
    case crossProcess = "Cross Process"
    case glow = "Glow"
    case neon = "Neon"
    case posterize = "Posterize"
    case solarize = "Solarize"
    case kaleidoscope = "Kaleidoscope"
    case pinch = "Pinch"
    case twirl = "Twirl"
    case bump = "Bump"
    case glass = "Glass"
    case dotScreen = "Dot Screen"
    case lineScreen = "Line Screen"

    var id: String { rawValue }

    var category: String {
        switch self {
        case .none: return "Basic"
        case .vintage, .mono, .vivid, .dramatic, .portrait, .landscape, .bw, .sepia, .cyanotype:
            return "Basic"
        case .hdr, .softFocus, .sharpen: return "Enhancement"
        case .warmth, .cool: return "Color"
        case .kodak, .fuji, .cinestill: return "Film"
        case .oilPaint, .sketch, .comic: return "Artistic"
        case .crystal, .emboss, .gaussianBlur, .vignette, .grain: return "Effects"
        case .crossProcess, .glow, .neon, .posterize, .solarize: return "Special"
        case .kaleidoscope, .pinch, .twirl, .bump, .glass: return "Distortion"
        case .dotScreen, .lineScreen: return "Halftone"
        }
    }
}

enum NightMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case auto = "Auto"
    case on = "On"

    var id: String { rawValue }
}

enum ExposureMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case manual = "Manual"
    case priorityAperture = "Aperture Priority"
    case priorityShutter = "Shutter Priority"
    case program = "Program"

    var id: String { rawValue }
}

enum FocusMode: String, CaseIterable, Identifiable {
    case auto = "Auto Focus"
    case manual = "Manual Focus"
    case continuous = "Continuous AF"
    case single = "Single AF"

    var id: String { rawValue }
}

enum StabilizationMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case on = "On"
    case cinematic = "Cinematic"

    var id: String { rawValue }
}

enum GridOverlay: String, CaseIterable, Identifiable {
    case none = "None"
    case thirds = "Rule of Thirds"
    case golden = "Golden Ratio"
    case square = "Square"
    case diagonal = "Diagonal"
    case center = "Center Cross"

    var id: String { rawValue }
}

enum BurstMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case low = "Low (3 fps)"
    case medium = "Medium (5 fps)"
    case high = "High (10 fps)"

    var id: String { rawValue }

    var frameRate: Double {
        switch self {
        case .off: return 0
        case .low: return 3
        case .medium: return 5
        case .high: return 10
        }
    }
}

enum BracketingMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case exposure = "Exposure (±0.5EV)"
    case exposureWide = "Exposure (±1EV)"
    case focus = "Focus Bracketing"

    var id: String { rawValue }
}

enum ZoomMode: String, CaseIterable, Identifiable {
    case optical = "Optical Only"
    case digital = "Digital Zoom"
    case hybrid = "Hybrid"

    var id: String { rawValue }
}

// MARK: - CameraService

class CameraService: NSObject, ObservableObject {
    // MARK: - Shared Instance
    static var shared: CameraService?

    // MARK: - Published Properties
    @Published var isConfigured = false
    @Published var lastPhoto: UIImage?
    @Published var error: String?
    @Published var spotSuggestion: String?

    // MARK: - Dependencies
    weak var webSocketService: WebSocketService?

    // Camera Controls
    @Published var aspectRatio: AspectRatio = .full
    @Published var zoomFactor: CGFloat = 1.0
    @Published var isAEAFLocked = false
    @Published var evBias: CGFloat = 0.0
    @Published var wbPreset: WBPreset = .auto
    @Published var captureTimer: CaptureTimer = .off

    // Camera position info
    var currentCameraPosition: AVCaptureDevice.Position? {
        return device?.position
    }
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var autoSaveToLibrary = false

    // MARK: - Manual Photo Saving
    func saveCurrentPhotoToLibrary(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let photo = lastPhoto else {
            completion?(false, NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No photo to save"]))
            return
        }

        let data = photo.jpegData(compressionQuality: 0.95) ?? photo.pngData()
        guard let imageData = data else {
            completion?(false, NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert photo to data"]))
            return
        }

        // Provide default completion if none given
        let actualCompletion: (Bool, Error?) -> Void = completion ?? { success, error in
            if let error = error {
                print("Failed to save photo to library: \(error.localizedDescription)")
            } else if success {
                print("Photo saved to library successfully")
            }
        }

        saveToLibrary(imageData, completion: actualCompletion)
    }
    @Published var isCapturing = false

    // Advanced Controls
    @Published var iso: CGFloat = 100.0
    @Published var shutterSpeed: CMTime = CMTime(seconds: 1.0/60.0, preferredTimescale: 1000000)
    @Published var focusDistance: CGFloat = 0.5
    @Published var whiteBalanceTemperature: CGFloat = 5500.0
    @Published var whiteBalanceTint: CGFloat = 0.0
    @Published var contrast: CGFloat = 1.0
    @Published var brightness: CGFloat = 0.0
    @Published var saturation: CGFloat = 1.0
    @Published var sharpness: CGFloat = 1.0
    @Published var exposureMode: ExposureMode = .auto
    @Published var focusMode: FocusMode = .auto
    @Published var stabilizationMode: StabilizationMode = .on
    @Published var gridOverlay: GridOverlay = .none
    @Published var burstMode: BurstMode = .off
    @Published var bracketingMode: BracketingMode = .off
    @Published var zoomMode: ZoomMode = .optical
    @Published var nightMode: NightMode = .off
    @Published var nightModeIntensity: Float = 0.5 // 0.0 to 1.0
    @Published var currentFilter: CameraFilter = .none
    @Published var currentPreset: FilterPreset?

    // UI Helper Properties
    @Published var minExposureTargetBias: CGFloat = -2.0
    @Published var maxExposureTargetBias: CGFloat = 2.0

    // Additional Professional Controls
    @Published var aperture: CGFloat = 2.8
    @Published var focalLength: CGFloat = 50.0
    @Published var frameRate: Double = 30.0
    @Published var hdrMode: Bool = false
    @Published var rawCapture: Bool = false
    @Published var focusPeaking: Bool = false
    @Published var zebraStripes: Bool = false
    @Published var levelIndicator: Bool = false
    @Published var histogram: Bool = false
    @Published var audioRecording: Bool = true
    @Published var gpsTagging: Bool = true
    
    // Pending post-processing settings (applied after photo capture)
    @Published var pendingSaturation: CGFloat? = nil
    @Published var pendingSharpness: CGFloat? = nil
    @Published var pendingContrast: CGFloat? = nil
    
    // Professional visual aids (lightweight overlays)
    @Published var showFocusPeaking: Bool = false
    @Published var showZebraStripes: Bool = false  
    @Published var showLevelIndicator: Bool = false
    @Published var showHistogram: Bool = false

    // Device capabilities
    @Published var minISO: CGFloat = 23.0
    @Published var maxISO: CGFloat = 7360.0
    @Published var minShutterSpeed: CMTime = CMTime(seconds: 1.0/8000.0, preferredTimescale: 1000000)
    @Published var maxShutterSpeed: CMTime = CMTime(seconds: 30.0, preferredTimescale: 1000000)
    @Published var supportsNightMode = false
    @Published var supportsHDR = false
    @Published var supportsRAW = false
    @Published var maxFrameRate: Double = 60.0
    @Published var minAperture: CGFloat = 1.4
    @Published var maxAperture: CGFloat = 16.0

    // MARK: - Private Properties
    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var output: AVCapturePhotoOutput?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var filterProcessor: FilterProcessor?

    // Completion handler for photo capture
    private var photoCompletionHandler: ((UIImage?) -> Void)?

    // MARK: - Initialization
    override init() {
        super.init()
        // Delay camera setup until permissions are granted
        // setupCamera() will be called explicitly after permissions
    }

    // MARK: - Permission-Based Initialization
    func initializeCameraAfterPermissions() {
        guard !isConfigured else { return }
        setupCamera()
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            error = "Camera not available"
            return
        }

        self.device = device

        // Query device capabilities
        setupDeviceCapabilities(device)

        do {
            input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input!) {
                session.addInput(input!)
            }

            output = AVCapturePhotoOutput()
            if session.canAddOutput(output!) {
                session.addOutput(output!)
                
                // Configure for high quality photo capture
                output!.maxPhotoQualityPrioritization = .quality
                output!.isHighResolutionCaptureEnabled = true
                output!.isLivePhotoCaptureEnabled = false
                
                // Set photo output connection properties
                if let connection = output!.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = device.position == .front
                    }
                }
            }

            // Setup video data output for filters
            setupVideoDataOutput()

            session.commitConfiguration()
            isConfigured = true

            // Initialize current values from device
            updateCurrentValuesFromDevice()

            // Start session on background thread
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }

        } catch {
            self.error = "Failed to setup camera: \(error.localizedDescription)"
            session.commitConfiguration()
        }
    }

    private func setupDeviceCapabilities(_ device: AVCaptureDevice) {
        // ISO range
        minISO = CGFloat(device.activeFormat.minISO)
        maxISO = CGFloat(device.activeFormat.maxISO)

        // Shutter speed range
        minShutterSpeed = device.activeFormat.minExposureDuration
        maxShutterSpeed = device.activeFormat.maxExposureDuration

        // Exposure bias range
        minExposureTargetBias = CGFloat(device.minExposureTargetBias)
        maxExposureTargetBias = CGFloat(device.maxExposureTargetBias)

        // Night mode support - check multiple conditions
        supportsNightMode = device.hasTorch && device.isLowLightBoostSupported

        // Initialize filter processor
        filterProcessor = FilterProcessor()
    }

    private func setupVideoDataOutput() {
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if let videoDataOutput = videoDataOutput,
           session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Don't set video orientation here - let iOS handle it automatically
            // for proper device orientation support
            // Video mirroring is already set correctly above based on camera position
        }
        videoDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

        if let videoOutput = videoDataOutput, session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        }
    }

    private func updateCurrentValuesFromDevice() {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            iso = CGFloat(device.iso)
            shutterSpeed = device.exposureDuration
            focusDistance = CGFloat(device.lensPosition)
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to read device values: \(error.localizedDescription)"
        }
    }


    // MARK: - Camera Controls

    func setZoom(factor: CGFloat) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            let clampedFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
            device.videoZoomFactor = clampedFactor
            zoomFactor = clampedFactor
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set zoom: \(error.localizedDescription)"
        }
    }

    func focus(at point: CGPoint) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to focus: \(error.localizedDescription)"
        }
    }

    func toggleAEAFLock() {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            if isAEAFLocked {
                device.unlockForConfiguration()
                isAEAFLocked = false
            } else {
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
                if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }
                device.unlockForConfiguration()
                isAEAFLocked = true
            }
        } catch {
            self.error = "Failed to toggle AE/AF lock: \(error.localizedDescription)"
        }
    }

    func setExposureBias(_ bias: CGFloat) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            let clampedBias = max(Float(device.minExposureTargetBias), min(Float(bias), Float(device.maxExposureTargetBias)))
            device.setExposureTargetBias(clampedBias, completionHandler: nil)
            evBias = CGFloat(clampedBias)
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set exposure bias: \(error.localizedDescription)"
        }
    }

    func applyWhiteBalancePreset(_ preset: WBPreset) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            wbPreset = preset

            switch preset {
            case .auto:
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                whiteBalanceTemperature = 5500.0
                whiteBalanceTint = 0.0
            case .sunny:
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(5500), tint: Float(0)))
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                whiteBalanceTemperature = 5500.0
                whiteBalanceTint = 0.0
            case .cloudy:
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(6500), tint: Float(0)))
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                whiteBalanceTemperature = 6500.0
                whiteBalanceTint = 0.0
            case .shade:
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(7500), tint: Float(0)))
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                whiteBalanceTemperature = 7500.0
                whiteBalanceTint = 0.0
            case .tungsten:
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(2850), tint: Float(0)))
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                whiteBalanceTemperature = 2850.0
                whiteBalanceTint = 0.0
            case .fluorescent:
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(3800), tint: Float(0)))
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                whiteBalanceTemperature = 3800.0
                whiteBalanceTint = 0.0
            }

            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set white balance: \(error.localizedDescription)"
        }
    }

    // MARK: - Advanced Camera Controls

    func setISO(_ newISO: CGFloat) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            let clampedISO = max(minISO, min(maxISO, newISO))
            device.setExposureModeCustom(duration: shutterSpeed, iso: Float(clampedISO), completionHandler: nil)
            iso = clampedISO
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set ISO: \(error.localizedDescription)"
        }
    }

    func setShutterSpeed(_ newShutterSpeed: CMTime) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            let clampedSpeed = CMTimeClampToRange(newShutterSpeed, range: CMTimeRange(start: minShutterSpeed, duration: CMTimeSubtract(maxShutterSpeed, minShutterSpeed)))
            device.setExposureModeCustom(duration: clampedSpeed, iso: Float(iso), completionHandler: nil)
            shutterSpeed = clampedSpeed
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set shutter speed: \(error.localizedDescription)"
        }
    }

    func setFocusDistance(_ distance: CGFloat) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
                device.setFocusModeLocked(lensPosition: Float(distance), completionHandler: nil)
                focusDistance = distance
            }
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set focus: \(error.localizedDescription)"
        }
    }

    func setWhiteBalanceTemperature(_ temperature: CGFloat, tint: CGFloat = 0.0) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            var gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(temperature), tint: Float(tint)))
            // Clamp gains to valid range
            gains.redGain = max(1.0, min(gains.redGain, device.maxWhiteBalanceGain))
            gains.greenGain = max(1.0, min(gains.greenGain, device.maxWhiteBalanceGain))
            gains.blueGain = max(1.0, min(gains.blueGain, device.maxWhiteBalanceGain))
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
            whiteBalanceTemperature = temperature
            whiteBalanceTint = tint
            wbPreset = .auto // Custom setting
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set white balance temperature: \(error.localizedDescription)"
        }
    }

    func setContrast(_ newContrast: CGFloat) {
        contrast = max(0.5, min(2.0, newContrast))
    }

    func setBrightness(_ newBrightness: CGFloat) {
        brightness = max(-0.5, min(0.5, newBrightness))
    }

    func setSaturation(_ newSaturation: CGFloat) {
        saturation = max(0.0, min(2.0, newSaturation))
    }

    func setNightMode(_ mode: NightMode) {
        guard let device = device else { return }

        nightMode = mode

        do {
            try device.lockForConfiguration()

            switch mode {
            case .off:
                // Only set low light boost if supported
                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = false
                }
                device.torchMode = .off
            case .auto:
                // Only set low light boost if supported
                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
            case .on:
                // Only set low light boost if supported
                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
                if device.hasTorch {
                    device.torchMode = .on
                }
            }

            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set night mode: \(error.localizedDescription)"
        }
    }

    func setSharpness(_ newSharpness: CGFloat) {
        sharpness = max(0.0, min(2.0, newSharpness))
    }

    func setFrameRate(_ newFrameRate: Double) {
        guard let device = device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Find the best format that supports the requested frame rate
            let desiredRate = min(max(1.0, newFrameRate), maxFrameRate)
            
            for range in device.activeFormat.videoSupportedFrameRateRanges {
                if desiredRate >= range.minFrameRate && desiredRate <= range.maxFrameRate {
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(desiredRate))
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(desiredRate))
                    frameRate = desiredRate
                    break
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set frame rate: \(error.localizedDescription)"
        }
    }

    func setBracketingMode(_ mode: BracketingMode) {
        bracketingMode = mode
        // Note: Actual bracketing implementation would require multiple photo captures
        // This sets the mode for UI/state tracking purposes
    }

    func setHDRMode(_ enabled: Bool) {
        guard let device = device else { return }
        
        hdrMode = enabled
        
        do {
            try device.lockForConfiguration()
            
            // Check if current format supports HDR
            if device.activeFormat.isVideoHDRSupported {
                // HDR is typically controlled via photo output settings during capture
                // Store the preference for use during photo capture
                print("HDR mode set to: \(enabled)")
            } else {
                print("HDR not supported by current camera format")
            }
            
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to configure HDR mode: \(error.localizedDescription)"
        }
    }

    func setRAWCapture(_ enabled: Bool) {
        guard let output = output else { return }
        
        rawCapture = enabled
        
        // Check if RAW is supported by the current camera format
        let rawFormats = output.availableRawPhotoPixelFormatTypes
        if !rawFormats.isEmpty && enabled {
            print("RAW capture enabled")
        } else if enabled {
            print("RAW capture not supported by current camera")
            rawCapture = false
        } else {
            print("RAW capture disabled")
        }
    }

    func setNightModeIntensity(_ intensity: Float) {
        nightModeIntensity = max(0.0, min(1.0, intensity))
        // Note: This controls the intensity of night mode effects
        // Actual implementation would depend on specific night mode algorithms
    }

    func setStabilizationMode(_ mode: StabilizationMode) {
        guard let device = device else { return }
        
        stabilizationMode = mode
        
        do {
            try device.lockForConfiguration()
            
            // Configure optical image stabilization if available
            if device.activeFormat.isVideoStabilizationModeSupported(.auto) {
                switch mode {
                case .off:
                    if let connection = output?.connection(with: .video) {
                        connection.preferredVideoStabilizationMode = .off
                    }
                case .on:
                    if let connection = output?.connection(with: .video) {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                case .cinematic:
                    if let connection = output?.connection(with: .video) {
                        connection.preferredVideoStabilizationMode = .cinematic
                    }
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            self.error = "Failed to set stabilization mode: \(error.localizedDescription)"
        }
    }

    func setBurstMode(_ mode: BurstMode) {
        burstMode = mode
        // Note: Burst mode implementation would require rapid sequential captures
        // This sets the mode for UI/state tracking purposes
    }

    func setZoomMode(_ mode: ZoomMode) {
        zoomMode = mode
        // Note: This controls zoom behavior preference
        // Actual zoom limits would be enforced in setZoom method
    }

    func setAudioRecording(_ enabled: Bool) {
        audioRecording = enabled
        // Note: This is for future video recording features
    }

    func setGPSTagging(_ enabled: Bool) {
        gpsTagging = enabled
        // Note: GPS tagging is handled in photo metadata extraction
    }

    func setFilter(_ filter: CameraFilter) {
        print("📷 CameraService.setFilter called: \(filter.rawValue)")
        let startTime = CFAbsoluteTimeGetCurrent()

        currentFilter = filter
        currentPreset = nil  // Clear preset when using legacy filter
        filterProcessor?.currentFilter = filter
        filterProcessor?.setCurrentPreset(nil)

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        print("📷 CameraService.setFilter completed in \(duration * 1000)ms")
    }

    func setPreset(_ preset: FilterPreset?) {
        print("📷 CameraService.setPreset called: \(preset?.name ?? "none")")
        let startTime = CFAbsoluteTimeGetCurrent()

        currentPreset = preset
        currentFilter = .none  // Clear legacy filter when using preset
        filterProcessor?.setCurrentPreset(preset)

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        print("📷 CameraService.setPreset completed in \(duration * 1000)ms")
    }

    // MARK: - Utility Methods

    func resetToAuto() {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            device.exposureMode = .continuousAutoExposure
            device.focusMode = .continuousAutoFocus
            device.whiteBalanceMode = .continuousAutoWhiteBalance
            device.unlockForConfiguration()

            // Reset manual controls
            iso = CGFloat(device.iso)
            shutterSpeed = device.exposureDuration
            focusDistance = CGFloat(device.lensPosition)
            contrast = 1.0
            brightness = 0.0
            saturation = 1.0
            nightMode = .auto
            currentFilter = .none
            currentPreset = nil
            whiteBalanceTemperature = 5500.0
            whiteBalanceTint = 0.0

        } catch {
            self.error = "Failed to reset to auto: \(error.localizedDescription)"
        }
    }

    // MARK: - Advanced Features

    func getCurrentSettingsInfo() -> String {
        let isoStr = "ISO \(Int(iso))"
        let shutterStr = String(format: "%.3fs", shutterSpeed.seconds)
        let focusStr = String(format: "Focus %.2f", focusDistance)
        let wbStr = "\(Int(whiteBalanceTemperature))K"

        return "\(isoStr) | \(shutterStr) | \(focusStr) | \(wbStr) | \(currentFilter.rawValue)"
    }

    func createCustomFilterChain(_ filters: [CameraFilter]) -> CameraFilter {
        // This would create a custom filter by chaining multiple effects
        // For now, return the first non-none filter
        return filters.first(where: { $0 != .none }) ?? .none
    }

    func optimizeForLowLight() {
        setNightMode(.on)
        setISO(min(maxISO * 0.8, minISO)) // Boost ISO for low light
        setShutterSpeed(CMTime(seconds: 1.0/30.0, preferredTimescale: 1000000)) // Slower shutter
    }

    func optimizeForAction() {
        setNightMode(.off)
        setISO(minISO) // Lowest ISO for best quality
        setShutterSpeed(CMTime(seconds: 1.0/500.0, preferredTimescale: 1000000)) // Fast shutter for action
        setFocusDistance(0.5) // Mid-range focus
    }

    func optimizeForPortrait() {
        setNightMode(.auto)
        setISO(min(maxISO * 0.6, minISO)) // Moderate ISO
        setShutterSpeed(CMTime(seconds: 1.0/125.0, preferredTimescale: 1000000)) // Portrait shutter speed
        setFilter(.portrait)
        setContrast(1.2) // Slightly higher contrast for portraits
        setBrightness(0.1) // Slight brightness boost
    }

    func switchCamera() {
        guard let currentInput = input else { return }

        session.beginConfiguration()

        // Remove current input
        session.removeInput(currentInput)

        // Get new position
        let newPosition: AVCaptureDevice.Position = (device?.position == .back) ? .front : .back

        // Get new device
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            error = "Front camera not available"
            session.commitConfiguration()
            return
        }

        device = newDevice

        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                input = newInput
            }
        } catch {
            self.error = "Failed to switch camera: \(error.localizedDescription)"
        }

        session.commitConfiguration()
    }

    // MARK: - WebSocket Camera Settings Application
    
    /// Applies camera settings received from WebSocket with validation and clamping
    /// - Parameter settings: Camera settings from WebSocket response
    /// - Returns: Array of strings describing what settings were applied
    func applyCameraSettingsFromWebSocket(_ settings: CameraSettings) -> [String] {
        var appliedSettings: [String] = []
        
        print("🤖 Applying AI camera settings from WebSocket...")
        
        // Collect ALL property updates for a single main thread dispatch
        var allPropertyUpdates: [String: Any] = [:]
        
        // Single device lock for all hardware settings to minimize performance impact
        guard let device = device else {
            print("❌ Camera device not available")
            return appliedSettings
        }
        
        do {
            try device.lockForConfiguration()
            
            // Apply all hardware settings in one locked session (background thread safe)
            
            // 1. Exposure Controls (hardware)
            if let exposure = settings.exposure_controls {
                let (applied, updates) = applyExposureControlsLocked(exposure, device: device)
                appliedSettings.append(contentsOf: applied)
                allPropertyUpdates.merge(updates) { _, new in new }
            }
            
            // 2. White Balance Controls (hardware)
            if let whiteBalance = settings.white_balance_controls {
                let (applied, updates) = applyWhiteBalanceControlsLocked(whiteBalance, device: device)
                appliedSettings.append(contentsOf: applied)
                allPropertyUpdates.merge(updates) { _, new in new }
            }
            
            // 4. Advanced Modes (hardware)
            if let advanced = settings.advanced_modes {
                let (applied, updates) = applyAdvancedModesLocked(advanced, device: device)
                appliedSettings.append(contentsOf: applied)
                allPropertyUpdates.merge(updates) { _, new in new }
            }
            
            device.unlockForConfiguration()
            
        } catch {
            print("❌ Failed to lock device for camera settings: \(error.localizedDescription)")
            return appliedSettings
        }
        
        // Apply non-hardware settings (no device lock needed, collect property updates)
        
        // 3. Image Processing Settings
        if let processing = settings.image_processing {
            // Apply filter (if needed)
            if let filterString = processing.current_filter {
                if let filter = CameraFilter(rawValue: filterString.capitalized) {
                    allPropertyUpdates["currentFilter"] = filter
                    appliedSettings.append("Filter: \(filter.rawValue)")
                }
            }
            
            // NOTE: 
            // - Brightness: Already handled via EV bias in exposure controls (real-time hardware)
            //   Formula: brightness_change = 2^(-EV_bias)
            // - Contrast, Saturation & Sharpness: Post-processing only (apply after photo capture)
            
            // Store post-processing settings for after photo click
            if let contrast = processing.contrast {
                allPropertyUpdates["pendingContrast"] = max(0.5, min(2.0, contrast))
                appliedSettings.append("Contrast: queued for post-processing")
            }
            
            if let saturation = processing.saturation {
                allPropertyUpdates["pendingSaturation"] = max(0.0, min(2.0, saturation))
                appliedSettings.append("Saturation: queued for post-processing")
            }
            
            if let sharpness = processing.sharpness {
                allPropertyUpdates["pendingSharpness"] = max(0.0, min(2.0, sharpness))
                appliedSettings.append("Sharpness: queued for post-processing")
            }
        }
        
        // 5. Professional Features (mostly software flags - @Published properties)
        if let professional = settings.professional_features {
            let (applied, updates) = applyProfessionalFeaturesSafe(professional)
            appliedSettings.append(contentsOf: applied)
            allPropertyUpdates.merge(updates) { _, new in new }
        }
        
        // Single main thread dispatch for ALL property updates to prevent UI thrashing
        DispatchQueue.main.async {
            self.updatePublishedProperties(allPropertyUpdates)
        }
        
        print("🤖 Applied \(appliedSettings.count) camera settings efficiently")
        return appliedSettings
    }
    
    private func applyExposureControlsLocked(_ exposure: ExposureControls, device: AVCaptureDevice) -> ([String], [String: Any]) {
        var applied: [String] = []
        var propertyUpdates: [String: Any] = [:]
        
        // Exposure Mode
        if let modeString = exposure.exposure_mode {
            if let mode = ExposureMode(rawValue: modeString.capitalized) {
                propertyUpdates["exposureMode"] = mode
                applied.append("Exposure mode: \(mode.rawValue)")
            }
        }
        
        // ISO and Shutter Speed together (device already locked)
        var newISO: CGFloat?
        var newShutterSpeed: CMTime?
        
        if let isoValue = exposure.iso {
            newISO = max(minISO, min(maxISO, CGFloat(isoValue)))
        }
        
        if let shutterValue = exposure.shutter_speed {
            // Clamp to reasonable handheld photography range (1/8000s to 1/4s)
            // Anything slower than 1/4s (0.25s) causes noticeable lag and camera shake
            let clampedShutter = max(0.000125, min(0.25, shutterValue)) // 1/8000s to 1/4s
            let shutterTime = CMTime(seconds: clampedShutter, preferredTimescale: 1000000)
            newShutterSpeed = CMTimeClampToRange(shutterTime, range: CMTimeRange(start: minShutterSpeed, duration: CMTimeSubtract(maxShutterSpeed, minShutterSpeed)))
            
            if clampedShutter != shutterValue {
                print("⚠️ Shutter speed clamped from \(shutterValue)s to \(clampedShutter)s for handheld photography")
            }
        }
        
        // Apply ISO and shutter speed together if both are provided
        if let iso = newISO, let shutter = newShutterSpeed {
            device.setExposureModeCustom(duration: shutter, iso: Float(iso), completionHandler: nil)
            propertyUpdates["iso"] = iso
            propertyUpdates["shutterSpeed"] = shutter
            applied.append("ISO: \(Int(iso))")
            let shutterDisplay = shutter.seconds >= 0.1 ? String(format: "%.3fs", shutter.seconds) : String(format: "1/%.0fs", 1.0/shutter.seconds)
            applied.append("Shutter: \(shutterDisplay)")
        } else if let iso = newISO {
            device.setExposureModeCustom(duration: shutterSpeed, iso: Float(iso), completionHandler: nil)
            propertyUpdates["iso"] = iso
            applied.append("ISO: \(Int(iso))")
        } else if let shutter = newShutterSpeed {
            device.setExposureModeCustom(duration: shutter, iso: Float(iso), completionHandler: nil)
            propertyUpdates["shutterSpeed"] = shutter
            let shutterDisplay = shutter.seconds >= 0.1 ? String(format: "%.3fs", shutter.seconds) : String(format: "1/%.0fs", 1.0/shutter.seconds)
            applied.append("Shutter: \(shutterDisplay)")
        }
        
        // EV Bias
        if let newEVBias = exposure.ev_bias {
            let clampedEV = max(CGFloat(device.minExposureTargetBias), min(CGFloat(device.maxExposureTargetBias), CGFloat(newEVBias)))
            device.setExposureTargetBias(Float(clampedEV), completionHandler: nil)
            propertyUpdates["evBias"] = clampedEV
            applied.append("EV: \(String(format: "%.1f", clampedEV))")
        }
        
        // Skip unsupported iOS settings with friendly messages
        if let _ = exposure.aperture {
            applied.append("Aperture: fixed by lens (unsupported)")
        }
        if let _ = exposure.focal_length {
            applied.append("Focal length: fixed by lens (unsupported)")
        }
        if let _ = exposure.frame_rate {
            applied.append("Frame rate: photo mode only (skipped)")
        }
        
        // Bracketing Mode (software setting)
        if let bracketingString = exposure.bracketing_mode {
            if let mode = BracketingMode(rawValue: bracketingString.capitalized) {
                propertyUpdates["bracketingMode"] = mode
                applied.append("Bracketing: \(mode.rawValue)")
            }
        }
        
        return (applied, propertyUpdates)
    }
    
    private func applyWhiteBalanceControlsLocked(_ whiteBalance: WhiteBalanceControls, device: AVCaptureDevice) -> ([String], [String: Any]) {
        var applied: [String] = []
        var propertyUpdates: [String: Any] = [:]
        
        // WB Preset or Custom Temperature (device already locked)
        if let presetString = whiteBalance.wb_preset {
            if let preset = WBPreset(rawValue: presetString.capitalized) {
                propertyUpdates["wbPreset"] = preset
                
                switch preset {
                case .auto:
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                    propertyUpdates["whiteBalanceTemperature"] = CGFloat(5500.0)
                    propertyUpdates["whiteBalanceTint"] = CGFloat(0.0)
                case .sunny:
                    let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 5500, tint: 0))
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                    propertyUpdates["whiteBalanceTemperature"] = CGFloat(5500.0)
                    propertyUpdates["whiteBalanceTint"] = CGFloat(0.0)
                case .cloudy:
                    let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 6500, tint: 0))
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                    propertyUpdates["whiteBalanceTemperature"] = CGFloat(6500.0)
                    propertyUpdates["whiteBalanceTint"] = CGFloat(0.0)
                case .shade:
                    let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 7500, tint: 0))
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                    propertyUpdates["whiteBalanceTemperature"] = CGFloat(7500.0)
                    propertyUpdates["whiteBalanceTint"] = CGFloat(0.0)
                case .tungsten:
                    let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 2850, tint: 0))
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                    propertyUpdates["whiteBalanceTemperature"] = CGFloat(2850.0)
                    propertyUpdates["whiteBalanceTint"] = CGFloat(0.0)
                case .fluorescent:
                    let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 3800, tint: 0))
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                    propertyUpdates["whiteBalanceTemperature"] = CGFloat(3800.0)
                    propertyUpdates["whiteBalanceTint"] = CGFloat(0.0)
                }
                applied.append("WB: \(preset.rawValue)")
            }
        }
        // Custom WB Temperature and Tint
        else if let temperature = whiteBalance.white_balance_temperature,
                let tint = whiteBalance.white_balance_tint {
            let clampedTemp = max(2000.0, min(10000.0, temperature))
            let clampedTint = max(-100.0, min(100.0, tint))
            
            var gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(clampedTemp), tint: Float(clampedTint)))
            // Clamp gains to valid range
            gains.redGain = max(1.0, min(gains.redGain, device.maxWhiteBalanceGain))
            gains.greenGain = max(1.0, min(gains.greenGain, device.maxWhiteBalanceGain))
            gains.blueGain = max(1.0, min(gains.blueGain, device.maxWhiteBalanceGain))
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
            
            propertyUpdates["whiteBalanceTemperature"] = CGFloat(clampedTemp)
            propertyUpdates["whiteBalanceTint"] = CGFloat(clampedTint)
            propertyUpdates["wbPreset"] = WBPreset.auto // Custom setting
            applied.append("WB: \(Int(clampedTemp))K, tint: \(String(format: "%.1f", clampedTint))")
        }
        
        return (applied, propertyUpdates)
    }
    
    private func applyImageProcessing(_ processing: ImageProcessing) -> [String] {
        var applied: [String] = []
        
        // Contrast
        if let newContrast = processing.contrast {
            let clampedContrast = max(0.5, min(2.0, newContrast))
            setContrast(CGFloat(clampedContrast))
            applied.append("Contrast: \(String(format: "%.1f", clampedContrast))")
        }
        
        // Brightness
        if let newBrightness = processing.brightness {
            let clampedBrightness = max(-0.5, min(0.5, newBrightness))
            setBrightness(CGFloat(clampedBrightness))
            applied.append("Brightness: \(String(format: "%.1f", clampedBrightness))")
        }
        
        // Saturation
        if let newSaturation = processing.saturation {
            let clampedSaturation = max(0.0, min(2.0, newSaturation))
            setSaturation(CGFloat(clampedSaturation))
            applied.append("Saturation: \(String(format: "%.1f", clampedSaturation))")
        }
        
        // Sharpness
        if let newSharpness = processing.sharpness {
            let clampedSharpness = max(0.0, min(2.0, newSharpness))
            setSharpness(CGFloat(clampedSharpness))
            applied.append("Sharpness: \(String(format: "%.1f", clampedSharpness))")
        }
        
        // Filter
        if let filterString = processing.current_filter {
            if let filter = CameraFilter(rawValue: filterString.capitalized) {
                setFilter(filter)
                applied.append("Filter: \(filter.rawValue)")
            }
        }
        
        return applied
    }
    
    private func applyAdvancedModesLocked(_ advanced: AdvancedModes, device: AVCaptureDevice) -> ([String], [String: Any]) {
        var applied: [String] = []
        var propertyUpdates: [String: Any] = [:]
        
        // Night Mode (device already locked)
        if let nightModeString = advanced.night_mode {
            if let mode = NightMode(rawValue: nightModeString.lowercased()) {
                propertyUpdates["nightMode"] = mode
                
                switch mode {
                case .off:
                    if device.isLowLightBoostSupported {
                        device.automaticallyEnablesLowLightBoostWhenAvailable = false
                    }
                    device.torchMode = .off
                case .auto:
                    if device.isLowLightBoostSupported {
                        device.automaticallyEnablesLowLightBoostWhenAvailable = true
                    }
                case .on:
                    if device.isLowLightBoostSupported {
                        device.automaticallyEnablesLowLightBoostWhenAvailable = true
                    }
                    if device.hasTorch {
                        device.torchMode = .on
                    }
                }
                applied.append("Night mode: \(mode.rawValue)")
            }
        }
        
        // Night Mode Intensity (software setting)
        if let intensity = advanced.night_mode_intensity {
            let clampedIntensity = max(0.0, min(1.0, intensity))
            propertyUpdates["nightModeIntensity"] = Float(clampedIntensity)
            applied.append("Night intensity: \(String(format: "%.1f", clampedIntensity))")
        }
        
        // Skip stabilization mode to prevent FPS issues
        // Stabilization Mode - COMMENTED OUT to prevent FPS drops
        // if let stabilizationString = advanced.stabilization_mode {
        //     applied.append("Stabilization: skipped (performance)")
        // }
        
        // Burst Mode (software setting)
        if let burstString = advanced.burst_mode {
            if let mode = BurstMode(rawValue: burstString.capitalized) {
                propertyUpdates["burstMode"] = mode
                applied.append("Burst: \(mode.rawValue)")
            }
        }
        
        // Zoom Mode (software setting)
        if let zoomString = advanced.zoom_mode {
            if let mode = ZoomMode(rawValue: zoomString.capitalized) {
                propertyUpdates["zoomMode"] = mode
                applied.append("Zoom: \(mode.rawValue)")
            }
        }
        
        // HDR Mode (device setting)
        if let hdrEnabled = advanced.hdr_mode {
            propertyUpdates["hdrMode"] = hdrEnabled
            if device.activeFormat.isVideoHDRSupported {
                applied.append("HDR: \(hdrEnabled ? "On" : "Off")")
            } else {
                applied.append("HDR: not supported")
            }
        }
        
        // RAW Capture (output setting - not device hardware)
        if let rawEnabled = advanced.raw_capture {
            propertyUpdates["rawCapture"] = rawEnabled
            applied.append("RAW: \(rawEnabled ? "On" : "Off")")
        }
        
        return (applied, propertyUpdates)
    }
    
    private func applyImageProcessingSafe(_ processing: ImageProcessing) -> ([String], [String: Any]) {
        var applied: [String] = []
        var propertyUpdates: [String: Any] = [:]
        
        // Contrast
        if let newContrast = processing.contrast {
            let clampedContrast = max(0.5, min(2.0, newContrast))
            propertyUpdates["contrast"] = CGFloat(clampedContrast)
            applied.append("Contrast: \(String(format: "%.1f", clampedContrast))")
        }
        
        // Brightness
        if let newBrightness = processing.brightness {
            let clampedBrightness = max(-0.5, min(0.5, newBrightness))
            propertyUpdates["brightness"] = CGFloat(clampedBrightness)
            applied.append("Brightness: \(String(format: "%.1f", clampedBrightness))")
        }
        
        // Saturation
        if let newSaturation = processing.saturation {
            let clampedSaturation = max(0.0, min(2.0, newSaturation))
            propertyUpdates["saturation"] = CGFloat(clampedSaturation)
            applied.append("Saturation: \(String(format: "%.1f", clampedSaturation))")
        }
        
        // Sharpness
        if let newSharpness = processing.sharpness {
            let clampedSharpness = max(0.0, min(2.0, newSharpness))
            propertyUpdates["sharpness"] = CGFloat(clampedSharpness)
            applied.append("Sharpness: \(String(format: "%.1f", clampedSharpness))")
        }
        
        // Filter
        if let filterString = processing.current_filter {
            if let filter = CameraFilter(rawValue: filterString.capitalized) {
                propertyUpdates["currentFilter"] = filter
                applied.append("Filter: \(filter.rawValue)")
            }
        }
        
        return (applied, propertyUpdates)
    }
    
    private func applyProfessionalFeaturesSafe(_ professional: ProfessionalFeatures) -> ([String], [String: Any]) {
        var applied: [String] = []
        var propertyUpdates: [String: Any] = [:]
        
        // Visual aid overlays (lightweight)
        if let focusPeaking = professional.focus_peaking {
            propertyUpdates["showFocusPeaking"] = focusPeaking
            applied.append("Focus peaking: \(focusPeaking ? "On" : "Off")")
        }
        
        if let zebraStripes = professional.zebra_stripes {
            propertyUpdates["showZebraStripes"] = zebraStripes
            applied.append("Zebra stripes: \(zebraStripes ? "On" : "Off")")
        }
        
        if let levelIndicator = professional.level_indicator {
            propertyUpdates["showLevelIndicator"] = levelIndicator
            applied.append("Level indicator: \(levelIndicator ? "On" : "Off")")
        }
        
        if let histogram = professional.histogram {
            propertyUpdates["showHistogram"] = histogram
            applied.append("Histogram: \(histogram ? "On" : "Off")")
        }
        
        // Hardware-related features
        if let audioEnabled = professional.audio_recording {
            propertyUpdates["audioRecording"] = audioEnabled
            applied.append("Audio: \(audioEnabled ? "On" : "Off")")
        }
        
        if let gpsEnabled = professional.gps_tagging {
            propertyUpdates["gpsTagging"] = gpsEnabled
            applied.append("GPS: \(gpsEnabled ? "On" : "Off")")
        }
        
        return (applied, propertyUpdates)
    }
    
    private func updatePublishedProperties(_ updates: [String: Any]) {
        // This method must be called on main thread
        for (key, value) in updates {
            switch key {
            case "exposureMode": exposureMode = value as! ExposureMode
            case "iso": iso = value as! CGFloat
            case "shutterSpeed": shutterSpeed = value as! CMTime
            case "evBias": evBias = value as! CGFloat
            case "bracketingMode": bracketingMode = value as! BracketingMode
            case "wbPreset": wbPreset = value as! WBPreset
            case "whiteBalanceTemperature": whiteBalanceTemperature = value as! CGFloat
            case "whiteBalanceTint": whiteBalanceTint = value as! CGFloat
            case "nightMode": nightMode = value as! NightMode
            case "nightModeIntensity": nightModeIntensity = value as! Float
            case "burstMode": burstMode = value as! BurstMode
            case "zoomMode": zoomMode = value as! ZoomMode
            case "hdrMode": hdrMode = value as! Bool
            case "rawCapture": rawCapture = value as! Bool
            case "contrast": contrast = value as! CGFloat
            case "brightness": brightness = value as! CGFloat
            case "saturation": saturation = value as! CGFloat
            case "sharpness": sharpness = value as! CGFloat
            case "currentFilter": 
                let newFilter = value as! CameraFilter
                // Only call setFilter if the filter is actually changing to prevent unnecessary UI updates
                if currentFilter != newFilter {
                    setFilter(newFilter)
                } else {
                    // Update the property directly to avoid UI thrashing when filter is unchanged
                    currentFilter = newFilter
                }
            case "audioRecording": audioRecording = value as! Bool
            case "gpsTagging": gpsTagging = value as! Bool
            case "pendingSaturation": pendingSaturation = value as? CGFloat
            case "pendingSharpness": pendingSharpness = value as? CGFloat
            case "pendingContrast": pendingContrast = value as? CGFloat
            case "showFocusPeaking": showFocusPeaking = value as! Bool
            case "showZebraStripes": showZebraStripes = value as! Bool
            case "showLevelIndicator": showLevelIndicator = value as! Bool
            case "showHistogram": showHistogram = value as! Bool
            default: break
            }
        }
    }
    
    private func applyProfessionalFeatures(_ professional: ProfessionalFeatures) -> [String] {
        var applied: [String] = []
        
        // Only apply hardware-related professional features
        
        // Audio Recording
        if let audioEnabled = professional.audio_recording {
            setAudioRecording(audioEnabled)
            applied.append("Audio: \(audioEnabled ? "On" : "Off")")
        }
        
        // GPS Tagging
        if let gpsEnabled = professional.gps_tagging {
            setGPSTagging(gpsEnabled)
            applied.append("GPS: \(gpsEnabled ? "On" : "Off")")
        }
        
        // Note: Visual overlay features (focus_peaking, zebra_stripes, level_indicator, histogram)
        // are not implemented as they would require UI changes
        
        return applied
    }

    // MARK: - Photo Capture

    func capturePhoto(completion: ((UIImage?) -> Void)? = nil) {
        guard output != nil else {
            error = "Photo output not available"
            completion?(nil)
            return
        }

        // Store the completion handler for later use
        photoCompletionHandler = completion
        isCapturing = true

        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        // Configure photo settings
        if let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first {
            settings.previewPhotoFormat = [
                kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                kCVPixelBufferWidthKey as String: 1080,
                kCVPixelBufferHeightKey as String: 1920
            ]
        }
        
        // Enable high quality capture
        settings.isHighResolutionPhotoEnabled = true
        settings.photoQualityPrioritization = .quality

        if captureTimer.seconds > 0 {
            // Start timer
            var remainingSeconds = captureTimer.seconds
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                remainingSeconds -= 1
                if remainingSeconds <= 0 {
                    timer.invalidate()
                    self?.performCapture(settings: settings)
                }
            }
        } else {
            performCapture(settings: settings)
        }
    }

    private func performCapture(settings: AVCapturePhotoSettings) {
        guard let output = output else { return }

        output.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Photo Saving

    private func processAndDeliverImage(_ image: UIImage) {
        print("📸 Processing captured image - Size: \(image.size)")

        // Apply filters to captured photo
        let processedImage: UIImage
        if let preset = currentPreset, let processor = filterProcessor {
            processedImage = processor.applyPreset(to: image, preset: preset)
        } else {
            processedImage = filterProcessor?.applyFilter(to: image, filter: currentFilter) ?? image
        }
        lastPhoto = processedImage

        print("📸 Processed image - Size: \(processedImage.size)")

        // Call the completion handler if provided
        photoCompletionHandler?(processedImage)
        print("📸 Called completion handler with image")

        // Clear the completion handler after use
        photoCompletionHandler = nil

        // Upload to database and cache (async, non-blocking)
        Task {
            await uploadPhotoToDatabaseAndCache(processedImage)
        }

        if autoSaveToLibrary {
            if let processedData = processedImage.jpegData(compressionQuality: 0.95) {
                saveToLibrary(processedData) { success, error in
                    if let error = error {
                        self.error = "Failed to save photo: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func uploadPhotoToDatabaseAndCache(_ image: UIImage) async {
        let photoId = UUID().uuidString

        // Cache the image locally first
        print("📸 Caching original photo with ID: \(photoId)")
        ImageCacheService.shared.cacheImage(image, id: photoId, type: .original)

        // Verify the image was cached
        if ImageCacheService.shared.getCachedImage(id: photoId) != nil {
            print("✅ Original photo successfully cached: \(photoId)")
        } else {
            print("❌ Failed to cache original photo: \(photoId)")
        }

        // Extract comprehensive metadata from the captured image
        let extractedMetadata = await extractPhotoMetadata(from: image)

        // Try to upload to database
        do {
            let metadata = PhotoMetadata(
                camera: extractedMetadata.cameraSettings,
                location: extractedMetadata.location,
                exif: EXIFMetadata(
                    make: extractedMetadata.exifData.cameraModel?.components(separatedBy: " ").first,
                    model: extractedMetadata.exifData.cameraModel != nil ? extractedMetadata.exifData.cameraModel!.components(separatedBy: " ").dropFirst().joined(separator: " ") : nil,
                    software: getAppVersion(),
                    imageDescription: nil as String?,
                    dateTime: extractedMetadata.captureTime,
                    orientation: 1, // Portrait
                    xResolution: nil as Double?,
                    yResolution: nil as Double?,
                    resolutionUnit: nil as Int?,
                    exposureTime: extractedMetadata.exifData.shutterSpeed,
                    fNumber: extractedMetadata.exifData.aperture,
                    exposureProgram: nil as Int?,
                    isoSpeedRatings: extractedMetadata.exifData.iso != nil ? [Int(extractedMetadata.exifData.iso!)] : nil,
                    exifVersion: nil as String?,
                    dateTimeOriginal: extractedMetadata.captureTime,
                    dateTimeDigitized: extractedMetadata.captureTime,
                    componentConfiguration: nil as String?,
                    shutterSpeedValue: extractedMetadata.exifData.shutterSpeed,
                    apertureValue: extractedMetadata.exifData.aperture,
                    brightnessValue: nil as Double?,
                    exposureBiasValue: nil as Double?,
                    meteringMode: nil as Int?,
                    flash: nil as Int?,
                    focalLength: extractedMetadata.exifData.focalLength,
                    subjectArea: nil as [Int]?,
                    makerNote: nil as Data?,
                    subsecTimeOriginal: nil as String?,
                    subsecTimeDigitized: nil as String?,
                    flashPixVersion: nil as String?,
                    colorSpace: nil as Int?,
                    pixelXDimension: extractedMetadata.width,
                    pixelYDimension: extractedMetadata.height,
                    sensingMethod: nil as Int?,
                    sceneType: nil as Data?,
                    exposureMode: nil as Int?,
                    whiteBalance: nil as Int?,
                    focalLengthIn35mmFilm: nil as Int?,
                    sceneCaptureType: nil as Int?,
                    lensSpecification: nil as [Double]?,
                    lensMake: extractedMetadata.exifData.lens?.components(separatedBy: " ").first,
                    lensModel: extractedMetadata.exifData.lens != nil ? extractedMetadata.exifData.lens!.components(separatedBy: " ").dropFirst().joined(separator: " ") : nil,
                    lensSerialNumber: nil as String?
                ),
                timestamp: extractedMetadata.captureTime,
                deviceModel: extractedMetadata.deviceInfo.model ?? "Unknown",
                osVersion: extractedMetadata.deviceInfo.systemVersion ?? "Unknown"
            )

            // Get user ID for photo upload
            guard let userId = UserDefaults.standard.string(forKey: "database_user_id") else {
                print("❌ Cannot upload photo: User not authenticated")
                return
            }

            guard let webSocketService = webSocketService else {
                print("❌ Cannot upload photo: WebSocketService not available")
                return
            }

            _ = try await webSocketService.uploadPhotoToBackend(
                image: image,
                userId: userId,
                isGenerated: false,
                metadata: metadata
            )

            print("✅ Photo uploaded to backend and cached successfully")
        } catch {
            print("❌ Failed to upload photo to backend: \(error.localizedDescription)")
            print("ℹ️ Photo is cached locally and will be uploaded when connection is restored")
        }
    }

    func saveToLibrary(_ data: Data, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, NSError(domain: "PhotoLibrary", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                return
            }

            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false
        timer?.invalidate()

        if let error = error {
            self.error = "Photo capture failed: \(error.localizedDescription)"
            photoCompletionHandler?(nil)
            photoCompletionHandler = nil
            return
        }

        // Try to get the captured image data
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData) {
            // Debug: print original orientation
            print("📸 Original image orientation: \(image.imageOrientation.rawValue)")
            print("📸 Image size: \(image.size)")
            print("📸 Camera position: \(device?.position.rawValue ?? -1)")
            print("📸 Using fileDataRepresentation path")
            print("📸 Photo metadata keys: \(photo.metadata.keys.sorted())")

            processAndDeliverImage(image)
            return
        }
        
        // If file data failed, try the preview pixel buffer
        if let previewPixelBuffer = photo.previewPixelBuffer {
            let ciImage = CIImage(cvPixelBuffer: previewPixelBuffer)
            if let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) {
                // Create UIImage from preview buffer - let iOS determine orientation
                let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
                print("📸 Using preview pixel buffer path")
                print("📸 Preview buffer image orientation: \(image.imageOrientation.rawValue)")
                print("📸 Preview buffer image size: \(image.size)")
                processAndDeliverImage(image)
                return
            }
        }
        
        // Both methods failed
        self.error = "Failed to process photo data"
        photoCompletionHandler?(nil)
        photoCompletionHandler = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // This is called for each video frame, but we're not processing live preview filters yet
        // The live filter processing would go here if we want real-time preview filters
    }
}

// MARK: - MAXIMUM PHOTO METADATA EXTRACTION (EVERYTHING POSSIBLE)
extension CameraService {
    private func extractPhotoMetadata(from image: UIImage) async -> ExtractedPhotoMetadata {
        let startTime = Date()

        let currentSettings = getCurrentCameraSettings()
        let exifMetadata = extractEXIFMetadata(from: image)
        let gpsMetadata = extractGPSMetadata(from: image)
        let imageProperties = extractImageProperties(from: image)
        let systemInfo = await extractSystemInformation()
        let cameraHardware = extractCameraHardwareInfo()
        let performanceMetrics = extractPerformanceMetrics()
        let environmentalData = extractEnvironmentalData()
        let processingInfo = extractProcessingInfo(from: image, startTime: startTime)

        return ExtractedPhotoMetadata(
            // BASIC IMAGE PROPERTIES
            width: Int(image.size.width),
            height: Int(image.size.height),
            format: determineImageFormat(from: image),
            fileSize: imageProperties.fileSize,
            bitDepth: imageProperties.bitDepth,
            dpi: imageProperties.dpi,
            colorSpace: extractColorSpace(from: image),
            hasAlpha: imageProperties.hasAlpha,
            compressionQuality: imageProperties.compressionQuality,

            // TIMING INFORMATION
            captureTime: Date(),
            timezone: TimeZone.current.identifier,
            processingTime: processingInfo.processingTime,
            systemUptime: systemInfo.uptime,

            // DEVICE INFORMATION (MAXIMUM DETAIL)
            deviceInfo: getDeviceInfo(),
            deviceModel: systemInfo.deviceModel,
            deviceName: systemInfo.deviceName,
            systemName: systemInfo.systemName,
            systemVersion: systemInfo.systemVersion,
            buildNumber: systemInfo.buildNumber,
            deviceOrientation: UIDevice.current.orientation.rawValue,
            screenBrightness: UIScreen.main.brightness,
            screenScale: UIScreen.main.scale,
            screenSize: extractScreenSize(),

            // HARDWARE CAPABILITIES (MAXIMUM DETAIL)
            cpuInfo: systemInfo.cpuInfo,
            memoryInfo: systemInfo.memoryInfo,
            storageInfo: systemInfo.storageInfo,
            batteryInfo: systemInfo.batteryInfo,
            thermalState: systemInfo.thermalState,
            networkInfo: systemInfo.networkInfo,

            // CAMERA SETTINGS (EVERYTHING POSSIBLE)
            cameraSettings: CameraSettingsMetadata(
                iso: exifMetadata.iso ?? currentSettings.iso,
                shutterSpeed: exifMetadata.shutterSpeed ?? currentSettings.shutterSpeed,
                aperture: exifMetadata.aperture ?? currentSettings.aperture,
                focalLength: exifMetadata.focalLength ?? currentSettings.focalLength,
                lens: exifMetadata.lens ?? currentSettings.lens,
                whiteBalance: currentSettings.whiteBalance,
                exposureCompensation: currentSettings.exposureCompensation,
                flashMode: currentSettings.flashMode,
                meteringMode: currentSettings.meteringMode,
                lensPosition: currentSettings.lensPosition,
                focusMode: currentSettings.focusMode,
                exposureMode: currentSettings.exposureMode,
                flash: currentSettings.flash,
                nightMode: currentSettings.nightMode,
                filter: currentSettings.filter,
                zoom: currentSettings.zoom,
                filterApplied: currentSettings.filterApplied
            ),

            // CAMERA HARDWARE (MAXIMUM DETAIL)
            cameraHardware: cameraHardware,

            // LOCATION DATA (MAXIMUM DETAIL)
            location: gpsMetadata,
            altitude: gpsMetadata?.altitude,
            gpsAccuracy: extractGPSAccuracy(from: image),
            locationServicesEnabled: CLLocationManager.locationServicesEnabled(),
            heading: extractDeviceHeading(),

            // ORIENTATION & MOTION
            orientation: image.imageOrientation.rawValue,
            deviceMotion: extractDeviceMotion(),
            accelerometerData: extractAccelerometerData(),

            // SOFTWARE & APP INFORMATION
            software: getAppVersion(),
            appVersion: systemInfo.appVersion,
            appBuild: systemInfo.appBuild,
            filterApplied: currentSettings.filterApplied ?? "none",
            processingPipeline: processingInfo.processingPipeline,

            // PERFORMANCE METRICS
            performanceMetrics: performanceMetrics,

            // ENVIRONMENTAL DATA
            environmentalData: environmentalData,

            // EXIF DATA (RAW FROM CAMERA)
            exifData: exifMetadata,

            // IMAGE ANALYSIS
            imageAnalysis: ImageAnalysis(dominantColors: nil, brightness: nil, contrast: nil, saturation: nil),

            // ACCESSIBILITY & PREFERENCES
            accessibilitySettings: extractAccessibilitySettings(),
            userPreferences: extractUserPreferences(),

            // DEBUG & DIAGNOSTIC INFORMATION
            debugInfo: extractDebugInfo(),

            // SECURITY & PRIVACY INFORMATION
            securityInfo: extractSecurityInfo(),

            // NETWORK & CONNECTIVITY
            connectivityInfo: extractConnectivityInfo(),

            // POWER MANAGEMENT
            powerManagement: extractPowerManagement(),

            // AUDIO INFORMATION (if recording)
            audioInfo: extractAudioInfo(),

            // ARKIT INFORMATION (if available)
            arInfo: extractARInfo(),

            // CUSTOM METADATA
            customMetadata: extractCustomMetadata()
        )
    }
}

// MARK: - MAXIMUM METADATA EXTRACTION FUNCTIONS
extension CameraService {
    private func extractImageProperties(from image: UIImage) -> ImageProperties {
        let fileSize = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        let bitDepth = image.cgImage?.bitsPerComponent ?? 8
        let dpi = extractImageDPI(from: image)
        let hasAlpha = image.cgImage?.alphaInfo != .none
        let compressionQuality: Float = 0.95 // Default high quality

        return ImageProperties(
            fileSize: fileSize,
            bitDepth: bitDepth,
            dpi: dpi,
            hasAlpha: hasAlpha,
            compressionQuality: compressionQuality
        )
    }

    private func extractImageDPI(from image: UIImage) -> Double? {
        if let imageData = image.jpegData(compressionQuality: 1.0),
           let source = CGImageSourceCreateWithData(imageData as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {

            if let dpiWidth = properties[kCGImagePropertyDPIWidth as String] as? Double {
                return dpiWidth
            }
            if let dpiHeight = properties[kCGImagePropertyDPIHeight as String] as? Double {
                return dpiHeight
            }
        }
        return 72.0 // Default DPI
    }

    private func extractScreenSize() -> String {
        let screen = UIScreen.main
        let bounds = screen.bounds
        return "\(Int(bounds.width))x\(Int(bounds.height))"
    }

    private func extractGPSAccuracy(from image: UIImage) -> Double? {
        if let imageData = image.jpegData(compressionQuality: 1.0),
           let source = CGImageSourceCreateWithData(imageData as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
           let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {

            return gpsDict[kCGImagePropertyGPSHPositioningError as String] as? Double
        }
        return nil
    }

    private func extractDeviceHeading() -> Double? {
        // This would require CLLocationManager with heading updates
        // For now, return nil
        return nil
    }

    private func extractDeviceMotion() -> DeviceMotionData? {
        // Extract device motion data using CoreMotion
        // This would require CMMotionManager
        return DeviceMotionData(
            accelerometer: nil as [String: Double]?,
            gyroscope: nil as [String: Double]?,
            magnetometer: nil as [String: Double]?,
            attitude: nil as [String: Double]?,
            gravity: nil as [String: Double]?,
            rotationRate: nil as [String: Double]?,
            userAcceleration: nil as [String: Double]?
        )
    }

    private func extractAccelerometerData() -> AccelerometerData? {
        // Extract raw accelerometer data
        return AccelerometerData(
            x: nil as Double?,
            y: nil as Double?,
            z: nil as Double?,
            timestamp: Date()
        )
    }

    private func extractSystemInformation() async -> SystemInformation {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo

        return SystemInformation(
            deviceModel: device.model,
            deviceName: device.name,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            uptime: processInfo.systemUptime,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            cpuInfo: extractCPUInfo(),
            memoryInfo: extractMemoryInfo(),
            storageInfo: extractStorageInfo(),
            batteryInfo: extractBatteryInfo(),
            thermalState: extractThermalState(),
            networkInfo: extractNetworkInfo()
        )
    }

    private func extractCPUInfo() -> CPUInfo {
        return CPUInfo(
            processorCount: ProcessInfo.processInfo.processorCount,
            activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
            physicalMemory: ProcessInfo.processInfo.physicalMemory
        )
    }

    private func extractMemoryInfo() -> MemoryInfo {
        return MemoryInfo(
            totalMemory: ProcessInfo.processInfo.physicalMemory,
            availableMemory: nil, // Would need more complex system calls
            usedMemory: nil,
            memoryPressure: nil
        )
    }

    private func extractStorageInfo() -> StorageInfo {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            return StorageInfo(
                totalSpace: attributes[.systemSize] as? Int64,
                availableSpace: attributes[.systemFreeSize] as? Int64,
                usedSpace: nil
            )
        } catch {
            return StorageInfo(totalSpace: nil as Int64?, availableSpace: nil as Int64?, usedSpace: nil as Int64?)
        }
    }

    private func extractBatteryInfo() -> BatteryInfo {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return BatteryInfo(
            level: UIDevice.current.batteryLevel,
            state: UIDevice.current.batteryState.rawValue,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    private func extractThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private func extractNetworkInfo() -> NetworkInfo {
        // This would require Network framework
        return NetworkInfo(
            connectionType: nil,
            isConnected: nil,
            wifiSSID: nil,
            cellularType: nil,
            carrierName: nil,
            signalStrength: nil
        )
    }

    private func extractCameraHardwareInfo() -> CameraHardwareInfo {
        guard let device = device else {
            return CameraHardwareInfo(
                cameraModel: nil,
                sensorSize: nil,
                pixelSize: nil,
                focalLength: nil,
                aperture: nil,
                hasFlash: false,
                hasTorch: false,
                supportsDepth: false,
                supportsHDR: false,
                supportsRAW: false,
                maxZoom: nil,
                minISO: nil,
                maxISO: nil,
                lensCount: nil,
                model: nil,
                maxZoomFactor: nil
            )
        }

        return CameraHardwareInfo(
            cameraModel: device.localizedName,
            sensorSize: nil, // Would need device-specific data
            pixelSize: nil,
            focalLength: nil as Float?, // Would need device-specific data
            aperture: nil as Float?, // Would need device-specific data
            hasFlash: device.hasFlash,
            hasTorch: device.hasTorch,
            supportsDepth: false, // Would need to check device capabilities
            supportsHDR: device.activeFormat.isVideoHDRSupported,
            supportsRAW: false, // Would need to check device capabilities for RAW support
            maxZoom: Float(device.activeFormat.videoMaxZoomFactor),
            minISO: Float(device.activeFormat.minISO),
            maxISO: Float(device.activeFormat.maxISO),
            lensCount: 1, // Most iOS devices have single lens
            model: device.localizedName,
            maxZoomFactor: Double(device.activeFormat.videoMaxZoomFactor)
        )
    }

    private func extractPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            captureTime: Date().timeIntervalSince1970,
            processingTime: nil,
            memoryUsage: nil,
            cpuUsage: nil,
            gpuUsage: nil,
            frameRate: nil,
            droppedFrames: nil
        )
    }

    private func extractEnvironmentalData() -> EnvironmentalData {
        return EnvironmentalData(
            temperature: nil, // Would need sensor access
            humidity: nil,
            pressure: nil,
            lightLevel: nil,
            ambientNoise: nil
        )
    }

    private func extractProcessingInfo(from image: UIImage, startTime: Date) -> ProcessingInfo {
        let processingTime = Date().timeIntervalSince(startTime)
        return ProcessingInfo(
            processingTime: processingTime,
            processingPipeline: ["capture", "filter", "compression", "metadata"]
        )
    }

    private func analyzeImageContent(from image: UIImage) -> ImageAnalysis {
        // This would use Vision framework for advanced analysis
        return ImageAnalysis(
            dominantColors: nil,
            brightness: nil,
            contrast: nil,
            saturation: nil
        )
    }

    private func extractAccessibilitySettings() -> AccessibilitySettings {
        return AccessibilitySettings(
            voiceOverEnabled: UIAccessibility.isVoiceOverRunning,
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled,
            increaseContrast: UIAccessibility.isDarkerSystemColorsEnabled,
            boldText: UIAccessibility.isBoldTextEnabled,
            largerText: nil as Bool?, // Would need to check preferred content size
            grayscale: UIAccessibility.isGrayscaleEnabled,
            invertColors: UIAccessibility.isInvertColorsEnabled
        )
    }

    private func extractUserPreferences() -> UserPreferences {
        return UserPreferences(
            language: Locale.current.languageCode,
            region: Locale.current.regionCode,
            calendar: String(describing: Calendar.current.identifier),
            measurementSystem: nil as String?, // Would need Locale measurement system
            temperatureUnit: nil as String?, // Would need temperature unit detection
            currencyCode: Locale.current.currencyCode,
            firstWeekday: Calendar.current.firstWeekday,
            timeZone: TimeZone.current.identifier
        )
    }

    private func extractDebugInfo() -> DebugInfo {
        return DebugInfo(
            sessionId: UUID().uuidString,
            buildConfiguration: getBuildConfiguration(),
            compilerFlags: nil as String?,
            optimizationLevel: nil as String?,
            debugSymbols: nil as Bool?,
            crashReports: nil as Bool?,
            memoryLeaks: nil as Bool?,
            threadCount: nil as Int?
        )
    }

    private func extractSecurityInfo() -> SecurityInfo {
        return SecurityInfo(
            isJailbroken: isDeviceJailbroken(),
            hasPasscode: nil as Bool?, // Cannot detect from app
            biometricType: getBiometricType(),
            securityLevel: nil as String?,
            encryptionEnabled: nil as Bool?,
            vpnActive: nil as Bool?
        )
    }

    private func extractConnectivityInfo() -> ConnectivityInfo {
        return ConnectivityInfo(
            wifiEnabled: nil,
            bluetoothEnabled: nil,
            cellularEnabled: nil,
            hotspotEnabled: nil,
            airplaneMode: nil
        )
    }

    private func extractPowerManagement() -> CameraPowerManagement {
        return CameraPowerManagement(
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            batteryOptimization: nil as Bool?,
            backgroundAppRefresh: nil as Bool?,
            autoLock: nil as Bool?,
            screenTimeout: nil as Int?
        )
    }

    private func extractAudioInfo() -> AudioInfo {
        return AudioInfo(
            hasMicrophone: nil as Bool?,
            audioInputAvailable: nil as Bool?,
            audioOutputAvailable: nil as Bool?,
            volumeLevel: nil as Float?,
            muteSwitch: nil as Bool?,
            audioFormat: nil as String?,
            sampleRate: nil as Double?,
            bitDepth: nil as Int?
        )
    }

    private func extractARInfo() -> ARInfo {
        return ARInfo(
            arkitSupported: ARConfiguration.isSupported,
            lidarAvailable: nil as Bool?,
            faceTracking: nil as Bool?,
            worldTracking: nil as Bool?,
            imageTracking: nil as Bool?,
            objectScanning: nil as Bool?,
            peopleOcclusion: nil as Bool?
        )
    }

    private func extractCustomMetadata() -> [String: Any] {
        return [
            "app_name": "Slay AI",
            "capture_method": "AVFoundation",
            "processing_engine": "CoreImage",
            "filter_library": "CIFilter",
            "metadata_version": "1.0",
            "extraction_timestamp": Date().timeIntervalSince1970,
            "platform": "iOS",
            "architecture": getDeviceArchitecture()
        ]
    }

    private func getBuildConfiguration() -> String {
        #if DEBUG
        return "debug"
        #elseif RELEASE
        return "release"
        #else
        return "unknown"
        #endif
    }

    private func isDeviceJailbroken() -> Bool {
        // Basic jailbreak detection
        let fileManager = FileManager.default
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]

        for path in jailbreakPaths {
            if fileManager.fileExists(atPath: path) {
                return true
            }
        }

        // Check for suspicious files
        if let url = URL(string: "cydia://package/com.example.package"),
           UIApplication.shared.canOpenURL(url) {
            return true
        }

        return false
    }

    private func getBiometricType() -> String {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: return "face_id"
            case .touchID: return "touch_id"
            case .none: return "none"
            @unknown default: return "unknown"
            }
        }

        return "none"
    }

    private func getDeviceArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - MAXIMUM METADATA STRUCTURES
struct ExtractedPhotoMetadata {
    // BASIC IMAGE PROPERTIES
    let width: Int
    let height: Int
    let format: String
    let fileSize: Int?
    let bitDepth: Int?
    let dpi: Double?
    let colorSpace: String?
    let hasAlpha: Bool?
    let compressionQuality: Float?

    // TIMING INFORMATION
    let captureTime: Date
    let timezone: String?
    let processingTime: TimeInterval?
    let systemUptime: TimeInterval?

    // DEVICE INFORMATION (MAXIMUM DETAIL)
    let deviceInfo: DeviceInfo
    let deviceModel: String?
    let deviceName: String?
    let systemName: String?
    let systemVersion: String?
    let buildNumber: String?
    let deviceOrientation: Int?
    let screenBrightness: CGFloat?
    let screenScale: CGFloat?
    let screenSize: String?

    // HARDWARE CAPABILITIES (MAXIMUM DETAIL)
    let cpuInfo: CPUInfo?
    let memoryInfo: MemoryInfo?
    let storageInfo: StorageInfo?
    let batteryInfo: BatteryInfo?
    let thermalState: String?
    let networkInfo: NetworkInfo?

    // CAMERA SETTINGS (EVERYTHING POSSIBLE)
    let cameraSettings: CameraSettingsMetadata

    // CAMERA HARDWARE (MAXIMUM DETAIL)
    let cameraHardware: CameraHardwareInfo?

    // LOCATION DATA (MAXIMUM DETAIL)
    let location: LocationMetadata?
    let altitude: Double?
    let gpsAccuracy: Double?
    let locationServicesEnabled: Bool?
    let heading: Double?

    // ORIENTATION & MOTION
    let orientation: Int
    let deviceMotion: DeviceMotionData?
    let accelerometerData: AccelerometerData?

    // SOFTWARE & APP INFORMATION
    let software: String
    let appVersion: String?
    let appBuild: String?
    let filterApplied: String
    let processingPipeline: [String]?

    // PERFORMANCE METRICS
    let performanceMetrics: PerformanceMetrics?

    // ENVIRONMENTAL DATA
    let environmentalData: EnvironmentalData?

    // EXIF DATA (RAW FROM CAMERA)
    let exifData: CameraEXIFMetadata

    // IMAGE ANALYSIS
    let imageAnalysis: ImageAnalysis?

    // ACCESSIBILITY & PREFERENCES
    let accessibilitySettings: AccessibilitySettings?
    let userPreferences: UserPreferences?

    // DEBUG & DIAGNOSTIC INFORMATION
    let debugInfo: DebugInfo?

    // SECURITY & PRIVACY INFORMATION
    let securityInfo: SecurityInfo?

    // NETWORK & CONNECTIVITY
    let connectivityInfo: ConnectivityInfo?

    // POWER MANAGEMENT
    let powerManagement: CameraPowerManagement?

    // AUDIO INFORMATION (if recording)
    let audioInfo: AudioInfo?

    // ARKIT INFORMATION (if available)
    let arInfo: ARInfo?

    // CUSTOM METADATA
    let customMetadata: [String: Any]?
}

// SUPPORTING STRUCTURES
struct ImageProperties {
    let fileSize: Int
    let bitDepth: Int
    let dpi: Double?
    let hasAlpha: Bool
    let compressionQuality: Float
}

struct SystemInformation {
    let deviceModel: String
    let deviceName: String
    let systemName: String
    let systemVersion: String
    let buildNumber: String
    let uptime: TimeInterval
    let appVersion: String
    let appBuild: String
    let cpuInfo: CPUInfo
    let memoryInfo: MemoryInfo
    let storageInfo: StorageInfo
    let batteryInfo: BatteryInfo
    let thermalState: String
    let networkInfo: NetworkInfo
}

// CPUInfo moved to SharedTypes.swift

// MemoryInfo moved to SharedTypes.swift

// StorageInfo moved to SharedTypes.swift

// BatteryInfo moved to SharedTypes.swift

// NetworkInfo moved to SharedTypes.swift

// CameraHardwareInfo moved to SharedTypes.swift

// DeviceMotionData moved to SharedTypes.swift

// AccelerometerData moved to SharedTypes.swift

// Internal EXIF structure for CameraService
struct CameraEXIFMetadata {
    let aperture: Double?
    let shutterSpeed: Double?
    let iso: Double?
    let focalLength: Double?
    let lens: String?
    let cameraModel: String?
}

struct ProcessingInfo {
    let processingTime: TimeInterval
    let processingPipeline: [String]
}

// PerformanceMetrics moved to SharedTypes.swift

// EnvironmentalData moved to SharedTypes.swift

// ImageAnalysis moved to SharedTypes.swift

// AccessibilitySettings moved to SharedTypes.swift

// UserPreferences, DebugInfo, and SecurityInfo moved to SharedTypes.swift

// ConnectivityInfo moved to SharedTypes.swift

struct CameraPowerManagement {
    let lowPowerMode: Bool
    let batteryOptimization: Bool?
    let backgroundAppRefresh: Bool?
    let autoLock: Bool?
    let screenTimeout: Int?
}

    // MARK: - Missing Helper Functions
    private func getCurrentCameraSettings() -> CameraSettingsMetadata {
        return CameraSettingsMetadata(
            iso: nil,
            shutterSpeed: nil,
            aperture: nil,
            focalLength: nil,
            lens: nil,
            whiteBalance: nil,
            exposureCompensation: nil,
            flashMode: nil,
            meteringMode: nil,
            lensPosition: nil,
            focusMode: nil,
            exposureMode: nil,
            flash: nil,
            nightMode: nil,
            filter: nil,
            zoom: nil,
            filterApplied: nil
        )
    }

    private func extractGPSMetadata(from image: UIImage) -> LocationMetadata? {
        return nil
    }

    private func determineImageFormat(from image: UIImage) -> String {
        return "jpeg"
    }
    
    private func extractColorSpace(from image: UIImage) -> String {
        return image.cgImage?.colorSpace?.name as String? ?? "sRGB"
    }

    private func getDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        return DeviceInfo(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            name: device.name
        )
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Photo Metadata Extraction
    // ExtractedPhotoMetadata and CameraEXIFMetadata structs defined above
    
    private func extractPhotoMetadata(from image: UIImage) async -> ExtractedPhotoMetadata {
        let currentSettings = getCurrentCameraSettings()
        let exifMetadata = extractEXIFMetadata(from: image)
        let gpsMetadata = extractGPSMetadata(from: image)
        let deviceInfo = getDeviceInfo()
//        let systemInfo = await extractSystemInformation()
        
        return ExtractedPhotoMetadata(
            // BASIC IMAGE PROPERTIES
            width: Int(image.size.width),
            height: Int(image.size.height),
            format: determineImageFormat(from: image),
            fileSize: nil as Int?,
            bitDepth: nil as Int?,
            dpi: nil as Double?,
            colorSpace: extractColorSpace(from: image),
            hasAlpha: nil as Bool?,
            compressionQuality: nil as Float?,
            
            // TIMING INFORMATION
            captureTime: Date(),
            timezone: TimeZone.current.identifier,
            processingTime: nil as TimeInterval?,
            systemUptime: ProcessInfo.processInfo.systemUptime,
            
            // DEVICE INFORMATION
            deviceInfo: deviceInfo,
            deviceModel: deviceInfo.model,
            deviceName: deviceInfo.name,
            systemName: deviceInfo.systemName,
            systemVersion: deviceInfo.systemVersion,
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            deviceOrientation: nil as Int?,
            screenBrightness: UIScreen.main.brightness,
            screenScale: UIScreen.main.scale,
            screenSize: "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))",
            
            // HARDWARE CAPABILITIES
            cpuInfo: nil as CPUInfo?,
            memoryInfo: nil as MemoryInfo?,
            storageInfo: nil as StorageInfo?,
            batteryInfo: nil as BatteryInfo?,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue.description,
            networkInfo: nil as NetworkInfo?,
            
            // CAMERA SETTINGS
            cameraSettings: currentSettings,
            
            // CAMERA HARDWARE
            cameraHardware: nil as CameraHardwareInfo?,
            
            // LOCATION DATA
            location: gpsMetadata,
            altitude: gpsMetadata?.altitude,
            gpsAccuracy: nil as Double?,
            locationServicesEnabled: CLLocationManager.locationServicesEnabled(),
            heading: nil as Double?,
            
            // ORIENTATION & MOTION
            orientation: 1, // Portrait orientation
            deviceMotion: nil as DeviceMotionData?,
            accelerometerData: nil as AccelerometerData?,
            
            // SOFTWARE & APP INFORMATION
            software: getAppVersion(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            filterApplied: "none", // No filter applied
            processingPipeline: ["capture", "metadata_extraction"],
            
            // PERFORMANCE METRICS
            performanceMetrics: nil as PerformanceMetrics?,
            
            // ENVIRONMENTAL DATA
            environmentalData: nil as EnvironmentalData?,
            
            // EXIF DATA
            exifData: exifMetadata,

            // IMAGE ANALYSIS
            imageAnalysis: ImageAnalysis(dominantColors: nil, brightness: nil, contrast: nil, saturation: nil),

            // ACCESSIBILITY & PREFERENCES
            accessibilitySettings: nil as AccessibilitySettings?,
            userPreferences: nil as UserPreferences?,
            
            // DEBUG & DIAGNOSTIC INFORMATION
            debugInfo: nil as DebugInfo?,
            
            // SECURITY & PRIVACY INFORMATION
            securityInfo: nil as SecurityInfo?,
            
            // NETWORK & CONNECTIVITY
            connectivityInfo: nil as ConnectivityInfo?,
            
            // POWER MANAGEMENT
            powerManagement: nil as CameraPowerManagement?,
            
            // AUDIO INFORMATION
            audioInfo: nil as AudioInfo?,
            
            // ARKIT INFORMATION
            arInfo: nil as ARInfo?,
            
            // CUSTOM METADATA
            customMetadata: nil as [String: Any]?
        )
    }
    
    private func extractEXIFMetadata(from image: UIImage) -> CameraEXIFMetadata {
        // Simple EXIF extraction - in a real implementation this would parse actual EXIF data
        return CameraEXIFMetadata(
            aperture: nil as Double?,
            shutterSpeed: nil as Double?,
            iso: nil as Double?,
            focalLength: nil as Double?,
            lens: nil as String?,
            cameraModel: UIDevice.current.model
        )
    }

// AudioInfo and ARInfo moved to SharedTypes.swift

