import LinkPresentation
import SwiftUI
import UIKit

enum NativeLinkPreviewStyle {
    case standard
    case composer
    case messageBubble

    var minHeight: CGFloat {
        switch self {
        case .standard:
            return 156
        case .composer:
            return 156
        case .messageBubble:
            return 140
        }
    }

    var fixedWidth: CGFloat? {
        switch self {
        case .standard, .composer:
            return nil
        case .messageBubble:
            return 220
        }
    }
}

struct NativeLinkPreviewView: View {
    let url: URL
    let style: NativeLinkPreviewStyle

    @State private var loadState: LinkPreviewLoadState = .loading
    @State private var loadingTimeoutTask: Task<Void, Never>?

    init(url: URL, style: NativeLinkPreviewStyle = .standard) {
        self.url = url
        self.style = style
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if loadState == .failed {
                unavailableFallback
            } else if loadState != .loaded {
                placeholder
            }

            NativeURLLinkPreviewCard(
                url: url,
                minHeight: style.minHeight,
                onStateChange: handleStateChange
            )
        }
        .frame(maxWidth: style.fixedWidth == nil ? .infinity : nil, alignment: .leading)
        .frame(width: style.fixedWidth, alignment: .leading)
        .frame(minHeight: style.minHeight)
        .id(url.absoluteString)
        .onChange(of: url.absoluteString) { _, _ in
            loadingTimeoutTask?.cancel()
            loadState = .loading
        }
        .onDisappear {
            loadingTimeoutTask?.cancel()
            loadingTimeoutTask = nil
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.loopedMutedBackground)
            .overlay(alignment: .leading) {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.loopedSecondary)
                    Text(url.host ?? "Loading link preview")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
            }
            .frame(minHeight: style.minHeight)
    }

    private var unavailableFallback: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.loopedMutedBackground)
            .overlay(alignment: .leading) {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.loopedCustom(.medium, size: 14))
                        .foregroundColor(.loopedTextSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.host ?? "Link")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(1)
                        Text("Preview unavailable")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
            }
            .frame(minHeight: style.minHeight)
    }

    private func handleStateChange(_ state: LinkPreviewLoadState) {
        guard loadState != state else { return }
        loadState = state
        switch state {
        case .loading:
            loadingTimeoutTask?.cancel()
            loadingTimeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else { return }
                if loadState == .loading {
                    loadState = .failed
                }
            }
        case .loaded, .failed:
            loadingTimeoutTask?.cancel()
            loadingTimeoutTask = nil
        }
    }
}

private struct NativeURLLinkPreviewCard: UIViewRepresentable {
    let url: URL
    let minHeight: CGFloat
    let onStateChange: (LinkPreviewLoadState) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChange: onStateChange)
    }

    func makeUIView(context: Context) -> LinkPreviewContainerView {
        let container = LinkPreviewContainerView(stateHandler: context.coordinator.onStateChange)
        container.configure(url: url)
        return container
    }

    func updateUIView(_ uiView: LinkPreviewContainerView, context: Context) {
        uiView.setStateHandler(context.coordinator.onStateChange)
        uiView.configure(url: url)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LinkPreviewContainerView, context: Context) -> CGSize {
        let targetWidth = proposal.width ?? UIScreen.main.bounds.width - 32
        let measured = uiView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let resolvedHeight = max(minHeight, measured.height)
        return CGSize(width: targetWidth, height: resolvedHeight)
    }

    final class Coordinator {
        let onStateChange: (LinkPreviewLoadState) -> Void

        init(onStateChange: @escaping (LinkPreviewLoadState) -> Void) {
            self.onStateChange = onStateChange
        }
    }
}

private enum LinkPreviewLoadState: Equatable {
    case loading
    case loaded
    case failed
}

private final class LinkPreviewContainerView: UIView {
    private static let metadataCache = NSCache<NSString, LPLinkMetadata>()

    private var currentURL: URL?
    private var linkView: LPLinkView?
    private var metadataProvider: LPMetadataProvider?
    private var stateHandler: ((LinkPreviewLoadState) -> Void)?

    init(stateHandler: @escaping (LinkPreviewLoadState) -> Void) {
        self.stateHandler = stateHandler
        super.init(frame: .zero)
        configureView()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        backgroundColor = .clear
        clipsToBounds = false
    }

    func setStateHandler(_ handler: @escaping (LinkPreviewLoadState) -> Void) {
        self.stateHandler = handler
    }

    func configure(url: URL) {
        guard currentURL != url || linkView == nil else { return }
        currentURL = url
        metadataProvider?.cancel()
        metadataProvider = nil

        linkView?.removeFromSuperview()

        let view = LPLinkView(url: url)
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false

        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        linkView = view
        let cacheKey = Self.cacheKey(for: url)
        if let cached = Self.metadataCache.object(forKey: cacheKey) {
            view.metadata = cached
            emitState(.loaded)
        } else {
            emitState(.loading)
            fetchMetadata(for: url, cacheKey: cacheKey, in: view)
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func fetchMetadata(for url: URL, cacheKey: NSString, in linkView: LPLinkView) {
        let provider = LPMetadataProvider()
        provider.timeout = 12
        metadataProvider = provider

        provider.startFetchingMetadata(for: url) { [weak self, weak linkView] metadata, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.currentURL == url else { return }
                defer { self.metadataProvider = nil }

                guard let linkView else { return }

                if let metadata {
                    Self.metadataCache.setObject(metadata, forKey: cacheKey)
                    linkView.metadata = metadata
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                    self.emitState(.loaded)
#if DEBUG
                    let resolvedTitle = metadata.title ?? "(no title)"
                    print("Link preview metadata applied url=\(url.absoluteString) title=\(resolvedTitle)")
#endif
                } else if let error {
                    self.emitState(.failed)
#if DEBUG
                    print("Link preview metadata fetch failed url=\(url.absoluteString) error=\(error.localizedDescription)")
#endif
                } else {
                    self.emitState(.failed)
                }
            }
        }
    }

    private static func cacheKey(for url: URL) -> NSString {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString as NSString
        }
        components.fragment = nil
        if let host = components.host {
            components.host = host.lowercased()
        }
        let normalized = components.url?.absoluteString ?? url.absoluteString
        return normalized as NSString
    }

    private func emitState(_ state: LinkPreviewLoadState) {
        guard let handler = stateHandler else { return }
        DispatchQueue.main.async {
            handler(state)
        }
    }
}
