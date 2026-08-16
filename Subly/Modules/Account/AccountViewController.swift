import UIKit
import AuthenticationServices

final class AccountViewController: UIViewController {

    private let viewModel: AccountViewModel
    private let haptics: HapticsService

    // MARK: - Outlets

    @IBOutlet private weak var card: SublyCardView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var identifierLabel: UILabel!
    @IBOutlet private weak var entitlementLabel: UILabel!
    @IBOutlet private weak var signInContainer: UIView!
    @IBOutlet private weak var signOutButton: UIButton!

    private lazy var signInButton: ASAuthorizationAppleIDButton = ASAuthorizationAppleIDButton(type: .signIn, style: .black)

    // MARK: - Init

    init(viewModel: AccountViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.Account.title
        view.backgroundColor = DesignSystem.Colors.background
        configureSignInButton()
        configureSignOutButton()
        configureBindings()
        viewModel.start()
    }

    private func configureSignInButton() {
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.cornerRadius = DesignSystem.Radius.lg
        signInButton.addTarget(self, action: #selector(didTapSignIn), for: .touchUpInside)
        signInContainer.addSubview(signInButton)
        NSLayoutConstraint.activate([
            signInButton.topAnchor.constraint(equalTo: signInContainer.topAnchor),
            signInButton.leadingAnchor.constraint(equalTo: signInContainer.leadingAnchor),
            signInButton.trailingAnchor.constraint(equalTo: signInContainer.trailingAnchor),
            signInButton.bottomAnchor.constraint(equalTo: signInContainer.bottomAnchor)
        ])
    }

    private func configureSignOutButton() {
        signOutButton.setTitle(Strings.Common.signOut, for: .normal)
        signOutButton.titleLabel?.font = DesignSystem.Typography.body
        signOutButton.titleLabel?.adjustsFontForContentSizeCategory = true
        signOutButton.tintColor = DesignSystem.Colors.danger
        signOutButton.addTarget(self, action: #selector(didTapSignOut), for: .touchUpInside)
        signOutButton.isHidden = true
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onErrorMessage = { [weak self] message in
            self?.haptics.play(.error)
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Strings.Common.ok, style: .default))
            self?.present(alert, animated: true)
        }
    }

    private func render(_ state: ViewState<AccountViewModel.Snapshot>) {
        guard case .loaded(let snapshot) = state else { return }
        nameLabel.text = snapshot.authLabel
        if let identifier = snapshot.identifier {
            identifierLabel.isHidden = false
            identifierLabel.text = identifier
        } else {
            identifierLabel.isHidden = true
        }
        entitlementLabel.text = String(format: Strings.Account.planLabelFormat, snapshot.entitlementLabel)
        signInContainer.isHidden = snapshot.isSignedIn
        signOutButton.isHidden = !snapshot.isSignedIn
    }

    @objc private func didTapSignIn() {
        haptics.play(.lightImpact)
        viewModel.didTapSignIn()
    }

    @objc private func didTapSignOut() {
        haptics.play(.warning)
        viewModel.didTapSignOut()
    }
}
