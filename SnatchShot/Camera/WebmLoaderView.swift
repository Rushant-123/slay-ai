import SwiftUI
import AVFoundation

struct WebmLoaderView: UIViewRepresentable {
    let videoURL: URL
    let desiredSize: CGSize?

    init(videoURL: URL, desiredSize: CGSize? = nil) {
        self.videoURL = videoURL
        self.desiredSize = desiredSize
        print("🎬 VideoLoaderView: INIT - URL: \(videoURL.lastPathComponent)")
    }

    func makeUIView(context: Context) -> UIView {
        print("🎬 VideoLoaderView: makeUIView called")

        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.layer.cornerRadius = (desiredSize?.width ?? 250) / 2

        // Create and setup video player immediately
        do {
            let player = AVPlayer(url: videoURL)
            let playerLayer = AVPlayerLayer(player: player)

            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.frame = CGRect(origin: .zero, size: desiredSize ?? CGSize(width: 250, height: 250))

            view.layer.addSublayer(playerLayer)

            // Setup looping
            context.coordinator.setupLooping(for: player)

            // Start playing
            player.play()

            print("🎬 VideoLoaderView: Video player created and started")
        } catch {
            print("🎬 VideoLoaderView: ERROR creating player: \(error)")
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update frame if needed
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = CGRect(origin: .zero, size: desiredSize ?? CGSize(width: 250, height: 250))
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
                print("🎬 VideoLoaderView: Video looped")
            }
        }

        deinit {
            if let observer = loopObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
