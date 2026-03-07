import Foundation
import Testing
@testable import looped_iOS

@Suite
struct ShareSheetPayloadTests {
    @Test
    func combinesPrimaryTextAndURLForCopyAndMessage() {
        let url = URL(string: "https://looped-social.com/p/42")!
        let payload = ShareSheetPayload(items: ["Check this out", url])

        #expect(payload.primaryText == "Check this out")
        #expect(payload.primaryURL == url)
        #expect(payload.copyText == "Check this out https://looped-social.com/p/42")
        #expect(payload.messageBody == "Check this out https://looped-social.com/p/42")
    }

    @Test
    func usesURLWhenTextMissing() {
        let url = URL(string: "https://looped-social.com/c/10")!
        let payload = ShareSheetPayload(items: [url])

        #expect(payload.primaryText == nil)
        #expect(payload.primaryURL == url)
        #expect(payload.copyText == "https://looped-social.com/c/10")
        #expect(payload.messageBody == "https://looped-social.com/c/10")
    }

    @Test
    func usesTextWhenURLMissing() {
        let payload = ShareSheetPayload(items: ["Looped invite"])

        #expect(payload.primaryText == "Looped invite")
        #expect(payload.primaryURL == nil)
        #expect(payload.copyText == "Looped invite")
        #expect(payload.messageBody == "Looped invite")
    }

    @Test
    func trimsAndIgnoresEmptyText() {
        let url = URL(string: "https://looped-social.com")!
        let payload = ShareSheetPayload(items: ["   ", "  Hey  ", url])

        #expect(payload.primaryText == "Hey")
        #expect(payload.copyText == "Hey https://looped-social.com")
    }
}
