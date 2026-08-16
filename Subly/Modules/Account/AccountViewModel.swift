import Foundation

@MainActor
final class AccountViewModel {

    struct Snapshot: Equatable {
        let authLabel: String
        let identifier: String?
        let entitlementLabel: String
        let isSignedIn: Bool
    }

    private let authService: AuthService
    private let storeKitService: StoreKitService
    private var authState: AuthState = .signedOut
    private var entitlement: SublyEntitlement = .free
    private var authTask: Task<Void, Never>?
    private var entitlementTask: Task<Void, Never>?

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onSignInRequested: (() -> Void)?
    var onErrorMessage: ((String) -> Void)?

    init(authService: AuthService, storeKitService: StoreKitService) {
        self.authService = authService
        self.storeKitService = storeKitService
    }

    deinit {
        authTask?.cancel()
        entitlementTask?.cancel()
    }

    func start() {
        authState = authService.currentState()
        publishSnapshot()
        authTask = Task { [weak self] in
            guard let self else { return }
            for await state in authService.observe() {
                self.authState = state
                self.publishSnapshot()
            }
        }
        entitlementTask = Task { [weak self] in
            guard let self else { return }
            for await entitlement in storeKitService.entitlements() {
                self.entitlement = entitlement
                self.publishSnapshot()
            }
        }
    }

    func didTapSignIn() {
        onSignInRequested?()
    }

    func didTapSignOut() {
        authService.signOut()
    }

    private func publishSnapshot() {
        let label: String
        let identifier: String?
        let isSignedIn: Bool
        switch authState {
        case .signedOut:
            label = Strings.Settings.notSignedIn
            identifier = nil
            isSignedIn = false
        case .signedIn(let userID, let fullName, let email):
            label = fullName ?? email ?? Strings.Account.signedInFallback
            identifier = email ?? String(userID.prefix(8))
            isSignedIn = true
        }
        let entitlementLabel: String
        switch entitlement {
        case .free: entitlementLabel = Strings.Account.free
        case .plus: entitlementLabel = Strings.Account.plus
        }
        state = .loaded(Snapshot(
            authLabel: label,
            identifier: identifier,
            entitlementLabel: entitlementLabel,
            isSignedIn: isSignedIn
        ))
    }
}
