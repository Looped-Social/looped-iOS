import SwiftUI
import AVKit

// MARK: - Full Screen Video Player (Native SwiftUI VideoPlayer)
struct VideoPlayerSheet: View {
    let videoUrl: String
    @Binding var isPresented: Bool

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        player?.pause()
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
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
