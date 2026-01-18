import SwiftUI
import AVKit

// MARK: - Full Screen Video Player (Native SwiftUI VideoPlayer)
struct VideoPlayerSheet: View {
    let videoUrl: String
    @Binding var isPresented: Bool

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.loopedBlack.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.loopedWhite)
                    .scaleEffect(1.5)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    LoopedCloseButton(
                        action: {
                            player?.pause()
                            isPresented = false
                        },
                        foregroundColor: .loopedWhite,
                        iconSize: 20,
                        hitArea: 44,
                        showsBackground: true,
                        backgroundColor: .loopedBlack,
                        backgroundOpacity: 0.5
                    )
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            if let url = URL(string: videoUrl) {
                player = AVPlayer(url: url)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

#Preview {
    VideoPlayerSheet(
        videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        isPresented: .constant(true)
    )
}
