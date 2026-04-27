import SwiftUI
import Foundation
import Combine

// Note: Avoid type ambiguities by using uniquely named app/store types here.

@main
struct FinalProjectApp: App {
    @StateObject private var store = AppLibraryStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppLibraryStore
    @State private var showSplash: Bool = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(onFinish: {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showSplash = false
                    }
                })
                .transition(.opacity)
            } else {
                LibraryView()
                    .transition(.opacity)
            }
        }
    }
}

struct SplashView: View {
    var onFinish: () -> Void
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            SplashBackground()

            Text("Hello, Bookworm!")
                .font(.poppinsBold(size: 34))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.7, blendDuration: 0.2)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                    // Hold briefly, then finish
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            opacity = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            onFinish()
                        }
                    }
                }
        }
    }
}

@MainActor
final class AppLibraryStore: ObservableObject {
    @Published var books: [String: Book] = [:]
    @Published var shelves: [ShelfType: [String]] = [
        .unread: [],
        .reading: [],
        .read: [],
        .favorites: []
    ]
    
    struct ReadingSession: Identifiable, Hashable {
        let id: UUID = UUID()
        let bookID: String
        var date: Date
        var startPage: Int
        var endPage: Int
        var durationMinutes: Int
        var reflection: String
        var pagesRead: Int { max(0, endPage - startPage) }
    }
    struct ReadingGoal {
        var dailyPages: Int
        var dailyTimeMinutes: Int
    }
    @Published var sessionsByBook: [String: [ReadingSession]] = [:]
    @Published var goal: ReadingGoal = .init(dailyPages: 20, dailyTimeMinutes: 20)

    func books(on shelf: ShelfType) -> [Book] {
        let ids = shelves[shelf] ?? []
        return ids.compactMap { books[$0] }
    }

    func add(_ book: Book, to shelf: ShelfType) {
        books[book.id] = book
        if !(shelves[shelf] ?? []).contains(book.id) {
            shelves[shelf, default: []].append(book.id)
        }
    }
    
    func addSession(for book: Book, startPage: Int, endPage: Int, durationMinutes: Int, reflection: String, date: Date = .now) {
        let session = ReadingSession(bookID: book.id, date: date, startPage: startPage, endPage: endPage, durationMinutes: durationMinutes, reflection: reflection)
        sessionsByBook[book.id, default: []].append(session)
        // Remove from Unread if present
        if let idx = shelves[.unread]?.firstIndex(of: book.id) {
            shelves[.unread]?.remove(at: idx)
        }
        // Determine if finished
        let isFinished: Bool
        if let total = books[book.id]?.pageCount {
            isFinished = endPage >= total
        } else {
            isFinished = false
        }
        if isFinished {
            // Move to Read
            if !(shelves[.read] ?? []).contains(book.id) {
                shelves[.read, default: []].append(book.id)
            }
            // Also remove from Currently Reading if present
            shelves[.reading]?.removeAll { $0 == book.id }
        } else {
            // Move to Currently Reading
            if !(shelves[.reading] ?? []).contains(book.id) {
                shelves[.reading, default: []].append(book.id)
            }
            // Ensure not in Read yet
            shelves[.read]?.removeAll { $0 == book.id }
        }
    }
    
    func sessions(for book: Book) -> [ReadingSession] {
        sessionsByBook[book.id] ?? []
    }
    
    func deleteSessions(for book: Book, at offsets: IndexSet) {
        guard var arr = sessionsByBook[book.id] else { return }
        arr.remove(atOffsets: offsets)
        sessionsByBook[book.id] = arr
    }
    
    func updateDailyGoal(pages: Int, minutes: Int) {
        goal.dailyPages = max(0, pages)
        goal.dailyTimeMinutes = max(0, minutes)
    }

    func toggleFavorite(_ book: Book) {
        guard var b = books[book.id] else { return }
        b.isFavorite.toggle()
        books[book.id] = b
        if b.isFavorite {
            if !(shelves[.favorites] ?? []).contains(b.id) {
                shelves[.favorites, default: []].append(b.id)
            }
        } else {
            shelves[.favorites]?.removeAll { $0 == b.id }
        }
    }

    func setFavorite(_ book: Book, isFavorite: Bool) {
        // Ensure the book exists in the library
        if books[book.id] == nil {
            books[book.id] = book
        }
        guard var b = books[book.id] else { return }
        b.isFavorite = isFavorite
        books[book.id] = b
        if isFavorite {
            if !(shelves[.favorites] ?? []).contains(b.id) {
                shelves[.favorites, default: []].append(b.id)
            }
        } else {
            shelves[.favorites]?.removeAll { $0 == b.id }
        }
    }

    func remove(_ book: Book, from shelf: ShelfType) {
        shelves[shelf]?.removeAll { $0 == book.id }
    }

    func move(_ book: Book, from fromShelf: ShelfType, to toShelf: ShelfType) {
        remove(book, from: fromShelf)
        if !(shelves[toShelf] ?? []).contains(book.id) {
            shelves[toShelf, default: []].append(book.id)
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var store: AppLibraryStore
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            Theme.background
            TabView(selection: $selectedTab) {
                ShelvesView(
                    onRequestSearch: { selectedTab = 1 },
                    onRequestStartSession: { book in
                        selectedTab = 2
                        NotificationCenter.default.post(name: Notification.Name("StartSessionFromShelf"), object: book)
                    }
                )
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .tag(0)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                ReadingLogView()
                    .tabItem {
                        Label("Reading Log", systemImage: "book.closed")
                    }
                    .tag(2)

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                    .tag(3)
            }
            .tint(Theme.accentTeal)
            .background(Theme.background)
        }
    }
}

struct ShelvesView: View {
    var onRequestSearch: (() -> Void)? = nil
    var onRequestStartSession: ((Book) -> Void)? = nil
    @EnvironmentObject var store: AppLibraryStore

    private let shelves: [(type: ShelfType, title: String, systemImage: String)] = [
        (.unread, "Unread", "bookmark"),
        (.reading, "Currently Reading", "book"),
        (.read, "Read", "checkmark.circle"),
        (.favorites, "Favorites", "star.fill")
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            NavigationStack {
                List {
                    ForEach(shelves, id: \.title) { shelf in
                        NavigationLink(destination: ShelfBooksView(shelf: shelf.type, onRequestSearch: onRequestSearch, onRequestStartSession: onRequestStartSession)) {
                            ShelfRow(systemImage: shelf.systemImage, title: shelf.title)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                        
                    }
                }
                //.padding(16)
                //.clipShape(RoundedRectangle(cornerRadius: 22))
               .scrollContentBackground(.hidden)
                .listStyle(.plain)
                .background(Theme.background)
                .navigationTitle("")
                .toolbarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .principal) { Text("Library").titleFont() } }
                .appTheming()
            }
        }
    }
}

struct ShelfRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.accentTeal)
            Text(title)
                .foregroundStyle(Theme.text)
                .font(.headline)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
    }
}

struct ShelfBooksView: View {
    @EnvironmentObject var store: AppLibraryStore
    let shelf: ShelfType
    var onRequestSearch: (() -> Void)? = nil
    var onRequestStartSession: ((Book) -> Void)? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            let books = store.books(on: shelf)
            Group {
                if books.isEmpty {
                    Button(action: { onRequestSearch?() }) {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.text)
                            Text("No books here yet! Let's search for your next read")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                } else {
                    List(books, id: \.id) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            HStack {
                                BookRow(book: book)
                                Spacer()
                                Menu("Actions") {
                                    Button("Start Session") {
                                        onRequestStartSession?(book)
                                    }
                                    let isFav = store.books[book.id]?.isFavorite == true
                                    Button(isFav ? "Remove Favorite" : "Add to Favorites") {
                                        store.toggleFavorite(book)
                                    }
                                    Menu("Move To") {
                                        ForEach(ShelfType.allCases.filter { $0 != shelf }, id: \.self) { target in
                                            Button(target.rawValue) {
                                                store.move(book, from: shelf, to: target)
                                            }
                                        }
                                    }
                                    Button("Remove from \(shelf.rawValue)", role: .destructive) {
                                        store.remove(book, from: shelf)
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .listRowBackground(Color.clear)
                    .background(Theme.background)
                }
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Text(shelf.rawValue).titleFont() } }
        .appTheming()
    }
}

struct BookDetailView: View {
    let book: Book
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let url = book.thumbnailURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFit().cornerRadius(8)
                            case .empty: ProgressView()
                            case .failure: Image(systemName: "book").resizable().scaledToFit().foregroundStyle(.secondary)
                            @unknown default: EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Text(book.title).font(.title2.bold())
                    if !book.authors.isEmpty {
                        Text(book.authors.joined(separator: ", ")).foregroundStyle(.secondary)
                    }
                    if let pages = book.pageCount { Text("\(pages) pages").foregroundStyle(.secondary) }
                    if let desc = book.description { Text(desc) }

                    HStack(spacing: 12) {
                        // Favorite toggle
                        FavoriteButton(book: book)
                        // Start Session button posts the same notification used elsewhere
                        Button {
                            NotificationCenter.default.post(name: Notification.Name("StartSessionFromShelf"), object: book)
                        } label: {
                            Label("Start Session", systemImage: "play.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accentTeal)
                    }
                    Spacer(minLength: 12)
                }
                .padding()
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("Book Details").titleFont() } }
        }
    }
}

struct FavoriteButton: View {
    @EnvironmentObject var store: AppLibraryStore
    let book: Book
    @State private var showCheck: Bool = false

    var body: some View {
        let isFav = store.books[book.id]?.isFavorite == true
        return ZStack {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    store.setFavorite(book, isFavorite: !isFav)
                    showCheck = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.2)) { showCheck = false }
                }
            } label: {
                Label(isFav ? "Unfavorite" : "Favorite", systemImage: isFav ? "star.slash" : "star")
            }
            .buttonStyle(.bordered)
            if showCheck {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accentTeal)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct ReadingSessionDetailView: View {
    @EnvironmentObject var store: AppLibraryStore
    let book: Book
    @State var session: AppLibraryStore.ReadingSession
    @State private var isEditing = false

    var body: some View {
        Form {
            Section("Details") {
                DatePicker("Date", selection: Binding(get: { session.date }, set: { session.date = $0 }), displayedComponents: .date)
                Stepper(value: Binding(get: { session.startPage }, set: { session.startPage = $0 }), in: 0...Int.max) { Text("Start page: \(session.startPage)") }
                Stepper(value: Binding(get: { session.endPage }, set: { session.endPage = $0 }), in: 0...Int.max) { Text("End page: \(session.endPage)") }
                Stepper(value: Binding(get: { session.durationMinutes }, set: { session.durationMinutes = $0 }), in: 0...10_000) { Text("Duration: \(session.durationMinutes)m") }
            }
            Section("Reflection") {
                TextEditor(text: Binding(get: { session.reflection }, set: { session.reflection = $0 }))
                    .frame(minHeight: 120)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .disabled(!isEditing)
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("Session").titleFont() }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
            }
        }
        .onDisappear {
            // Persist edits back into store
            var arr = store.sessionsByBook[book.id] ?? []
            if let idx = arr.firstIndex(where: { $0.id == session.id }) {
                arr[idx] = session
                store.sessionsByBook[book.id] = arr
            }
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var store: AppLibraryStore
    @State private var query = ""
    @State private var results: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var debounceTask: Task<Void, Never>? = nil
    
    private var googleBooksAPIKey: String? {
        // Prefer Info.plist key to avoid hardcoding; fallback to provided key if absent
        if let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_API_KEY") as? String, !key.isEmpty {
            return key
        }
        // Fallback (you can remove this after adding the key to Info.plist)
        return "AIzaSyDChM_6NLukeRWnQZ4R-u2Gx3bhhMQdhMc"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Group {
                    if isLoading {
                        ProgressView("Searching…")
                    } else if errorMessage != nil {
                        VStack(spacing: 12) {
                            Text("Finding your next read...")
                                .foregroundStyle(.red)
                            Button("Please wait") {
                                Task { await performSearch(query: query) }
                            }
                        }
                    } else if results.isEmpty && !query.isEmpty {
                        Text("No results")
                            .foregroundStyle(.secondary)
                    } else {
                        List(results, id: \.id) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                HStack(alignment: .center) {
                                    BookRow(book: book)
                                    Menu("Add") {
                                        ForEach(ShelfType.allCases, id: \.self) { shelf in
                                            Button(shelf.rawValue) {
                                                store.add(book, to: shelf)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("Search").titleFont() } }
            .searchable(text: $query, prompt: "Search books")
            .onChange(of: query) { newValue in
                debounceTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    results = []
                    errorMessage = nil
                    return
                }
                debounceTask = Task { [trimmed] in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await performSearch(query: trimmed)
                }
            }
            .onSubmit(of: .search) {
                Task { await performSearch(query: query) }
            }
        }
        .appTheming()
    }

    private func performSearch(query q: String) async {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "maxResults", value: "20")
        ]
        if let key = googleBooksAPIKey, !key.isEmpty {
            items.append(URLQueryItem(name: "key", value: key))
        }
        components.queryItems = items
        guard let url = components.url else {
            errorMessage = "Invalid URL"
            return
        }
        var request = URLRequest(url: url)
        request.setValue("MyLibraryApp/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                if http.statusCode == 429 {
                    let retryAfter = http.value(forHTTPHeaderField: "Retry-After") ?? "a moment"
                    self.errorMessage = "You’re searching too fast. Please wait \(retryAfter) and try again."
                } else if http.statusCode == 403 {
                    self.errorMessage = "Access denied (403). You may have hit the API quota. Try again later."
                } else {
                    self.errorMessage = "Server error: \(http.statusCode)"
                }
                return
            }
            self.results = parseGoogleBooks(data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseGoogleBooks(data: Data) -> [Book] {
        // Parse Google Books API response
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [Book] = []
        for item in items {
            guard let id = item["id"] as? String,
                  let volumeInfo = item["volumeInfo"] as? [String: Any] else { continue }
            let title = volumeInfo["title"] as? String ?? "Untitled"
            let authors = volumeInfo["authors"] as? [String] ?? []
            let description = volumeInfo["description"] as? String
            var thumbURL: URL? = nil
            if let imageLinks = volumeInfo["imageLinks"] as? [String: Any],
               var thumb = imageLinks["thumbnail"] as? String {
                // Prefer https
                if thumb.hasPrefix("http:") { thumb = thumb.replacingOccurrences(of: "http:", with: "https:") }
                // Upgrade resolution where possible
                if thumb.contains("zoom=") {
                    thumb = thumb.replacingOccurrences(of: "zoom=0", with: "zoom=2")
                    thumb = thumb.replacingOccurrences(of: "zoom=1", with: "zoom=2")
                } else {
                    let separator = thumb.contains("?") ? "&" : "?"
                    thumb += "\(separator)zoom=2"
                }
                thumbURL = URL(string: thumb)
            }
            let pageCount = volumeInfo["pageCount"] as? Int
            // Construct Book with available details
            let book = Book(id: id, title: title, authors: authors, description: description, thumbnailURL: thumbURL, pageCount: pageCount, isFavorite: false)
            out.append(book)
        }
        return out
        
    }
    
}

struct ReadingLogView: View {
    @EnvironmentObject var store: AppLibraryStore
    @State private var showingAddSession: Bool = false
    @State private var selectedBook: Book? = nil
    
    @Environment(\.editMode) private var editMode
    @State private var pendingDelete: (book: Book, offsets: IndexSet)? = nil
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            List {
                // Show only books that have sessions
                ForEach(store.sessionsByBook.keys.sorted(), id: \.self) { bookID in
                    if let book = store.books[bookID] {
                        Section(book.title) {
                            ForEach(store.sessions(for: book)) { session in
                                NavigationLink(destination: ReadingSessionDetailView(book: book, session: session)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(session.date, style: .date)
                                            Spacer()
                                            Text("\(session.pagesRead) pages")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        HStack(spacing: 12) {
                                            Label("Start: \(session.startPage)", systemImage: "arrow.right.circle")
                                            Label("End: \(session.endPage)", systemImage: "checkmark.circle")
                                            Label("\(session.durationMinutes)m", systemImage: "clock")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        if !session.reflection.isEmpty {
                                            Text(session.reflection)
                                                .font(.body)
                                        }
                                    }
                                }
                            }
                            .onDelete { offsets in
                                pendingDelete = (book, offsets)
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("Reading Log").titleFont() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditButton()
                        .foregroundStyle(Theme.text)
                        .tint(Theme.text)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        selectedBook = nil
                        showingAddSession = true
                    } label: {
                        Label("Add Session", systemImage: "plus")
                    }
                    .tint(Theme.accentTeal)
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionView(selectedBook: $selectedBook)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartSessionFromShelf"))) { output in
                if let book = output.object as? Book {
                    selectedBook = book
                    showingAddSession = true
                }
            }
            .confirmationDialog("Delete selected session(s)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let pending = pendingDelete {
                        store.deleteSessions(for: pending.book, at: pending.offsets)
                        self.pendingDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This action cannot be undone.")
            }
        }
        .appTheming()
    }
}

struct AddSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppLibraryStore
    @Binding var selectedBook: Book?
    @State private var chosenBookID: String = ""
    @State private var startPage: Int = 0
    @State private var endPage: Int = 0
    @State private var durationMinutes: Int = 0
    @State private var durationSeconds: Int = 0
    @State private var reflection: String = ""
    @State private var date: Date = .now

    @State private var isTimerRunning: Bool = false
    @State private var timerStart: Date? = nil
    @State private var timer: Timer? = nil

    @State private var showSaveConfirm: Bool = false

    @FocusState private var focusedField: Field?
    enum Field { case start, end, minutes }

    private var formattedDuration: String {
        let totalSeconds: Int
        if isTimerRunning, let start = timerStart {
            totalSeconds = max(durationSeconds, Int(Date().timeIntervalSince(start)))
        } else {
            totalSeconds = durationSeconds
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%dm %02ds", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    Picker("Title", selection: $chosenBookID) {
                        ForEach(store.books.values.sorted(by: { $0.title < $1.title }), id: \.id) { book in
                            Text(book.title).tag(book.id)
                        }
                    }
                }
                Section("Session") {
                    HStack {
                        Text("Start page")
                        Spacer()
                        TextField("0", value: $startPage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .start)
                            .onTapGesture { if startPage == 0 { startPage = 0; DispatchQueue.main.async { startPage = 0 } } }
                            .onChange(of: focusedField) { new in
                                if new == .start, startPage == 0 { startPage = 0 }
                            }
                    }
                    HStack {
                        Text("End page")
                        Spacer()
                        TextField("0", value: $endPage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .end)
                            .onTapGesture { if endPage == 0 { endPage = 0 } }
                            .onChange(of: focusedField) { new in
                                if new == .end, endPage == 0 { endPage = 0 }
                            }
                    }
                    // Timer controls
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Theme.accentTeal.opacity(0.3), lineWidth: 8)
                                .frame(width: 150, height: 150)
                            Text(formattedDuration)
                                .font(.largeTitle).bold()
                                .monospacedDigit()
                        }
                        HStack(spacing: 16) {
                            Button {
                                if isTimerRunning { stopTimer() } else { startTimer() }
                            } label: {
                                Label(isTimerRunning ? "Stop" : "Start", systemImage: isTimerRunning ? "stop.circle.fill" : "play.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                durationMinutes = 0
                                durationSeconds = 0
                                timerStart = nil
                                isTimerRunning = false
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    HStack {
                        Text("Manual time (min)")
                        Spacer()
                        TextField("0", value: $durationMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .minutes)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                    TextField("Reflection", text: $reflection, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("New Session").titleFont() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isTimerRunning { stopTimer() }
                        showSaveConfirm = true
                    }
                    .disabled(chosenBookID.isEmpty || endPage < startPage)
                }
            }
            .onAppear {
                if let sb = selectedBook {
                    chosenBookID = sb.id
                }
            }
            .confirmationDialog("Save this reading session?", isPresented: $showSaveConfirm, titleVisibility: .visible) {
                Button("Save", role: .none) {
                    guard let book = store.books[chosenBookID] else { return }
                    store.addSession(for: book, startPage: startPage, endPage: endPage, durationMinutes: durationMinutes, reflection: reflection, date: date)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Pages: \(startPage)–\(endPage) • Time: \(durationMinutes)m \(durationSeconds % 60)s")
            }
        }
        .appTheming()
    }

    private func startTimer() {
        isTimerRunning = true
        if timerStart == nil { timerStart = Date() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = timerStart {
                durationSeconds = max(durationSeconds, Int(Date().timeIntervalSince(start)))
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    private func stopTimer() {
        isTimerRunning = false
        if let start = timerStart {
            durationSeconds = max(durationSeconds, Int(Date().timeIntervalSince(start)))
        }
        durationMinutes = durationSeconds / 60
        timer?.invalidate()
        timer = nil
        timerStart = nil
    }
}

struct ProfileView: View {
    @EnvironmentObject var store: AppLibraryStore
    @State private var tempGoal: Int = 0
    @State private var tempMinutes: Int = 0
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Card: Reading Goal Editor
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reading Goal")
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Page goal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        Text("\(tempGoal) pages/day")
                                            .font(.body)
                                            .foregroundStyle(Theme.text)
                                        Spacer()
                                        Picker("", selection: $tempGoal) {
                                            ForEach(0...2000, id: \.self) { value in
                                                Text("\(value)").tag(value)
                                            }
                                        }
                                        
                                        .pickerStyle(.menu)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Minute goal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        Text("\(tempMinutes) min/day")
                                            .font(.body)
                                            .foregroundStyle(Theme.text)
                                        Spacer()
                                        Picker("", selection: $tempMinutes) {
                                            ForEach(0...600, id: \.self) { value in
                                                Text("\(value)").tag(value)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }
                            }
                            Button("Save Goal") {
                                store.updateDailyGoal(pages: tempGoal, minutes: tempMinutes)
                            }
                            .buttonStyle(ThemedButtonStyle())
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white)
                        )

                        // Card: Current Goal
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Goal")
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            Text("\(store.goal.dailyPages) pages/day")
                                .foregroundStyle(Theme.text)
                            Text("\(store.goal.dailyTimeMinutes) min/day")
                                .foregroundStyle(Theme.text)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.never)
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("Profile").titleFont() } }
        }
        .themedBackground()
        .appTheming()
        .onAppear {
            tempGoal = store.goal.dailyPages
            tempMinutes = store.goal.dailyTimeMinutes
            
        }
        
    }
}

// Title font modifier and extension
struct TitleFontModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.custom("Poppins-Bold", size: 28))
    }
}
extension View {
    func titleFont() -> some View { self.modifier(TitleFontModifier()) }
}

struct AppTheming: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(Theme.accentTeal)
    }
}
extension View {
    func appTheming() -> some View { self.modifier(AppTheming()) }
}

