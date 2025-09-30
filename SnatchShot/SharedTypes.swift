//
//  SharedTypes.swift
//  SnatchShot
//
//  Created by AI Assistant on 19/09/25.
//

import Foundation
import CoreLocation

// MARK: - Purchase Controller Protocol
protocol PurchaseControllerDelegate: AnyObject {
    func didCompletePurchase(_ productId: String)
    func didFailPurchase(_ error: Error)
    func didRestorePurchases()
    func didStartTrial(_ productId: String)
}

// MARK: - Photo Metadata Types
struct PhotoMetadata: Codable {
    let camera: CameraSettingsMetadata
    let location: LocationMetadata?
    let exif: EXIFMetadata
    let timestamp: Date
    let deviceModel: String
    let osVersion: String
}

struct CameraSettingsMetadata: Codable {
    let iso: Double?
    let shutterSpeed: Double?
    let aperture: Double?
    let focalLength: Double?
    let lens: String?
    let whiteBalance: String?
    let exposureCompensation: Double?
    let flashMode: String?
    let meteringMode: String?
    let lensPosition: Float?
    let focusMode: String?
    let exposureMode: String?
    let flash: String?
    let nightMode: Bool?
    let filter: String?
    let zoom: Double?
    let filterApplied: String?
}

struct LocationMetadata: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double
    let verticalAccuracy: Double?
    let timestamp: Date
    
    init?(from location: CLLocation?) {
        guard let location = location else { return nil }
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.verticalAccuracy > 0 ? location.altitude : nil
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy > 0 ? location.verticalAccuracy : nil
        self.timestamp = location.timestamp
    }
}

struct EXIFMetadata: Codable {
    let make: String?
    let model: String?
    let software: String?
    let imageDescription: String?
    let dateTime: Date?
    let orientation: Int?
    let xResolution: Double?
    let yResolution: Double?
    let resolutionUnit: Int?
    let exposureTime: Double?
    let fNumber: Double?
    let exposureProgram: Int?
    let isoSpeedRatings: [Int]?
    let exifVersion: String?
    let dateTimeOriginal: Date?
    let dateTimeDigitized: Date?
    let componentConfiguration: String?
    let shutterSpeedValue: Double?
    let apertureValue: Double?
    let brightnessValue: Double?
    let exposureBiasValue: Double?
    let meteringMode: Int?
    let flash: Int?
    let focalLength: Double?
    let subjectArea: [Int]?
    let makerNote: Data?
    let subsecTimeOriginal: String?
    let subsecTimeDigitized: String?
    let flashPixVersion: String?
    let colorSpace: Int?
    let pixelXDimension: Int?
    let pixelYDimension: Int?
    let sensingMethod: Int?
    let sceneType: Data?
    let exposureMode: Int?
    let whiteBalance: Int?
    let focalLengthIn35mmFilm: Int?
    let sceneCaptureType: Int?
    let lensSpecification: [Double]?
    let lensMake: String?
    let lensModel: String?
    let lensSerialNumber: String?
}

// MARK: - Additional Metadata Types

struct CPUInfo: Codable {
    let processorCount: Int?
    let activeProcessorCount: Int?
    let physicalMemory: UInt64?
}

struct MemoryInfo: Codable {
    let totalMemory: UInt64?
    let availableMemory: UInt64?
    let usedMemory: UInt64?
    let memoryPressure: String?
}

struct StorageInfo: Codable {
    let totalSpace: Int64?
    let availableSpace: Int64?
    let usedSpace: Int64?
}

struct BatteryInfo: Codable {
    let level: Float
    let state: Int
    let isLowPowerMode: Bool
}

struct NetworkInfo: Codable {
    let connectionType: String?
    let isConnected: Bool?
    let wifiSSID: String?
    let cellularType: String?
    let carrierName: String?
    let signalStrength: Int?
}

struct CameraHardwareInfo: Codable {
    let cameraModel: String?
    let sensorSize: String?
    let pixelSize: Double?
    let focalLength: Float?
    let aperture: Float?
    let hasFlash: Bool
    let hasTorch: Bool
    let supportsDepth: Bool
    let supportsHDR: Bool
    let supportsRAW: Bool
    let maxZoom: Float?
    let minISO: Float?
    let maxISO: Float?
    let lensCount: Int?
    let model: String?
    let maxZoomFactor: Double?
}

struct DeviceMotionData: Codable {
    let accelerometer: [String: Double]?
    let gyroscope: [String: Double]?
    let magnetometer: [String: Double]?
    let attitude: [String: Double]?
    let gravity: [String: Double]?
    let rotationRate: [String: Double]?
    let userAcceleration: [String: Double]?
}

struct AccelerometerData: Codable {
    let x: Double?
    let y: Double?
    let z: Double?
    let timestamp: Date
}

struct PerformanceMetrics: Codable {
    let captureTime: TimeInterval
    let processingTime: TimeInterval?
    let memoryUsage: UInt64?
    let cpuUsage: Double?
    let gpuUsage: Double?
    let frameRate: Double?
    let droppedFrames: Int?
}

struct EnvironmentalData: Codable {
    let temperature: Double?
    let humidity: Double?
    let pressure: Double?
    let lightLevel: Double?
    let ambientNoise: Double?
}

struct ImageAnalysis: Codable {
    let dominantColors: [String]?
    let brightness: Double?
    let contrast: Double?
    let saturation: Double?
}

struct AccessibilitySettings: Codable {
    let voiceOverEnabled: Bool
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let increaseContrast: Bool
    let boldText: Bool
    let largerText: Bool?
    let grayscale: Bool
    let invertColors: Bool
}

struct UserPreferences: Codable {
    let language: String?
    let region: String?
    let calendar: String?
    let measurementSystem: String?
    let temperatureUnit: String?
    let currencyCode: String?
    let firstWeekday: Int?
    let timeZone: String?
}

struct DebugInfo: Codable {
    let sessionId: String
    let buildConfiguration: String
    let compilerFlags: String?
    let optimizationLevel: String?
    let debugSymbols: Bool?
    let crashReports: Bool?
    let memoryLeaks: Bool?
    let threadCount: Int?
}

struct SecurityInfo: Codable {
    let isJailbroken: Bool
    let hasPasscode: Bool?
    let biometricType: String
    let securityLevel: String?
    let encryptionEnabled: Bool?
    let vpnActive: Bool?
}

struct ConnectivityInfo: Codable {
    let wifiEnabled: Bool?
    let bluetoothEnabled: Bool?
    let cellularEnabled: Bool?
    let hotspotEnabled: Bool?
    let airplaneMode: Bool?
}

struct PowerManagement: Codable {
    let lowPowerModeEnabled: Bool?
    let batteryOptimizationEnabled: Bool?
}

struct AudioInfo: Codable {
    let hasMicrophone: Bool?
    let audioInputAvailable: Bool?
    let audioOutputAvailable: Bool?
    let volumeLevel: Float?
    let muteSwitch: Bool?
    let audioFormat: String?
    let sampleRate: Double?
    let bitDepth: Int?
}

struct ARInfo: Codable {
    let arkitSupported: Bool
    let lidarAvailable: Bool?
    let faceTracking: Bool?
    let worldTracking: Bool?
    let imageTracking: Bool?
    let objectScanning: Bool?
    let peopleOcclusion: Bool?
}


struct EXIFData: Codable {
    let aperture: Double?
    let shutter_speed: Double?
    let iso: Int?
    let focal_length: Double?
    let lens_make: String?
    let lens_model: String?
    let camera_make: String?
    let camera_model: String?
}

// MARK: - Device Info (Shared between services)

struct DeviceInfo: Codable {
    let model: String?
    let systemName: String?
    let systemVersion: String?
    let name: String?
}

struct EnhancedDeviceInfo: Codable {
    let model: String?
    let system_name: String?
    let system_version: String?
    let device_name: String?
}


// MARK: - Shared Types

/// Photo type enum to help with filtering and categorization
public enum PhotoType: String, Codable {
    case original
    case generated
    case all
}
