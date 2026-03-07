import SwiftUI

struct UserNoticeSheetView: View {
    let notice: UserNotice
    let inFlightAction: UserNoticeAckAction?
    let onAction: (UserNoticeAckAction) -> Void

    private struct NoticeContent {
        let title: String
        let detail: String
        let detailColor: Color
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Image("logo-banner")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 52)
                    .accessibilityHidden(true)

                Text(content.title)
                    .font(.loopedSubheadSemibold)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(content.detail)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(content.detailColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)

            VStack(spacing: 10) {
                PrimaryButton(
                    title: primaryActionTitle,
                    isEnabled: inFlightAction == nil,
                    isLoading: inFlightAction == primaryAction
                ) {
                    onAction(primaryAction)
                }

                if let secondaryTitle {
                    StyledButton(
                        title: secondaryTitle,
                        style: MutedSecondaryButtonStyle(),
                        isEnabled: inFlightAction == nil,
                        isLoading: inFlightAction == .dismiss
                    ) {
                        onAction(.dismiss)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 390, alignment: .top)
        .background(Color.loopedBackground)
        .accessibilityIdentifier("userNoticeSheet")
    }

    private var content: NoticeContent {
        if isMigrationNotice {
            return NoticeContent(
                title: "We're still figuring things out, and we made a big change.",
                detail: "We removed school and major communities so Looped can focus on workplaces and fields. If this disrupted how you used the app, we're sorry. Verify your job and there will be a place for you here on Looped. - The Looped Team",
                detailColor: .loopedTextPrimary
            )
        }

        return NoticeContent(
            title: notice.title,
            detail: notice.body,
            detailColor: .loopedTextSecondary
        )
    }

    private var normalizedCtaLabel: String? {
        guard let rawLabel = notice.ctaLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawLabel.isEmpty else {
            return nil
        }
        return rawLabel
    }

    private var primaryActionTitle: String {
        if isMigrationNotice {
            return normalizedCtaLabel ?? "Got it"
        }

        if let normalizedCtaLabel {
            return normalizedCtaLabel
        }

        return notice.dismissible ? "Close" : "Continue"
    }

    private var primaryAction: UserNoticeAckAction {
        if isMigrationNotice {
            return .cta
        }

        if normalizedCtaLabel != nil {
            return .cta
        }

        return notice.dismissible ? .dismiss : .cta
    }

    private var secondaryTitle: String? {
        guard !isMigrationNotice else { return nil }
        guard notice.dismissible, normalizedCtaLabel != nil else {
            return nil
        }

        return "Close"
    }

    private var isMigrationNotice: Bool {
        notice.key == "workplace_fields_migration_v1"
    }
}

#Preview("Migration Notice") {
    UserNoticeSheetView(
        notice: UserNotice(
            key: "workplace_fields_migration_v1",
            title: "Looped now supports workplaces + fields",
            body: "School and major communities are no longer available. If needed, update your workplace/field in Settings.",
            dismissible: false,
            ctaLabel: "Got it"
        ),
        inFlightAction: nil,
        onAction: { _ in }
    )
    .padding()
    .background(Color.loopedMutedBackground)
}

#Preview("Generic Notice") {
    UserNoticeSheetView(
        notice: UserNotice(
            key: "generic_notice_v1",
            title: "Privacy update",
            body: "We tightened privacy controls for this account.",
            dismissible: true,
            ctaLabel: "Review"
        ),
        inFlightAction: nil,
        onAction: { _ in }
    )
    .padding()
    .background(Color.loopedMutedBackground)
}
