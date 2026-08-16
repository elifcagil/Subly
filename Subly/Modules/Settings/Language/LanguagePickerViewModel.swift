import Foundation

@MainActor
final class LanguagePickerViewModel {

    struct Row: Hashable {
        let language: AppLanguage
        let title: String
        let isSelected: Bool
    }

    struct Snapshot: Hashable {
        let rows: [Row]
    }

    private let localizationManager: LocalizationManaging
    private var observationTask: Task<Void, Never>?

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?

    init(localizationManager: LocalizationManaging) {
        self.localizationManager = localizationManager
    }

    deinit {
        observationTask?.cancel()
    }

    func start() {
        publish(current: localizationManager.currentLanguage())
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await language in localizationManager.observe() {
                if Task.isCancelled { return }
                self.publish(current: language)
            }
        }
    }

    func select(_ language: AppLanguage) {
        localizationManager.setLanguage(language)
    }

    private func publish(current: AppLanguage) {
        let rows = AppLanguage.allCases.map { lang in
            Row(language: lang, title: lang.displayName, isSelected: lang == current)
        }
        state = .loaded(Snapshot(rows: rows))
    }
}
