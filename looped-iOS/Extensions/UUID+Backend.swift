import Foundation

extension UUID {
    static func fromBackendId(_ value: Int) -> UUID {
        let hex = String(format: "%012X", value)
        let uuidString = "00000000-0000-0000-0000-\(hex)"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    /// Converts a UUID generated from `fromBackendId` back into its integer form.
    /// Returns nil if the UUID is not in the expected padded format.
    var backendInt: Int? {
        let components = uuidString.split(separator: "-")
        guard
            components.count == 5,
            components[0] == "00000000",
            components[1] == "0000",
            components[2] == "0000",
            components[3] == "0000",
            components[4].count == 12
        else {
            return nil
        }

        return Int(components[4], radix: 16)
    }
}
