//
//  ImageCacheService.swift
//  SnatchShot
//
//  Created by AI Assistant on 19/09/25.
//

import Foundation
import UIKit

// Image rotation is handled by the rotateToCorrectOrientation extension in Extensions.swift

// MARK: - Shared Types
// PhotoType is now defined in SharedTypes.swift

// MARK: - Cached Photo Model

struct CachedPhoto: Codable {
    let id: String
    let imageData: Data
    let type: PhotoType
    let timestamp: Date
    var metadata: [String: Any]? // Not Codable due to [String: Any]

    enum CodingKeys: String, CodingKey {
        case id, imageData, type, timestamp
        // metadata is not included in Codable
    }

    init(id: String, image: UIImage, type: PhotoType, timestamp: Date = Date(), metadata: [String: Any]? = nil) {
        print("📸 Caching image \(id): orientation = \(image.imageOrientation.rawValue), size = \(image.size)")
        // Image should already be rotated correctly by CameraViewModel
        self.id = id
        self.imageData = image.jpegData(compressionQuality: 0.9) ?? Data()
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        imageData = try container.decode(Data.self, forKey: .imageData)
        type = try container.decode(PhotoType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        metadata = nil // Metadata not persisted with Codable
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        // metadata is not encoded
    }

    func getImage() -> UIImage? {
        return UIImage(data: imageData)
    }
}

// MARK: - Image Cache Service

class ImageCacheService {
    static let shared = ImageCacheService()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private let maxCacheSize: Int = 500 * 1024 * 1024 // 500MB
    private let maxCacheAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    private init() {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("SnatchShotImages")

        print("📁 ImageCacheService cache directory: \(cacheDirectory.path)")

        // Create cache directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                print("✅ Created cache directory: \(cacheDirectory.path)")
            } catch {
                print("❌ Failed to create cache directory: \(error)")
            }
        } else {
            print("✅ Cache directory already exists: \(cacheDirectory.path)")
        }
    }

    // MARK: - Cache Operations

    func cacheImage(_ image: UIImage, id: String, type: PhotoType, metadata: [String: Any]? = nil) {
        let cachedPhoto = CachedPhoto(id: id, image: image, type: type, metadata: metadata)
        saveToDisk(cachedPhoto)

        // Clean up old files if cache is getting too large
        DispatchQueue.global(qos: .background).async {
            self.cleanupCacheIfNeeded()
        }
    }

    func getCachedImage(id: String) -> UIImage? {
        guard let cachedPhoto = loadFromDisk(id: id) else { return nil }
        return cachedPhoto.getImage()
    }

    func getAllCachedPhotos(type: PhotoType? = nil) -> [CachedPhoto] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        var cachedPhotos: [CachedPhoto] = []

        for fileURL in fileURLs where fileURL.pathExtension == "cache" {
            if let cachedPhoto = loadFromDisk(url: fileURL) {
                if type == nil || cachedPhoto.type == type {
                    cachedPhotos.append(cachedPhoto)
                }
            }
        }

        // Sort by timestamp (newest first)
        return cachedPhotos.sorted { $0.timestamp > $1.timestamp }
    }

    func deleteCachedImage(id: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(id).cache")
        try? fileManager.removeItem(at: fileURL)
    }

    func clearCache() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for fileURL in fileURLs {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Private Methods

    private func saveToDisk(_ cachedPhoto: CachedPhoto) {
        let fileURL = cacheDirectory.appendingPathComponent("\(cachedPhoto.id).cache")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cachedPhoto)
            try data.write(to: fileURL)
            print("💾 Successfully saved cached photo: \(cachedPhoto.id) to \(fileURL.path)")
        } catch {
            print("❌ Failed to save cached photo \(cachedPhoto.id): \(error)")
        }
    }

    private func loadFromDisk(id: String) -> CachedPhoto? {
        let fileURL = cacheDirectory.appendingPathComponent("\(id).cache")
        return loadFromDisk(url: fileURL)
    }

    private func loadFromDisk(url: URL) -> CachedPhoto? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedPhoto.self, from: data)
        } catch {
            print("❌ Failed to load cached photo: \(error)")
            return nil
        }
    }

    private func cleanupCacheIfNeeded() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]) else {
            return
        }

        var totalSize: Int = 0
        var filesWithInfo: [(url: URL, date: Date, size: Int)] = []

        for fileURL in fileURLs {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               let fileSize = attributes[.size] as? Int {
                totalSize += fileSize
                filesWithInfo.append((url: fileURL, date: creationDate, size: fileSize))
            }
        }

        // If cache is too large or has old files, clean up
        if totalSize > maxCacheSize {
            // Sort by creation date (oldest first)
            filesWithInfo.sort { $0.date < $1.date }

            // Remove oldest files until we're under the limit
            for fileInfo in filesWithInfo {
                if totalSize <= maxCacheSize {
                    break
                }

                try? fileManager.removeItem(at: fileInfo.url)
                totalSize -= fileInfo.size
            }
        }

        // Remove files older than maxCacheAge
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)
        for fileInfo in filesWithInfo {
            if fileInfo.date < cutoffDate {
                try? fileManager.removeItem(at: fileInfo.url)
            }
        }
    }

    // MARK: - Cache Statistics

    func getCacheSize() -> (fileCount: Int, totalSize: Int) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return (0, 0)
        }

        var totalSize = 0
        for fileURL in fileURLs {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int {
                totalSize += fileSize
            }
        }

        return (fileURLs.count, totalSize)
    }
}
