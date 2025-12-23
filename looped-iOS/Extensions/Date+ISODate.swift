import Foundation

extension Date {
    func yyyyMMddString() -> String {
        DateFormatter.yyyyMMdd.string(from: self)
    }
}

extension String {
    func yyyyMMddDate() -> Date? {
        DateFormatter.yyyyMMdd.date(from: self)
    }
}

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
