import UIKit

/// v5 Add — Catalog (screen 05): search field, a dashed-border "Custom
/// subscription" row (accent-tint plus tile) pinned to the top, then the
/// "Popular" 3-column grid of template cards (44pt tile + name) beneath it.
final class CatalogPickerViewController: UIViewController {

    private let viewModel: CatalogPickerViewModel
    private let haptics: HapticsService

    private let searchController = UISearchController(searchResultsController: nil)
    private var collectionView: UICollectionView!
    private var entries: [CatalogEntry] = []

    private enum Section: Int, CaseIterable {
        case custom
        case popular
    }

    init(viewModel: CatalogPickerViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.Catalog.title
        view.backgroundColor = DesignSystem.Colors.sheet
        configureNavigationBar()
        configureSearch()
        configureCollection()
        configureBindings()
        viewModel.load()
    }

    private func configureNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel)
        )
        navigationItem.largeTitleDisplayMode = .never
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = Strings.Catalog.searchPlaceholder
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func configureCollection() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ServiceCardCell.self, forCellWithReuseIdentifier: ServiceCardCell.reuseID)
        collectionView.register(CustomRowCell.self, forCellWithReuseIdentifier: CustomRowCell.reuseID)
        collectionView.register(
            SectionTitleView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionTitleView.reuseID
        )
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let inset = DesignSystem.Spacing.screenH
            switch Section(rawValue: sectionIndex) {
            case .popular:
                let item = NSCollectionLayoutItem(layoutSize: .init(
                    widthDimension: .fractionalWidth(1.0 / 3.0),
                    heightDimension: .estimated(92)
                ))
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(92)),
                    subitems: [item]
                )
                group.interItemSpacing = .fixed(10)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 10
                section.contentInsets = .init(top: 8, leading: inset, bottom: 32, trailing: inset)
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(30)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
                return section
            case .custom, .none:
                let item = NSCollectionLayoutItem(layoutSize: .init(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(64)
                ))
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64)),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 12, leading: inset, bottom: 8, trailing: inset)
                return section
            }
        }
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            guard case .loaded(let snapshot) = state else { return }
            self?.entries = snapshot.entries
            self?.collectionView.reloadData()
        }
    }

    @objc private func didTapCancel() {
        viewModel.didTapCancel()
    }
}

extension CatalogPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { Section.allCases.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .popular: return entries.count
        case .custom: return 1
        case .none: return 0
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: SectionTitleView.reuseID,
            for: indexPath
        )
        (view as? SectionTitleView)?.configure(title: Strings.Catalog.sectionSuggested)
        return view
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section) {
        case .popular:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ServiceCardCell.reuseID, for: indexPath)
            (cell as? ServiceCardCell)?.configure(with: entries[indexPath.item])
            return cell
        case .custom, .none:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomRowCell.reuseID, for: indexPath)
            (cell as? CustomRowCell)?.configure(title: Strings.Catalog.rowManual)
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        haptics.play(.selection)
        switch Section(rawValue: indexPath.section) {
        case .popular: viewModel.didSelectEntry(entries[indexPath.item])
        case .custom: viewModel.didSelectManual()
        case .none: break
        }
    }
}

extension CatalogPickerViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        viewModel.updateQuery(searchController.searchBar.text ?? "")
    }
}

// MARK: - Cells

/// "Popular" grid card: surface + hairline, 44pt brand tile, name.
private final class ServiceCardCell: UICollectionViewCell {
    static let reuseID = "ServiceCardCell"

    private let tile = SublyAvatarView()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = DesignSystem.Colors.surface
        contentView.layer.cornerRadius = DesignSystem.Radius.lg
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = DesignSystem.Colors.hairline.cgColor

        tile.setSize(44)

        nameLabel.font = DesignSystem.Typography.footnote
        nameLabel.textColor = DesignSystem.Colors.textPrimary
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7

        let stack = UIStackView(arrangedSubviews: [tile, nameLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported.") }

    func configure(with entry: CatalogEntry) {
        nameLabel.text = entry.name
        let brand = SublyBrandAppearance.appearance(forName: entry.name, categoryName: entry.categoryName)
        tile.configure(with: .init(initial: brand.initial, background: brand.background, foreground: brand.foreground))
        accessibilityLabel = "\(entry.name), \(entry.categoryName)"
    }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.7 : 1 }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            contentView.layer.borderColor = DesignSystem.Colors.hairline.cgColor
        }
    }
}

/// Dashed-border "Custom subscription" row with an accent-tint plus tile.
private final class CustomRowCell: UICollectionViewCell {
    static let reuseID = "CustomRowCell"

    private let dashedBorder = CAShapeLayer()
    private let plusTile = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        dashedBorder.fillColor = nil
        dashedBorder.lineWidth = 1.5
        dashedBorder.lineDashPattern = [5, 4]
        contentView.layer.addSublayer(dashedBorder)

        plusTile.image = UIImage(systemName: "plus")
        plusTile.contentMode = .center
        plusTile.tintColor = DesignSystem.Colors.accentText
        plusTile.backgroundColor = DesignSystem.Colors.accentTint
        plusTile.layer.cornerRadius = DesignSystem.Radius.tileSmall
        plusTile.layer.cornerCurve = .continuous
        plusTile.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = DesignSystem.Typography.rowTitle
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [plusTile, titleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            plusTile.widthAnchor.constraint(equalToConstant: 40),
            plusTile.heightAnchor.constraint(equalToConstant: 40),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported.") }

    func configure(title: String) {
        titleLabel.text = title
        accessibilityLabel = title
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(
            roundedRect: contentView.bounds,
            cornerRadius: DesignSystem.Radius.lg
        )
        dashedBorder.path = path.cgPath
        dashedBorder.frame = contentView.bounds
        dashedBorder.strokeColor = DesignSystem.Colors.strokeControl.cgColor
    }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.7 : 1 }
    }
}

/// "Popular" section label.
private final class SectionTitleView: UICollectionReusableView {
    static let reuseID = "SectionTitleView"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = DesignSystem.Typography.sectionHeader
        label.textColor = DesignSystem.Colors.textSecondary
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            // Boundary items already follow the section's content insets.
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported.") }

    func configure(title: String) {
        label.text = title
    }
}
