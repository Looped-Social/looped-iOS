import Foundation

extension UUID {
    static func fromBackendId(_ value: Int) -> UUID {
        let hex = String(format: "%012X", value)
        let uuidString = "00000000-0000-0000-0000-\(hex)"
        return UUID(uuidString: uuidString) ?? UUID()
    }
}
