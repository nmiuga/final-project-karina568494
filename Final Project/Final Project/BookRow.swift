import SwiftUI

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ThumbnailView(url: book.thumbnailURL)
                .frame(width: 56, height: 84)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.shelfBorder, lineWidth: 0.5)
                )
            

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .headlineText()
                    .lineLimit(2)
                if !book.authors.isEmpty {
                    Text(book.authors.joined(separator: ", "))
                        .subheadlineText()
                        .lineLimit(1)
                }
                
            }
            Spacer()
            
        }
        .padding(.vertical, 6)
        
    }
    
}

private struct ThumbnailView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Theme.shelfBackground.opacity(0.2)
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
        .background(Theme.background.opacity(0.15))
    }

    private var placeholder: some View {
        ZStack {
            Theme.background.opacity(0.25)
            Image(systemName: "book")
                .imageScale(.large)
                .foregroundStyle(Theme.text.opacity(0.5))
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        List {
            BookRow(book: Book(id: "1", title: "Sample Book Title That May Be Long", authors: ["Jane Doe", "John Appleseed"], description: nil, thumbnailURL: URL(string: "https://books.google.com/books/content?id=zyTCAlFPjgYC&printsec=frontcover&img=1&zoom=2&source=gbs_api"), pageCount: 320))
            BookRow(book: Book(id: "2", title: "No Thumbnail Example", authors: ["Unknown"], description: nil, thumbnailURL: nil, pageCount: nil))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowBackground(Color.clear)
    }
}
