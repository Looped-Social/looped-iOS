import SwiftUI
import AVKit

// MARK: - Full Screen Video Player (Native SwiftUI VideoPlayer)
struct VideoPlayerSheet: View {
    let videoUrl: String
    @Binding var isPresented: Bool

    @State private var player: AVPlayer?
    @State private var isInvalidUrl = false

    var body: some View {
        ZStack {
            Color.loopedBlack.ignoresSafeArea()

            if isInvalidUrl {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.loopedCustom(size: 44))
                        .foregroundColor(.loopedWhite.opacity(0.7))
                    Text("Couldn't load this video")
                        .font(.loopedSubheadlineScaled)
                        .foregroundColor(.loopedWhite.opacity(0.8))
                }
            } else if let player = player {
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
                    Button {
                        player?.pause()
                        isPresented = false
                    } label: {
                        Image("minimize-icon")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.loopedWhite)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.loopedBlack.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Exit Full Screen")
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            isInvalidUrl = false
            let cleaned = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                isInvalidUrl = true
                return
            }
            guard let url = URL(string: cleaned) ?? URLComponents(string: cleaned)?.url else {
                isInvalidUrl = true
                return
            }
            player = AVPlayer(url: url)
            player?.play()
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
