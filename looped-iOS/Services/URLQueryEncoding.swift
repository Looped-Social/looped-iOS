import Foundation

enum URLQueryEncoding {
    /// A conservative character set for encoding query param values.
    /// Important for opaque cursors which may contain `+`, `/`, or `=`.
    static let allowedCharacterSet: CharacterSet = {
        CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+/=&?#"))
    }()

    static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? value
    }
}

