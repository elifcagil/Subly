import UIKit

final class SettingsViewController: UIViewController {

    private let viewModel: SettingsViewModel
    @IBOutlet private weak var tableView: UITableView!

    private var sections: [SettingsViewModel.Section] = []

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:).")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.Settings.title
        view.backgroundColor = DesignSystem.Colors.background
        configureTable()
        configureBindings()
        viewModel.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The Dashboard hides the navigation bar and only re-shows it during
        // this push. A bar that comes back mid-transition does not lay out
        // its large title until the table scrolls, so ask for it explicitly
        // and force a layout pass before the transition starts.
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.sizeToFit()
        viewModel.load()
    }

    private func configureTable() {
        tableView.register(
            UINib(nibName: String(describing: SettingsDisclosureCell.self), bundle: nil),
            forCellReuseIdentifier: SettingsDisclosureCell.reuseIdentifier
        )
        tableView.register(
            UINib(nibName: String(describing: SettingsValueCell.self), bundle: nil),
            forCellReuseIdentifier: SettingsValueCell.reuseIdentifier
        )
        tableView.register(
            UINib(nibName: String(describing: SettingsToggleCell.self), bundle: nil),
            forCellReuseIdentifier: SettingsToggleCell.reuseIdentifier
        )
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = DesignSystem.Colors.background
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onErrorMessage = { [weak self] message in
            self?.presentAlert(message: message)
        }
    }

    private func render(_ state: ViewState<SettingsViewModel.Snapshot>) {
        switch state {
        case .loaded(let snapshot):
            sections = snapshot.sections
            tableView.reloadData()
        case .idle, .loading, .empty, .failed:
            return
        }
    }

    private func presentAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Strings.Common.ok, style: .default))
        present(alert, animated: true)
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .disclosure(let title, let accessory, _):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: SettingsDisclosureCell.reuseIdentifier,
                for: indexPath
            ) as? SettingsDisclosureCell else { return UITableViewCell() }
            cell.configure(title: title, accessory: makeAccessory(from: accessory))
            return cell
        case .value(let title, let detail, _):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: SettingsValueCell.reuseIdentifier,
                for: indexPath
            ) as? SettingsValueCell else { return UITableViewCell() }
            cell.configure(title: title, detail: detail)
            return cell
        case .toggle(let title, let isOn, let action):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: SettingsToggleCell.reuseIdentifier,
                for: indexPath
            ) as? SettingsToggleCell else { return UITableViewCell() }
            cell.configure(title: title, isOn: isOn) { [weak self] newValue in
                self?.viewModel.didToggle(action: action, isOn: newValue)
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .disclosure(_, _, let action), .value(_, _, let action):
            viewModel.didSelect(action: action)
        case .toggle:
            break
        }
    }

    private func makeAccessory(from accessory: SettingsViewModel.DisclosureAccessory) -> SettingsDisclosureCell.Accessory {
        switch accessory {
        case .detail(let value): return .detail(value)
        case .chip(let text, let tone):
            return .chip(SublyChip.ViewModel(text: text, systemIcon: nil, tone: tone.tone))
        case .none: return .none
        }
    }
}
