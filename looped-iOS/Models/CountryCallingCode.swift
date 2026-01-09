import Foundation

struct CountryCallingCode: Identifiable, Hashable {
    let name: String
    let isoCode: String
    let callingCode: String

    var id: String { isoCode }

    var flagEmoji: String {
        let base: UInt32 = 127397
        return String(isoCode.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(base + scalar.value)
        }.map(Character.init))
    }

    var displayLabel: String {
        "\(flagEmoji) \(name) (+\(callingCode))"
    }
}

extension CountryCallingCode {
    static let supported: [CountryCallingCode] = [
        .init(name: "United States", isoCode: "US", callingCode: "1"),
        .init(name: "Canada", isoCode: "CA", callingCode: "1"),
        .init(name: "United Kingdom", isoCode: "GB", callingCode: "44"),
        .init(name: "Australia", isoCode: "AU", callingCode: "61"),
        .init(name: "Germany", isoCode: "DE", callingCode: "49"),
        .init(name: "France", isoCode: "FR", callingCode: "33"),
        .init(name: "Ireland", isoCode: "IE", callingCode: "353"),
        .init(name: "Netherlands", isoCode: "NL", callingCode: "31"),
        .init(name: "New Zealand", isoCode: "NZ", callingCode: "64"),
        .init(name: "Spain", isoCode: "ES", callingCode: "34"),
        .init(name: "Sweden", isoCode: "SE", callingCode: "46"),
        .init(name: "Switzerland", isoCode: "CH", callingCode: "41")
    ]

    static let defaultSelection: CountryCallingCode = .init(name: "United States", isoCode: "US", callingCode: "1")
}

