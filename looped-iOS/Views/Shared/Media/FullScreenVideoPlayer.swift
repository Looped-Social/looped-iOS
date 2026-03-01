import SwiftUI
import AVFoundation

// MARK: - Full Screen Video Player (Custom)
struct VideoPlayerSheet: View {
    let selection: VideoSelection
    @Binding var isPresented: Bool

    @StateObject private var localViewModel: InlineVideoPlayerViewModel
    private let sharedViewModel: InlineVideoPlayerViewModel?
    private let usesSharedViewModel: Bool

    init(selection: VideoSelection, isPresented: Binding<Bool>) {
        self.selection = selection
        _isPresented = isPresented
        if let shared = selection.inlineViewModel {
            sharedViewModel = shared
            usesSharedViewModel = true
            _localViewModel = StateObject(wrappedValue: InlineVideoPlayerViewModel(
                url: nil,
                startsMuted: true,
                debugId: "fullscreen:placeholder"
            ))
        } else {
            let cleaned = selection.url.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = URL(string: cleaned) ?? URLComponents(string: cleaned)?.url
            _localViewModel = StateObject(wrappedValue: InlineVideoPlayerViewModel(
                url: url,
                startsMuted: true,
                debugId: "fullscreen:\(selection.id.uuidString)"
            ))
            sharedViewModel = nil
            usesSharedViewModel = false
        }
    }

    var body: some View {
        VideoPlayerSheetBody(
            selection: selection,
            isPresented: $isPresented,
            viewModel: sharedViewModel ?? localViewModel,
            usesSharedViewModel: usesSharedViewModel
        )
    }
}

private struct VideoPlayerSheetBody: View {
    let selection: VideoSelection
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: InlineVideoPlayerViewModel
    let usesSharedViewModel: Bool

    private let playbackManager = VideoPlaybackManager.shared
    @State private var overlaysVisible = true
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let dragGesture = DragGesture(minimumDistance: 8)
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 140 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }

        ZStack {
            Color.loopedBlack
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            VideoPlayerView(
                player: viewModel.player,
                videoGravity: .resizeAspect,
                onReadyForDisplay: { _ in }
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            Color.loopedClear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        overlaysVisible.toggle()
                    }
                }

            if overlaysVisible {
                VStack(alignment: .leading, spacing: 12) {
                    headerSection
                    Spacer()
                    VideoControlsOverlayView(
                        isPlaying: viewModel.isPlaying,
                        currentTime: Binding(
                            get: { viewModel.currentTime },
                            set: { viewModel.currentTime = $0 }
                        ),
                        duration: viewModel.duration,
                        isMuted: viewModel.isMuted,
                        onPlayPause: togglePlayPause,
                        onBeginScrub: {
                            viewModel.beginScrub()
                            viewModel.pause()
                        },
                        onEndScrub: { newValue in
                            viewModel.currentTime = newValue
                            viewModel.endScrub(to: newValue, resumeIfPlaying: true)
                        },
                        onMuteToggle: {
                            viewModel.setMuted(!viewModel.isMuted)
                        },
                        onFullScreen: nil,
                        sizeScale: 1.2
                    )
                    .padding(.bottom, 4)

                    if let config = actionBarConfig {
                        PostActionBarCompact(config: config, sizeScale: 1.3)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .transition(.opacity)
            }

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.loopedCustom(.bold, size: 14))
                    .foregroundColor(.loopedWhite)
                    .frame(width: 34, height: 34)
                    .background(Color.loopedBlack.opacity(0.45))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .offset(y: dragOffset)
        .gesture(dragGesture)
        .onAppear {
            viewModel.setMuted(false)
            if usesSharedViewModel {
                if let inlineId = selection.inlineId {
                    playbackManager.lockActive(id: inlineId)
                }
                viewModel.setExternallyPresented(true)
                viewModel.play()
            } else {
                playbackManager.resetVisibility()
                let cleaned = selection.url.trimmingCharacters(in: .whitespacesAndNewlines)
                let url = URL(string: cleaned) ?? URLComponents(string: cleaned)?.url
                viewModel.updateURLIfNeeded(url)
                viewModel.play()
            }
        }
        .onDisappear {
            dragOffset = 0
            if usesSharedViewModel {
                viewModel.setExternallyPresented(false)
                if let inlineId = selection.inlineId {
                    playbackManager.unlockActive(id: inlineId)
                }
            } else {
                viewModel.pause()
            }
            playbackManager.requestVisibilityRefresh()
        }
    }

    private var backgroundOpacity: Double {
        let progress = min(max(dragOffset / 240, 0), 1)
        return 1 - Double(progress) * 0.6
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ProfileAvatarView(
                    imageURL: selection.authorImageUrl,
                    size: 34
                )
                VStack(alignment: .leading, spacing: 2) {
                    if let name = selection.authorName, !name.isEmpty {
                        Text(name)
                            .font(.loopedSubheadlineScaled)
                            .foregroundColor(.loopedWhite)
                    }
                    if let community = selection.communityName, !community.isEmpty {
                        Text(community)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedWhite.opacity(0.7))
                    }
                }
                Spacer()
            }

            if let caption = selection.caption?.trimmingCharacters(in: .whitespacesAndNewlines),
               !caption.isEmpty {
                Text(caption)
                    .font(.loopedBodyScaled)
                    .foregroundColor(.loopedWhite.opacity(0.9))
                    .lineLimit(3)
            }
        }
    }

    private func togglePlayPause() {
        if viewModel.isPlaying {
            viewModel.pause()
        } else {
            viewModel.play()
        }
    }

    private func dismiss() {
        isPresented = false
    }

    private func handleShareTap(_ externalShare: @escaping () -> Void) {
        FullScreenMediaShareAction.perform(
            dismiss: dismiss,
            externalShare: externalShare,
            presentInlineShareSheet: { }
        )
    }

    private var actionBarConfig: PostActionBarConfig? {
        guard let base = selection.postActionConfig else { return nil }
        return PostActionBarConfig(
            state: base.state,
            onLike: base.onLike,
            onComment: {
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    base.onComment()
                }
            },
            onRepost: base.onRepost,
            onShare: { handleShareTap(base.onShare) },
            onSave: base.onSave
        )
    }
}
