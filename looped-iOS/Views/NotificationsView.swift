import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            NotificationsHeader(
                isMarkAllDisabled: viewModel.notifications.allSatisfy(\.isRead) || viewModel.isLoading,
                onMarkAllRead: {
                    Task { await viewModel.markAllAsRead() }
                }
            )

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
                            Button(action: {
                                viewModel.handleNotificationTap(notification)
                            }) {
                                NotificationRow(
                                    notification: notification,
                                    isActionLoading: viewModel.actionLoadingIds.contains(notification.id),
                                    onActionTapped: {
                                        viewModel.handleActionButtonTap(notification)
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
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
        .navigationBarHidden(true)
        .toast($viewModel.toastMessage)
        .task {
            await viewModel.loadNotifications()
        }
    }
}

// MARK: - Notifications Header
struct NotificationsHeader: View {
    let isMarkAllDisabled: Bool
    let onMarkAllRead: () -> Void

    var body: some View {
        HStack {
            Text("Notifications")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            // Mark all as read button (optional)
            Button(action: {
                onMarkAllRead()
            }) {
                Image(systemName: "checkmark.circle")
                    .font(.loopedCustom(size: 20))
                    .foregroundColor(isMarkAllDisabled ? .loopedTextSecondary.opacity(0.4) : .loopedTextSecondary)
            }
            .disabled(isMarkAllDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.loopedBackground)

        // Divider
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.loopedTextSecondary.opacity(0.1))
    }
}

#Preview {
    NotificationsView()
}
