import Foundation

@MainActor
final class AppearancePickerViewModel {

    struct Row: Hashable {
        let mode: AppearanceMode
        let title: String
        let isSelected: Bool
    }

    struct Snapshot: Hashable {
        let rows: [Row]
    }

    private let themeManager: ThemeManaging
    private var observationTask: Task<Void, Never>?

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?

    init(themeManager: ThemeManaging) {
        self.themeManager = themeManager
    }

    deinit {
        observationTask?.cancel()
    }

    func start() {
        publish(current: themeManager.currentMode())
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await mode in themeManager.observe() {
                if Task.isCancelled { return }
                self.publish(current: mode)
            }
        }
    }

    func select(_ mode: AppearanceMode) {
        themeManager.setMode(mode)
    }

    private func publish(current: AppearanceMode) {
        let rows = AppearanceMode.allCases.map { mode in
            Row(mode: mode, title: mode.label, isSelected: mode == current)
        }
        state = .loaded(Snapshot(rows: rows))
    }
}
