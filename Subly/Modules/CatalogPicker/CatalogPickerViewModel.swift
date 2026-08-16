import Foundation

enum CatalogPickerSelection: Hashable, Sendable {
    case manual
    case catalog(CatalogEntry)
}

@MainActor
final class CatalogPickerViewModel {

    struct Snapshot: Hashable {
        let query: String
        let entries: [CatalogEntry]
    }

    private let catalogRepository: CatalogRepository
    private var allEntries: [CatalogEntry] = []
    private var query: String = ""

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onSelected: ((CatalogPickerSelection) -> Void)?
    var onCancelled: (() -> Void)?

    init(catalogRepository: CatalogRepository) {
        self.catalogRepository = catalogRepository
    }

    func load() {
        state = .loading
        Task { [weak self] in
            guard let self else { return }
            do {
                self.allEntries = try await catalogRepository.fetchAll()
                self.publishSnapshot()
            } catch {
                self.state = .failed(message: Strings.Common.somethingWentWrong)
            }
        }
    }

    func updateQuery(_ value: String) {
        query = value
        publishSnapshot()
    }

    func didSelectManual() {
        onSelected?(.manual)
    }

    func didSelectEntry(_ entry: CatalogEntry) {
        onSelected?(.catalog(entry))
    }

    func didTapCancel() {
        onCancelled?()
    }

    private func publishSnapshot() {
        let filtered: [CatalogEntry]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            filtered = allEntries
        } else {
            filtered = allEntries.filter { $0.matches(query: trimmed) }
        }
        state = .loaded(Snapshot(query: trimmed, entries: filtered))
    }
}
