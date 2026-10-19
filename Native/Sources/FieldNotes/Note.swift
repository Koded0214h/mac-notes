import Foundation

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var pinned: Bool

    init(id: UUID = UUID(), title: String = "Untitled note", content: String = "", createdAt: Date = .now, updatedAt: Date = .now, pinned: Bool = false) {
        self.id = id; self.title = title; self.content = content; self.createdAt = createdAt; self.updatedAt = updatedAt; self.pinned = pinned
    }
}
