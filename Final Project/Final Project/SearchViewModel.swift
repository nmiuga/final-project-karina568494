import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var results: [Book] = []
    @Published var isLoading: Bool = false

    func search(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let books = try await GoogleBooksAPI.searchVolumes(trimmed)
            results = books
        } catch {
            results = []
        }
    }
}
