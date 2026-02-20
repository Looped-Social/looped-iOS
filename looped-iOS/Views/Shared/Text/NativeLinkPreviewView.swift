import LinkPresentation
import SwiftUI

struct NativeLinkPreviewView: View {
    let url: URL

    @State private var metadata: LPLinkMetadata?
    @State private var isLoading = false
    @State private var failed = false

    var body: some View {
        Group {
            if let metadata {
                NativeLinkPreviewCard(metadata: metadata)
            } else if isLoading {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: url.absoluteString) {
            await loadIfNeeded()
        }
        .onChange(of: url.absoluteString) { _, _ in
            metadata = nil
            failed = false
            isLoading = false
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.loopedMutedBackground)
            .frame(height: 72)
            .overlay {
                ProgressView()
                    .tint(.loopedSecondary)
            }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard metadata == nil else { return }
        guard !isLoading, !failed else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            metadata = try await LinkPreviewMetadataStore.shared.metadata(for: url)
        } catch {
            failed = true
        }
    }
}

private struct NativeLinkPreviewCard: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        style(view)
        return view
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        style(uiView)
    }

    private func style(_ view: LPLinkView) {
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.backgroundColor = .clear
    }
}
