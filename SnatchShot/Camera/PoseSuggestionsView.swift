import SwiftUI
import UIKit

// Analytics
import Foundation

// MARK: - Array Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - API Response Models
struct ApiResponse: Decodable {
    let settings: Settings?
    let analysis: Analysis?
    let generatedImages: [GeneratedImage]
}

struct Settings: Decodable {
    let aperture: Any?
    
    // We'll decode this manually since aperture can be either String or Dictionary
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // Try to decode aperture as String first, then as Dictionary
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "aperture")) {
            self.aperture = stringValue
        } else if let dictValue = try? container.decodeIfPresent([String: Any].self, forKey: DynamicCodingKeys(stringValue: "aperture")) {
            self.aperture = dictValue
        } else {
            self.aperture = nil
        }
    }
}

// For handling dynamic keys in JSON
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// Extension to handle decoding of [String: Any]
extension KeyedDecodingContainer {
    func decodeIfPresent(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any]? {
        guard let value = try? self.decodeNil(forKey: key), !value else {
            return nil
        }
        let container = try self.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key)
        var dict: [String: Any] = [:]
        for key in container.allKeys {
            if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: key) {
                dict[key.stringValue] = boolValue
            } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
                dict[key.stringValue] = stringValue
            } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
                dict[key.stringValue] = intValue
            } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
                dict[key.stringValue] = doubleValue
            } else if let nestedDict = try? container.decodeIfPresent([String: Any].self, forKey: key) {
                dict[key.stringValue] = nestedDict
            }
        }
        return dict
    }
}

struct Analysis: Decodable {
    let photoImprovementSuggestions: [PhotoSuggestion]?
    
    private enum CodingKeys: String, CodingKey {
        case photoImprovementSuggestions = "photo_improvement_suggestions"
    }
}

struct PhotoSuggestion: Decodable {
    let title: String?
    let poseDescription: String?
    let facialExpression: String?
    let cameraAngle: String?
    
    private enum CodingKeys: String, CodingKey {
        case title
        case poseDescription = "pose_description"
        case facialExpression = "facial_expression"
        case cameraAngle = "camera_angle"
    }
}

struct GeneratedImage: Decodable {
    let data: String?
    let mimeType: String?
}

// MARK: - View Model
struct PoseSuggestion: Identifiable {
    let id: String
    let image: String // base64 encoded image
    let title: String
    let description: String

    init(from generatedImage: GeneratedImage, index: Int, analysis: PhotoSuggestion?) {
        self.id = UUID().uuidString
        self.image = generatedImage.data ?? ""
        self.title = analysis?.title ?? "Pose \(index + 1)"
        self.description = analysis?.poseDescription ?? ""
    }

    // WebSocket-specific initializer
    init(id: String, image: String, title: String, description: String = "") {
        self.id = id
        self.image = image
        self.title = title
        self.description = description
    }
}

struct PoseSuggestionsView: View {
    @Environment(\.dismiss) private var dismiss
    let capturedImage: UIImage
    let poseSuggestionsEnabled: Bool
    let cameraSettingsEnabled: Bool
    let userId: String?
    @State private var suggestions: [PoseSuggestion] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showGallery = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with buttons
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                        Image(systemName: "xmark")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Handle gallery button action
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding()
            .background(Color(red: 0.85, green: 0.85, blue: 1.0)) // Lavender background
            
            // Top half - captured image
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.5) // Top half of screen
                .background(Color(red: 0.85, green: 0.85, blue: 1.0)) // Lavender background
                .onAppear {
                    print("🖼️ PoseSuggestionsView appeared with image size: \(capturedImage.size)")
                    print("🖼️ Image scale: \(capturedImage.scale)")
                    print("🖼️ Image orientation: \(capturedImage.imageOrientation.rawValue)")
                    print("🖼️ Image orientation description: \(orientationDescription(capturedImage.imageOrientation))")
                }
            
            // Bottom half - popup with suggestions
            VStack(spacing: 0) {
                Spacer()
                
                // Content in the middle
                Group {
                    if isLoading {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Loading pose suggestions...")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    } else if let error = error {
                        VStack {
                            Text("Error loading suggestions")
                                .foregroundColor(.white)
                            Button("Retry") {
                                Task {
                                    await processCapturedImage()
                                }
                            }
                            .foregroundColor(.blue)
                        }
                    } else {
                        // Display pose suggestions
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(suggestions) { suggestion in
                                    PoseSuggestionCard(
                                        suggestion: suggestion,
                                        showGallery: $showGallery,
                                        selectedImage: $selectedImage
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 220)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.height * 0.5) // Bottom half of screen
            .background(Color.black.opacity(0.9))
            .cornerRadius(20, corners: [.topLeft, .topRight])
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .task {
            await processCapturedImage()
        }
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView(preselectedImage: selectedImage)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            // Track pose suggestions viewed
            AnalyticsService.shared.trackPoseSuggestionViewed(suggestionCount: 0) // Will be updated when suggestions load
        }
    }
    
    private func orientationDescription(_ orientation: UIImage.Orientation) -> String {
        switch orientation {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        case .upMirrored: return "upMirrored"
        case .downMirrored: return "downMirrored"
        case .leftMirrored: return "leftMirrored"
        case .rightMirrored: return "rightMirrored"
        @unknown default: return "unknown"
        }
    }
    
    private func processCapturedImage() async {
        print("🔄 Starting processCapturedImage")
        await MainActor.run {
            isLoading = true
            error = nil
        }
        print("🔄 Set isLoading = true")

        do {
            // Convert image to JPEG data (optimized for speed)
            guard let imageData = capturedImage.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "PoseSuggestionsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
            }

            // Create URL request
            var request = URLRequest(url: URL(string: "http://13.221.107.42:4000/process-image")!)
            request.httpMethod = "POST"

            // Create multipart form data
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // Create body
            var body = Data()

            // Add image data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"test-image.jpg\"\r\n".data(using: .utf8)!)
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
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
                body.append(userId.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }

            // Add closing boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            // Make API request
            let (data, response) = try await URLSession.shared.data(for: request)

            let httpResponse = response as? HTTPURLResponse
            guard let statusCode = httpResponse?.statusCode,
                  (200...299).contains(statusCode) else {
                print("❌ HTTP Error: Status code \(httpResponse?.statusCode ?? -1)")
                throw NSError(domain: "PoseSuggestionsView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server returned an error"])
            }

            // Log response size for debugging
            print("🔍 API Response size: \(data.count) bytes")

            // Parse response
            let decoder = JSONDecoder()
            do {
                let apiResponse = try decoder.decode(ApiResponse.self, from: data)
                print("✅ Successfully parsed API response")
                print("✅ Generated Images: \(apiResponse.generatedImages.count)")
                if let analysis = apiResponse.analysis {
                    print("✅ Analysis received with \(analysis.photoImprovementSuggestions?.count ?? 0) suggestions")
                }

                // Convert generated images to suggestions
                let suggestions = apiResponse.generatedImages.enumerated().map { index, image in
                    PoseSuggestion(
                        from: image,
                        index: index,
                        analysis: apiResponse.analysis?.photoImprovementSuggestions?[safe: index]
                    )
                }
                print("✅ Created \(suggestions.count) suggestions")

                // Cache the generated images
                for suggestion in suggestions {
                    if let imageData = Data(base64Encoded: suggestion.image),
                       let uiImage = UIImage(data: imageData) {
                        let imageId = suggestion.id
                        print("📸 Caching generated pose suggestion with ID: \(imageId)")
                        ImageCacheService.shared.cacheImage(uiImage, id: imageId, type: .generated)

                        // Verify the image was cached
                        if let cachedImage = ImageCacheService.shared.getCachedImage(id: imageId) {
                            print("✅ Generated pose suggestion successfully cached: \(imageId)")
                        } else {
                            print("❌ Failed to cache generated pose suggestion: \(imageId)")
                        }
                    }
                }

                await MainActor.run {
                    self.suggestions = suggestions
                    // Update pose suggestions viewed count
                    AnalyticsService.shared.trackPoseSuggestionViewed(suggestionCount: suggestions.count)
                }
            } catch {
                print("❌ JSON Parsing Error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("❌ Missing key '\(key.stringValue)' at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("❌ Type mismatch for '\(context.codingPath.last?.stringValue ?? "")': expected \(type)")
                        print("   Debug: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("❌ Missing value for '\(context.codingPath.last?.stringValue ?? "")': expected \(type)")
                    case .dataCorrupted(let context):
                        print("❌ Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("❌ Unknown decoding error: \(error)")
                    }
                }

                // Try to parse as dictionary to see the structure
                if let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("📝 Response structure:")
                    dict.keys.forEach { key in
                        print("   - \(key): \(type(of: dict[key]!))")
                    }
                }

                throw error
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }

        await MainActor.run {
            isLoading = false
        }
        print("🔄 Set isLoading = false")
    }
}

struct PoseSuggestionCard: View {
    let suggestion: PoseSuggestion
    @Binding var showGallery: Bool
    @Binding var selectedImage: UIImage?
    
    var body: some View {
        Button {
            // Track pose suggestion selected
            AnalyticsService.shared.trackPoseSuggestionSelected(suggestionId: suggestion.id, suggestionTitle: suggestion.title)

            // Extract image and navigate to gallery
            if let imageData = Data(base64Encoded: suggestion.image),
               let uiImage = UIImage(data: imageData) {
                selectedImage = uiImage
                showGallery = true
            }
        } label: {
            ZStack {
                // Background card shape
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black)
            
            VStack(spacing: 0) {
                // Top half - Image (50%) - ABSOLUTE edge-to-edge
                if let imageData = Data(base64Encoded: suggestion.image),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 140) // Exact card dimensions
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 15,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 15
                            )
                        )
                        .offset(x: 0, y: 0) // No offset, perfect alignment
                }
                
                // Bottom half - Text (50%)
                VStack(alignment: .leading, spacing: 8) {
                    Text(suggestion.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 8) // Extra spacing from image
                        .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.5), radius: 1, x: 0, y: 1)
                    
                    Text(suggestion.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.3), radius: 1, x: 0, y: 1)
                    
                    Spacer()
                }
                .frame(height: 140) // 50% height only
                .frame(maxWidth: .infinity) // Take full width
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.black)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 15,
                        bottomTrailingRadius: 15,
                        topTrailingRadius: 0
                    )
                )
            }
        }
        .frame(width: 160, height: 280)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.9),
                            Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8),
                            Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    PoseSuggestionsView(capturedImage: UIImage(), poseSuggestionsEnabled: true, cameraSettingsEnabled: false, userId: "test-user-123")
}

// MARK: - UIImage Extension for Orientation Fix
extension UIImage {
    func fixedOrientation() -> UIImage {
        // If the image orientation is already correct, return the original
        if imageOrientation == .up {
            return self
        }
        
        // Calculate the proper size for the rotated image
        var transform = CGAffineTransform.identity
        var outputSize = size
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
            outputSize = CGSize(width: size.height, height: size.width)
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
            outputSize = CGSize(width: size.height, height: size.width)
            
        default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        default:
            break
        }
        
        // Create the graphics context with the corrected size
        UIGraphicsBeginImageContextWithOptions(outputSize, false, scale)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return self
        }
        
        context.concatenate(transform)
        
        // Draw the image
        draw(in: CGRect(origin: .zero, size: size))
        
        // Get the corrected image
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        
        // Clean up the context
        UIGraphicsEndImageContext()
        
        return correctedImage
    }
}
