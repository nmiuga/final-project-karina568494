import Foundation
import os
import Combine
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LibraryStore", category: "Persistence")

    private var libraryURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("library.json")
    }

    private struct PersistedState: Codable {
        var books: [String: Book]
        var shelves: [ShelfType: Shelf]
        var sessions: [ReadingSession]
        var journals: [JournalEntry]
    }

    @Published var books: [String: Book] = [:]
    @Published var shelves: [ShelfType: Shelf] = [
        .unread: Shelf(type: .unread, bookIDs: []),
        .reading: Shelf(type: .reading, bookIDs: []),
        .read: Shelf(type: .read, bookIDs: []),
        .favorites: Shelf(type: .favorites, bookIDs: [])
    ]
    @Published var sessions: [ReadingSession] = []
    @Published var journals: [JournalEntry] = []

    init() {
        load()
    }

    func add(book: Book, to shelf: ShelfType) {
        books[book.id] = book
        if shelves[shelf]?.bookIDs.contains(book.id) != true {
            shelves[shelf]?.bookIDs.append(book.id)
        }
        if shelf == .read {
            shelves[.reading]?.bookIDs.removeAll { $0 == book.id }
            shelves[.unread]?.bookIDs.removeAll { $0 == book.id }
        }
        save()
    }

    func remove(bookID: String, from shelf: ShelfType) {
        shelves[shelf]?.bookIDs.removeAll { $0 == bookID }
        save()
    }

    func deleteShelf(_ type: ShelfType) {
        shelves[type]?.bookIDs.removeAll()
        save()
    }

    func toggleFavorite(bookID: String) {
        guard var book = books[bookID] else { return }
        book.isFavorite.toggle()
        books[bookID] = book
        if book.isFavorite {
            if shelves[.favorites]?.bookIDs.contains(bookID) != true {
                shelves[.favorites]?.bookIDs.append(bookID)
            }
        } else {
            shelves[.favorites]?.bookIDs.removeAll { $0 == bookID }
        }
        save()
    }

    func startSession(for bookID: String, startPage: Int?) -> ReadingSession {
        let session = ReadingSession(id: UUID(), bookID: bookID, startDate: Date(), endDate: nil, startPage: startPage, endPage: nil)
        sessions.append(session)
        if let book = books[bookID] {
            add(book: book, to: .reading)
        }
        save()
        return session
    }

    func endSession(id: UUID, endPage: Int?) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].endDate = Date()
        sessions[idx].endPage = endPage
        save()
    }

    func deleteSessions(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        save()
    }

    func addJournal(for sessionID: UUID, bookID: String, pageRange: String?, text: String) {
        let entry = JournalEntry(id: UUID(), date: Date(), sessionID: sessionID, bookID: bookID, pageRange: pageRange, text: text)
        journals.insert(entry, at: 0)
        save()
    }

    func updateJournal(id: UUID, text: String, pageRange: String?) {
        guard let idx = journals.firstIndex(where: { $0.id == id }) else { return }
        journals[idx].text = text
        journals[idx].pageRange = pageRange
        save()
    }

    func deleteJournal(id: UUID) {
        journals.removeAll { $0.id == id }
        save()
    }

    private func save() {
        do {
            let state = PersistedState(books: books, shelves: shelves, sessions: sessions, journals: journals)
            let data = try JSONEncoder().encode(state)
            try data.write(to: libraryURL, options: [.atomic])
        } catch {
            logger.error("Failed to save library: \(error.localizedDescription)")
        }
    }

    private func load() {
        do {
            let url = libraryURL
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder().decode(PersistedState.self, from: data)
            self.books = state.books
            self.shelves = state.shelves
            self.sessions = state.sessions
            self.journals = state.journals
        } catch {
            logger.error("Failed to load library: \(error.localizedDescription)")
        }
    }
}
