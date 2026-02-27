import Foundation

/// Debounced reporter for `/v1/app/open`.
///
/// - Debounce: at most once per 20 seconds while repeatedly becoming active.
/// - Cold start: first call in-process always sends.
actor AppOpenReporter {
    static let shared = AppOpenReporter()

    private let service: AppOpenServiceProtocol
    private let debounceWindowSeconds: TimeInterval = 20
    private let maxSeenCommunitiesToSend = 50

    private var lastSentAt: Date?
    private var pendingSeenCommunityIds: Set<Int> = []

    init(service: AppOpenServiceProtocol = AppOpenService()) {
        self.service = service
    }

    func markCommunitySeen(_ communityId: Int) {
        guard communityId > 0 else { return }
        pendingSeenCommunityIds.insert(communityId)
    }

    func reportIfNeeded(isAuthenticated: Bool, activeCommunityId: Int?) async {
        guard isAuthenticated else { return }

        let now = Date()
        if let lastSentAt, now.timeIntervalSince(lastSentAt) < debounceWindowSeconds {
            if let activeCommunityId {
                pendingSeenCommunityIds.insert(activeCommunityId)
            }
            return
        }

        lastSentAt = now
        if let activeCommunityId {
            pendingSeenCommunityIds.insert(activeCommunityId)
        }

        let seenIds = Array(pendingSeenCommunityIds)
            .filter { $0 > 0 }
            .prefix(maxSeenCommunitiesToSend)
        pendingSeenCommunityIds.removeAll()

        do {
            _ = try await service.reportOpen(
                openedAt: now,
                activeCommunityId: activeCommunityId,
                seenCommunityIds: seenIds.isEmpty ? nil : Array(seenIds)
            )
        } catch {
            // Best-effort only. Backend is monotonic; we'll try again on the next eligible activation.
        }
    }
}

