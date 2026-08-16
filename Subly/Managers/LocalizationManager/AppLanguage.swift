import Foundation

enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case turkish = "tr"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first.flatMap { String($0.prefix(2)) } ?? "en"
        return AppLanguage(rawValue: preferred) ?? .english
    }
}
