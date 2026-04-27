import Foundation

struct GoogleBooksAPI {
    struct VolumeResponse: Codable { let items: [Volume]? }
    struct Volume: Codable { let id: String; let volumeInfo: VolumeInfo }
    struct VolumeInfo: Codable {
        let title: String?
        let authors: [String]?
        let description: String?
        let pageCount: Int?
        let imageLinks: ImageLinks?
    }
    struct ImageLinks: Codable { let thumbnail: String?; let smallThumbnail: String? }

    static func searchVolumes(_ query: String) async throws -> [Book] {
        let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://www.googleapis.com/books/v1/volumes?q=\(escaped)&maxResults=20")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(VolumeResponse.self, from: data)
        let books: [Book] = (decoded.items ?? []).map { item in
            let info = item.volumeInfo
            let thumb = info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail
            let url: URL? = {
                guard var t = thumb else { return nil }
                // Prefer https
                if t.hasPrefix("http:") { t = t.replacingOccurrences(of: "http:", with: "https:") }
                // Upgrade resolution by increasing zoom if present, else append zoom=2
                if t.contains("zoom=") {
                    t = t.replacingOccurrences(of: "zoom=0", with: "zoom=2")
                    t = t.replacingOccurrences(of: "zoom=1", with: "zoom=2")
                } else {
                    let sep = t.contains("?") ? "&" : "?"
                    t += "\(sep)zoom=2"
                }
                return URL(string: t)
            }()
            return Book(
                id: item.id,
                title: info.title ?? "Untitled",
                authors: info.authors ?? [],
                description: info.description,
                thumbnailURL: url,
                pageCount: info.pageCount
            )
        }
        return books
    }
}
