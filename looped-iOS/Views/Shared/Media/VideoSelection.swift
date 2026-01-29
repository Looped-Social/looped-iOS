import Foundation

struct VideoSelection: Identifiable, Equatable {
    let id: String

    init(url: String) {
        self.id = url
    }

    var url: String { id }
}
