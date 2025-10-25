import SwiftUI
import Combine

struct PoseSuggestionsOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    let capturedImage: UIImage
    let startWithLoader: Bool // Controls whether to start with main loader
    let poseSuggestionsEnabled: Bool
    let cameraSettingsEnabled: Bool
    let userId: String?
    let onMinimizedStateChanged: ((Bool) -> Void)?

    init(capturedImage: UIImage,
         startWithLoader: Bool,
         poseSuggestionsEnabled: Bool,
         cameraSettingsEnabled: Bool,
         userId: String?,
         onMinimizedStateChanged: ((Bool) -> Void)? = nil) {
        self.capturedImage = capturedImage
        self.startWithLoader = startWithLoader
        self.poseSuggestionsEnabled = poseSuggestionsEnabled
        self.cameraSettingsEnabled = cameraSettingsEnabled
        self.userId = userId
        self.onMinimizedStateChanged = onMinimizedStateChanged
    }
    @State private var suggestions: [PoseSuggestion] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var isOverlayExpanded = true // Controls overlay visibility
    @State private var loaderView = EnhancedLoaderView()
    @State private var showPreviewOverlay = false // Controls when to show pose suggestions vs main loader
    @State private var showShimmerCards = false // Controls when to show shimmer cards
    @State private var showGallery = false
    @State private var selectedImage: UIImage?
    @State private var hasProcessedCurrentImage = false // Track if we've already processed this image
    @State private var statusMessage = "Processing..." // Animated status message

    // Shared WebSocket service from environment
    @EnvironmentObject private var webSocketService: WebSocketService
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            if isOverlayExpanded {
                // Expanded overlay - covers bottom 50%
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Toggle button at very top edge (centered)
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isOverlayExpanded.toggle()
                                    onMinimizedStateChanged?(!isOverlayExpanded)
                                }
                            }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 23)
                                    .background(Color(red: 0.075, green: 0.082, blue: 0.102).opacity(0.7))
                                    .clipShape(Capsule())
                            }
                            .offset(y: -30) // Move button much higher to sit on the very top edge
                            Spacer()
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 0)
                        
                        // Content area
                        VStack(spacing: 16) {
                            // Show loading, error, or suggestions based on state
                            if !showPreviewOverlay {
                                // Main loader until first image arrives
                                VStack {
                                    loaderView
                                        .onAppear {
                                            print("🎬 Loader animation now visible on screen")
                                        }
                                }
                                .padding()
                            } else if let error = error {
                                VStack {
                                    Text("Error loading suggestions")
                                        .foregroundColor(.white)
                                    Button("Retry") {
                                        Task {
                                            hasProcessedCurrentImage = false // Reset flag to allow reprocessing
                                            await processCapturedImage()
                                            hasProcessedCurrentImage = true
                                        }
                                    }
                                    .foregroundColor(.blue)
                                }
                                .padding()
                            } else {
                                // Pose suggestions preview
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // Force view update by depending on suggestions count
                                        let currentSuggestions = suggestions
                                        let suggestionCount = suggestions.count

                                        // Debug: Log suggestions count
                                        let _ = print("🎨 Rendering suggestions view - count: \(suggestionCount)")

                                        // Show completed suggestions
                                        ForEach(0..<currentSuggestions.count, id: \.self) { index in
                                            let suggestion = currentSuggestions[index]
                                            Button {
                                                // Extract image and navigate to gallery
                                                if let imageData = Data(base64Encoded: suggestion.image),
                                                   let uiImage = UIImage(data: imageData) {
                                                    // Use image exactly as received from socket - no rotation or modification
                                                    print("🖼️ Gallery navigation: using original image dimensions: \(uiImage.size)")
                                                    selectedImage = uiImage
                                                    showGallery = true
                                                }
                                            } label: {
                                                SimplePoseSuggestionCard(suggestion: suggestion)
                                            }
                                            .frame(width: 160, height: 280)
                                        }

                                        // Add placeholders for remaining expected images (max 4 total)
                                        if showShimmerCards {
                                            let analysis = webSocketService.getCapturedAnalysis()
                                            let remainingSlots = 4 - currentSuggestions.count
                                            ForEach(0..<min(remainingSlots, analysis.count), id: \.self) { index in
                                                let analysisIndex = currentSuggestions.count + index
                                                if let suggestion = analysis[safe: analysisIndex] {
                                                    ShimmeringPoseCard(suggestion: suggestion)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                }
                                .frame(height: 300)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.5) // 50% of screen
                    .background(Color.black.opacity(0.95))
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                }
                .edgesIgnoringSafeArea(.bottom) // Connect to bottom edge
            } else {
                // Minimized state - arrow button below shutter
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // Show loading indicator when processing, otherwise show expand button
                        if !showPreviewOverlay && isLoading {
                            // Loading state - show progress indicator (tappable to expand)
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isOverlayExpanded = true
                                }
                            }) {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                    Text(statusMessage)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.white.opacity(0.8))
                                }
                                .frame(width: 100, height: 50)
                                .background(Color.black.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            // Normal expand button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isOverlayExpanded.toggle()
                                    onMinimizedStateChanged?(!isOverlayExpanded)
                                }
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 23)
                                    .background(Color(red: 0.075, green: 0.082, blue: 0.102).opacity(0.7))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 140) // Position higher above status indicators
                }
            }
        }
    .onAppear {
        print("🖼️ PoseSuggestionsOverlayView appeared with image size: \(capturedImage.size)")
        print("🖼️ Image scale: \(capturedImage.scale)")
        print("🖼️ Image orientation: \(capturedImage.imageOrientation.rawValue)")

        // View may persist across images, so check if we need to reset
        print("🔄 Overlay view appeared - checking if reset needed")

        // Reset state for new image processing
        resetForNewImage()

        // Set up WebSocket handlers
        setupWebSocket()
    }
    .onChange(of: capturedImage) { oldImage, newImage in
        print("🖼️ PoseSuggestionsOverlayView: capturedImage changed from \(oldImage.size) to \(newImage.size)")

        // Reset state when image changes (view persists but content updates)
        resetForNewImage()
        hasProcessedCurrentImage = false  // Allow reprocessing

        // Re-setup WebSocket event handlers after reset
        setupWebSocket()

        // Restart processing with new image
        Task {
            print("🖼️ PoseSuggestionsOverlayView: Starting image processing task")
            await processCapturedImage()
        }
    }
    .task {
        // Fallback: also try to process on appear if onChange didn't trigger
        print("🖼️ PoseSuggestionsOverlayView: Task executed")
        if !hasProcessedCurrentImage {
            print("🖼️ PoseSuggestionsOverlayView: Processing image in task")
            await processCapturedImage()
            hasProcessedCurrentImage = true
        }
    }
        .onDisappear {
            // Keep WebSocket connected for faster subsequent requests
            // Just cancel event handlers to prevent duplicate events
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
            print("🔌 WebSocket kept connected for faster subsequent requests")
        }
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView(preselectedImage: selectedImage)
                .preferredColorScheme(.dark)
        }
    }
    
    private func setupWebSocket() {
        print("🔌 Setting up WebSocket event handlers")

                // Handle processing UI ready - start showing cards after analysis and animation
        webSocketService.onProcessingUIReady
            .receive(on: DispatchQueue.main)
            .sink { suggestion in
                print("🎯 Processing UI ready - adding suggestion to cards view: \(suggestion.title)")
                // Log dimensions as received from socket
                if let imageData = Data(base64Encoded: suggestion.image),
                   let uiImage = UIImage(data: imageData) {
                    print("📏 Socket image dimensions: \(uiImage.size), orientation: \(uiImage.imageOrientation.rawValue)")
                }
                DispatchQueue.main.async {
                    // Add each suggestion as it arrives (may be multiple from initial batch)
                    if !self.suggestions.contains(where: { $0.id == suggestion.id }) {
                        self.suggestions.append(suggestion)
                        print("✅ Added suggestion to processing UI: \(self.suggestions.count) total")
                    }
                }

                // Cache the generated image
                self.cacheGeneratedImage(suggestion)

                // Show processing UI with cards if not already shown
                if !self.showPreviewOverlay {
                    print("🎨 Switching to processing UI with cards")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.showPreviewOverlay = true
                        self.isLoading = false // Stop loading state
                    }
                    self.loaderView.completeProgress()
                }

                // When actual images start arriving, hide shimmer cards
                if self.showShimmerCards {
                    print("🎨 Step 2: Hiding shimmer cards as real images arrive")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.showShimmerCards = false
                    }
                }
            }
            .store(in: &cancellables)

        // Handle first image completed - legacy event, now handled by onProcessingUIReady
        webSocketService.onFirstImageCompleted
            .receive(on: DispatchQueue.main)
            .sink { firstSuggestion in
                print("🎯 First image completed event received (legacy) - ensuring UI is ready")
                // This event might still fire - ensure UI is in correct state
                if !self.showPreviewOverlay {
                    print("🎨 Activating processing UI for first image")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.showPreviewOverlay = true
                        self.isLoading = false
                    }
                    self.loaderView.completeProgress()
                }

                // Ensure first suggestion is added
                if self.suggestions.isEmpty {
                    self.suggestions.append(firstSuggestion)
                    self.cacheGeneratedImage(firstSuggestion)
                    print("✅ Added first suggestion via legacy event: \(self.suggestions.count)")
                }
            }
            .store(in: &cancellables)

        // Handle additional images completed - add to existing suggestions (prevent duplicates)
        webSocketService.onImageCompleted
            .receive(on: DispatchQueue.main)
            .sink { suggestion in
                print("📸 Additional image received after UI ready - adding to suggestions")
                // Log dimensions as received from socket
                if let imageData = Data(base64Encoded: suggestion.image),
                   let uiImage = UIImage(data: imageData) {
                    print("📏 Additional socket image dimensions: \(uiImage.size), orientation: \(uiImage.imageOrientation.rawValue)")
                }
                DispatchQueue.main.async {
                    // Only add if not already present and we haven't reached the limit (prevent duplicates and overflow)
                    if !self.suggestions.contains(where: { $0.id == suggestion.id }) && self.suggestions.count < 4 {
                        self.suggestions.append(suggestion)
                        print("✅ Added additional suggestion, total count: \(self.suggestions.count)")
                    } else {
                        print("⚠️ Suggestion already exists or limit reached, skipping")
                    }
                }

                // Cache the additional generated image
                self.cacheGeneratedImage(suggestion)
            }
            .store(in: &cancellables)

        // Handle image errors
        webSocketService.onImageError
            .receive(on: DispatchQueue.main)
            .sink { (imageIndex, errorMessage) in
                print("❌ Image \(imageIndex) failed: \(errorMessage)")
                // Create a placeholder suggestion for failed images to maintain 4-card layout
                let errorSuggestion = PoseSuggestion(
                    id: "error_\(imageIndex)",
                    image: "", // Empty image for error state
                    title: "Generation Failed",
                    description: "Unable to generate this pose suggestion. Please try again."
                )
                // Add error suggestion to maintain consistent UI layout
                if !self.suggestions.contains(where: { $0.id == errorSuggestion.id }) && self.suggestions.count < 4 {
                    self.suggestions.append(errorSuggestion)
                    print("⚠️ Added error placeholder for failed image \(imageIndex), total count: \(self.suggestions.count)")
                }
            }
            .store(in: &cancellables)

        // Handle content analysis complete - start the card reveal sequence
        webSocketService.onContentAnalysisComplete
            .receive(on: DispatchQueue.main)
            .sink { settings in
                print("🎯 Content analysis complete - starting card reveal sequence")
                DispatchQueue.main.async {
                    // Wait 2 seconds, then show shimmer cards
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.showShimmerCards = true
                            self.statusMessage = "Creating your perfect poses..."
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Handle image generation started
        webSocketService.onImageGenerationStarted
            .receive(on: DispatchQueue.main)
            .sink { requestId in
                print("🎨 Generation started - updating status")
                DispatchQueue.main.async {
                    self.statusMessage = "Creating your perfect poses..."
                }
            }
            .store(in: &cancellables)

        // Handle processing errors
        webSocketService.onProcessingError
            .receive(on: DispatchQueue.main)
            .sink { errorMessage in
                print("💥 Processing error: \(errorMessage)")
                self.error = NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                self.isLoading = false // Stop loading on error
                self.loaderView.completeProgress()
            }
            .store(in: &cancellables)

        // Handle show empty cards signal
        webSocketService.onShowEmptyCards
            .receive(on: DispatchQueue.main)
            .sink {
                print("🎨 Step 1: Showing empty shimmer cards")
                DispatchQueue.main.async {
                    // Show processing UI with empty shimmer cards
                    if !self.showPreviewOverlay {
                        print("🎨 Switching to processing UI with shimmer cards")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.showPreviewOverlay = true
                            self.showShimmerCards = true
                            // Don't stop loading yet - keep it for text animation
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Handle processing completed
        webSocketService.onProcessingCompleted
            .receive(on: DispatchQueue.main)
            .sink {
                print("🎉 All processing completed")
                // Processing is complete, but UI timing is handled separately
            }
            .store(in: &cancellables)
    }

    private func processCapturedImage() async {
        print("🔄 Starting WebSocket-based image processing")

        await MainActor.run {
            // Always start with loader to ensure animation is visible
            isLoading = true
            error = nil
            showPreviewOverlay = false

            // Start fresh loader animation (view persists but state resets)
            loaderView.resetLoader()

            print("🎬 Loader animation initialized - isLoading: \(isLoading), showPreviewOverlay: \(showPreviewOverlay)")
        }

        // Connect to WebSocket and immediately send image (no artificial delay)
        webSocketService.connect()

        // Send the image for processing immediately
        webSocketService.sendImage(capturedImage, poseSuggestionsEnabled: poseSuggestionsEnabled, cameraSettingsEnabled: cameraSettingsEnabled, userId: userId)

        // Note: We don't set isLoading = false here because the WebSocket events will handle UI state changes
        print("📤 Image sent via WebSocket - waiting for events...")

        // Timeout safety net to ensure loader doesn't run forever
        // AI processing can take 15-30 seconds, so we give reasonable time
        DispatchQueue.main.asyncAfter(deadline: .now() + 45.0) {
            if self.isLoading && !self.showPreviewOverlay {
                print("⚠️ Loader timeout - forcing transition to prevent infinite loading")
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.showPreviewOverlay = true
                    self.isLoading = false
                }
                self.loaderView.completeProgress()
                // Don't set error - processing usually completes successfully, timeout is just for stuck states
                print("ℹ️ Loader timed out but processing may still complete in background")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func cacheGeneratedImage(_ suggestion: PoseSuggestion) {
        if let imageData = Data(base64Encoded: suggestion.image),
           let uiImage = UIImage(data: imageData) {
            // Use image exactly as received from socket - no rotation or modification
            print("🖼️ Caching generated pose suggestion with original dimensions: \(uiImage.size)")

            let imageId = suggestion.id
            print("📸 Caching generated pose suggestion with ID: \(imageId)")
            ImageCacheService.shared.cacheImage(uiImage, id: imageId, type: .generated)

            // Verify the image was cached
            if let cachedImage = ImageCacheService.shared.getCachedImage(id: imageId) {
                print("✅ Generated pose suggestion successfully cached: \(imageId)")
            } else {
                print("❌ Failed to cache generated pose suggestion: \(imageId)")
            }
        } else {
            print("❌ Failed to decode base64 image data for suggestion: \(suggestion.id)")
        }
    }

    private func resetForNewImage() {
        print("🔄 Resetting overlay state for new image processing")

        // Reset all state variables
        suggestions = []
        print("🔄 Cleared suggestions - now empty")
        isLoading = false
        error = nil
        isOverlayExpanded = true
        showPreviewOverlay = false
        hasProcessedCurrentImage = false

        // Reset the existing loader view to maintain video continuity
        loaderView.resetLoader()

        print("🔄 PoseSuggestionsOverlayView: State reset complete")

        // Cancel any existing subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Note: Don't reset WebSocket service here - sendImage() will handle it
        // The WebSocket connection stays alive to avoid reconnection delays

        print("✅ Overlay state reset complete")
    }
}

// MARK: - Simple Pose Suggestion Card (without gallery navigation)

struct SimplePoseSuggestionCard: View {
    let suggestion: PoseSuggestion
    @State private var revealProgress: CGFloat = 0.0

    private var correctedImage: UIImage? {
        guard let imageData = Data(base64Encoded: suggestion.image),
              let uiImage = UIImage(data: imageData) else {
            return nil
        }
        // Use image exactly as received from socket - no rotation or modification
        print("🖼️ Card display: using original image dimensions: \(uiImage.size)")
        return uiImage
    }

    var body: some View {
        ZStack {
            // Background card shape
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black)
            
            VStack(spacing: 0) {
                // Top half - Image (50%) - ABSOLUTE edge-to-edge (only if image exists)
                if let image = correctedImage {
                    Image(uiImage: image)
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
                        .onAppear {
                            print("🖼️ Card displaying image with dimensions: \(image.size)")
                        }
                        .offset(x: 0, y: 0) // No offset, perfect alignment
                        .mask(
                            // Reveal mask that animates from top to bottom
                            VStack(spacing: 0) {
                                Rectangle()
                                    .frame(height: 140 * revealProgress)
                                Spacer()
                            }
                            .frame(width: 160, height: 140)
                        )
                        .onAppear {
                            // Start reveal animation after a brief delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeOut(duration: 1.5)) {
                                    revealProgress = 1.0
                                }
                            }
                        }

                    // Bottom half - Text (50%) when image exists
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
                            .foregroundColor(Color.white.opacity(0.9))
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
                } else {
                    // Full card - Text only (when no image - for error states)
                    VStack(alignment: .center, spacing: 12) {
                        Spacer()
                        
                        Text(suggestion.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.5), radius: 1, x: 0, y: 1)
                        
                        Text(suggestion.description)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.8))
                            .lineLimit(6)
                            .multilineTextAlignment(.center)
                            .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.3), radius: 1, x: 0, y: 1)
                        
                        Spacer()
                    }
                    .frame(height: 280) // Full card height
                    .frame(maxWidth: .infinity) // Take full width
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
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

// MARK: - Shimmering Pose Card Placeholder

enum ShimmerMode {
    case wave    // Initial color wave animation
    case pulse   // Continuous pulsing animation until image arrives
}

struct ShimmeringPoseCard: View {
    let suggestion: PhotoSuggestion
    @State private var shimmerPhase: CGFloat = -0.5
    @State private var titleText: String = ""
    @State private var descriptionText: String = ""
    @State private var showImageAnimation = false
    @State private var shimmerMode: ShimmerMode = .wave

    var body: some View {
        ZStack {
            // Background card shape (matches SimplePoseSuggestionCard)
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black)

            VStack(spacing: 0) {
                // Top half - Image area with loading animation
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 140, height: 140)

                    if showImageAnimation {
                        switch shimmerMode {
                        case .wave:
                            // Consistent multicolor shimmer throughout
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.purple.opacity(0.1),  // Same colors as band, lower opacity
                                            Color.blue.opacity(0.15),
                                            Color.cyan.opacity(0.12),
                                            Color.purple.opacity(0.1),
                                            Color.blue.opacity(0.15),
                                            Color.cyan.opacity(0.12),
                                            Color.purple.opacity(0.1)
                                        ]),
                                        startPoint: UnitPoint(x: 0, y: 0),
                                        endPoint: UnitPoint(x: 0, y: 1)
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .overlay(
                                    // Enhanced moving band with same color scheme
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clear,
                                                    Color.purple.opacity(0.8),
                                                    Color.blue.opacity(0.9),
                                                    Color.cyan.opacity(0.8),
                                                    Color.clear
                                                ]),
                                                startPoint: UnitPoint(x: 0, y: 0),
                                                endPoint: UnitPoint(x: 0, y: 1)
                                            )
                                        )
                                        .frame(width: 140, height: 35) // Slightly taller band
                                        .offset(y: (shimmerPhase + 0.5) * 110 - 55) // Move from -55 to 55
                                        .blur(radius: 0.5) // Very soft edges
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                        case .pulse:
                            // Consistent multicolor pulse mode
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.purple.opacity(0.1),  // Same base colors as wave mode
                                            Color.blue.opacity(0.15),
                                            Color.cyan.opacity(0.12),
                                            Color.purple.opacity(0.1),
                                            Color.blue.opacity(0.15),
                                            Color.cyan.opacity(0.12),
                                            Color.purple.opacity(0.1)
                                        ]),
                                        startPoint: UnitPoint(x: 0, y: 0),
                                        endPoint: UnitPoint(x: 0, y: 1)
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .overlay(
                                    // Moving band with same colors as wave mode
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clear,
                                                    Color.purple.opacity(0.8),
                                                    Color.blue.opacity(0.9),
                                                    Color.cyan.opacity(0.8),
                                                    Color.clear
                                                ]),
                                                startPoint: UnitPoint(x: 0, y: 0),
                                                endPoint: UnitPoint(x: 0, y: 1)
                                            )
                                        )
                                        .frame(width: 140, height: 35)
                                        .offset(y: (shimmerPhase + 0.5) * 110 - 55)
                                        .blur(radius: 0.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 15,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 15
                    )
                )

                // Bottom half - Text area with typing animation
                VStack(alignment: .leading, spacing: 8) {
                    // Title with typing animation
                    Text(titleText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 8)
                        .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.5), radius: 1, x: 0, y: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .truncationMode(.tail)

                    // Description with typing animation
                    Text(descriptionText)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.9))
                        .lineLimit(3) // Reduced to ensure it fits
                        .multilineTextAlignment(.leading)
                        .shadow(color: Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.3), radius: 1, x: 0, y: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(height: 140, alignment: .top) // Match the image height, align to top
            }
        }
        .frame(width: 160, height: 280)
        .clipped() // Ensure content doesn't overflow card bounds
        .onAppear {
            // Start wave animation - continuous movement (slower speed)
            Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
                DispatchQueue.main.async {
                    shimmerPhase += 0.025 // Half the speed
                    if shimmerPhase > 1.0 {
                        shimmerPhase = -0.5
                    }
                }
            }

            // Start typing animation for title
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let title = self.suggestion.title {
                    self.typeText(text: title, isTitle: true)
                }
            }

            // Start typing animation for description after title starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if let description = self.suggestion.poseDescription {
                    self.typeText(text: description, isTitle: false)
                }
            }

            // Start wave shimmer animation 1 second after text starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.showImageAnimation = true
                    self.shimmerMode = .wave
                }

                // After wave animation runs for a bit, switch to continuous pulse mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { // Wave for 3 seconds, then pulse
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.shimmerMode = .pulse
                    }
                }
            }
        }
    }

    private func typeText(text: String, isTitle: Bool) {
        let characters = Array(text)
        var currentIndex = 0

        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            if currentIndex < characters.count {
                if isTitle {
                    self.titleText.append(characters[currentIndex])
                } else {
                    self.descriptionText.append(characters[currentIndex])
                }
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}


#Preview {
    PoseSuggestionsOverlayView(capturedImage: UIImage(), startWithLoader: false, poseSuggestionsEnabled: true, cameraSettingsEnabled: false, userId: "test-user-123")
}