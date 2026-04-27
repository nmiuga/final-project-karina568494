import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var authors: [String]
    var description: String?
    var thumbnailURL: URL?
    var pageCount: Int?
    var isFavorite: Bool = false
}

enum ShelfType: String, CaseIterable, Codable {
    case unread = "Unread"
    case reading = "Currently Reading"
    case read = "Read"
    case favorites = "Favorites"
}

struct Shelf: Codable {
    var type: ShelfType
    var bookIDs: [String]
}

struct ReadingSession: Identifiable, Codable {
    let id: UUID
    let bookID: String
    let startDate: Date
    var endDate: Date?
    var startPage: Int?
    var endPage: Int?
}

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let sessionID: UUID
    let bookID: String
    var pageRange: String?
    var text: String
}
