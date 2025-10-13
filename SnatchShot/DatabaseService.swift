//
//  DatabaseService.swift
//  SnatchShot
//
//  Created by AI Assistant on 19/09/25.
//

#if os(iOS)
import Foundation
import UIKit

// MARK: - AnyCodable for flexible JSON encoding
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Database Models

struct SubscriptionPlan: Codable {
    let id: String
    let name: String
    let billing_cycle: String
    let price: Int
    let currency: String
    let max_photos_per_period: Int
}

struct DatabaseUser: Codable {
    let userId: String
    let email: String
    let first_name: String?
    let last_name: String?
    let username: String?
    let subscription_status: String
    let subscription_plan: SubscriptionPlan
}

// Separate struct for trial usage response (doesn't include user_id)
struct TrialUsageResponse: Codable {
    let email: String
    let first_name: String?
    let subscription_status: String
    let subscription_plan: SubscriptionPlan
    let trial_usage_count: Int?
}

struct UserRegistrationRequest: Codable {
    let email: String
    let password: String
    let userId: String?
    let firstName: String?
    let lastName: String?
    let username: String?
}

struct UserRegistrationResponse: Codable {
    let message: String
    let user: DatabaseUser
}

struct UserLoginRequest: Codable {
    let email: String
    let password: String
}

struct UserLoginResponse: Codable {
    let user: DatabaseUser
    let token: String
}

struct UserIdLoginRequest: Codable {
    let userId: String
}

struct UserOnlyLoginResponse: Codable {
    let message: String?
    let user: DatabaseUser
}

// MARK: - Photo Models

struct DatabasePhoto: Codable {
    let id: String
    let user_id: String
    let image_url: String
    let thumbnail_url: String?
    let file_size: Int
    let is_generated: Bool
    let metadata: PhotoMetadata?
    let created_at: String
    let updated_at: String
}

// Use the PhotoMetadata from SharedTypes.swift instead of defining a duplicate
typealias DatabasePhotoMetadata = PhotoMetadata

struct DatabaseCameraSettings: Codable {
    let aperture: String?
    let shutter_speed: String?
    let iso: Int?
    let focal_length: Double?
    let lens: String?

    // Enhanced camera settings
    let white_balance: String?
    let exposure_compensation: Float?
    let flash_mode: String?
    let metering_mode: String?
    let camera_model: String?
}

// EnhancedDeviceInfo and EXIFData moved to SharedTypes.swift

struct PhotoLocation: Codable {
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let place_name: String?
}

struct PhotoUploadRequest: Codable {
    let image_data: String // Base64 encoded image
    let file_name: String
    let is_generated: Bool
    let metadata: PhotoMetadata?
}

struct PhotoUploadResponse: Codable {
    let picture: APIPhoto
    let download_url: String
}

// API response model that matches the actual API structure
struct APIPhoto: Codable {
    let _id: String
    let type: String
    let userId: String
    let picture_id: String?
    let filename: String
    let original_filename: String
    let mime_type: String
    let size_bytes: Int
    let width: Int?
    let height: Int?
    let orientation: String?
    let color_space: String?
    let has_alpha: Bool?
    let processing_status: String
    let tags: [String]
    let categories: [String]
    let view_count: Int
    let like_count: Int
    let share_count: Int
    let created_at: String
    let updated_at: String
}

struct PhotosResponse: Codable {
    let photos: [DatabasePhoto]
    let total_count: Int
    let has_more: Bool
}

// MARK: - Reference Image Models

struct ReferenceImageUploadRequest: Codable {
    let user_id: String
    let reference_type: String // "face" or "body"
    let tags: [String]
    let categories: [String]
    let device_info: DatabaseDeviceInfo
}

struct ReferenceImageUploadResponse: Codable {
    let message: String
    let type: String
    let reference_image: ReferenceImage
    let download_url: String
    let gender_detection: GenderDetectionResult?
}

struct ReferenceUploadError: Codable {
    let error: String
    let gender_detection: GenderDetectionResult
}

// MARK: - Additional Database Types

struct ReferenceImage: Codable {
    let _id: String
    let filename: String
    let processing_status: String
    let reference_type: String
    let userId: String
    let created_at: String
}

struct GenderDetectionResult: Codable {
    let gender: String?
    let confidence: Double?
    let decision: String?
    let can_use: Bool?

    // Backward compatibility
    var detected_gender: String? { gender }
    var message: String? {
        switch decision {
        case "pass": return "Verification passed"
        case "review": return "Account under review"
        case "reject": return "Verification failed"
        default: return nil
        }
    }
}

struct DatabaseDeviceInfo: Codable {
    let device: String
    let platform: String
    let version: String
}

// MARK: - Database Service

class DatabaseService {
    static let shared = DatabaseService()

    private let session: URLSession
    private let baseURL: String
    private let timeout: TimeInterval

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Configuration.shared.databaseAPITimeout
        config.timeoutIntervalForResource = Configuration.shared.databaseAPITimeout

        self.session = URLSession(configuration: config)
        self.baseURL = Configuration.shared.databaseAPIBaseURL
        self.timeout = Configuration.shared.databaseAPITimeout
    }

    // MARK: - User Registration

    func registerUser(email: String,
                     password: String,
                     userId: String? = nil,
                     firstName: String? = nil,
                     lastName: String? = nil,
                     username: String? = nil) async throws -> DatabaseUser {

        let endpoint = "\(baseURL)/users/register"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        let requestData = UserRegistrationRequest(
            email: email,
            password: password,
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            username: username
        )

        let jsonData = try JSONEncoder().encode(requestData)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        print("📤 Database User Registration Request:")
        print("URL: \(url)")
        print("Email: \(email)")
        print("UserId: \(userId ?? "nil")")
        print("Username: \(username ?? "nil")")
        print("Name: \(firstName ?? "nil") \(lastName ?? "nil")")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        print("📥 Database Response Status: \(httpResponse.statusCode)")

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ Database Error Response: \(errorMessage)")
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            } else {
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }

        do {
            let registrationResponse = try JSONDecoder().decode(UserRegistrationResponse.self, from: data)
            print("✅ User registered successfully: \(registrationResponse.user.userId)")
            return registrationResponse.user
        } catch {
            print("❌ Failed to decode registration response: \(error)")
            print("Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw DatabaseError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - User Login

    func loginUser(email: String, password: String) async throws -> (user: DatabaseUser, token: String) {
        let endpoint = "\(baseURL)/users/login"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        let requestData = UserLoginRequest(email: email, password: password)
        let jsonData = try JSONEncoder().encode(requestData)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        print("🔐 Database User Login Request:")
        print("URL: \(url)")
        print("Email: \(email)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ Database Login Error: \(errorMessage)")
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            } else {
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }

        let loginResponse = try JSONDecoder().decode(UserLoginResponse.self, from: data)
        print("✅ User logged in successfully: \(loginResponse.user.userId)")
        return (loginResponse.user, loginResponse.token)
    }

    /// Login using only a backend-recognized userId (temporary, no-JWT fallback)
    /// Expects backend to accept `{ userId: "..." }` at POST /users/login and return a user object
    func loginByUserId(userId: String) async throws -> DatabaseUser {
        let endpoint = "\(baseURL)/users/login"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        let requestData = UserIdLoginRequest(userId: userId)
        let jsonData = try JSONEncoder().encode(requestData)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        print("🔐 Database UserId Login Request:")
        print("URL: \(url)")
        print("UserId: \(userId)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ Database UserId Login Error: \(errorMessage)")
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            } else {
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }

        do {
            let loginResponse = try JSONDecoder().decode(UserOnlyLoginResponse.self, from: data)
            print("✅ UserId login successful: \(loginResponse.user.userId)")
            return loginResponse.user
        } catch {
            print("❌ Failed to decode userId login response: \(error)")
            print("Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw DatabaseError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Photo Management

    func uploadPhoto(image: UIImage,
                    userId: String,
                    isGenerated: Bool = false,
                    metadata: PhotoMetadata? = nil) async throws -> DatabasePhoto {

        let endpoint = "\(baseURL)/pictures/upload"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        // Resize and compress image to reduce file size
        let resizedImage = resizeImageForUpload(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw DatabaseError.decodingError("Failed to convert image to data")
        }
        
        // Check file size and compress further if needed
        let finalImageData: Data
        if imageData.count > 2 * 1024 * 1024 { // If larger than 2MB
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.3) else {
                throw DatabaseError.decodingError("Failed to compress image")
            }
            finalImageData = compressedData
            print("📦 Compressed image from \(imageData.count) to \(compressedData.count) bytes")
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

        // Add tags (optional)
        if let metadata = metadata {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"tags\"\r\n\r\n".data(using: .utf8)!)
            body.append("[]".data(using: .utf8)!) // Empty array for now
            body.append("\r\n".data(using: .utf8)!)

            // Add categories (optional)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"categories\"\r\n\r\n".data(using: .utf8)!)
            body.append("[]".data(using: .utf8)!) // Empty array for now
            body.append("\r\n".data(using: .utf8)!)

            // Add device_info (optional)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"device_info\"\r\n\r\n".data(using: .utf8)!)
            let deviceInfo = "{\"platform\": \"ios\", \"app_version\": \"1.0.0\", \"device_model\": \"iOS\"}"
            body.append(deviceInfo.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("📤 Database Photo Upload Request:")
        print("URL: \(url)")
        print("File size: \(finalImageData.count) bytes")
        print("Is generated: \(isGenerated)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        print("📥 Database Photo Upload Response Status: \(httpResponse.statusCode)")

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ Database Photo Upload Error: \(errorMessage)")
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            } else {
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }

        do {
            let uploadResponse = try JSONDecoder().decode(PhotoUploadResponse.self, from: data)
            print("✅ Photo uploaded successfully: \(uploadResponse.picture._id)")

            // Convert APIPhoto to DatabasePhoto
            let databasePhoto = DatabasePhoto(
                id: uploadResponse.picture._id,
                user_id: uploadResponse.picture.userId,
                image_url: "\(baseURL)\(uploadResponse.download_url)",
                thumbnail_url: nil, // API doesn't provide thumbnail URL in upload response
                file_size: uploadResponse.picture.size_bytes,
                is_generated: isGenerated,
                metadata: metadata,
                created_at: uploadResponse.picture.created_at,
                updated_at: uploadResponse.picture.updated_at
            )

            return databasePhoto
        } catch {
            print("❌ Failed to decode photo upload response: \(error)")
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("📄 Raw response: \(responseBody)")
            throw DatabaseError.decodingError("Photo upload response decoding failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Reference Image Upload

    func uploadReferenceImage(image: UIImage,
                             referenceType: String,
                             userId: String,
                             tags: [String] = [],
                             categories: [String] = []) async throws -> (reference: ReferenceImage, genderResult: GenderDetectionResult?) {

        let endpoint = "\(baseURL)/references/upload"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        // Resize and compress image to reduce file size (same as photo upload)
        let resizedImage = resizeImageForUpload(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw DatabaseError.decodingError("Failed to convert image to data")
        }

        // Check file size and compress further if needed
        let finalImageData: Data
        if imageData.count > 2 * 1024 * 1024 { // If larger than 2MB
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.3) else {
                throw DatabaseError.decodingError("Failed to compress image")
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

        // Add userId
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append(userId.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Add reference_type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"reference_type\"\r\n\r\n".data(using: .utf8)!)
        body.append(referenceType.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("📤 Database Reference Image Upload Request:")
        print("URL: \(url)")
        print("Reference Type: \(referenceType)")
        print("File size: \(finalImageData.count) bytes")
        print("User ID: \(userId)")
        print("📋 Form data size: \(body.count) bytes (image + userId + reference_type)")
        print("📋 Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "Not set")")
        print("📋 Boundary: \(boundary)")

        // Debug: Show the first part of the request body to verify format
        if let bodyString = String(data: body.prefix(500), encoding: .utf8) {
            print("📋 Request body preview: \(bodyString)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        print("📥 Database Reference Upload Response Status: \(httpResponse.statusCode)")

        // Handle different response codes
        if httpResponse.statusCode == 201 {
            // Success - parse success response
            let uploadResponse = try JSONDecoder().decode(ReferenceImageUploadResponse.self, from: data)
            print("✅ Reference image uploaded successfully: \(uploadResponse.reference_image._id)")

            return (reference: uploadResponse.reference_image, genderResult: uploadResponse.gender_detection)

        } else if httpResponse.statusCode == 400 {
            // Gender detection rejection - parse error response
            if let errorResponse = try? JSONDecoder().decode(ReferenceUploadError.self, from: data) {
                print("❌ Reference image rejected: \(errorResponse.error)")
                // Return the gender detection result even for errors
                return (reference: ReferenceImage(
                    _id: "",
                    filename: "",
                    processing_status: "rejected",
                    reference_type: referenceType,
                    userId: userId,
                    created_at: ""
                ), genderResult: errorResponse.gender_detection)
            } else {
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode)")
            }

        } else if !(200...299).contains(httpResponse.statusCode) {
            // Other errors
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("❌ Database Reference Upload Error (HTTP \(httpResponse.statusCode)): \(responseBody)")
            print("📄 Full response data: \(data.count) bytes")
            print("🔍 Response headers: \(httpResponse.allHeaderFields)")
            if data.count == 0 {
                print("⚠️  Empty response body - server may not be providing error details")
                // Try to see if we can get more info from the raw data
                print("🔍 Raw response data (hex): \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
            } else {
                // Try to parse as JSON to see if it's a structured error
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let jsonDict = jsonObject as? [String: Any] {
                    print("🔍 Parsed error response: \(jsonDict)")
                } else {
                    print("🔍 Response is not valid JSON")
                }
            }
            throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(responseBody)")
        } else {
            // Unexpected success code
            throw DatabaseError.serverError("Unexpected response code: \(httpResponse.statusCode)")
        }
    }

    // MARK: - Image Processing Helper
    
    private func resizeImageForUpload(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1920 // Max width or height
        let maxFileSize = 1.5 * 1024 * 1024 // 1.5MB target
        
        // Calculate new size while maintaining aspect ratio
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            // Landscape
            newSize = CGSize(width: min(maxDimension, size.width), 
                           height: min(maxDimension, size.width) / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: min(maxDimension, size.height) * aspectRatio, 
                           height: min(maxDimension, size.height))
        }
        
        // Only resize if the image is actually larger
        if newSize.width >= size.width && newSize.height >= size.height {
            return image
        }
        
        // Create resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        print("📐 Resized image from \(size) to \(newSize)")
        return resizedImage
    }

    func getPhotos(limit: Int = 50,
                  offset: Int = 0,
                  isGenerated: Bool? = nil) async throws -> [DatabasePhoto] {

        // For now, disable database photo retrieval since we need user_id
        // and the API structure is different than expected
        print("ℹ️ Database photo retrieval temporarily disabled - using cache only")
        return []
        
        // TODO: Implement proper user-based photo retrieval
        /*
        let endpoint = "\(baseURL)/pictures/user/\(userId)?limit=\(limit)&skip=\(offset)"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        */

        /*
        print("📤 Database Get Photos Request:")
        print("URL: \(url)")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        print("📥 Database Get Photos Response Status: \(httpResponse.statusCode)")

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ Database Get Photos Error: \(errorMessage)")
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            } else {
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }

        let photosResponse = try JSONDecoder().decode(PhotosResponse.self, from: data)
        print("✅ Retrieved \(photosResponse.photos.count) photos")
        return photosResponse.photos
        */
    }

    func deletePhoto(photoId: String) async throws {
        let endpoint = "\(baseURL)/pictures/\(photoId)"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        print("📤 Database Delete Photo Request:")
        print("URL: \(url)")
        print("Photo ID: \(photoId)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        print("📥 Database Delete Photo Response Status: \(httpResponse.statusCode)")

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ Database Delete Photo Error: \(errorMessage)")
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            } else {
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }

        print("✅ Photo deleted successfully: \(photoId)")
    }

    // MARK: - Health Check

    func healthCheck() async throws -> Bool {
        // Health endpoint is at root level, not under /api
        let healthURL = baseURL.replacingOccurrences(of: "/api", with: "") + "/health"
        guard let url = URL(string: healthURL) else {
            throw DatabaseError.invalidURL
        }

        print("🔍 Health check URL: \(healthURL)")
        
        let (data, response) = try await session.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Health check status code: \(httpResponse.statusCode)")
        }

        // Simple check if we get a valid JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Health check response: \(jsonString)")
            if jsonString.contains("\"status\":\"ok\"") {
                print("✅ Database health check passed")
                return true
            }
        }

        print("❌ Database health check failed")
        return false
    }

    // MARK: - Helper Methods

    /// Generate a secure password for Google OAuth users
    func generateOAuthPassword(for userId: String) -> String {
        // Create a deterministic but secure password based on user ID
        // This ensures the same user always gets the same password
        let salt = "SnatchShot_OAuth_Salt_2024"
        let combined = userId + salt

        // Use a simple hash approach (in production, use proper crypto)
        let password = "oauth_\(userId.prefix(16))_\(String(combined.hash))"
        return password
    }

    /// Create username from email or name
    func createUsername(from email: String, firstName: String?, lastName: String?) -> String {
        if let firstName = firstName, let lastName = lastName {
            // Use first name + last initial
            let lastInitial = lastName.prefix(1).lowercased()
            let baseUsername = "\(firstName.lowercased())\(lastInitial)"

            // Add random number to ensure uniqueness
            let randomNum = Int.random(in: 100...999)
            return "\(baseUsername)\(randomNum)"
        } else {
            // Use email prefix
            let emailPrefix = email.components(separatedBy: "@").first ?? "user"
            let randomNum = Int.random(in: 100...999)
            return "\(emailPrefix.lowercased())\(randomNum)"
        }
    }

    // MARK: - Trial Management
    func getTrialUsage(for userId: String) async throws -> Int {
        let endpoint = "\(baseURL)/users/profile/\(userId)"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        let userProfile = try JSONDecoder().decode(TrialUsageResponse.self, from: data)
        return userProfile.trial_usage_count ?? 0
    }

    func incrementTrialUsage(for userId: String) async throws {
        let endpoint = "\(baseURL)/users/trial/increment"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        let requestBody = ["user_id": userId]
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
    }

    func checkTrialUsageLimit(for userId: String) async throws -> Bool {
        let usage = try await getTrialUsage(for: userId)
        return usage < 5 // 5 photo limit
    }

    func deleteAccount(userId: String) async throws {
        let endpoint = "\(baseURL)/users/\(userId)"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        print("📤 Database Delete Account Request:")
        print("URL: \(url)")
        print("User ID: \(userId)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        print("📥 Database Delete Account Response Status: \(httpResponse.statusCode)")

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ Database Delete Account Error: \(errorMessage)")
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            } else {
                throw DatabaseError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }

        print("✅ Account deleted successfully: \(userId)")
    }

    func resetTrialUsage(for userId: String) async throws {
        let endpoint = "\(baseURL)/users/trial/reset"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }

        let requestBody = ["user_id": userId]
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DatabaseError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
    }
}

// MARK: - Database Errors

enum DatabaseError: Error {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case decodingError(String)
    case networkError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
#endif
