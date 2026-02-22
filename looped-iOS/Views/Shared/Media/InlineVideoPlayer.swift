import SwiftUI
import AVFoundation
import UIKit
import Foundation
import QuartzCore

private final class VisibilityUpdateCoordinator {
    private var pendingFrame: CGRect?
    private var lastFrame: CGRect = .zero
    private var isScheduled = false

    var currentFrame: CGRect {
        lastFrame
    }

    func schedule(frame: CGRect, force: Bool, action: @escaping (CGRect) -> Void) {
        pendingFrame = frame
        guard !isScheduled else { return }
        isScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isScheduled = false
            let frameToUse = self.pendingFrame ?? self.lastFrame
            self.pendingFrame = nil
            if !force, frameToUse == self.lastFrame { return }
            self.lastFrame = frameToUse
            action(frameToUse)
        }
    }

    func reset() {
        pendingFrame = nil
        lastFrame = .zero
        isScheduled = false
    }
}

private final class PlaybackGateCoordinator {
    private var isScheduled = false

    func schedule(_ action: @escaping () -> Void) {
        guard !isScheduled else { return }
        isScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isScheduled = false
            action()
        }
    }
}

private struct VisibilityProbeView: UIViewRepresentable {
    let onFrameChange: (CGRect) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onFrameChange = onFrameChange
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.onFrameChange = onFrameChange
    }

    final class ProbeView: UIView {
        var onFrameChange: ((CGRect) -> Void)?

        private var displayLink: CADisplayLink?
        private var lastReportedFrame: CGRect = .zero

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            backgroundColor = .clear
            isUserInteractionEnabled = false
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                stopDisplayLink()
            } else {
                startDisplayLink()
            }
        }

        private func startDisplayLink() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tick))
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 15, preferred: 12)
            } else {
                link.preferredFramesPerSecond = 12
            }
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
            lastReportedFrame = .zero
        }

        deinit {
            stopDisplayLink()
        }

        @objc private func tick() {
            guard window != nil else { return }
            let frame = convert(bounds, to: nil)
            let rounded = CGRect(
                x: frame.origin.x.rounded(),
                y: frame.origin.y.rounded(),
                width: frame.size.width.rounded(),
                height: frame.size.height.rounded()
            )
            guard rounded != lastReportedFrame else { return }
            lastReportedFrame = rounded
            onFrameChange?(rounded)
        }
    }
}

private struct VideoDebugLogger {
    static var isEnabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["LOOPED_LOG_VIDEO"] == "1" || env["LOOPED_LOG_VIDEO_TAPS"] == "1"
    }

    static func log(_ message: String) {
#if DEBUG
        guard isEnabled else { return }
        print("LOOPED_VIDEO \(message)")
#endif
    }
}

final class VideoPlaybackManager: ObservableObject {
    static let shared = VideoPlaybackManager()
    static let refreshVisibilityNotification = Foundation.Notification.Name("LoopedVideoRefreshVisibility")

    @Published private(set) var activeVideoId: String?
    @Published private(set) var lockedActiveId: String?

    private struct VisibilityState {
        let ratio: Double
        let visibleHeight: Double
        let focusHeight: Double
        let lastUpdated: Date
    }

    private var visibilityById: [String: VisibilityState] = [:]
    private let visibilityThreshold: Double = 0.60
    private let minVisibleHeight: Double = 180
    private let hysteresisDelta: Double = 0.08
    private let staleVisibilityInterval: TimeInterval = 1.2

    func resetVisibility() {
        visibilityById.removeAll()
        lockedActiveId = nil
        if activeVideoId != nil {
            activeVideoId = nil
            VideoDebugLogger.log("activeVideoId cleared (reset)")
        }
    }

    func requestVisibilityRefresh() {
        NotificationCenter.default.post(name: Self.refreshVisibilityNotification, object: nil)
    }

    func updateVisibility(id: String, visibleRatio: Double, visibleHeight: Double, focusHeight: Double) {
        visibilityById[id] = VisibilityState(ratio: visibleRatio, visibleHeight: visibleHeight, focusHeight: focusHeight, lastUpdated: Date())
        recomputeActive()
    }

    func unregister(id: String) {
        visibilityById.removeValue(forKey: id)
        if activeVideoId == id {
            activeVideoId = nil
        }
        recomputeActive()
    }

    func promoteToActive(id: String) {
        if let lockedActiveId, lockedActiveId != id { return }
        guard activeVideoId != id else { return }
        activeVideoId = id
        VideoDebugLogger.log("activeVideoId set to \(id)")
    }

    func isVisibleEnough(_ id: String) -> Bool {
        guard let state = visibilityById[id] else { return false }
        return state.ratio >= visibilityThreshold || state.visibleHeight >= minVisibleHeight
    }

    func visibleRatio(for id: String) -> Double {
        visibilityById[id]?.ratio ?? 0
    }

    func lockActive(id: String) {
        lockedActiveId = id
        activeVideoId = id
        VideoDebugLogger.log("activeVideoId locked to \(id)")
    }

    func unlockActive(id: String) {
        guard lockedActiveId == id else { return }
        lockedActiveId = nil
        VideoDebugLogger.log("activeVideoId unlocked")
    }

    func isActiveStale() -> Bool {
        guard lockedActiveId == nil else { return false }
        guard let activeVideoId, let state = visibilityById[activeVideoId] else { return true }
        return Date().timeIntervalSince(state.lastUpdated) > staleVisibilityInterval
    }

    func clearActiveIfStale() {
        guard lockedActiveId == nil else { return }
        if isActiveStale() {
            activeVideoId = nil
        }
    }

    private func recomputeActive() {
        if let lockedActiveId {
            if activeVideoId != lockedActiveId {
                activeVideoId = lockedActiveId
            }
            return
        }
        let cutoff = Date().addingTimeInterval(-staleVisibilityInterval)
        if !visibilityById.isEmpty {
            visibilityById = visibilityById.filter { $0.value.lastUpdated >= cutoff }
        }
        let candidates = visibilityById.filter {
            $0.value.ratio >= visibilityThreshold || $0.value.visibleHeight >= minVisibleHeight
        }

        guard let best = candidates.max(by: { lhs, rhs in
            if lhs.value.visibleHeight != rhs.value.visibleHeight {
                return lhs.value.visibleHeight < rhs.value.visibleHeight
            }
            if lhs.value.focusHeight != rhs.value.focusHeight {
                return lhs.value.focusHeight < rhs.value.focusHeight
            }
            if lhs.value.ratio != rhs.value.ratio {
                return lhs.value.ratio < rhs.value.ratio
            }
            return lhs.value.lastUpdated < rhs.value.lastUpdated
        }) else {
            if activeVideoId != nil {
                activeVideoId = nil
                VideoDebugLogger.log("activeVideoId cleared (no visible candidates)")
            }
            return
        }

        if let currentId = activeVideoId,
           let current = visibilityById[currentId],
           current.ratio >= visibilityThreshold || current.visibleHeight >= minVisibleHeight {
            if currentId == best.key { return }
            if best.value.visibleHeight - current.visibleHeight < (minVisibleHeight * 0.15),
               best.value.ratio - current.ratio < hysteresisDelta {
                return
            }
        }

        if activeVideoId != best.key {
            activeVideoId = best.key
            VideoDebugLogger.log("activeVideoId switched to \(best.key) ratio=\(best.value.ratio) vh=\(Int(best.value.visibleHeight)) fh=\(Int(best.value.focusHeight))")
        }
    }
}

final class InlineVideoPlayerViewModel: ObservableObject {
    let player: AVPlayer

    @Published var isMuted: Bool
    @Published var isPlaying: Bool = false
    @Published var isReady: Bool = false
    @Published var isReadyForDisplay: Bool = false
    @Published var didReachEnd: Bool = false
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var errorDescription: String?
    @Published var isExternallyPresented: Bool = false
    @Published var debugStatusText: String = "unknown"
    @Published var debugTimeControlText: String = "unknown"
    @Published var debugURLText: String = ""
    @Published var debugHTTPText: String = ""
    @Published var debugAssetText: String = ""

    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?
    private var didPlayToEndObserver: NSObjectProtocol?
    private var failedToPlayObserver: NSObjectProtocol?
    private var stalledObserver: NSObjectProtocol?
    private var timeControlObserver: NSKeyValueObservation?
    private var isScrubbing = false
    private var loadedUrl: URL?
    private let debugId: String

    init(url: URL?, startsMuted: Bool = true, debugId: String) {
        self.player = AVPlayer()
        self.isMuted = startsMuted
        self.debugId = debugId
        player.isMuted = startsMuted
        replaceCurrentItem(url: url)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            guard !self.isScrubbing else { return }
            let seconds = time.seconds
            self.currentTime = seconds.isFinite ? max(seconds, 0) : 0
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.debugTimeControlText = self.timeControlLabel(player.timeControlStatus)
            }
        }
    }

    deinit {
        VideoAudioSessionManager.shared.setWantsPlaybackAudio(false, id: debugId)

        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let didPlayToEndObserver {
            NotificationCenter.default.removeObserver(didPlayToEndObserver)
        }
        if let failedToPlayObserver {
            NotificationCenter.default.removeObserver(failedToPlayObserver)
        }
        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
        }
        itemStatusObserver = nil
        durationObserver = nil
        timeControlObserver = nil
    }

    func updateURLIfNeeded(_ url: URL?) {
        if loadedUrl == url { return }
        replaceCurrentItem(url: url)
    }

    func updateReadyForDisplay(_ isReady: Bool) {
        if isReadyForDisplay == isReady { return }
        isReadyForDisplay = isReady
        VideoDebugLogger.log("id=\(debugId) readyForDisplay=\(isReady)")
    }

    private func replaceCurrentItem(url: URL?) {
        loadedUrl = url
        errorDescription = nil
        isReady = false
        isReadyForDisplay = false
        didReachEnd = false
        duration = 0
        currentTime = 0
        debugStatusText = "unknown"
        debugAssetText = ""
        debugHTTPText = ""
        debugURLText = ""

        itemStatusObserver = nil
        durationObserver = nil
        if let didPlayToEndObserver {
            NotificationCenter.default.removeObserver(didPlayToEndObserver)
        }
        if let failedToPlayObserver {
            NotificationCenter.default.removeObserver(failedToPlayObserver)
        }
        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
        }

        if let url {
            debugURLText = debugURLSummary(url)
            let asset = AVURLAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: item)

            if VideoDebugLogger.isEnabled {
                Task.detached { [weak self] in
                    await self?.runDebugChecks(for: asset, url: url)
                }
            }
        } else {
            player.replaceCurrentItem(with: nil)
        }

        player.isMuted = isMuted

        guard let item = player.currentItem else { return }
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isReady = item.status == .readyToPlay
                if item.status == .failed {
                    self.errorDescription = item.error?.localizedDescription ?? "Failed to load video"
                }
                self.debugStatusText = self.statusLabel(item.status)
                VideoDebugLogger.log("id=\(self.debugId) status=\(self.statusLabel(item.status))")
            }
        }

        durationObserver = item.observe(\.duration, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            let seconds = item.duration.seconds
            DispatchQueue.main.async {
                self.duration = seconds.isFinite ? max(seconds, 0) : 0
            }
        }

        didPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Loop previews automatically instead of stopping on a replay state.
            self.replay()
        }

        failedToPlayObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            self.isPlaying = false
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            self.errorDescription = err?.localizedDescription ?? item.error?.localizedDescription ?? "Video failed"
            VideoDebugLogger.log("id=\(self.debugId) failedToPlay error=\(self.errorDescription ?? "unknown")")
            self.updatePlaybackAudioSession()
        }

        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            VideoDebugLogger.log("id=\(self?.debugId ?? "unknown") stalled")
        }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        player.isMuted = muted
        updatePlaybackAudioSession()
    }

    func play() {
        isPlaying = true
        didReachEnd = false
        updatePlaybackAudioSession()
        player.play()
    }

    func pause() {
        isPlaying = false
        player.pause()
        updatePlaybackAudioSession()
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
            if target < max(self.duration - 0.1, 0) {
                self.didReachEnd = false
            }
            if resumeIfPlaying {
                self.play()
            }
        }
    }

    func replay() {
        didReachEnd = false
        isPlaying = true
        updatePlaybackAudioSession()
        player.seek(to: .zero) { [weak self] _ in
            self?.player.play()
        }
    }

    func setExternallyPresented(_ value: Bool) {
        if isExternallyPresented == value { return }
        isExternallyPresented = value
        VideoDebugLogger.log("id=\(debugId) externalPresentation=\(value)")
    }

    private func updatePlaybackAudioSession() {
        VideoAudioSessionManager.shared.setWantsPlaybackAudio(!isMuted && isPlaying, id: debugId)
    }

    private func statusLabel(_ status: AVPlayerItem.Status) -> String {
        switch status {
        case .unknown:
            return "unknown"
        case .readyToPlay:
            return "readyToPlay"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown"
        }
    }

    private func timeControlLabel(_ status: AVPlayer.TimeControlStatus) -> String {
        switch status {
        case .paused:
            return "paused"
        case .playing:
            return "playing"
        case .waitingToPlayAtSpecifiedRate:
            return "waiting"
        @unknown default:
            return "unknown"
        }
    }

    private func debugURLSummary(_ url: URL) -> String {
        let scheme = url.scheme ?? "nil"
        let host = url.host ?? "nil"
        return "\(scheme)://\(host)\(url.path)"
    }

    private func runDebugChecks(for asset: AVURLAsset, url: URL) async {
        let urlSummary = debugURLSummary(url)
        await MainActor.run {
            debugURLText = urlSummary
        }

        do {
            let playable = try await asset.load(.isPlayable)
            let protected = try await asset.load(.hasProtectedContent)
            let duration = try await asset.load(.duration).seconds
            let durationText = duration.isFinite ? String(format: "%.2f", duration) : "n/a"
            let info = "playable=\(playable) protected=\(protected) duration=\(durationText)"
            await MainActor.run {
                debugAssetText = info
            }
            VideoDebugLogger.log("id=\(debugId) asset \(info)")
        } catch {
            await MainActor.run {
                debugAssetText = "asset error: \(error.localizedDescription)"
            }
            VideoDebugLogger.log("id=\(debugId) asset error=\(error.localizedDescription)")
        }

        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = tracks.first {
                let natural = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let transformed = natural.applying(transform)
                let width = abs(transformed.width)
                let height = abs(transformed.height)
                let fps = try await track.load(.nominalFrameRate)
                let dataRate = try await track.load(.estimatedDataRate) // bits/sec (estimated)
                let mbps = Double(dataRate) / 1_000_000
                let trackInfo = "video=\(Int(width))x\(Int(height)) \(String(format: "%.1f", fps))fps ~\(String(format: "%.1f", mbps))Mbps"
                VideoDebugLogger.log("id=\(debugId) \(trackInfo)")
                await MainActor.run {
                    debugAssetText = "\(debugAssetText) \(trackInfo)"
                }
            }
        } catch {
            VideoDebugLogger.log("id=\(debugId) track error=\(error.localizedDescription)")
        }

        var head = URLRequest(url: url)
        head.httpMethod = "HEAD"
        head.timeoutInterval = 12
        do {
            let (_, response) = try await URLSession.shared.data(for: head)
            if let http = response as? HTTPURLResponse {
                let type = http.value(forHTTPHeaderField: "Content-Type") ?? "nil"
                let ranges = http.value(forHTTPHeaderField: "Accept-Ranges") ?? "nil"
                let length = http.value(forHTTPHeaderField: "Content-Length") ?? "nil"
                let text = "HEAD \(http.statusCode) \(type) len=\(length) ranges=\(ranges)"
                await MainActor.run {
                    debugHTTPText = text
                }
                VideoDebugLogger.log("id=\(debugId) \(text)")
            }
        } catch {
            let text = "HEAD error: \(error.localizedDescription)"
            await MainActor.run {
                debugHTTPText = text
            }
            VideoDebugLogger.log("id=\(debugId) \(text)")
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    let onReadyForDisplay: (Bool) -> Void

    func makeUIView(context: Context) -> PlayerContainerUIView {
        let view = PlayerContainerUIView()
        view.onReadyForDisplay = onReadyForDisplay
        view.videoGravity = videoGravity
        view.setPlayer(player)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerUIView, context: Context) {
        uiView.onReadyForDisplay = onReadyForDisplay
        uiView.videoGravity = videoGravity
        uiView.setPlayer(player)
    }
}

final class PlayerContainerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var readyObserver: NSKeyValueObservation?
    var onReadyForDisplay: ((Bool) -> Void)?
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill {
        didSet {
            playerLayer.videoGravity = videoGravity
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.masksToBounds = true
        playerLayer.videoGravity = videoGravity
        playerLayer.masksToBounds = true
        playerLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(playerLayer)

        readyObserver = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            DispatchQueue.main.async {
                self?.onReadyForDisplay?(layer.isReadyForDisplay)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        readyObserver = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let scale = window?.screen.scale {
            playerLayer.contentsScale = scale
        }
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
    let onFullScreen: ((InlineVideoPlayerViewModel) -> Void)?

    @ObservedObject private var playbackManager = VideoPlaybackManager.shared
    @StateObject private var viewModel: InlineVideoPlayerViewModel
    @State private var visibleRatio: Double = 0
    @State private var isScrubbing = false
    @State private var controlsVisible = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var userPaused = false
    @State private var hasAttemptedPlayback = false
    @State private var lastLoggedVisibility: Double = -1
    @State private var controlsRequestedByUser = false
    @State private var visibilityRefreshTask: Task<Void, Never>?
    @State private var visibilityCoordinator = VisibilityUpdateCoordinator()
    @State private var playbackGateCoordinator = PlaybackGateCoordinator()
    @State private var isActive = true
    @State private var lastVisibleHeight: Double = 0
    @State private var lastGateState: String = ""

    init(
        id: String,
        videoUrl: String,
        thumbnailUrl: String?,
        aspectRatio: CGFloat? = nil,
        maxHeight: CGFloat = 350,
        onFullScreen: ((InlineVideoPlayerViewModel) -> Void)? = nil
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
        _viewModel = StateObject(wrappedValue: InlineVideoPlayerViewModel(url: url, startsMuted: true, debugId: id))
    }

    var body: some View {
        let resolvedAspectRatio = aspectRatio ?? (16.0 / 9.0)
        let minHeight = min(maxHeight, 280.0)
        let clipShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let hasThumbnail = (thumbnailUrl ?? "").isEmpty == false
        let shouldShowPoster = hasThumbnail && !viewModel.isReadyForDisplay
        let muteBottomPadding: CGFloat = (controlsVisible && onFullScreen == nil) ? 54 : 10

        ZStack {
            Rectangle().fill(Color.loopedBlack)

            if let thumbnailUrl, !thumbnailUrl.isEmpty {
                AsyncImage(url: URL.loopedMediaURL(from: thumbnailUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Rectangle().fill(Color.loopedMutedBackground)
                    }
                }
                .opacity(shouldShowPoster ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: shouldShowPoster)
                .allowsHitTesting(false)
            } else {
                Rectangle()
                    .fill(Color.loopedMutedBackground)
                    .allowsHitTesting(false)
            }

            VideoPlayerView(
                player: viewModel.player,
                videoGravity: .resizeAspectFill,
                onReadyForDisplay: { isReady in
                    viewModel.updateReadyForDisplay(isReady)
                }
            )
            .opacity(viewModel.isReadyForDisplay ? 1 : 0)
            .allowsHitTesting(false)
            .zIndex(1)

            if hasAttemptedPlayback, !viewModel.isReadyForDisplay, viewModel.errorDescription == nil {
                ProgressView()
                    .tint(.loopedWhite.opacity(0.9))
                    .allowsHitTesting(false)
                    .zIndex(2)
            }

            if let error = viewModel.errorDescription, hasAttemptedPlayback {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.loopedCustom(size: 18))
                        .foregroundColor(.loopedWhite.opacity(0.75))
                    Text("Couldn't play video")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedWhite.opacity(0.8))
                    Text(error)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedWhite.opacity(0.6))
                        .lineLimit(2)
                }
                .padding(10)
                .background(Color.loopedBlack.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)
                .allowsHitTesting(false)
                .zIndex(2)
            }

            Group {
                if #available(iOS 18.0, *) {
                    LoopedScrollSafeTapCaptureView {
                        handlePrimaryTap()
                    }
                } else {
                    Color.loopedClear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handlePrimaryTap()
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(3)

            if viewModel.didReachEnd {
                ReplayOverlayView {
                    handleReplayTap()
                }
                .zIndex(3.5)
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
        .overlay(alignment: .bottom) {
            if controlsVisible, onFullScreen == nil {
                controlsOverlay
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            muteButton
                .padding(.bottom, muteBottomPadding)
                .padding(.trailing, 10)
        }
        .background(
            VisibilityProbeView { frame in
                visibilityCoordinator.schedule(frame: frame, force: false) { frame in
                    guard isActive else { return }
                    updateVisibility(frame: frame)
                    schedulePlaybackGate()
                }
            }
            .allowsHitTesting(false)
        )
        .onAppear {
            isActive = true
            VideoDebugLogger.log("id=\(id) bind url=\(videoUrl) thumbnail=\(thumbnailUrl ?? "nil")")
            refreshVisibility()
            scheduleVisibilityRefresh()

            let cleanedUrl = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            let isRunningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            let url = isRunningForPreviews
                ? nil
                : (URL(string: cleanedUrl) ?? URLComponents(string: cleanedUrl)?.url)
            viewModel.updateURLIfNeeded(url)
        }
        .onChange(of: videoUrl) { _, newValue in
            resetForNewMedia()
            let cleanedUrl = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let isRunningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            let url = isRunningForPreviews
                ? nil
                : (URL(string: cleanedUrl) ?? URLComponents(string: cleanedUrl)?.url)
            viewModel.updateURLIfNeeded(url)
            VideoDebugLogger.log("id=\(id) bind urlUpdated=\(newValue)")
        }
        .onDisappear {
            hideControlsTask?.cancel()
            hideControlsTask = nil
            visibilityRefreshTask?.cancel()
            visibilityRefreshTask = nil
            guard !viewModel.isExternallyPresented else { return }
            isActive = false
            visibilityCoordinator.reset()
            playbackManager.unregister(id: id)
            viewModel.pause()
        }
        .onChange(of: viewModel.isReady) { _, _ in
            schedulePlaybackGate()
        }
        .onChange(of: visibleRatio) { _, _ in
            schedulePlaybackGate()
        }
        .onChange(of: playbackManager.activeVideoId) { _, _ in
            schedulePlaybackGate()
        }
        .onChange(of: controlsVisible) { _, newValue in
            VideoDebugLogger.log("id=\(id) controlsVisible=\(newValue) overlayZ=4 playerZ=1")
        }
        .onChange(of: viewModel.didReachEnd) { _, newValue in
            if newValue {
                hideControls()
            }
        }
        .onChange(of: viewModel.isExternallyPresented) { _, _ in
            schedulePlaybackGate()
        }
        .onReceive(NotificationCenter.default.publisher(for: VideoPlaybackManager.refreshVisibilityNotification)) { _ in
            refreshVisibility()
        }
    }

    private var muteButton: some View {
        let iconSize: CGFloat = 22
        let buttonSize: CGFloat = 44

        return Button {
            viewModel.setMuted(!viewModel.isMuted)
            scheduleAutoHideControlsIfNeeded()
        } label: {
            Image(viewModel.isMuted ? "mute-icon" : "volume-icon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(.loopedWhite)
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.plain)
        .zIndex(4)
    }

    private var controlsOverlay: some View {
        VideoControlsOverlayView(
            isPlaying: viewModel.isPlaying,
            currentTime: Binding(
                get: { viewModel.currentTime },
                set: { viewModel.currentTime = $0 }
            ),
            duration: viewModel.duration,
            isMuted: viewModel.isMuted,
            onPlayPause: togglePlayPauseFromUser,
            onBeginScrub: {
                hideControlsTask?.cancel()
                hideControlsTask = nil
                isScrubbing = true
                viewModel.beginScrub()
                viewModel.pause()
            },
            onEndScrub: { newValue in
                let shouldResume = playbackManager.isVisibleEnough(id) && playbackManager.activeVideoId == id && !userPaused
                viewModel.currentTime = newValue
                viewModel.endScrub(to: newValue, resumeIfPlaying: shouldResume)
                isScrubbing = false
                scheduleAutoHideControlsIfNeeded()
            },
            onMuteToggle: {
                viewModel.setMuted(!viewModel.isMuted)
                scheduleAutoHideControlsIfNeeded()
            },
            onFullScreen: onFullScreen.map { handler in
                { handler(viewModel) }
            },
            sizeScale: 1.0
        )
    }

    private func updateVisibility(frame: CGRect, ratioOverride: Double? = nil, visibleHeightOverride: Double? = nil) {
        if ratioOverride == nil, frame.height <= 1 || frame.width <= 1 {
            return
        }
        let metrics = computeVisibleMetrics(frame: frame)
        let ratio = ratioOverride ?? metrics.ratio
        let visibleHeight = visibleHeightOverride ?? metrics.visibleHeight
        let focusHeight = metrics.focusHeight
        visibleRatio = ratio
        lastVisibleHeight = visibleHeight
        playbackManager.updateVisibility(id: id, visibleRatio: ratio, visibleHeight: visibleHeight, focusHeight: focusHeight)
        if VideoDebugLogger.isEnabled {
            if lastLoggedVisibility < 0 || abs(ratio - lastLoggedVisibility) >= 0.05 {
                lastLoggedVisibility = ratio
                VideoDebugLogger.log("id=\(id) visibleRatio=\(String(format: "%.2f", ratio)) vh=\(Int(visibleHeight)) fh=\(Int(focusHeight))")
            }
        }
    }

    private func computeVisibleMetrics(frame: CGRect) -> (ratio: Double, visibleHeight: Double, focusHeight: Double) {
        let screen = UIScreen.main.bounds
        guard frame.height > 1 else { return (0, 0, 0) }
        let visibleTop = max(frame.minY, 0)
        let visibleBottom = min(frame.maxY, screen.height)
        let visibleHeight = max(0, visibleBottom - visibleTop)
        let ratio = Double(visibleHeight / frame.height)
        let focusTop = screen.height * 0.25
        let focusBottom = screen.height * 0.75
        let focusVisibleTop = max(frame.minY, focusTop)
        let focusVisibleBottom = min(frame.maxY, focusBottom)
        let focusHeight = max(0, focusVisibleBottom - focusVisibleTop)
        return (ratio, Double(visibleHeight), Double(focusHeight))
    }

    private func refreshVisibility() {
        let frame = visibilityCoordinator.currentFrame
        guard frame.height > 1, frame.width > 1 else {
            scheduleVisibilityRefresh()
            return
        }
        let metrics = computeVisibleMetrics(frame: frame)
        visibilityCoordinator.schedule(frame: frame, force: true) { frame in
            guard isActive else { return }
            playbackManager.clearActiveIfStale()
            updateVisibility(frame: frame, ratioOverride: metrics.ratio, visibleHeightOverride: metrics.visibleHeight)
            schedulePlaybackGate()
        }
    }

    private func scheduleVisibilityRefresh() {
        visibilityRefreshTask?.cancel()
        visibilityRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                refreshVisibility()
            }
        }
    }

    private func schedulePlaybackGate() {
        playbackGateCoordinator.schedule {
            applyPlaybackGate()
        }
    }

    private func applyPlaybackGate() {
        guard isActive else {
            logGate("inactive")
            viewModel.pause()
            return
        }
        guard !isScrubbing else {
            logGate("scrubbing")
            return
        }
        guard !viewModel.isExternallyPresented else {
            logGate("external")
            return
        }
        if viewModel.didReachEnd {
            logGate("ended")
            viewModel.pause()
            return
        }
        playbackManager.clearActiveIfStale()
        let isVisibleEnough = playbackManager.isVisibleEnough(id)
        guard isVisibleEnough else {
            logGate("notVisible")
            viewModel.pause()
            return
        }
        if playbackManager.activeVideoId == nil {
            playbackManager.promoteToActive(id: id)
        }
        guard playbackManager.activeVideoId == id else {
            logGate("notActive")
            viewModel.pause()
            return
        }

        hasAttemptedPlayback = true

        if userPaused {
            logGate("userPaused")
            viewModel.pause()
            return
        }

        logGate("play")
        viewModel.play()
    }

    private func logGate(_ state: String) {
        guard VideoDebugLogger.isEnabled else { return }
        guard state != lastGateState else { return }
        lastGateState = state
        VideoDebugLogger.log(
            "id=\(id) gate=\(state) ratio=\(String(format: "%.2f", visibleRatio)) vh=\(Int(lastVisibleHeight)) active=\(playbackManager.activeVideoId ?? "nil") locked=\(playbackManager.lockedActiveId ?? "nil")"
        )
    }

    private func showControls() {
        withAnimation(.easeInOut(duration: 0.15)) {
            controlsVisible = true
        }
        controlsRequestedByUser = true
        scheduleAutoHideControlsIfNeeded()
    }

    private func hideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = nil
        withAnimation(.easeInOut(duration: 0.15)) {
            controlsVisible = false
        }
        controlsRequestedByUser = false
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
        if viewModel.didReachEnd {
            handleReplayTap()
            return
        }
        if viewModel.isPlaying {
            userPaused = true
            viewModel.pause()
        } else {
            userPaused = false
            playbackManager.promoteToActive(id: id)
            viewModel.play()
        }
        scheduleAutoHideControlsIfNeeded()
    }

    private func handleReplayTap() {
        userPaused = false
        hasAttemptedPlayback = true
        playbackManager.promoteToActive(id: id)
        viewModel.replay()
    }

    private func handlePrimaryTap() {
        VideoDebugLogger.log("id=\(id) tapped")
        playbackManager.promoteToActive(id: id)
        if let onFullScreen {
            viewModel.setExternallyPresented(true)
            onFullScreen(viewModel)
        } else {
            showControls()
        }
    }

    private func resetForNewMedia() {
        hasAttemptedPlayback = false
        userPaused = false
        hideControlsTask?.cancel()
        hideControlsTask = nil
        controlsVisible = false
        isScrubbing = false
        visibilityCoordinator.reset()
        viewModel.setExternallyPresented(false)
        viewModel.setMuted(true)
    }
}

struct VideoControlsOverlayView: View {
    let isPlaying: Bool
    @Binding var currentTime: Double
    let duration: Double
    let isMuted: Bool
    let onPlayPause: () -> Void
    let onBeginScrub: () -> Void
    let onEndScrub: (Double) -> Void
    let onMuteToggle: () -> Void
    let onFullScreen: (() -> Void)?
    let sizeScale: CGFloat

    var body: some View {
        let iconSize = 18 * sizeScale
        let buttonSize = 36 * sizeScale
        let horizontalPadding = 12 * sizeScale
        let verticalPadding = 8 * sizeScale

        HStack(spacing: 12 * sizeScale) {
            Button(action: onPlayPause) {
                Image(isPlaying ? "pause-icon" : "play-icon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(.loopedWhite)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)

            VideoScrubber(
                value: Binding(
                    get: { duration > 0 ? min(currentTime, duration) : 0 },
                    set: { currentTime = $0 }
                ),
                duration: duration,
                sizeScale: sizeScale,
                onEditingChanged: { isEditing, newValue in
                    if isEditing {
                        onBeginScrub()
                    } else {
                        onEndScrub(newValue)
                    }
                }
            )

            Text("\(formatTime(currentTime))/\(formatTime(duration))")
                .font(.loopedCustom(size: 12 * sizeScale))
                .foregroundColor(.loopedWhite.opacity(0.92))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Button(action: onMuteToggle) {
                Image(isMuted ? "mute-icon" : "volume-icon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(.loopedWhite)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)

            if let onFullScreen {
                Button(action: onFullScreen) {
                    Image("maximize-icon")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(.loopedWhite)
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(max(seconds, 0).rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

private struct ReplayOverlayView: View {
    let onReplay: () -> Void

    var body: some View {
        Button(action: onReplay) {
            ZStack {
                Color.loopedBlack.opacity(0.35)
                Image("replay-icon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.loopedWhite)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("Replay")
    }
}

private struct VideoScrubber: View {
    @Binding var value: Double
    let duration: Double
    let sizeScale: CGFloat
    let onEditingChanged: (Bool, Double) -> Void

    var body: some View {
        let trackHeight = 2 * sizeScale
        let thumbSize = 6 * sizeScale
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
                        let raw = min(max(gesture.location.x, 0), width)
                        let updated = (raw / width) * clampedDuration
                        value = updated
                        onEditingChanged(true, updated)
                    }
                    .onEnded { _ in
                        onEditingChanged(false, value)
                    }
            )
        }
        .frame(minWidth: 60, maxWidth: .infinity)
        .frame(height: 14)
        .accessibilityLabel("Scrubber")
    }
}
