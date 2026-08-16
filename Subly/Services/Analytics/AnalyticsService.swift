import Foundation

protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
}

struct AnalyticsEvent: Sendable {
    let name: String
    let properties: [String: String]

    init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

struct NoOpAnalyticsService: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}
