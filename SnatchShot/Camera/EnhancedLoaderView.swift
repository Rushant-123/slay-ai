import SwiftUI
import AVFoundation

struct EnhancedLoaderView: View {
    @State private var progress: Double = 0.0
    @State private var currentMessageIndex = 0
    @State private var messageTimer: Timer?
    @State private var progressTimer: Timer?
    @State private var usedMessageIndices: Set<Int> = []

    let messages = [
        "Serving main-character energy…",
        "Finding your best angles…",
        "Sprinkling a little camera magic…",
        "Prepping your power pose…",
        "Perfecting the glow, hold tight…",
        "Polishing that unstoppable main-character glow now…"
    ]

    var currentMessage: String {
        messages[currentMessageIndex % messages.count]
    }

    private var videoLoader: some View {
        Group {
            // Try to load video directly from bundle
            if let videoURL = Bundle.main.url(forResource: "VgsrhsRx4m", withExtension: "mp4") {
                VideoPlayerInline(url: videoURL)
                    .frame(width: 250, height: 250)
                    .onAppear {
                        print("🎬 EnhancedLoaderView: VideoPlayerInline VIEW appeared - VIDEO SHOULD BE PLAYING NOW")
                    }
            } else {
                // Fallback
                Circle()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 250, height: 250)
                    .overlay(
                        Text("NO VIDEO")
                            .foregroundColor(.white)
                            .font(.caption)
                    )
                    .onAppear {
                        print("🎬 EnhancedLoaderView: ERROR - Video URL not found!")
                    }
            }
        }
    }

    private var messageOverlay: some View {
        VStack {
            Spacer()
            Text(currentMessage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                videoLoader
                messageOverlay
            }
            .onAppear {
                print("🎬 EnhancedLoaderView: Main ZStack (video + message) appeared")
            }
            .onDisappear {
                print("🎬 EnhancedLoaderView: Main ZStack (video + message) disappeared")
            }

            // Progress Bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .frame(width: CGFloat(progress) * 250, height: 8)
                    .animation(.linear(duration: 1), value: progress)
            }
            .frame(width: 250)
        }
        .onAppear {
            print("🎬 EnhancedLoaderView appeared - starting timers")
            startTimers()
        }
        .onDisappear {
            print("🎬 EnhancedLoaderView disappeared - stopping timers")
            stopTimers()
        }
    }

    private func startTimers() {
        print("🎬 Starting loader timers and progress animation")
        
        // Message cycling timer (every 4 seconds, cycle through all before repeating)
        messageTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation {
                // If all messages have been used, reset the set
                if self.usedMessageIndices.count >= self.messages.count {
                    self.usedMessageIndices.removeAll()
                }

                // Get available indices (not yet used in this cycle)
                let availableIndices = (0..<self.messages.count).filter { !self.usedMessageIndices.contains($0) }

                // Pick a random available index
                if let randomIndex = availableIndices.randomElement() {
                    self.currentMessageIndex = randomIndex
                    self.usedMessageIndices.insert(randomIndex)
                }
            }
        }

        // Progress timer (starts at 18 seconds, continues if loading takes longer)
        let updateInterval: TimeInterval = 0.1
        var currentStep = 0

        progressTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            currentStep += 1
            let elapsedTime = Double(currentStep) * updateInterval

            // First 15 seconds: progress from 0% to 95%
            if elapsedTime <= 15.0 {
                // Linear progress from 0% to 95% over 15 seconds
                self.progress = (elapsedTime / 15.0) * 0.95
            }
            // After 15 seconds, slowly continue from 95% toward 100%
            else {
                // Very slow progress from 95% to 99% over time (takes about 40 more seconds to reach 99%)
                let progressFrom95 = min((elapsedTime - 15.0) / 40.0, 0.04) // Max 4% additional progress
                self.progress = 0.95 + progressFrom95
            }

            // Timer continues indefinitely until completeProgress() is called
        }
    }

    private func stopTimers() {
        messageTimer?.invalidate()
        messageTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // Method to complete progress when response arrives
    func completeProgress() {
        withAnimation(.easeOut(duration: 1.0)) {
            progress = 1.0
        }
        stopTimers()
    }

    // Method to reset loader for reuse
    func resetLoader() {
        print("🎬 EnhancedLoaderView: Resetting loader for reuse - ENSURING VIDEO LOADER IS VISIBLE")
        stopTimers()
        progress = 0.0
        currentMessageIndex = 0
        usedMessageIndices.removeAll() // Reset used message tracking

        // Video is loaded directly in the view now - no setup needed
        print("🎬 EnhancedLoaderView: resetLoader completed - video loads inline and should be visible for 3+ seconds")
    }
}

struct VideoPlayerInline: UIViewRepresentable {
    let url: URL
    let id = UUID() // Unique identifier for debugging

    func makeUIView(context: Context) -> UIView {
        print("🎬 VideoPlayerInline[\(id)]: Creating UIView")

        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true

        // Set initial frame to a reasonable size
        let initialSize = CGSize(width: 250, height: 250)
        view.frame = CGRect(origin: .zero, size: initialSize)

        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        playerLayer.isHidden = false
        playerLayer.opacity = 1.0
        playerLayer.zPosition = 1

        view.layer.addSublayer(playerLayer)

        // Setup looping
        context.coordinator.setupLooping(for: player)

        // Start playing
        player.play()

        print("🎬 VideoPlayerInline[\(id)]: Video player created and started")
        print("🎬 VideoPlayerInline[\(id)]: Player rate: \(player.rate), status: \(player.status.rawValue)")
        print("🎬 VideoPlayerInline[\(id)]: Layer frame: \(playerLayer.frame), hidden: \(playerLayer.isHidden), opacity: \(playerLayer.opacity)")
        print("🎬 VideoPlayerInline[\(id)]: View sublayers count: \(view.layer.sublayers?.count ?? 0)")

        // Check status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎬 VideoPlayerInline[\(id)]: Status after 0.5s - rate: \(player.rate)")
            if let currentItem = player.currentItem {
                print("🎬 VideoPlayerInline[\(id)]: Current item status: \(currentItem.status.rawValue)")
                if currentItem.status == .failed {
                    print("🎬 VideoPlayerInline[\(id)]: ERROR - Playback failed: \(currentItem.error?.localizedDescription ?? "Unknown error")")
                }
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        private var loopObserver: NSObjectProtocol?

        func setupLooping(for player: AVPlayer) {
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
                print("🎬 VideoPlayerInline: Video looped")
            }
        }

        deinit {
            if let observer = loopObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
