import UIKit

final class SubscriptionListViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: SubscriptionListViewModel
    private let haptics: HapticsService
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var emptyStateView: SublyEmptyStateView!
    @IBOutlet private weak var chipScrollView: UIScrollView!
    @IBOutlet private weak var chipStack: UIStackView!

    private let searchController = UISearchController(searchResultsController: nil)
    private var sortBarItem: UIBarButtonItem?

    private var sections: [SubscriptionListViewModel.Section] = []
    private lazy var dataSource = makeDataSource()
    private var currentSnapshot: SubscriptionListViewModel.Snapshot?

    // MARK: - Init

    init(viewModel: SubscriptionListViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:haptics:).")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.SubscriptionList.title
        view.backgroundColor = DesignSystem.Colors.background
        configureNavigationBar()
        configureSearch()
        configureHierarchy()
        configureBindings()
        viewModel.start()
    }

    // MARK: - Configuration

    private func configureNavigationBar() {
        let sort = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            menu: makeSortMenu()
        )
        sort.accessibilityLabel = Strings.List.sortButton
        navigationItem.rightBarButtonItem = sort
        sortBarItem = sort
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = Strings.List.searchPlaceholder
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func configureHierarchy() {
        tableView.register(
            UINib(nibName: String(describing: SubscriptionCell.self), bundle: nil),
            forCellReuseIdentifier: SubscriptionCell.reuseIdentifier
        )
        tableView.register(SectionHeaderView.self, forHeaderFooterViewReuseIdentifier: SectionHeaderView.reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.backgroundColor = DesignSystem.Colors.background
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.sectionHeaderTopPadding = DesignSystem.Spacing.sm

        emptyStateView.configure(with: .init(
            title: Strings.SubscriptionList.emptyTitle,
            message: Strings.SubscriptionList.emptyMessage,
            systemIcon: "tray"
        ))
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onDeleteSubscription = { [weak self] subscription in
            self?.presentDeleteConfirmation(for: subscription)
        }
        viewModel.onArchivedSubscription = { [weak self] in
            self?.haptics.play(.lightImpact)
        }
    }

    // MARK: - Sort menu

    private func makeSortMenu() -> UIMenu {
        let orders: [(SubscriptionListViewModel.SortOrder, String)] = [
            (.renewalDate, Strings.List.sortRenewalDate),
            (.amount, Strings.List.sortAmount),
            (.name, Strings.List.sortName),
            (.recentlyAdded, Strings.List.sortRecentlyAdded)
        ]
        let actions = orders.map { order, title in
            UIAction(title: title, state: viewModel.sortOrder == order ? .on : .off) { [weak self] _ in
                self?.haptics.play(.selection)
                self?.viewModel.setSortOrder(order)
            }
        }
        return UIMenu(title: Strings.List.sortButton, options: .singleSelection, children: actions)
    }

    // MARK: - Diffable data source

    private enum SectionID: Hashable {
        case section(Int)
    }

    private func makeDataSource() -> UITableViewDiffableDataSource<SectionID, SubscriptionListViewModel.Row> {
        UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, row in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SubscriptionCell.reuseIdentifier,
                for: indexPath
            )
            (cell as? SubscriptionCell)?.configure(with: row)
            return cell
        }
    }

    // MARK: - Rendering

    private func render(_ state: ViewState<SubscriptionListViewModel.Snapshot>) {
        switch state {
        case .idle, .loading:
            tableView.isHidden = false
            emptyStateView.isHidden = true
        case .loaded(let snapshot):
            currentSnapshot = snapshot
            sections = snapshot.sections
            applyChips(snapshot)
            sortBarItem?.menu = makeSortMenu()

            if snapshot.sections.isEmpty {
                tableView.isHidden = true
                emptyStateView.isHidden = false
                if snapshot.archivedFilter == .archived && !snapshot.hasFiltersApplied {
                    emptyStateView.configure(with: .init(
                        title: Strings.List.filterArchived,
                        message: Strings.SubscriptionList.emptyMessage,
                        systemIcon: "archivebox"
                    ))
                } else {
                    emptyStateView.configure(with: .init(
                        title: Strings.List.noMatchesTitle,
                        message: Strings.List.noMatchesMessage,
                        systemIcon: "magnifyingglass"
                    ))
                }
                applySnapshot()
            } else {
                tableView.isHidden = false
                emptyStateView.isHidden = true
                applySnapshot()
            }
        case .empty:
            currentSnapshot = nil
            sections = []
            tableView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(with: .init(
                title: Strings.SubscriptionList.emptyTitle,
                message: Strings.SubscriptionList.emptyMessage,
                systemIcon: "tray"
            ))
            chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            applySnapshot()
        case .failed(let message):
            sections = []
            tableView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(with: .init(
                title: Strings.SubscriptionList.failedTitle,
                message: message,
                systemIcon: "exclamationmark.triangle"
            ))
            applySnapshot()
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<SectionID, SubscriptionListViewModel.Row>()
        for (index, section) in sections.enumerated() {
            let id = SectionID.section(index)
            snapshot.appendSections([id])
            snapshot.appendItems(section.rows, toSection: id)
        }
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func applyChips(_ snapshot: SubscriptionListViewModel.Snapshot) {
        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let activeChip = makeFilterChip(
            title: Strings.List.filterActive,
            isSelected: snapshot.archivedFilter == .active
        ) { [weak self] in
            self?.haptics.play(.selection)
            self?.viewModel.setArchivedFilter(.active)
        }
        chipStack.addArrangedSubview(activeChip)

        let archivedChip = makeFilterChip(
            title: Strings.List.filterArchived,
            isSelected: snapshot.archivedFilter == .archived
        ) { [weak self] in
            self?.haptics.play(.selection)
            self?.viewModel.setArchivedFilter(.archived)
        }
        chipStack.addArrangedSubview(archivedChip)

        for chip in snapshot.categoryChips {
            let view = makeFilterChip(
                title: chip.title,
                isSelected: chip.isSelected
            ) { [weak self] in
                self?.haptics.play(.selection)
                self?.viewModel.selectCategory(chip.id)
            }
            chipStack.addArrangedSubview(view)
        }
    }

    private func makeFilterChip(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> UIControl {
        let button = FilterChipButton(title: title, isSelected: isSelected)
        button.onTap = onTap
        return button
    }

    private func presentDeleteConfirmation(for subscription: Subscription) {
        let alert = UIAlertController(
            title: String(format: Strings.SubscriptionList.deleteTitleFormat, subscription.name),
            message: Strings.SubscriptionList.deleteMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.Common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.Common.delete, style: .destructive) { [weak self] _ in
            self?.haptics.play(.warning)
            self?.viewModel.delete(subscription)
        })
        present(alert, animated: true)
    }
}

extension SubscriptionListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // v5: one flat group, no per-category headers — category lives in
        // each row's meta line.
        guard sections.indices.contains(section), !sections[section].title.isEmpty else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: SectionHeaderView.reuseIdentifier
        ) as? SectionHeaderView
        let model = sections[section]
        header?.configure(title: model.title, count: model.rows.count)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard sections.indices.contains(section), !sections[section].title.isEmpty else { return 0 }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return }
        haptics.play(.selection)
        viewModel.didSelectSubscription(row.subscription)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let delete = UIContextualAction(style: .destructive, title: Strings.Common.delete) { [weak self] _, _, completion in
            self?.viewModel.didRequestDelete(row.subscription)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")

        if row.subscription.isArchived {
            let restore = UIContextualAction(style: .normal, title: Strings.List.unarchiveAction) { [weak self] _, _, completion in
                self?.viewModel.restore(row.subscription)
                completion(true)
            }
            restore.image = UIImage(systemName: "tray.and.arrow.up")
            restore.backgroundColor = DesignSystem.Colors.accent
            return UISwipeActionsConfiguration(actions: [delete, restore])
        } else {
            let archive = UIContextualAction(style: .normal, title: Strings.List.archiveAction) { [weak self] _, _, completion in
                self?.viewModel.archive(row.subscription)
                completion(true)
            }
            archive.image = UIImage(systemName: "archivebox")
            archive.backgroundColor = DesignSystem.Colors.warning
            return UISwipeActionsConfiguration(actions: [delete, archive])
        }
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return UIContextMenuConfiguration(identifier: row.subscription.id as NSCopying, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            let edit = UIAction(title: Strings.Common.edit, image: UIImage(systemName: "pencil")) { _ in
                self.viewModel.didRequestEdit(row.subscription)
            }
            let archiveOrRestore: UIAction
            if row.subscription.isArchived {
                archiveOrRestore = UIAction(title: Strings.List.unarchiveAction, image: UIImage(systemName: "tray.and.arrow.up")) { _ in
                    self.viewModel.restore(row.subscription)
                }
            } else {
                archiveOrRestore = UIAction(title: Strings.List.archiveAction, image: UIImage(systemName: "archivebox")) { _ in
                    self.viewModel.archive(row.subscription)
                }
            }
            let delete = UIAction(
                title: Strings.Common.delete,
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self.viewModel.didRequestDelete(row.subscription)
            }
            return UIMenu(title: row.subscription.name, children: [edit, archiveOrRestore, delete])
        }
    }
}

extension SubscriptionListViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        viewModel.updateQuery(searchController.searchBar.text ?? "")
    }
}

