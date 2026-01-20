import SwiftUI

struct NotificationsView: View {
    @ObservedObject var viewModel: NotificationsViewModel
    @State private var selectedProfileDestination: ProfileDestination?

    init(viewModel: NotificationsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Notifications List
            if viewModel.notifications.isEmpty, let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "exclamationmark.triangle")
                        .font(.loopedCustom(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.3))

                    Text("Couldn’t load notifications")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)

                    Text(errorMessage)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button(action: { Task { await viewModel.loadNotifications() } }) {
                        Text("Retry")
                            .font(.loopedSubBodyBold)
                            .foregroundColor(.loopedWhite)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.loopedPrimary)
                            )
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.notifications.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "bell.slash")
                        .font(.loopedCustom(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.3))

                    Text("No notifications yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)

                    Text("When you get notifications, they'll show up here")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.notifications) { notification in
                            NotificationRow(
                                notification: notification,
                                actionTitle: viewModel.actionTitle(for: notification),
                                isActionLoading: viewModel.actionLoadingIds.contains(notification.id),
                                isActionEnabled: viewModel.isActionEnabled(for: notification),
                                onActionTapped: {
                                    viewModel.handleActionButtonTap(notification)
                                },
                                onActorTapped: {
                                    if let destination = ProfileDestination(notification: notification) {
                                        selectedProfileDestination = destination
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.handleNotificationTap(notification)
                            }
                            .onAppear {
                                if notification.id == viewModel.notifications.last?.id {
                                    Task { await viewModel.loadMoreNotifications() }
                                }
                            }

                            // Divider
                            if notification.id != viewModel.notifications.last?.id {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                                    .padding(.leading, 68) // Indent to align with content
                            }
                        }
                    }
                }
                .refreshable {
                    await viewModel.refreshNotifications()
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.markAllAsRead() }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.loopedCustom(size: 20))
                        .foregroundColor(isMarkAllDisabled ? .loopedTextSecondary.opacity(0.4) : .loopedTextSecondary)
                }
                .disabled(isMarkAllDisabled)
            }
        }
        .toast($viewModel.toastMessage)
        .navigationDestination(item: $selectedProfileDestination) { destination in
            switch destination {
            case .user(let id):
                UserProfileView(userId: id)
            case .anon(let id):
                UserProfileView(anonProfileId: id)
            }
        }
        .task {
            if viewModel.notifications.isEmpty {
                await viewModel.loadNotifications()
            }
        }
    }

    private var isMarkAllDisabled: Bool {
        viewModel.notifications.isEmpty || viewModel.notifications.allSatisfy(\.isRead) || viewModel.isLoading
    }
}

private enum ProfileDestination: Hashable, Identifiable {
    case user(Int)
    case anon(Int)

    var id: String {
        switch self {
        case .user(let id):
            return "user:\(id)"
        case .anon(let id):
            return "anon:\(id)"
        }
    }

    init?(notification: Notification) {
        if notification.actorIsAnonymous, let anonId = notification.actorAnonProfileId?.backendInt {
            self = .anon(anonId)
            return
        }
        if let userId = notification.actorId?.backendInt {
            self = .user(userId)
            return
        }
        return nil
    }
}

#Preview {
    NotificationsView(viewModel: NotificationsViewModel())
}
