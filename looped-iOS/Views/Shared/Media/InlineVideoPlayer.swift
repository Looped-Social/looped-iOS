import SwiftUI
import AVFoundation
import UIKit

private struct InlineVideoFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

final class InlineVideoPlaybackCoordinator: ObservableObject {
    static let shared = InlineVideoPlaybackCoordinator()
    @Published var activeVideoId: String?

    func requestPlayback(id: String) {
        if activeVideoId != id {
            activeVideoId = id
        }
    }
}

final class InlineVideoPlayerViewModel: ObservableObject {
    let player: AVPlayer

    @Published var isMuted: Bool
    @Published var isPlaying: Bool = false
    @Published var isReady: Bool = false
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0

    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?
    private var didPlayToEndObserver: NSObjectProtocol?
    private var isScrubbing = false

    init(url: URL?, startsMuted: Bool = true) {
        if let url {
            self.player = AVPlayer(url: url)
        } else {
            self.player = AVPlayer()
        }
        self.isMuted = startsMuted
        player.isMuted = startsMuted

        let item = player.currentItem
        itemStatusObserver = item?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isReady = item.status == .readyToPlay
            }
        }

        durationObserver = item?.observe(\.duration, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            let seconds = item.duration.seconds
            DispatchQueue.main.async {
                self.duration = seconds.isFinite ? max(seconds, 0) : 0
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            guard !self.isScrubbing else { return }
            let seconds = time.seconds
            self.currentTime = seconds.isFinite ? max(seconds, 0) : 0
        }

        didPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.player.seek(to: .zero)
            if self.isPlaying {
                self.player.play()
            }
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let didPlayToEndObserver {
            NotificationCenter.default.removeObserver(didPlayToEndObserver)
        }
        itemStatusObserver = nil
        durationObserver = nil
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        player.isMuted = muted
    }

    func play() {
        isPlaying = true
        player.play()
    }

    func pause() {
        isPlaying = false
        player.pause()
    }

    func beginScrub() {
        isScrubbing = true
    }

    func endScrub(to seconds: Double, resumeIfPlaying: Bool) {
        let target = max(0, min(seconds, duration))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { [weak self] _ in
            guard let self else { return }
            self.currentTime = target
            self.isScrubbing = false
            if resumeIfPlaying {
                self.play()
            }
        }
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerUIView {
        let view = PlayerContainerUIView()
        view.setPlayer(player)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerUIView, context: Context) {
        uiView.setPlayer(player)
    }
}

private final class PlayerContainerUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.masksToBounds = true
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.masksToBounds = true
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func setPlayer(_ player: AVPlayer) {
        if playerLayer.player !== player {
            playerLayer.player = player
        }
    }
}

struct InlineVideoPlayer: View {
    let id: String
    let videoUrl: String
    let thumbnailUrl: String?
    let aspectRatio: CGFloat?
    let maxHeight: CGFloat
    let onFullScreen: ((String) -> Void)?

    @ObservedObject private var coordinator = InlineVideoPlaybackCoordinator.shared
    @StateObject private var viewModel: InlineVideoPlayerViewModel
    @State private var isVisibleEnough = false
    @State private var isScrubbing = false
    @State private var controlsVisible = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var userPaused = false

    init(
        id: String,
        videoUrl: String,
        thumbnailUrl: String?,
        aspectRatio: CGFloat? = nil,
        maxHeight: CGFloat = 350,
        onFullScreen: ((String) -> Void)? = nil
    ) {
        self.id = id
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.aspectRatio = aspectRatio
        self.maxHeight = maxHeight
        self.onFullScreen = onFullScreen

        let isRunningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let cleanedUrl = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = isRunningForPreviews
            ? nil
            : (URL(string: cleanedUrl) ?? URLComponents(string: cleanedUrl)?.url)
        _viewModel = StateObject(wrappedValue: InlineVideoPlayerViewModel(url: url, startsMuted: true))
    }

    var body: some View {
        let resolvedAspectRatio = aspectRatio ?? (16.0 / 9.0)
        let minHeight = min(maxHeight, 280.0)
        let clipShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        ZStack {
            Rectangle().fill(Color.loopedBlack)

            if let thumbnailUrl, !thumbnailUrl.isEmpty, !viewModel.isReady {
                AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Rectangle().fill(Color.loopedMutedBackground)
                    }
                }
            } else {
                Rectangle().fill(Color.loopedMutedBackground)
            }

            PlayerLayerView(player: viewModel.player)
                .opacity(viewModel.isReady ? 1 : 0)

            Color.loopedClear
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture().onEnded {
                        showControls()
                    },
                    including: .all
                )

            if controlsVisible {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .aspectRatio(resolvedAspectRatio, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: maxHeight)
        .frame(minHeight: minHeight)
        .compositingGroup()
        .clipped()
        .clipShape(clipShape)
        .contentShape(clipShape)
        .background(
            GeometryReader { geo in
                Color.loopedClear.preference(key: InlineVideoFramePreferenceKey.self, value: geo.frame(in: .global))
            }
        )
        .onPreferenceChange(InlineVideoFramePreferenceKey.self) { frame in
            updateVisibility(frame: frame)
            applyPlaybackGate()
        }
        .onAppear {
            // Fallback for cases where geometry callbacks are delayed/missed in lazy scroll containers.
            // `onAppear` for a cell should only fire when it is on screen.
            if !isVisibleEnough {
                isVisibleEnough = true
            }
            applyPlaybackGate()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            hideControlsTask = nil
            if coordinator.activeVideoId == id {
                coordinator.activeVideoId = nil
            }
            viewModel.pause()
        }
        .onChange(of: viewModel.isReady) { _, _ in
            applyPlaybackGate()
        }
        .onChange(of: isVisibleEnough) { _, _ in
            applyPlaybackGate()
        }
        .onChange(of: coordinator.activeVideoId) { _, _ in
            applyPlaybackGate()
        }
    }

    private var controlsOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Button {
                    togglePlayPauseFromUser()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.loopedCustom(.semibold, size: 16))
                        .foregroundColor(.loopedWhite)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                InlineVideoScrubber(
                    value: Binding(
                        get: { viewModel.duration > 0 ? min(viewModel.currentTime, viewModel.duration) : 0 },
                        set: { newValue in viewModel.currentTime = newValue }
                    ),
                    duration: viewModel.duration,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            hideControlsTask?.cancel()
                            hideControlsTask = nil
                            isScrubbing = true
                            viewModel.beginScrub()
                            viewModel.pause()
                        } else {
                            let shouldResume = isVisibleEnough && coordinator.activeVideoId == id && !userPaused
                            viewModel.endScrub(to: viewModel.currentTime, resumeIfPlaying: shouldResume)
                            isScrubbing = false
                            scheduleAutoHideControlsIfNeeded()
                        }
                    }
                )

                Text("\(formatTime(viewModel.currentTime))/\(formatTime(viewModel.duration))")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedWhite.opacity(0.92))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Button {
                    viewModel.setMuted(!viewModel.isMuted)
                    scheduleAutoHideControlsIfNeeded()
                } label: {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.loopedCustom(.semibold, size: 16))
                        .foregroundColor(.loopedWhite)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                if let onFullScreen {
                    Button {
                        onFullScreen(videoUrl)
                        scheduleAutoHideControlsIfNeeded()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.loopedCustom(.semibold, size: 16))
                            .foregroundColor(.loopedWhite)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.loopedBlack.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }

    private func updateVisibility(frame: CGRect) {
        let screen = UIScreen.main.bounds
        // Ignore zero/invalid frames (can happen transiently in lazy lists).
        guard frame.height > 1 else { return }
        let visibleTop = max(frame.minY, 0)
        let visibleBottom = min(frame.maxY, screen.height)
        let visibleHeight = max(0, visibleBottom - visibleTop)
        let ratio = visibleHeight / frame.height
        isVisibleEnough = ratio >= 0.60
    }

    private func applyPlaybackGate() {
        guard !isScrubbing else { return }
        guard isVisibleEnough else {
            if controlsVisible {
                hideControls()
            }
            viewModel.pause()
            return
        }

        if coordinator.activeVideoId == nil || coordinator.activeVideoId == id {
            coordinator.requestPlayback(id: id)
        }

        guard coordinator.activeVideoId == id else {
            if controlsVisible {
                hideControls()
            }
            viewModel.pause()
            return
        }

        if userPaused {
            viewModel.pause()
            return
        }

        viewModel.play()
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(max(seconds, 0).rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func showControls() {
        withAnimation(.easeInOut(duration: 0.15)) {
            controlsVisible = true
        }
        scheduleAutoHideControlsIfNeeded()
    }

    private func hideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = nil
        withAnimation(.easeInOut(duration: 0.15)) {
            controlsVisible = false
        }
    }

    private func scheduleAutoHideControlsIfNeeded() {
        hideControlsTask?.cancel()
        hideControlsTask = nil
        guard controlsVisible else { return }
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                hideControls()
            }
        }
    }

    private func togglePlayPauseFromUser() {
        if viewModel.isPlaying {
            userPaused = true
            viewModel.pause()
        } else {
            userPaused = false
            if coordinator.activeVideoId == nil || coordinator.activeVideoId == id {
                coordinator.requestPlayback(id: id)
            }
            viewModel.play()
        }
        scheduleAutoHideControlsIfNeeded()
    }
}

private struct InlineVideoScrubber: View {
    @Binding var value: Double
    let duration: Double
    let onEditingChanged: (Bool) -> Void

    private let trackHeight: CGFloat = 2
    private let thumbSize: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let clampedDuration = max(duration, 0.0001)
            let progress = min(max(value / clampedDuration, 0), 1)
            let x = progress * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.loopedWhite.opacity(0.25))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.loopedWhite.opacity(0.9))
                    .frame(width: max(x, 0), height: trackHeight)

                Circle()
                    .fill(Color.loopedWhite)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: min(max(x - thumbSize / 2, -thumbSize / 2), width - thumbSize / 2))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onEditingChanged(true)
                        let raw = min(max(gesture.location.x, 0), width)
                        value = (raw / width) * clampedDuration
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(minWidth: 60, maxWidth: .infinity)
        .frame(height: 14)
        .accessibilityLabel("Scrubber")
    }
}
