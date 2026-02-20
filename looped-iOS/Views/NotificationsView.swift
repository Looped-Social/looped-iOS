import SwiftUI

struct NotificationsView: View {
    @ObservedObject var viewModel: NotificationsViewModel
    @State private var selectedProfileDestination: ProfileDestination?
    @State private var selectedDetailDestination: NotificationDetailDestination?
    @State private var isAtTop = true

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
                                },
                                onHideTapped: {
                                    viewModel.toastMessage = ToastMessage(
                                        text: "Hide is preview-only for now.",
                                        kind: .info
                                    )
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if notification.type == .announcement || notification.type == .system {
                                    selectedDetailDestination = NotificationDetailDestination(notification: notification)
                                    viewModel.markNotificationAsRead(notification)
                                    return
                                }
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
                    .background(
                        GeometryReader { geo in
                            Color.loopedClear
                                .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                                    isAtTop = newValue >= -20
                                }
                        }
                    )
                }
                .loopedPullToRefresh(isAtTop: isAtTop) {
                    await viewModel.refreshNotifications()
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 0) {
                    Text("Notifications")
                        .font(.loopedHeaderStrong)
                        .foregroundColor(.loopedTextPrimary)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ToolbarItem(placement: .topBarTrailing) {
                bulkNotificationActionsButton
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
        .navigationDestination(item: $selectedDetailDestination) { destination in
            NotificationDetailView(destination: destination)
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

    private var isDismissAllDisabled: Bool {
        viewModel.notifications.isEmpty || viewModel.isLoading
    }

    private var areBulkNotificationActionsDisabled: Bool {
        isDismissAllDisabled && isMarkAllDisabled
    }

    private var bulkNotificationActionsButton: some View {
        Menu {
            Button {
                viewModel.toastMessage = ToastMessage(
                    text: "Dismiss all is preview-only for now.",
                    kind: .info
                )
            } label: {
                Label("Dismiss all", systemImage: "eye.slash")
            }
            .disabled(isDismissAllDisabled)

            Button {
                Task { await viewModel.markAllAsRead() }
            } label: {
                Label("Read all", systemImage: "checkmark.circle")
            }
            .disabled(isMarkAllDisabled)
        } label: {
            Image(systemName: "ellipsis")
                .font(.loopedCustom(.medium, size: 18))
                .foregroundColor(
                    areBulkNotificationActionsDisabled
                    ? .loopedTextSecondary.opacity(0.4)
                    : .loopedTextSecondary
                )
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notification actions")
        .disabled(areBulkNotificationActionsDisabled)
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

private struct NotificationDetailDestination: Hashable, Identifiable {
    let id: UUID
    let kindRawValue: String
    let actorName: String
    let title: String?
    let body: String?
    let createdAt: Date

    init(notification: Notification) {
        id = notification.id
        kindRawValue = notification.type.rawValue
        actorName = notification.actorName
        let trimmedTitle = notification.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedTitle, !trimmedTitle.isEmpty {
            title = trimmedTitle
        } else if notification.type == .announcement || notification.type == .system {
            title = notification.notificationText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            title = nil
        }
        body = notification.previewText?.trimmingCharacters(in: .whitespacesAndNewlines)
        createdAt = notification.createdAt
    }

    var navigationTitle: String {
        kindRawValue == NotificationType.announcement.rawValue ? "Announcement" : "Notification"
    }

    var headerTitle: String {
        if let title, !title.isEmpty { return title }
        return kindRawValue == NotificationType.announcement.rawValue ? "Announcement" : "Notification"
    }
}

private struct NotificationDetailView: View {
    let destination: NotificationDetailDestination

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(destination.headerTitle)
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text(destination.actorName)
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                    Text("•")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                    Text(destination.createdAt, style: .date)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                    Text(destination.createdAt, style: .time)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                }

                Divider()
                    .overlay(Color.loopedTextSecondary.opacity(0.15))

                if let body = destination.body, !body.isEmpty {
                    Text(body)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No additional details available.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .textSelection(.enabled)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle(destination.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NotificationsView(viewModel: NotificationsViewModel())
}
