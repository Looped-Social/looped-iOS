import SwiftUI

struct MessageRequestsView: View {
    @ObservedObject var viewModel: MessagesViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoadingRequests && viewModel.messageRequests.isEmpty {
                    ProgressView("Loading requests...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else if viewModel.messageRequests.isEmpty {
                    EmptyMessagesView(
                        title: "No requests",
                        subtitle: "When someone you don't follow messages you, they'll show up here.",
                        buttonTitle: "Refresh",
                        onButtonTap: {
                            Task { await viewModel.loadMessageRequests() }
                        }
                    )
                } else {
                    Text("Approve or reject people you don't follow before chatting.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    ForEach(viewModel.messageRequests) { request in
                        MessageRequestRow(
                            request: request,
                            isProcessing: viewModel.processingRequestIds.contains(request.backendId),
                            onPreview: {},
                            onProfileTap: { _ in },
                            onApprove: {
                                Task { await viewModel.approveMessageRequest(request) }
                            },
                            onReject: {
                                Task { await viewModel.rejectMessageRequest(request) }
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Requests")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.messageRequests.isEmpty {
                await viewModel.loadMessageRequests()
            }
        }
    }
}

#Preview {
    MessageRequestsView(viewModel: MessagesViewModel())
}
