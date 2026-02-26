import Testing
@testable import looped_iOS

@Suite
struct StringLoopedTests {
    @Test
    func compactRailPersonName_keepsShortName() {
        #expect("Andre Roberts".compactRailPersonName(maxLength: 20) == "Andre Roberts")
    }

    @Test
    func compactRailPersonName_usesFirstNameAndLastInitialWhenLong() {
        #expect("Andre Roberts".compactRailPersonName(maxLength: 10) == "Andre R.")
    }

    @Test
    func compactRailPersonName_fallsBackToTwoDotTruncation() {
        #expect("Alexanderthegreat".compactRailPersonName(maxLength: 10) == "Alexande..")
    }
}
