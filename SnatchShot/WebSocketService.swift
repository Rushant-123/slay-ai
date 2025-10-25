//
//  WebSocketService.swift
//  SnatchShot
//
//  Created by Rushant on 15/09/25.
//

import Foundation
import Combine
import UIKit
import AVFoundation
import SuperwallKit

// Import for API response types
import Foundation // Already imported, but for API types

// MARK: - iOS WebSocket Architecture Notes
//
// iOS WebSocket Limitations:
// - Maximum message size: 1MB (system-imposed by WebKit/iOS)
// - Cannot be increased via code - this is a system-level limitation
// - Large messages (>1MB) will fail with "Message too long" error
//
// Our Solution:
// - WebSocket: Real-time progress updates, analysis data, status events
// - HTTP: Large image data (works around WebSocket size limits)
// - Binary Image Handling: Server sends compressed JPEG buffers, we convert to base64
// - This is the recommended iOS WebSocket pattern for media-heavy apps
//
// New Binary Image Handling (Server Update):
// - Server sends compressed JPEG data directly as binary WebSocket messages
// - iOS receives binary data and converts to base64 for compatibility
// - Binary messages are stored as "pending" until matched with metadata events
// - Text events provide titles/metadata, binary events provide image data
// - This avoids the 1MB limit while maintaining real-time delivery
//
// Expected Behavior:
// - WebSocket connects successfully and receives all progress events
// - Binary image data arrives separately from text metadata
// - "Message too long" errors are expected and handled gracefully
// - HTTP fallback provides complete images when WebSocket can't
// - Users get smooth progress updates + final images seamlessly
// - Images are properly compressed and ready for display

// MARK: - WebSocket Event Types
enum WebSocketEventType: String, Decodable {
    case connection_established
    case processing_started
    case analysis_started
    case content_analysis_complete
    case photo_analysis_complete
    case image_generation_started
    case individual_image_started
    case individual_image_completed
    case individual_image_error
    case image_generation_completed
    case image_generation_error
    case processing_completed
    case processing_error
    case usage_stats
    case plan_limit_reached
}

// MARK: - WebSocket Event Models
struct WebSocketEvent: Decodable {
    let type: WebSocketEventType
    let requestId: String?
    let message: String?
    let timestamp: String
    let imageData: String? // base64 for individual_image_completed
    let imageIndex: Int? // for individual_image_started/completed/error
    let totalImages: Int? // for individual_image_started/completed/error
    let title: String? // for individual_image_started/completed/error
    let error: String? // for error events
    let settings: CameraSettings? // for content_analysis_complete
    let analysis: WebSocketAnalysis? // for photo_analysis_complete
    // Usage stats fields
    let userId: String? // for usage_stats
    let currentUsage: Int? // for usage_stats
    let limit: Int? // for usage_stats and plan_limit_reached
    let plan: String? // for usage_stats and plan_limit_reached
    let resetDate: String? // for usage_stats and plan_limit_reached

    enum CodingKeys: String, CodingKey {
        case type, requestId, message, timestamp, imageData, imageIndex, totalImages, title, error, settings, analysis, userId, currentUsage, limit, plan, resetDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(WebSocketEventType.self, forKey: .type)
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        imageData = try container.decodeIfPresent(String.self, forKey: .imageData)
        imageIndex = try container.decodeIfPresent(Int.self, forKey: .imageIndex)
        totalImages = try container.decodeIfPresent(Int.self, forKey: .totalImages)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        error = try container.decodeIfPresent(String.self, forKey: .error)

        // Decode nested objects conditionally
        settings = try container.decodeIfPresent(CameraSettings.self, forKey: .settings)
        analysis = try container.decodeIfPresent(WebSocketAnalysis.self, forKey: .analysis)

        // Decode usage stats fields
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        currentUsage = try container.decodeIfPresent(Int.self, forKey: .currentUsage)
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        resetDate = try container.decodeIfPresent(String.self, forKey: .resetDate)
    }
}

struct WebSocketAnalysis: Decodable {
    let photoImprovementSuggestions: [PhotoSuggestion]?

    private enum CodingKeys: String, CodingKey {
        case photoImprovementSuggestions = "photo_improvement_suggestions"
    }
}

struct CameraSettings: Decodable {
    let exposure_controls: ExposureControls?
    let white_balance_controls: WhiteBalanceControls?
    let image_processing: ImageProcessing?
    let advanced_modes: AdvancedModes?
    let professional_features: ProfessionalFeatures?
}

struct ExposureControls: Decodable {
    let exposure_mode: String?
    let iso: Double?
    let shutter_speed: Double?
    let aperture: Double?
    let ev_bias: Double?
    let focal_length: Double?
    let frame_rate: Double?
    let bracketing_mode: String?
}

struct WhiteBalanceControls: Decodable {
    let wb_preset: String?
    let white_balance_temperature: Double?
    let white_balance_tint: Double?
}

struct ImageProcessing: Decodable {
    let contrast: Double?
    let brightness: Double?
    let saturation: Double?
    let sharpness: Double?
    let current_filter: String?
}

struct AdvancedModes: Decodable {
    let night_mode: String?
    let night_mode_intensity: Double?
    let stabilization_mode: String?
    let burst_mode: String?
    let zoom_mode: String?
    let hdr_mode: Bool?
    let raw_capture: Bool?
}

struct ProfessionalFeatures: Decodable {
    let focus_peaking: Bool?
    let zebra_stripes: Bool?
    let level_indicator: Bool?
    let histogram: Bool?
    let audio_recording: Bool?
    let gps_tagging: Bool?
}

// MARK: - Enhanced Camera Settings for AI Recommendations

/// Comprehensive camera settings recommendation from AI analysis
struct AICameraRecommendation: Decodable {
    /// Overall confidence in these recommendations (0.0 to 1.0)
    let confidence: Float

    /// Human-readable explanation of why these settings were chosen
    let reasoning: String

    /// Detected scene type (affects which settings are prioritized)
    let sceneType: String // "portrait", "landscape", "low-light", "action", "macro", etc.

    /// Time in seconds for smooth transitions between settings
    let transitionDuration: TimeInterval

    /// Core exposure settings (most important - always include these)
    let exposure: AIExposureSettings?

    /// Focus and depth of field settings (critical for sharp images)
    let focus: AIFocusSettings?

    /// White balance and color temperature (essential for color accuracy)
    let whiteBalance: AIWhiteBalanceSettings?

    /// Image processing adjustments (enhance the final result)
    let processing: AIProcessingSettings?

    /// Special modes and features (situational optimizations)
    let special: AISpecialSettings?

    /// Safety bounds for the current device/camera
    let bounds: AISafetyBounds?

    private enum CodingKeys: String, CodingKey {
        case confidence, reasoning, sceneType = "scene_type"
        case transitionDuration = "transition_duration"
        case exposure, focus, whiteBalance = "white_balance"
        case processing, special, bounds
    }
}

/// Exposure triangle settings with AI recommendations
struct AIExposureSettings: Decodable {
    /// Exposure mode: "auto", "manual", "aperture_priority", "shutter_priority", "program"
    let mode: String?

    /// ISO sensitivity (will be clamped to device capabilities)
    let iso: Float?

    /// Shutter speed in seconds (e.g., 0.0167 for 1/60s)
    let shutterSpeed: Float?

    /// Aperture f-stop value
    let aperture: Float?

    /// Exposure compensation in EV (-2.0 to +2.0)
    let evBias: Float?

    private enum CodingKeys: String, CodingKey {
        case mode, iso, shutterSpeed = "shutter_speed", aperture, evBias = "ev_bias"
    }
}

/// Focus and depth of field settings
struct AIFocusSettings: Decodable {
    /// Focus mode: "auto", "manual", "continuous", "single"
    let mode: String?

    /// Manual focus distance (0.0 = closest, 1.0 = infinity)
    let distance: Float?

    /// Touch-to-focus coordinates (normalized 0.0-1.0)
    let pointOfInterest: [Float]? // [x, y] coordinates

    private enum CodingKeys: String, CodingKey {
        case mode, distance, pointOfInterest = "point_of_interest"
    }
}

/// White balance and color temperature
struct AIWhiteBalanceSettings: Decodable {
    /// Preset: "auto", "sunny", "cloudy", "shade", "tungsten", "fluorescent"
    let preset: String?

    /// Color temperature in Kelvin (2000-10000)
    let temperature: Float?

    /// Green/magenta tint adjustment (-50 to +50)
    let tint: Float?
}

/// Image processing and enhancement
struct AIProcessingSettings: Decodable {
    /// Brightness adjustment (-0.5 to 0.5)
    let brightness: Float?

    /// Contrast adjustment (0.5 to 2.0)
    let contrast: Float?

    /// Saturation adjustment (0.0 to 2.0)
    let saturation: Float?

    /// Sharpness adjustment (0.0 to 2.0)
    let sharpness: Float?

    /// Camera filter to apply (matches CameraFilter enum names)
    let filter: String?
}

/// Special camera modes and features
struct AISpecialSettings: Decodable {
    /// Night mode: "off", "auto", "on"
    let nightMode: String?

    /// Stabilization: "off", "on", "cinematic"
    let stabilization: String?

    /// Zoom factor (1.0 = no zoom, higher = more zoom)
    let zoom: Float?

    /// Flash mode: "off", "on", "auto"
    let flash: String?

    /// High Dynamic Range mode
    let hdr: Bool?

    /// Burst mode: "off", "low", "medium", "high"
    let burstMode: String?

    private enum CodingKeys: String, CodingKey {
        case nightMode = "night_mode", stabilization, zoom, flash, hdr, burstMode = "burst_mode"
    }
}

/// Safety bounds for the current device capabilities
struct AISafetyBounds: Decodable {
    /// ISO range
    let isoMin: Float?
    let isoMax: Float?

    /// Shutter speed range in seconds
    let shutterMin: Float?
    let shutterMax: Float?

    /// Aperture range
    let apertureMin: Float?
    let apertureMax: Float?

    /// Zoom range
    let zoomMin: Float?
    let zoomMax: Float?

    private enum CodingKeys: String, CodingKey {
        case isoMin = "iso_min", isoMax = "iso_max"
        case shutterMin = "shutter_min", shutterMax = "shutter_max"
        case apertureMin = "aperture_min", apertureMax = "aperture_max"
        case zoomMin = "zoom_min", zoomMax = "zoom_max"
    }
}

// MARK: - BACKEND JSON SPECIFICATION

/*
================================================================================
📋 BACKEND JSON SPECIFICATION FOR AI CAMERA SETTINGS
================================================================================

Copy this entire specification to Slack for backend developers.

The JSON structure below is what the backend MUST send via WebSocket for AI camera settings.
All fields are OPTIONAL - if AI misses any setting, we fall back to device defaults.

================================================================================

REQUIRED JSON STRUCTURE:
{
  "type": "camera_settings",  // Required: identifies this as camera settings message
  "confidence": 0.85,         // Required: AI confidence level (0.0 to 1.0)
  "reasoning": "Human-readable explanation of why these settings were chosen",
  "scene_type": "portrait",   // Required: scene type for context
  "transition_duration": 1.5, // Required: seconds for smooth transitions

  "exposure": {               // OPTIONAL: core exposure settings
    "mode": "auto",           // "auto", "manual", "aperture_priority", "shutter_priority", "program"
    "iso": 400,              // ISO sensitivity (device-dependent range)
    "shutter_speed": 0.0333, // seconds (e.g., 0.0333 = 1/30s)
    "aperture": 2.8,         // f-stop value
    "ev_bias": 0.0           // -2.0 to +2.0 EV
  },

  "focus": {                  // OPTIONAL: focus settings
    "mode": "auto",           // "auto", "manual", "continuous", "single"
    "distance": 0.5,         // 0.0 (closest) to 1.0 (infinity)
    "point_of_interest": [0.5, 0.4]  // [x, y] coordinates (0.0-1.0)
  },

  "white_balance": {          // OPTIONAL: color temperature
    "preset": "auto",         // "auto", "sunny", "cloudy", "shade", "tungsten", "fluorescent"
    "temperature": 5500,     // Kelvin (2000-10000)
    "tint": 0                // green/magenta adjustment (-50 to +50)
  },

  "processing": {             // OPTIONAL: image processing
    "brightness": 0.0,        // -0.5 to 0.5
    "contrast": 1.0,          // 0.5 to 2.0
    "saturation": 1.0,        // 0.0 to 2.0
    "sharpness": 1.0,         // 0.0 to 2.0
    "filter": "none"          // camera filter name from enum
  },

  "special": {                // OPTIONAL: special modes
    "night_mode": "auto",     // "off", "auto", "on"
    "stabilization": "on",    // "off", "on", "cinematic"
    "zoom": 1.0,             // zoom factor (1.0 = no zoom)
    "flash": "auto",         // "off", "on", "auto"
    "hdr": false,            // High Dynamic Range
    "burst_mode": "off"      // "off", "low", "medium", "high"
  }
}

================================================================================

DEFAULT VALUES (when AI doesn't provide):
- exposure.mode: "auto"
- focus.mode: "auto"
- white_balance.preset: "auto"
- processing.brightness: 0.0
- processing.contrast: 1.0
- processing.saturation: 1.0
- processing.sharpness: 1.0
- processing.filter: "none"
- special.night_mode: "auto"
- special.stabilization: "on"
- special.zoom: 1.0
- special.flash: "auto"
- special.hdr: false
- special.burst_mode: "off"

================================================================================

EXAMPLE MESSAGES:

1. MINIMAL (AI only provides essential settings):
{
  "type": "camera_settings",
  "confidence": 0.78,
  "reasoning": "Bright outdoor conditions detected",
  "scene_type": "landscape",
  "transition_duration": 0.8,
  "exposure": {"mode": "auto"}
}

2. COMPLETE (AI optimizes everything):
{
  "type": "camera_settings",
  "confidence": 0.94,
  "reasoning": "Indoor portrait with tungsten lighting - optimized all settings",
  "scene_type": "portrait",
  "transition_duration": 1.5,
  "exposure": {
    "mode": "manual",
    "iso": 800,
    "shutter_speed": 0.0333,
    "aperture": 2.8,
    "ev_bias": 0.3
  },
  "focus": {
    "mode": "single",
    "distance": 0.4,
    "point_of_interest": [0.5, 0.35]
  },
  "white_balance": {
    "preset": "tungsten",
    "temperature": 2850
  },
  "processing": {
    "brightness": 0.1,
    "contrast": 1.2,
    "saturation": 1.1,
    "sharpness": 0.9,
    "filter": "portrait"
  },
  "special": {
    "night_mode": "auto",
    "stabilization": "on",
    "zoom": 1.2,
    "flash": "off"
  }
}

================================================================================

NOTES FOR BACKEND:
1. All fields except "type", "confidence", "reasoning", "scene_type", "transition_duration" are OPTIONAL
2. AI can provide partial settings - missing ones use device defaults
3. Values must be within device capabilities (we clamp them on iOS side)
4. Send this JSON as part of the WebSocket message payload
5. Use "type": "camera_settings" to identify camera settings messages

================================================================================
*/

// Using the existing PhotoAnalysis and PhotoSuggestion from PoseSuggestionsView
// We need to create WebSocket-specific versions to avoid naming conflicts

// API response models are already defined in PoseSuggestionsView.swift
// Using existing models to avoid naming conflicts

// MARK: - WebSocket Service
public class WebSocketService: NSObject, ObservableObject {
    public static let shared = WebSocketService()
    
    public override init() {
        super.init()
        // Load saved usage data immediately
        loadSavedUsageData()
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var serverURL: URL {
        let baseURL = Configuration.shared.webSocketBaseURL
        if let userId = UserDefaults.standard.string(forKey: "database_user_id") {
            return URL(string: "\(baseURL)?userId=\(userId)")!
        } else {
            return URL(string: baseURL)!
        }
    }

    // Published properties for UI updates
    @Published var isConnected = false
    @Published var connectionError: Error?
    @Published var currentRequestId: String?

    // Track analysis completion for proper UI sequencing
    @Published var photoAnalysisCompleted = false

    // Track usage for UI display
    @Published var currentUsage: Int? {
        didSet {
            if let value = currentUsage {
                UserDefaults.standard.set(value, forKey: "last_known_usage")
            }
        }
    }
    @Published var usageLimit: Int? {
        didSet {
            if let value = usageLimit {
                UserDefaults.standard.set(value, forKey: "last_known_limit")
            }
        }
    }
    @Published var userPlan: String? {
        didSet {
            if let value = userPlan {
                UserDefaults.standard.set(value, forKey: "last_known_plan")
            }
        }
    }
    
    private func loadSavedUsageData() {
        currentUsage = UserDefaults.standard.object(forKey: "last_known_usage") as? Int
        usageLimit = UserDefaults.standard.object(forKey: "last_known_limit") as? Int
        userPlan = UserDefaults.standard.string(forKey: "last_known_plan")
        
        print("📊 Loading saved usage data...")
        print("📊 Current usage from UserDefaults: \(currentUsage.map(String.init) ?? "nil")")
        print("📊 Usage limit from UserDefaults: \(usageLimit.map(String.init) ?? "nil")")
        print("📊 User plan from UserDefaults: \(userPlan ?? "nil")")
        
        // Request fresh data immediately after loading saved data
        DispatchQueue.main.async { [weak self] in
            self?.requestUsageData()
            print("📊 Requested fresh usage data after loading saved data")
        }
    }

    // Store images when processing UI isn't ready yet
    private var pendingImages: [PoseSuggestion] = []
    private var processingUIReady = false
    private var cardLoadingSequenceStarted = false

    // Event publishers
    let onConnectionEstablished = PassthroughSubject<String, Never>()
    let onProcessingStarted = PassthroughSubject<String, Never>()
    let onAnalysisStarted = PassthroughSubject<String, Never>()
    let onProcessingUIReady = PassthroughSubject<PoseSuggestion, Never>()
    let onShowEmptyCards = PassthroughSubject<Void, Never>() // Signal to show empty shimmer cards
    let onContentAnalysisComplete = PassthroughSubject<CameraSettings, Never>()
    let onImageGenerationStarted = PassthroughSubject<String, Never>()
    let onFirstImageCompleted = PassthroughSubject<PoseSuggestion, Never>()
    let onImageCompleted = PassthroughSubject<PoseSuggestion, Never>()
    let onImageError = PassthroughSubject<(Int, String), Never>()
    let onProcessingCompleted = PassthroughSubject<Void, Never>()
    let onProcessingError = PassthroughSubject<String, Never>()

    private var receivedImages: [PoseSuggestion] = []
    private var expectedTotalImages = 4 // Based on the WebSocket docs
    private var totalMessagesReceived = 0
    private var lastEventTimestamp: Date?

    // Store analysis data from WebSocket events
    private var capturedAnalysis: [PhotoSuggestion] = []

    // MARK: - AI Camera Settings Integration
    // Track applied AI settings for user feedback
    private var lastAppliedAISettings: AICameraRecommendation?
    private var appliedSettingsSummary: [String] = []
    
    // MARK: - Camera Settings Integration
    // Throttling for camera settings to prevent rapid changes
    private var lastCameraSettingsApplied: Date = Date.distantPast
    private let cameraSettingsThrottleInterval: TimeInterval = 2.0
    private weak var cameraService: CameraService?
    private weak var cameraViewModel: CameraViewModel?
    
    // MARK: - Error Handling & Timeout
    private var processingTimeoutTimer: Timer?
    private let processingTimeoutInterval: TimeInterval = 25.0

    // MARK: - Camera Service Integration
    func setCameraService(_ cameraService: CameraService) {
        self.cameraService = cameraService
        // Set bidirectional reference so cameraService can access webSocketService
        cameraService.webSocketService = self
    }
    
    func setCameraViewModel(_ cameraViewModel: CameraViewModel) {
        self.cameraViewModel = cameraViewModel
    }

    // MARK: - Connection Management
    func connect() {
        // Check if already connected to avoid duplicate connections
        if isConnected && webSocketTask != nil {
            print("🔌 WebSocket already connected - reusing existing connection")
            // Request usage data even if already connected
            requestUsageData()
            return
        }

        // Reset state for clean connection
        reset()

        // Clean up any existing connection state
        if webSocketTask != nil {
            print("🔌 Cleaning up previous WebSocket connection")
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
            urlSession = nil
        }

        print("🔌 Attempting to connect to WebSocket server at \(serverURL)")
        print("🔌 WebSocket URL: \(serverURL.absoluteString)")

        // Try to configure WebSocket with larger buffer sizes (may not work due to system limits)
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 10
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300

        // Log system limitations for debugging
        print("🔌 iOS WebSocket Limitations:")
        print("🔌 - Maximum message size: 1MB (system-imposed)")
        print("🔌 - This is a WebKit/iOS system limitation, not configurable via code")
        print("🔌 - Large images must use HTTP, small updates use WebSocket")
        print("🔌 - Current approach (HTTP + WebSocket) is the recommended solution")

        // Create new session and task
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: serverURL)
        
        // Log current state before connecting
        print("🔌 Current state before connecting:")
        print("🔌 - isConnected: \(isConnected)")
        print("🔌 - webSocketTask: \(webSocketTask != nil ? "exists" : "nil")")
        print("🔌 - urlSession: \(urlSession != nil ? "exists" : "nil")")
        print("🔌 - currentUsage: \(currentUsage.map(String.init) ?? "nil")")
        print("🔌 - usageLimit: \(usageLimit.map(String.init) ?? "nil")")
        
        // Start the connection
        webSocketTask?.resume()
        receiveMessage()

        // Set connected state and request usage data
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isConnected = true
            self.connectionError = nil
            print("🔌 WebSocket connection initiated")
            
            // Load any saved data first
            print("🔌 Loading saved usage data while waiting for connection...")
            self.loadSavedUsageData()
            
            // Request fresh data immediately
            print("🔌 Requesting fresh usage data after connection...")
            self.requestUsageData()
            
            // Schedule multiple retries if data doesn't arrive
            let retryIntervals = [2.0, 4.0, 8.0] // Retry after 2s, 4s, and 8s
            for interval in retryIntervals {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                    guard let self = self else { return }
                    if self.currentUsage == nil || self.usageLimit == nil {
                        print("⚠️ Usage data not received after \(interval)s - retrying request")
                        self.requestUsageData()
                    }
                }
            }
        }
    }

    func requestUsageData() {
        guard let userId = UserDefaults.standard.string(forKey: "database_user_id") else {
            print("❌ No user ID found for usage data request")
            return
        }

        // Check WebSocket connection
        guard isConnected, let webSocketTask = webSocketTask else {
            print("❌ Cannot request usage data - WebSocket not connected")
            // Try to reconnect
            connect()
            return
        }

        let message = [
            "type": "get_usage_stats",
            "userId": userId
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let messageString = String(data: data, encoding: .utf8)!
            let message = URLSessionWebSocketTask.Message.string(messageString)
            
            print("📊 Requesting usage data for user: \(userId)")
            print("📊 Current WebSocket state: \(isConnected ? "Connected" : "Disconnected")")
            print("📊 Current usage: \(currentUsage.map(String.init) ?? "nil")")
            print("📊 Current limit: \(usageLimit.map(String.init) ?? "nil")")
            
            webSocketTask.send(message) { [weak self] error in
                if let error = error {
                    print("❌ Failed to request usage data: \(error)")
                    // Try to reconnect on error
                    DispatchQueue.main.async {
                        self?.connect()
                    }
                } else {
                    print("📤 Usage data request sent successfully")
                    // Schedule a retry if we don't get a response
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        guard let self = self else { return }
                        if self.currentUsage == nil || self.usageLimit == nil {
                            print("⚠️ No usage data received after 2s - retrying request")
                            self.requestUsageData()
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to encode usage data request: \(error)")
        }
    }

    func disconnect() {
        print("🔌 Disconnecting from WebSocket server")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.receivedImages.removeAll()
            // Reset connection state to ensure clean reconnection
            self.connectionError = nil
            self.reset()
        }
    }

    // MARK: - Message Handling
    func receiveMessage() {
        guard let webSocketTask = webSocketTask else {
            print("❌ No WebSocket task available for receiving messages")
            return
        }

        webSocketTask.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("📨 Received WebSocket message: \(text)")
                    self.handleTextMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("📨 Received WebSocket data message: \(text)")
                        self.handleTextMessage(text)
                    }
                @unknown default:
                    print("❌ Unknown message type received")
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                print("❌ WebSocket receive error: \(error)")
                
                // Attempt to reconnect on failure
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.connect() // This will handle cleanup and reconnection
                }
            }
        }
    func handleTextMessage(_ text: String) {
        do {
            // Parse the message as a WebSocket event
            let event = try JSONDecoder().decode(WebSocketEvent.self, from: text.data(using: .utf8)!)
            
            // Handle the event based on its type
            switch event.type {
            case .connection_established:
                print("🔌 ✅ WebSocket connection successfully opened")
                print("🔌 ℹ️ Connection established - ready for low-latency image processing")
                
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.connectionError = nil
                    print("🔌 Connection state updated to: Connected")
                    
                    // Request usage data after successful connection
                    self.requestUsageData()
                    
                    // Schedule a retry if data doesn't arrive quickly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if self.currentUsage == nil || self.usageLimit == nil {
                            print("⚠️ Usage data not received after 2s - retrying request")
                            self.requestUsageData()
                        }
                    }
                }
                
            case .usage_stats:
                print("📊 Usage stats received")
                if let currentUsage = event.currentUsage,
                   let limit = event.limit,
                   let plan = event.plan {
                    print("📊 Current usage: \(currentUsage)/\(limit) (\(plan))")
                    
                    // Update published properties for UI
                    DispatchQueue.main.async {
                        self.currentUsage = currentUsage
                        self.usageLimit = limit
                        self.userPlan = plan
                        
                        // Update subscription manager
                        SubscriptionManager.shared.updateUsage(current: currentUsage, limit: limit)
                        if let appSubscriptionPlan = AppSubscriptionPlan(rawValue: plan) {
                            SubscriptionManager.shared.state.currentPlan = appSubscriptionPlan
                        }
                    }
                }
                
            default:
                // Handle other event types
                break
            }
        } catch {
            print("❌ Failed to decode WebSocket message: \(error)")
            print("Message was: \(text)")
        }
    }

    func handleWebSocketMessage(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            switch message {
            case .string(let text):
                print("📨 Received WebSocket message: \(text)")
                self.handleTextMessage(text)
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    print("📨 Received WebSocket data message: \(text)")
                    self.handleTextMessage(text)
                }
            @unknown default:
                print("❌ Unknown message type received")
            }
            // Continue listening for more messages
            self.receiveMessage()
            
        case .failure(let error):
                let nsError = error as NSError

                // Handle "Message too long" errors gracefully
                if nsError.domain == NSPOSIXErrorDomain && nsError.code == 40 {
                    print("🔌 ℹ️ WebSocket message too large (1MB limit) - expected for image data")
                    print("🔌 ℹ️ HTTP fallback will provide the images")
                    // Don't set connection error for expected message size issues
                    return
                }

                print("❌ WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self.connectionError = error
                    self.isConnected = false
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        totalMessagesReceived += 1
        let timestamp = Date()
        lastEventTimestamp = timestamp

        print("📨 [\(totalMessagesReceived)] Received WebSocket message at \(DateFormatter.localizedString(from: timestamp, dateStyle: .none, timeStyle: .medium))")

        switch message {
        case .string(let text):
            print("📝 Text message (\(text.count) chars): \(text.prefix(200))\(text.count > 200 ? "..." : "")")
            handleTextMessage(text)
        case .data(let data):
            print("📦 Binary data: \(data.count) bytes")
            handleBinaryMessage(data)
        @unknown default:
            print("❓ Unknown message type received")
        }

        // Print summary after each message
        print("📊 Response Summary: \(totalMessagesReceived) total messages, \(receivedImages.count) images received")
    }

    private func handleTextMessage(_ text: String) {
        do {
            let event = try JSONDecoder().decode(WebSocketEvent.self, from: Data(text.utf8))
            handleEvent(event)
        } catch {
            print("❌ Failed to decode WebSocket event: \(error)")
            print("📄 Raw message: \(text)")
            print("🔍 Message length: \(text.count) characters")

            // Try to parse as generic JSON to see structure
            if let jsonData = text.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                print("🔍 JSON structure:")
                for (key, value) in jsonObject {
                    print("   \(key): \(type(of: value)) = \(String(describing: value).prefix(100))")
                }
            }
        }
    }

    private func handleBinaryMessage(_ data: Data) {
        print("🖼️ Received binary image data: \(data.count) bytes")

        // Server now sends compressed JPEG data directly as binary buffers
        // We need to convert to base64 for compatibility with existing image handling

        // Check if this looks like a reasonable JPEG image size
        if data.count > 1000 && data.count < 2_000_000 { // 1KB to 2MB range
            let base64String = data.base64EncodedString()
            print("🔄 Converted binary JPEG to base64: \(base64String.count) chars")

            // Store the binary data as a pending image to be matched with metadata
            storePendingBinaryImage(data: base64String)
            print("💾 Stored compressed JPEG as pending - will match with next image_completed event")

            // Verify it's actually JPEG data by checking header
            if data.count > 4 {
                let header = data.prefix(4).map { String(format: "%02x", $0) }.joined()
                print("📋 Image header: \(header) (should be JPEG: ffd8)")
            }

        } else if data.count > 2_000_000 {
            print("⚠️ Binary data too large (\(data.count) bytes) - exceeds 2MB limit")
            print("🔄 This might be hitting the 1MB WebSocket limit, will rely on HTTP fallback")
        } else {
            print("⚠️ Binary data too small (\(data.count) bytes) - might not be an image")
            // Try to interpret as text anyway (could be a malformed message)
            if let text = String(data: data, encoding: .utf8) {
                print("📦 Binary interpreted as text: \(text.prefix(200))\(text.count > 200 ? "..." : "")")
                handleTextMessage(text)
            }
        }
    }

    private var pendingBinaryImages: [String] = []

    private func storePendingBinaryImage(data: String) {
        pendingBinaryImages.append(data)
        print("📦 Pending binary images: \(pendingBinaryImages.count)")
    }

    private func getNextPendingImage() -> String? {
        guard !pendingBinaryImages.isEmpty else { return nil }
        let imageData = pendingBinaryImages.removeFirst()
        print("📦 Retrieved pending binary image, remaining: \(pendingBinaryImages.count)")
        return imageData
    }

    private func handleEvent(_ event: WebSocketEvent) {
        let eventDetails = [
            event.requestId.map { "RequestID: \($0)" },
            event.message.map { "Message: \($0)" },
            event.imageIndex.map { "ImageIndex: \($0)" },
            event.totalImages.map { "TotalImages: \($0)" },
            event.title.map { "Title: \($0)" },
            event.error.map { "Error: \($0)" }
        ].compactMap { $0 }.joined(separator: ", ")

        print("📡 [\(totalMessagesReceived)] Event: \(event.type.rawValue)")
        if !eventDetails.isEmpty {
            print("   📋 Details: \(eventDetails)")
        }

        // Log the current state
        print("   📊 Current state: \(getTrackingStatus())")

        // Update current request ID if provided
        if let requestId = event.requestId {
            print("   🔗 Tracking Request ID: \(requestId)")
            DispatchQueue.main.async {
                self.currentRequestId = requestId
            }
        }

        switch event.type {
        case .connection_established:
            if let connectionId = event.requestId {
                print("   🔌 ✅ WebSocket connected successfully with ID: \(connectionId)")
                DispatchQueue.main.async {
                    self.onConnectionEstablished.send(connectionId)
                }
            } else {
                print("   🔌 ✅ WebSocket connected (no connection ID)")
            }

        case .processing_started:
            if let requestId = event.requestId {
                print("   🚀 ✅ Image processing started - Request: \(requestId)")
                DispatchQueue.main.async {
                    self.onProcessingStarted.send(requestId)
                }
            }

        case .analysis_started:
            if let requestId = event.requestId {
                print("   🔍 ✅ AI analysis started - Request: \(requestId)")
                DispatchQueue.main.async {
                    self.onAnalysisStarted.send(requestId)
                }
            }

        case .image_generation_started:
            if let requestId = event.requestId {
                print("   🎨 ✅ Image generation started - Request: \(requestId)")
                DispatchQueue.main.async {
                    self.onImageGenerationStarted.send(requestId)
                }
            } else {
                print("   🚀 ✅ Image processing started")
            }

        case .individual_image_completed:
            print("   🖼️ ✅ Image completed - processing...")
            handleImageCompleted(event)

        case .individual_image_error:
            if let imageIndex = event.imageIndex, let error = event.error {
                print("   ❌ Image \(imageIndex) processing failed: \(error)")
                DispatchQueue.main.async {
                    self.onImageError.send((imageIndex, error))
                }
            } else {
                print("   ❌ Image processing error (missing details)")
            }

        case .processing_completed:
            print("   🎉 ✅ All processing completed successfully!")
            print("   📊 Final count: \(receivedImages.count) images received")
            clearProcessingTimeout() // Clear timeout on successful completion
            DispatchQueue.main.async {
                self.onProcessingCompleted.send()
            }

        case .processing_error:
            clearProcessingTimeout() // Clear timeout on error
            if let error = event.error {
                print("   💥 ❌ Processing failed with error: \(error)")
                DispatchQueue.main.async {
                    self.onProcessingError.send(error)
                }
            } else {
                print("   💥 ❌ Processing failed (unknown error)")
            }

        case .photo_analysis_complete:
            if let analysis = event.analysis?.photoImprovementSuggestions {
                print("   📋 Photo analysis completed - captured \(analysis.count) improvement suggestions")
                DispatchQueue.main.async {
                    self.capturedAnalysis = analysis
                    self.photoAnalysisCompleted = true  // Mark analysis as complete
                    print("   💾 Analysis data captured and stored for later use with HTTP images")
                    print("   🎯 Analysis phase complete - ready for card loading sequence")

                    // Start card loading sequence immediately after photo analysis completes
                    if !self.cardLoadingSequenceStarted {
                        print("   🎨 Photo analysis complete - starting card loading sequence")
                        self.cardLoadingSequenceStarted = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            print("   📸 Step 1: Show empty shimmer cards with typing animation")
                            self.onShowEmptyCards.send(())

                            // After showing empty cards, wait for typing animation (3 seconds) + image animation (2 seconds) = 5 seconds total
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                print("   📸 Step 2: Animations complete - showing actual images")
                                self.processingUIReady = true

                                // Send all currently queued images
                                let imagesToSend = self.pendingImages
                                self.pendingImages.removeAll()
                                for queuedImage in imagesToSend {
                                    self.onProcessingUIReady.send(queuedImage)
                                }
                            }
                        }
                    }
                }
            } else {
                print("   📋 Photo analysis completed but no suggestions found")
            }

        case .content_analysis_complete:
            if let settings = event.settings {
                print("   🎯 Content analysis completed - camera settings received")
                clearProcessingTimeout() // Clear timeout on camera settings received
                handleCameraSettingsFromWebSocket(settings)
                DispatchQueue.main.async {
                    self.onContentAnalysisComplete.send(settings)
                }
            } else {
                print("   🎯 Content analysis completed (no camera settings)")
                clearProcessingTimeout() // Clear timeout even if no settings
            }

        case .usage_stats:
            print("   📊 Usage stats received")
            if let currentUsage = event.currentUsage,
               let limit = event.limit,
               let plan = event.plan {
                // Multiply limit by 4 for the actual limit
                let actualLimit = limit * 4
                print("   📈 Current usage: \(currentUsage)/\(actualLimit) (\(plan))")
                if let resetDate = event.resetDate {
                    print("   📅 Resets on: \(resetDate)")
                }

                // Update published properties for UI
                DispatchQueue.main.async {
                    self.currentUsage = currentUsage
                    self.usageLimit = actualLimit // Use the actual limit
                    self.userPlan = plan
                }

                // Update subscription manager with usage data
                DispatchQueue.main.async {
                    SubscriptionManager.shared.updateUsage(current: currentUsage, limit: actualLimit)

                    // Update subscription plan if provided
                    if let appSubscriptionPlan = AppSubscriptionPlan(rawValue: plan) {
                        SubscriptionManager.shared.state.currentPlan = appSubscriptionPlan
                    }

                    // Update trial status based on plan
                    if plan == "trial" {
                        SubscriptionManager.shared.state.trialStatus = .active
                    } else if plan != "trial" && SubscriptionManager.shared.state.trialStatus == .active {
                        // If user has a paid plan but was in trial, trial is completed
                        SubscriptionManager.shared.state.trialStatus = .expired
                        SubscriptionManager.shared.state.isPaidSubscriber = true
                    }
                }

                // Use subscription manager for paywall decisions
                let paywallType = SubscriptionManager.shared.shouldShowPaywall()
                if paywallType != .none && currentUsage >= limit {
                    let placement = SubscriptionManager.shared.getPaywallPlacement()
                    print("   🎯 User has reached limit (\(currentUsage)/\(limit)) - showing \(placement) paywall")
                    DispatchQueue.main.async {
                        Superwall.shared.register(placement: placement) {
                            // Paywall shown - user will interact with it directly
                            print("   💰 Superwall paywall interaction completed for \(placement)")
                        }
                        print("   💰 Superwall paywall shown for \(placement)")
                    }
                } else {
                    print("   ✅ Usage within limits")
                }
            } else {
                print("   ⚠️ Usage stats event missing required fields")
            }

        case .plan_limit_reached:
            print("   🚫 Plan limit reached")
            if let plan = event.plan,
               let limit = event.limit,
               let resetDate = event.resetDate {
                print("   📊 Plan: \(plan), Limit: \(limit), Resets: \(resetDate)")

                // Update subscription manager with limit data
                DispatchQueue.main.async {
                    SubscriptionManager.shared.updateUsage(current: limit, limit: limit * 4) // At limit

                    // Update subscription plan
                    if let appSubscriptionPlan = AppSubscriptionPlan(rawValue: plan) {
                        SubscriptionManager.shared.state.currentPlan = appSubscriptionPlan
                    }
                }

                // Use subscription manager for paywall decisions
                let paywallType = SubscriptionManager.shared.shouldShowPaywall()
                if paywallType != .none {
                    let placement = SubscriptionManager.shared.getPaywallPlacement()
                    print("   🎯 User hit plan limit - showing \(placement) paywall")
                    DispatchQueue.main.async {
                        Superwall.shared.register(placement: placement) {
                            // Paywall shown - user will interact with it directly
                            print("   💰 Superwall paywall interaction completed for \(placement)")
                        }
                        print("   💰 Superwall paywall shown for \(placement)")
                    }
                }
            } else {
                print("   ⚠️ Plan limit reached event missing required fields")
            }

        default:
            print("   📋 Other event: \(event.type.rawValue) - \(event.message ?? "no message")")
            if let requestId = event.requestId {
                print("   🔗 Associated with request: \(requestId)")
            }
        }

        // Log timing information
        if let lastTimestamp = lastEventTimestamp {
            let timeSinceLast = Date().timeIntervalSince(lastTimestamp)
            print("   ⏱️ Time since last event: \(String(format: "%.2f", timeSinceLast))s")
        }
    }

    private func handleImageCompleted(_ event: WebSocketEvent) {
        guard let imageIndex = event.imageIndex,
              let title = event.title else {
            print("   ❌ Missing required metadata in image_completed event (imageIndex, title)")
            return
        }

        // Try to get image data from the event (legacy) or pending binary images (new)
        guard let imageData = event.imageData ?? getNextPendingImage() else {
            print("   ❌ No image data available - neither in event nor in pending binary images")
            return
        }

        if event.imageData != nil {
            print("   📦 Using image data from event (legacy format)")
        } else {
            print("   📦 Using image data from pending binary images (new format)")
        }

        let totalImages = event.totalImages ?? 4
        let progress = "\(imageIndex)/\(totalImages)"
        let imageSizeKB = imageData.count / 1024

        print("   🖼️ ✅ Image \(progress) completed: '\(title)'")
        print("   📊 Image size: \(imageSizeKB)KB, Base64 length: \(imageData.count) chars")

        // Get description from captured analysis data
        let analysisItem = self.capturedAnalysis[safe: imageIndex - 1]
        let description = analysisItem?.poseDescription ?? ""

        // Debug logging for description extraction
        if let analysisItem = analysisItem {
            print("   📝 Extracted description for image \(imageIndex): '\(description)'")
        } else {
            print("   ⚠️ No analysis data found for image \(imageIndex) (using empty description)")
        }

        // Create PoseSuggestion from WebSocket data
        let suggestion = PoseSuggestion(
            id: UUID().uuidString,
            image: imageData,
            title: title,
            description: description
        )

        DispatchQueue.main.async {
            self.receivedImages.append(suggestion)

            // Queue all images until processing UI is ready
            print("   📸 Image \(imageIndex) ready - queuing until processing UI is ready")
            self.pendingImages.append(suggestion)

            // Images are queued and will be sent after the card loading sequence completes
            if self.processingUIReady {
                // Processing UI is already ready, send images immediately
                print("   📸 Processing UI ready - sending image immediately")
                self.onImageCompleted.send(suggestion)
                // Remove from pending if it was there
                if let index = self.pendingImages.firstIndex(where: { $0.id == suggestion.id }) {
                    self.pendingImages.remove(at: index)
                }
            }

            // Show progress update
            let currentCount = self.receivedImages.count
            print("   📊 Progress: \(currentCount)/\(totalImages) images received")
        }
    }

    // MARK: - Public Methods
    func getCapturedAnalysis() -> [PhotoSuggestion] {
        return capturedAnalysis
    }

    func sendImage(_ image: UIImage, poseSuggestionsEnabled: Bool = false, cameraSettingsEnabled: Bool = false, userId: String? = nil) {
        print("📤 📸 SENDING IMAGE FOR PROCESSING VIA HTTP API...")
        print("🔌 WebSocket connection status: \(isConnected ? "Connected" : "Disconnected")")

        // Reset WebSocket state from previous requests
        reset()
        print("🔄 WebSocket state reset for new image processing")

        // Store parameters for use in completion handlers
        let shouldTrackUsage = poseSuggestionsEnabled
        let currentUserId = userId

        // Check trial usage limit for pose suggestions (parallel with image prep)
        // Temporarily disabled due to API endpoint issues
        let trialCheckTask: Task<Bool, Error>? = nil // shouldTrackUsage && currentUserId != nil ? Task {
        //     guard let userId = currentUserId else { return true }
        //     return try await DatabaseService.shared.checkTrialUsageLimit(for: userId)
        // } : nil

        // Start timeout timer for processing
        startProcessingTimeout()

        // Convert image to JPEG data for HTTP request (optimized for speed)
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to JPEG")
            return
        }

        // Check trial usage with proper error handling (async, non-blocking)
        if let trialCheckTask = trialCheckTask {
            Task {
                do {
                    let withinLimit = try await trialCheckTask.value
                    if !withinLimit {
                        print("🎯 Trial usage limit reached (5 photos), showing appropriate paywall")
                        await MainActor.run {
                            let paywallType = SubscriptionManager.shared.shouldShowPaywall()
                            if paywallType != .none {
                                let placement = SubscriptionManager.shared.getPaywallPlacement()
                                Superwall.shared.register(placement: placement) {
                                    print("💰 Superwall paywall interaction completed for \(placement)")
                                }
                                print("💰 Superwall paywall shown for \(placement)")
                            }
                        }
                        // Note: Processing may have already started, but user sees paywall
                    } else {
                        print("✅ Within trial usage limit, proceeding with processing")
                    }
                } catch {
                    print("❌ Error checking trial usage limit: \(error)")
                    print("ℹ️ Continuing with processing (fail open - don't punish user for our API issues)")
                    // Continue with processing if we can't check the limit (fail open for network issues)
                }
            }
        }

        let imageSizeKB = imageData.count / 1024
        print("📤 Image details: \(imageSizeKB)KB (\(imageData.count) bytes)")
        print("🔄 Starting HTTP request to trigger WebSocket events...")

        // Create HTTP request to /process-image endpoint with userId as query parameter
        var urlString = "\(Configuration.shared.databaseAPIBaseURL)/process-image"
        if let userId = userId {
            urlString += "?userId=\(userId)"
        }
        let httpURL = URL(string: urlString)!
        print("🌐 HTTP Request URL: \(httpURL.absoluteString)")
        var request = URLRequest(url: httpURL)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image data as multipart form field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"captured-image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add pose suggestions enabled parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"poseSuggestionsEnabled\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(poseSuggestionsEnabled)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Add camera settings enabled parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"cameraSettingsEnabled\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cameraSettingsEnabled)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Add user ID parameter
        if let userId = userId {
            print("📋 Adding userId to HTTP request: \(userId)")
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
            body.append(userId.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        } else {
            print("⚠️ userId is nil - not adding to HTTP request")
        }

        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("📤 HTTP request payload size: \(body.count) bytes")
        print("🔄 Making HTTP POST request to trigger WebSocket events...")

        // Set up a timeout for processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if self.receivedImages.isEmpty {
                print("⏰ Timeout: No processing events received in 60 seconds")
                print("ℹ️ Possible causes:")
                print("   - HTTP request failed (check server status)")
                print("   - WebSocket not receiving events from HTTP processing")
                print("   - Server processing taking longer than expected")
                print("   - Server might be down or unreachable")
                print("   - WebSocket/HTTP server mismatch")
            }
        }

        // Make HTTP request
        URLSession.shared.dataTask(with: request) { [shouldTrackUsage, currentUserId] data, response, error in
            DispatchQueue.main.async { [shouldTrackUsage, currentUserId] in
                if let error = error {
                    print("❌ HTTP request failed: \(error)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Response: \(httpResponse.statusCode)")

                    if (200...299).contains(httpResponse.statusCode) {
                        print("✅ HTTP request successful - WebSocket should now receive processing events")
                        print("🔄 Waiting for WebSocket events: processing_started, individual_image_completed, etc.")

                        // Try to parse HTTP response for image data
                        if let responseData = data {
                            self.parseHTTPResponseData(responseData, shouldTrackUsage: shouldTrackUsage, currentUserId: currentUserId)
                        }
                    } else {
                        print("❌ HTTP request failed with status: \(httpResponse.statusCode)")
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("📄 Error response: \(errorString)")
                        }
                    }
                } else {
                    print("❌ Invalid HTTP response")
                }
            }
        }.resume()
    }

    func getReceivedImages() -> [PoseSuggestion] {
        return receivedImages
    }

    func getTrackingStatus() -> String {
        let connectionStatus = isConnected ? "Connected" : "Disconnected"
        let imagesReceived = receivedImages.count
        let messagesReceived = totalMessagesReceived
        let lastActivity = lastEventTimestamp.map { "Last: \(DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium))" } ?? "No activity"

        return "Status: \(connectionStatus) | Images: \(imagesReceived)/4 | Messages: \(messagesReceived) | \(lastActivity)"
    }

    private func parseHTTPResponseData(_ data: Data, shouldTrackUsage: Bool, currentUserId: String?) {
        do {
            // Use the JSONDecoder with the correct key decoding strategy for snake_case
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let apiResponse = try decoder.decode(ApiResponse.self, from: data)
            print("📄 HTTP Response parsed successfully")
            print("📄 Found \(apiResponse.generatedImages.count) images in HTTP response")

            // Convert API response to PoseSuggestion objects
            let suggestions = apiResponse.generatedImages.enumerated().map { index, image in
                // Create a GeneratedImage instance for the PoseSuggestion initializer
                let generatedImage = GeneratedImage(data: image.data, mimeType: image.mimeType)

                // Use captured analysis from WebSocket if available, otherwise try HTTP response
                let analysis = self.capturedAnalysis[safe: index] ?? apiResponse.analysis?.photoImprovementSuggestions?[safe: index]

                // Debug: Log what analysis data we're getting
                if let analysis = analysis {
                    print("📄 Image \(index + 1) analysis: title='\(analysis.title ?? "nil")', description='\(analysis.poseDescription ?? "nil")' (source: \(self.capturedAnalysis[safe: index] != nil ? "WebSocket" : "HTTP"))")
                } else {
                    print("📄 Image \(index + 1) analysis: nil (will use default title)")
                }

                return PoseSuggestion(
                    from: generatedImage,
                    index: index,
                    analysis: analysis
                )
            }

            print("📄 Created \(suggestions.count) pose suggestions from HTTP response")

            // If we don't have images from WebSocket yet, use HTTP response as fallback
            // But only if WebSocket hasn't started sending events yet
            if self.receivedImages.isEmpty && !suggestions.isEmpty && self.totalMessagesReceived < 10 {
                print("🔄 Using HTTP response as fallback for image data (WebSocket inactive)")
                DispatchQueue.main.async {
                    self.receivedImages = suggestions

                    // Send first image completed event
                    if let firstSuggestion = suggestions.first {
                        print("🎯 FIRST IMAGE READY (from HTTP) - Switching to preview overlay")
                        self.onFirstImageCompleted.send(firstSuggestion)
                    }

                    // Send remaining images
                    for (index, suggestion) in suggestions.enumerated() where index > 0 {
                        print("📸 Additional image \(index + 1) ready (from HTTP) - Adding to overlay")
                        self.onImageCompleted.send(suggestion)
                    }

                    // Increment trial usage if pose suggestions were enabled
                    if shouldTrackUsage, let userId = currentUserId {
                        Task {
                            do {
                                try await DatabaseService.shared.incrementTrialUsage(for: userId)
                                print("📊 Trial usage incremented for user \(userId)")
                            } catch {
                                print("❌ Failed to increment trial usage: \(error)")
                            }
                        }
                    }

                    // Send processing completed
                    print("🎉 All processing completed (from HTTP)")
                    self.onProcessingCompleted.send()
                }
            }

        } catch {
            print("❌ Failed to parse HTTP response: \(error)")
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("📄 Raw HTTP response (first 2000 chars): \(rawResponse.prefix(2000))")

            // Try to debug the structure
            if rawResponse.contains("analysis") {
                print("📄 HTTP response DOES contain 'analysis' field")
                // Try to extract analysis section
                if let analysisStart = rawResponse.range(of: "\"analysis\":"),
                   let analysisEnd = rawResponse.range(of: "\"generated_images\":", range: analysisStart.upperBound..<rawResponse.endIndex) {
                    let analysisSection = rawResponse[analysisStart.lowerBound..<analysisEnd.lowerBound]
                    print("📄 Analysis section: \(analysisSection.prefix(500))")
                }
            } else {
                print("📄 HTTP response does NOT contain 'analysis' field")
            }

            if rawResponse.contains("photo_improvement_suggestions") {
                print("📄 HTTP response DOES contain 'photo_improvement_suggestions'")
            } else {
                print("📄 HTTP response does NOT contain 'photo_improvement_suggestions'")
            }

            // Try to manually parse with different structure
            print("🔍 Attempting manual JSON parsing...")
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("📋 JSON keys found: \(jsonObject.keys.joined(separator: ", "))")

                if let analysis = jsonObject["analysis"] as? [String: Any] {
                    print("📋 Analysis object found with keys: \(analysis.keys.joined(separator: ", "))")

                    if let suggestions = analysis["photo_improvement_suggestions"] as? [[String: Any]] {
                        print("📋 Found \(suggestions.count) photo improvement suggestions")
                        for (i, suggestion) in suggestions.enumerated() {
                            print("📋 Suggestion \(i+1): \(suggestion.keys.joined(separator: ", ")) - Title: \(suggestion["title"] ?? "nil")")
                        }
                    }
                } else {
                    print("📋 No analysis object found")
                }
            }
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.receivedImages.removeAll()
            self.capturedAnalysis.removeAll()
            self.pendingBinaryImages.removeAll()
            self.currentRequestId = nil
            self.connectionError = nil
            self.totalMessagesReceived = 0
            self.lastEventTimestamp = nil
            self.photoAnalysisCompleted = false  // Reset analysis completion flag
            self.pendingImages.removeAll()  // Clear any pending images
            self.processingUIReady = false  // Reset processing UI state
            self.cardLoadingSequenceStarted = false  // Reset card loading sequence flag
        }
        print("🔄 WebSocket tracking reset - cleared images, analysis, and pending binary data")
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketService: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocolName: String?) {
        print("🔌 ✅ WebSocket connection successfully opened")
        print("🔌 ℹ️ Connection established - ready for low-latency image processing")
        if let protocolValue = protocolName {
            print("🔌 Protocol: \(protocolValue)")
        }
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
            print("🔌 Connection state updated to: Connected")
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 ❌ WebSocket connection closed with code: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            print("🔌 Close reason: \(reasonString)")
        }
        DispatchQueue.main.async {
            self.isConnected = false
            print("🔌 Connection state updated to: Disconnected")
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError

            // Handle "Message too long" errors more gracefully
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == 40 {
                print("🔌 ℹ️ WebSocket message size limit exceeded (1MB) - this is expected")
                print("🔌 ℹ️ Large images are handled via HTTP, WebSocket handles progress updates")
                print("🔌 ℹ️ This is the recommended iOS WebSocket pattern")
                return // Don't set connection error for expected message size issues
            }

            print("🔌 ❌ WebSocket task failed: \(error.localizedDescription)")
            print("🔌 Error domain: \(nsError.domain), code: \(nsError.code)")
            DispatchQueue.main.async {
                self.isConnected = false
                self.connectionError = error
                print("🔌 Connection state updated to: Error")
            }
        } else {
            print("🔌 ✅ WebSocket task completed successfully")
        }
    }

    // MARK: - AI Camera Settings Integration

    /// Applies AI-recommended camera settings to the camera service
    /// - Parameter recommendation: The AI camera settings recommendation
    /// - Parameter cameraService: The camera service to apply settings to
    func applyAICameraRecommendation(_ recommendation: AICameraRecommendation, to cameraService: CameraService) {
        print("🤖 Applying AI camera recommendation (confidence: \(recommendation.confidence))")
        print("📝 Reasoning: \(recommendation.reasoning)")
        print("🎭 Scene type: \(recommendation.sceneType)")

        // Store for user feedback
        lastAppliedAISettings = recommendation
        appliedSettingsSummary.removeAll()

        // Apply settings with smooth transitions
        let transitionDuration = recommendation.transitionDuration

        // Apply exposure settings
        if let exposure = recommendation.exposure {
            applyExposureSettings(exposure, to: cameraService, transitionDuration: transitionDuration)
        }

        // Apply focus settings
        if let focus = recommendation.focus {
            applyFocusSettings(focus, to: cameraService, transitionDuration: transitionDuration)
        }

        // Apply white balance settings
        if let whiteBalance = recommendation.whiteBalance {
            applyWhiteBalanceSettings(whiteBalance, to: cameraService, transitionDuration: transitionDuration)
        }

        // Apply processing settings
        if let processing = recommendation.processing {
            applyProcessingSettings(processing, to: cameraService, transitionDuration: transitionDuration)
        }

        // Apply special settings
        if let special = recommendation.special {
            applySpecialSettings(special, to: cameraService, transitionDuration: transitionDuration)
        }

        print("✅ AI camera settings applied successfully")
        print("📊 Applied \(appliedSettingsSummary.count) setting changes")
    }

    private func applyExposureSettings(_ exposure: AIExposureSettings, to cameraService: CameraService, transitionDuration: TimeInterval) {
        if let mode = exposure.mode {
            switch mode {
            case "auto":
                cameraService.exposureMode = .auto
                appliedSettingsSummary.append("📷 Exposure mode: Auto")
            case "manual":
                cameraService.exposureMode = .manual
                appliedSettingsSummary.append("📷 Exposure mode: Manual")
            case "aperture_priority":
                cameraService.exposureMode = .priorityAperture
                appliedSettingsSummary.append("📷 Exposure mode: Aperture Priority")
            case "shutter_priority":
                cameraService.exposureMode = .priorityShutter
                appliedSettingsSummary.append("📷 Exposure mode: Shutter Priority")
            case "program":
                cameraService.exposureMode = .program
                appliedSettingsSummary.append("📷 Exposure mode: Program")
            default:
                break
            }
        }

        if let iso = exposure.iso {
            appliedSettingsSummary.append("🔆 ISO: \(Int(iso))")
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.2) { [weak cameraService] in
                cameraService?.setISO(CGFloat(iso))
            }
        }

        if let shutterSpeed = exposure.shutterSpeed {
            let shutterFraction = Int(1.0 / shutterSpeed)
            appliedSettingsSummary.append("⚡ Shutter: 1/\(shutterFraction)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.4) { [weak cameraService] in
                cameraService?.setShutterSpeed(CMTime(seconds: Double(shutterSpeed), preferredTimescale: 1000000))
            }
        }

        if let aperture = exposure.aperture {
            appliedSettingsSummary.append("🔵 Aperture: f/\(aperture)")
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.6) { [weak cameraService] in
                cameraService?.aperture = CGFloat(aperture)
            }
        }

        if let evBias = exposure.evBias {
            appliedSettingsSummary.append("📊 EV Bias: \(evBias > 0 ? "+" : "")\(evBias)EV")
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.8) { [weak cameraService] in
                cameraService?.setExposureBias(CGFloat(evBias))
            }
        }
    }

    private func applyFocusSettings(_ focus: AIFocusSettings, to cameraService: CameraService, transitionDuration: TimeInterval) {
        if let mode = focus.mode {
            switch mode {
            case "auto":
                cameraService.focusMode = .auto
            case "manual":
                cameraService.focusMode = .manual
            case "continuous":
                cameraService.focusMode = .continuous
            case "single":
                cameraService.focusMode = .single
            default:
                break
            }
        }

        if let distance = focus.distance {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.3) { [weak cameraService] in
                cameraService?.setFocusDistance(CGFloat(distance))
            }
        }

        if let pointOfInterest = focus.pointOfInterest, pointOfInterest.count >= 2 {
            let point = CGPoint(x: CGFloat(pointOfInterest[0]), y: CGFloat(pointOfInterest[1]))
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.5) { [weak cameraService] in
                cameraService?.focus(at: point)
            }
        }
    }

    private func applyWhiteBalanceSettings(_ wb: AIWhiteBalanceSettings, to cameraService: CameraService, transitionDuration: TimeInterval) {
        if let preset = wb.preset {
            switch preset {
            case "auto":
                cameraService.wbPreset = .auto
            case "sunny":
                cameraService.wbPreset = .sunny
            case "cloudy":
                cameraService.wbPreset = .cloudy
            case "shade":
                cameraService.wbPreset = .shade
            case "tungsten":
                cameraService.wbPreset = .tungsten
            case "fluorescent":
                cameraService.wbPreset = .fluorescent
            default:
                break
            }
            cameraService.applyWhiteBalancePreset(cameraService.wbPreset)
        }

        if let temperature = wb.temperature {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.7) { [weak cameraService] in
                cameraService?.setWhiteBalanceTemperature(CGFloat(temperature), tint: wb.tint != nil ? CGFloat(wb.tint!) : 0.0)
            }
        }
    }

    private func applyProcessingSettings(_ processing: AIProcessingSettings, to cameraService: CameraService, transitionDuration: TimeInterval) {
        if let brightness = processing.brightness {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.2) { [weak cameraService] in
                cameraService?.setBrightness(CGFloat(brightness))
            }
        }

        if let contrast = processing.contrast {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.4) { [weak cameraService] in
                cameraService?.setContrast(CGFloat(contrast))
            }
        }

        if let saturation = processing.saturation {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.6) { [weak cameraService] in
                cameraService?.setSaturation(CGFloat(saturation))
            }
        }

        if let sharpness = processing.sharpness {
            cameraService.sharpness = CGFloat(sharpness)
        }

        if let filter = processing.filter {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.8) { [weak cameraService] in
                if let cameraFilter = CameraFilter(rawValue: filter) {
                    cameraService?.setFilter(cameraFilter)
                }
            }
        }
    }

    private func applySpecialSettings(_ special: AISpecialSettings, to cameraService: CameraService, transitionDuration: TimeInterval) {
        if let nightMode = special.nightMode {
            switch nightMode {
            case "off":
                cameraService.nightMode = .off
            case "auto":
                cameraService.nightMode = .auto
            case "on":
                cameraService.nightMode = .on
            default:
                break
            }
            cameraService.setNightMode(cameraService.nightMode)
        }

        if let stabilization = special.stabilization {
            switch stabilization {
            case "off":
                cameraService.stabilizationMode = .off
            case "on":
                cameraService.stabilizationMode = .on
            case "cinematic":
                cameraService.stabilizationMode = .cinematic
            default:
                break
            }
        }

        if let zoom = special.zoom {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.5) { [weak cameraService] in
                cameraService?.setZoom(factor: CGFloat(zoom))
            }
        }

        if let flash = special.flash {
            switch flash {
            case "off":
                cameraService.flashMode = .off
            case "on":
                cameraService.flashMode = .on
            case "auto":
                cameraService.flashMode = .auto
            default:
                break
            }
        }

        if let hdr = special.hdr {
            cameraService.hdrMode = hdr
        }

        if let burstMode = special.burstMode {
            switch burstMode {
            case "off":
                cameraService.burstMode = .off
            case "low":
                cameraService.burstMode = .low
            case "medium":
                cameraService.burstMode = .medium
            case "high":
                cameraService.burstMode = .high
            default:
                break
            }
        }
    }

    // MARK: - Processing Timeout Handling
    
    private func startProcessingTimeout() {
        // Clear any existing timer
        processingTimeoutTimer?.invalidate()
        
        // Start new timeout timer
        processingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: processingTimeoutInterval, repeats: false) { [weak self] _ in
            self?.handleProcessingTimeout()
        }
        
        print("⏰ Started processing timeout timer for \(processingTimeoutInterval) seconds")
    }
    
    private func clearProcessingTimeout() {
        processingTimeoutTimer?.invalidate()
        processingTimeoutTimer = nil
        print("✅ Cleared processing timeout timer")
    }
    
    private func handleProcessingTimeout() {
        print("⏰ Processing timeout reached after \(processingTimeoutInterval) seconds")
        
        DispatchQueue.main.async {
            if let viewModel = self.cameraViewModel {
                viewModel.showProcessingTimeout()
            }
        }
        
        // Clear the timer
        processingTimeoutTimer = nil
    }

    // MARK: - Camera Settings from WebSocket
    
    private func handleCameraSettingsFromWebSocket(_ settings: CameraSettings) {
        // Check throttling to prevent rapid setting changes
        let now = Date()
        guard now.timeIntervalSince(lastCameraSettingsApplied) >= cameraSettingsThrottleInterval else {
            print("   ⏱️ Camera settings throttled - ignoring (last applied \(String(format: "%.1f", now.timeIntervalSince(lastCameraSettingsApplied)))s ago)")
            return
        }
        
        guard let cameraService = cameraService else {
            print("   ❌ Camera service not available for applying settings")
            return
        }
        
        // Apply settings on background thread to prevent FPS drops
        DispatchQueue.global(qos: .userInitiated).async {
            let appliedSettings = cameraService.applyCameraSettingsFromWebSocket(settings)
            
            DispatchQueue.main.async {
                if appliedSettings.isEmpty {
                    print("   ℹ️ No camera settings were applied")
                } else {
                    print("   ✅ Applied \(appliedSettings.count) camera settings:")
                    for setting in appliedSettings {
                        print("     - \(setting)")
                    }
                }
                
                // Hide camera settings overlay if it's showing
                if let viewModel = self.cameraViewModel {
                    viewModel.hideCameraSettingsOverlay()
                }
                
                // Update throttling timestamp
                self.lastCameraSettingsApplied = now
            }
        }
    }

    // MARK: - AI Settings Management

    /// Get information about currently applied AI settings
    func getAppliedAISettingsInfo() -> [String] {
        if appliedSettingsSummary.isEmpty {
            return ["🤖 AI settings: None applied yet"]
        }

        var summary = ["🤖 AI Applied Settings:"]
        summary.append(contentsOf: appliedSettingsSummary)

        if let lastSettings = lastAppliedAISettings {
            summary.append("📝 Reasoning: \(lastSettings.reasoning)")
            summary.append("🎯 Confidence: \(Int(lastSettings.confidence * 100))%")
        }

        return summary
    }

    // MARK: - Backend Upload Methods

    func uploadPhotoToBackend(image: UIImage,
                             userId: String,
                             isGenerated: Bool = false,
                             metadata: PhotoMetadata? = nil) async throws -> APIPhoto {

        let urlString = "\(Configuration.shared.databaseAPIBaseURL)/api/pictures/upload"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        // Resize and compress image to reduce file size
        let resizedImage = resizeImageForUpload(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Check file size and compress further if needed
        let finalImageData: Data
        if imageData.count > 2 * 1024 * 1024 { // If larger than 2MB
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.3) else {
                throw URLError(.cannotDecodeContentData)
            }
            finalImageData = compressedData
            print("📦 Compressed photo from \(imageData.count) to \(compressedData.count) bytes")
        } else {
            finalImageData = imageData
        }

        let fileName = "photo_\(UUID().uuidString).jpg"
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Create multipart form data
        var body = Data()

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(finalImageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add userId
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append(userId.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Add isGenerated
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"isGenerated\"\r\n\r\n".data(using: .utf8)!)
        body.append((isGenerated ? "true" : "false").data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Add metadata if provided
        if let metadata = metadata {
            // Convert PhotoMetadata to JSON data
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let metadataData = try encoder.encode(metadata)

                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"metadata\"\r\n\r\n".data(using: .utf8)!)
                body.append(metadataData)
                body.append("\r\n".data(using: .utf8)!)
            } catch {
                print("⚠️ Failed to encode metadata: \(error)")
            }
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("📤 Backend Photo Upload Request:")
        print("URL: \(urlString)")
        print("File size: \(finalImageData.count) bytes")
        print("User ID: \(userId)")
        print("Is Generated: \(isGenerated)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("📥 Backend Photo Upload Response Status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 201 {
            let uploadResponse = try JSONDecoder().decode(PhotoUploadResponse.self, from: data)
            print("✅ Photo uploaded to backend successfully: \(uploadResponse.picture._id)")
            return uploadResponse.picture
        }

        // Generic error
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        print("❌ Backend photo upload failed with status \(httpResponse.statusCode): \(errorMessage)")
        throw NSError(domain: "BackendUpload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
    }



    func uploadReferenceImageToBackend(image: UIImage,
                                       referenceType: String,
                                       userId: String) async throws -> (reference: ReferenceImage, genderResult: GenderDetectionResult?) {

        let urlString = "\(Configuration.shared.databaseAPIBaseURL)/api/references/upload?userId=\(userId)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        // Resize and compress image to reduce file size
        let resizedImage = resizeImageForUpload(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Check file size and compress further if needed
        let finalImageData: Data
        if imageData.count > 2 * 1024 * 1024 { // If larger than 2MB
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.3) else {
                throw URLError(.cannotDecodeContentData)
            }
            finalImageData = compressedData
            print("📦 Compressed reference image from \(imageData.count) to \(compressedData.count) bytes")
        } else {
            finalImageData = imageData
        }

        let fileName = "ref_\(UUID().uuidString)_\(referenceType).jpg"
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Create multipart form data
        var body = Data()

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(finalImageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add reference_type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"reference_type\"\r\n\r\n".data(using: .utf8)!)
        body.append(referenceType.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("📤 Backend Reference Image Upload Request:")
        print("URL: \(urlString)")
        print("Reference Type: \(referenceType)")
        print("File size: \(finalImageData.count) bytes")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("📥 Backend Reference Upload Response Status: \(httpResponse.statusCode)")

        // Handle different response codes
        if httpResponse.statusCode == 201 {
            // Success - parse success response
            let uploadResponse = try JSONDecoder().decode(ReferenceImageUploadResponse.self, from: data)
            print("✅ Reference image uploaded to backend successfully: \(uploadResponse.reference_image._id)")

            return (reference: uploadResponse.reference_image, genderResult: uploadResponse.gender_detection)

        } else if httpResponse.statusCode == 400 {
            // Gender detection rejection - parse error response
            if let errorResponse = try? JSONDecoder().decode(ReferenceUploadError.self, from: data) {
                print("❌ Reference upload rejected: \(errorResponse.error)")
                throw NSError(domain: "BackendUpload", code: 400, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])
            }
        }

        // Generic error
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        print("❌ Backend upload failed with status \(httpResponse.statusCode): \(errorMessage)")
        throw NSError(domain: "BackendUpload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
    }

    private func resizeImageForUpload(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2048
        let minDimension: CGFloat = 1024

        let size = image.size
        var newSize = size

        // If image is too large, scale it down
        if size.width > maxDimension || size.height > maxDimension {
            let aspectRatio = size.width / size.height
            if size.width > size.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
        }

        // If image is too small, scale it up to minimum size
        if size.width < minDimension && size.height < minDimension {
            let aspectRatio = size.width / size.height
            if size.width < size.height {
                newSize = CGSize(width: minDimension, height: minDimension / aspectRatio)
            } else {
                newSize = CGSize(width: minDimension * aspectRatio, height: minDimension)
            }
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }


}
