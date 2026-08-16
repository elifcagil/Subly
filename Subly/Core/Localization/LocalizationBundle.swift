import Foundation

final class LocalizationBundle: @unchecked Sendable {

    static let shared = LocalizationBundle()

    private let lock = NSLock()
    private var bundle: Bundle = .main

    private init() {}

    func set(language: AppLanguage) {
        lock.lock()
        defer { lock.unlock() }
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let resolved = Bundle(path: path) else {
            bundle = .main
            return
        }
        bundle = resolved
    }

    func localizedString(forKey key: String) -> String {
        lock.lock()
        let current = bundle
        lock.unlock()
        return current.localizedString(forKey: key, value: key, table: nil)
    }
}

func L(_ key: String) -> String {
    LocalizationBundle.shared.localizedString(forKey: key)
}
