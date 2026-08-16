import Foundation

struct Category: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var systemIconName: String

    init(id: UUID = UUID(), name: String, systemIconName: String) {
        self.id = id
        self.name = name
        self.systemIconName = systemIconName
    }
}

extension Category {
    /// Default categories use **stable** IDs so persisted subscriptions keep
    /// resolving across launches (the in-memory repository is rebuilt each run).
    static let defaults: [Category] = [
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!, name: "Streaming", systemIconName: "play.tv"),
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!, name: "Music", systemIconName: "music.note"),
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C003")!, name: "Productivity", systemIconName: "briefcase"),
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C004")!, name: "AI Tools", systemIconName: "sparkles"),
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C005")!, name: "News", systemIconName: "newspaper"),
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C006")!, name: "Cloud", systemIconName: "icloud"),
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C007")!, name: "Fitness", systemIconName: "figure.run"),
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C008")!, name: "Other", systemIconName: "square.grid.2x2")
    ]
}
