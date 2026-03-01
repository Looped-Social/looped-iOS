import Testing
@testable import looped_iOS

struct FullScreenMediaShareActionTests {
    @Test
    func perform_withExternalShare_dismissesBeforeSchedulingAndSharing() {
        var events: [String] = []

        FullScreenMediaShareAction.perform(
            dismiss: { events.append("dismiss") },
            externalShare: { events.append("share") },
            presentInlineShareSheet: { events.append("inline") },
            schedule: { action in
                events.append("scheduled")
                #expect(events == ["dismiss", "scheduled"])
                action()
            }
        )

        #expect(events == ["dismiss", "scheduled", "share"])
    }

    @Test
    func perform_withoutExternalShare_presentsInlineShareSheetWithoutDismiss() {
        var events: [String] = []

        FullScreenMediaShareAction.perform(
            dismiss: { events.append("dismiss") },
            externalShare: nil,
            presentInlineShareSheet: { events.append("inline") },
            schedule: { _ in
                events.append("scheduled")
            }
        )

        #expect(events == ["inline"])
    }
}
