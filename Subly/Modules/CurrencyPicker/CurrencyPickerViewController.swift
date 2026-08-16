import UIKit

final class CurrencyPickerViewController: UIViewController {

    private let viewModel: CurrencyPickerViewModel
    private let haptics: HapticsService

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var emptyStateView: SublyEmptyStateView!

    private let cellIdentifier = "CurrencyRow"
    private var sections: [CurrencyPickerViewModel.Section] = []

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        controller.searchBar.placeholder = Strings.Currency.searchPlaceholder
        controller.searchResultsUpdater = self
        return controller
    }()

    init(viewModel: CurrencyPickerViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported. Use init(viewModel:haptics:).")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.Currency.title
        view.backgroundColor = DesignSystem.Colors.background
        configureNavigationBar()
        configureSearch()
        configureTable()
        configureBindings()
        viewModel.start()
    }

    private func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(didTapClose)
        )
    }

    private func configureSearch() {
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func configureTable() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = DesignSystem.Colors.background
        tableView.keyboardDismissMode = .onDrag
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func render(_ state: ViewState<CurrencyPickerViewModel.Snapshot>) {
        switch state {
        case .idle, .loading:
            return
        case .loaded(let snapshot):
            sections = snapshot.sections
            tableView.reloadData()
            emptyStateView.isHidden = !snapshot.isEmpty
            tableView.isHidden = snapshot.isEmpty
            if snapshot.isEmpty {
                emptyStateView.configure(with: .init(
                    title: Strings.Currency.emptyTitle,
                    message: Strings.Currency.emptyMessage,
                    systemIcon: "magnifyingglass"
                ))
            }
        case .empty:
            sections = []
            tableView.reloadData()
            emptyStateView.isHidden = false
            tableView.isHidden = true
        case .failed(let message):
            emptyStateView.configure(with: .init(
                title: Strings.Common.somethingWentWrong,
                message: message,
                systemIcon: "exclamationmark.triangle"
            ))
        }
    }

    @objc private func didTapClose() {
        dismiss(animated: true)
    }
}

extension CurrencyPickerViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.secondaryText = row.detail
        content.textProperties.font = DesignSystem.Typography.body
        content.textProperties.color = DesignSystem.Colors.textPrimary
        content.secondaryTextProperties.font = DesignSystem.Typography.footnote
        content.secondaryTextProperties.color = DesignSystem.Colors.textSecondary
        cell.contentConfiguration = content
        cell.accessoryType = row.isSelected ? .checkmark : .none
        cell.tintColor = DesignSystem.Colors.accent
        cell.accessibilityLabel = "\(row.currency.code), \(row.detail)"
        cell.accessibilityTraits = row.isSelected ? [.button, .selected] : .button
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        haptics.play(.selection)
        viewModel.select(row.currency.code)
    }
}

extension CurrencyPickerViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        viewModel.updateQuery(searchController.searchBar.text ?? "")
    }
}
