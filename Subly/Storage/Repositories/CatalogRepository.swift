import Foundation

protocol CatalogRepository: Sendable {
    func fetchAll() async throws -> [CatalogEntry]
    func search(_ query: String) async throws -> [CatalogEntry]
}

struct InMemoryCatalogRepository: CatalogRepository {

    private let entries: [CatalogEntry]

    init(entries: [CatalogEntry] = CatalogEntry.defaults) {
        self.entries = entries.sorted { $0.name < $1.name }
    }

    func fetchAll() async throws -> [CatalogEntry] {
        entries
    }

    func search(_ query: String) async throws -> [CatalogEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { $0.matches(query: trimmed) }
    }
}

extension CatalogEntry {

    static let defaults: [CatalogEntry] = [
        .init(
            name: "Netflix",
            suggestedAmount: Decimal(string: "15.99")!,
            categoryName: "Streaming",
            systemIcon: "play.tv",
            searchTerms: ["movies", "tv", "streaming"]
        ),
        .init(
            name: "Spotify",
            suggestedAmount: Decimal(string: "10.99")!,
            categoryName: "Music",
            systemIcon: "music.note",
            searchTerms: ["music", "audio"]
        ),
        .init(
            name: "Apple Music",
            suggestedAmount: Decimal(string: "10.99")!,
            categoryName: "Music",
            systemIcon: "music.note",
            searchTerms: ["music", "apple"]
        ),
        .init(
            name: "YouTube Premium",
            suggestedAmount: Decimal(string: "13.99")!,
            categoryName: "Streaming",
            systemIcon: "play.rectangle",
            searchTerms: ["video", "youtube"]
        ),
        .init(
            name: "Disney+",
            suggestedAmount: Decimal(string: "10.99")!,
            categoryName: "Streaming",
            systemIcon: "sparkles.tv",
            searchTerms: ["disney", "movies"]
        ),
        .init(
            name: "Amazon Prime",
            suggestedAmount: Decimal(string: "14.99")!,
            categoryName: "Streaming",
            systemIcon: "shippingbox",
            searchTerms: ["prime", "amazon", "shipping"]
        ),
        .init(
            name: "iCloud+",
            suggestedAmount: Decimal(string: "2.99")!,
            categoryName: "Cloud",
            systemIcon: "icloud",
            searchTerms: ["icloud", "storage", "apple"]
        ),
        .init(
            name: "Apple One",
            suggestedAmount: Decimal(string: "19.95")!,
            categoryName: "Cloud",
            systemIcon: "applelogo",
            searchTerms: ["apple", "bundle"]
        ),
        .init(
            name: "ChatGPT Plus",
            suggestedAmount: Decimal(string: "20.00")!,
            categoryName: "Productivity",
            systemIcon: "brain.head.profile",
            searchTerms: ["chatgpt", "openai", "ai"]
        ),
        .init(
            name: "Claude Pro",
            suggestedAmount: Decimal(string: "20.00")!,
            categoryName: "Productivity",
            systemIcon: "brain",
            searchTerms: ["claude", "anthropic", "ai"]
        ),
        .init(
            name: "LinkedIn Premium",
            suggestedAmount: Decimal(string: "29.99")!,
            categoryName: "Productivity",
            systemIcon: "person.crop.rectangle",
            searchTerms: ["linkedin", "career"]
        ),
        .init(
            name: "Notion",
            suggestedAmount: Decimal(string: "10.00")!,
            categoryName: "Productivity",
            systemIcon: "doc.text",
            searchTerms: ["notion", "notes"]
        ),
        .init(
            name: "GitHub Copilot",
            suggestedAmount: Decimal(string: "10.00")!,
            categoryName: "Productivity",
            systemIcon: "chevron.left.forwardslash.chevron.right",
            searchTerms: ["github", "copilot", "ai"]
        ),
        .init(
            name: "Dropbox",
            suggestedAmount: Decimal(string: "11.99")!,
            categoryName: "Cloud",
            systemIcon: "shippingbox.fill",
            searchTerms: ["dropbox", "storage"]
        ),
        .init(
            name: "Google One",
            suggestedAmount: Decimal(string: "1.99")!,
            categoryName: "Cloud",
            systemIcon: "g.circle",
            searchTerms: ["google", "storage"]
        ),
        .init(
            name: "Strava",
            suggestedAmount: Decimal(string: "11.99")!,
            categoryName: "Fitness",
            systemIcon: "figure.run",
            searchTerms: ["strava", "running"]
        ),
        .init(
            name: "Peloton",
            suggestedAmount: Decimal(string: "12.99")!,
            categoryName: "Fitness",
            systemIcon: "bicycle",
            searchTerms: ["peloton", "cycling"]
        ),
        .init(
            name: "Calm",
            suggestedAmount: Decimal(string: "14.99")!,
            categoryName: "Fitness",
            systemIcon: "leaf",
            searchTerms: ["calm", "meditation"]
        ),
        .init(
            name: "The New York Times",
            suggestedAmount: Decimal(string: "17.00")!,
            categoryName: "News",
            systemIcon: "newspaper",
            searchTerms: ["nyt", "news"]
        ),
        .init(
            name: "Medium",
            suggestedAmount: Decimal(string: "5.00")!,
            categoryName: "News",
            systemIcon: "doc.richtext",
            searchTerms: ["medium", "articles"]
        )
    ]
}
