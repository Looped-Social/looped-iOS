import Testing
@testable import looped_iOS

@Suite
struct ToastKindTests {
    @Test
    func pendingToastKind_usesPendingTitleAndClockSymbol() {
        #expect(ToastKind.pending.title == "Pending")
        #expect(ToastKind.pending.symbolName == "clock.fill")
    }
}
