import Foundation
@preconcurrency import AuthenticationServices

protocol AuthService: Sendable {
    @MainActor func currentState() -> AuthState
    @MainActor func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws -> AuthState
    @MainActor func signOut()
    func observe() -> AsyncStream<AuthState>
}

enum AuthState: Equatable, Sendable {
    case signedOut
    case signedIn(userID: String, fullName: String?, email: String?)
}

enum AuthServiceError: Error, UserFacingError {
    case cancelled
    case failed
    case unsupported

    var userMessage: String {
        switch self {
        case .cancelled: return "Sign in was cancelled."
        case .failed: return "Sign in didn't complete. Please try again."
        case .unsupported: return "Sign in with Apple isn't available right now."
        }
    }
}

@MainActor
final class AppleAuthService: NSObject, AuthService, @unchecked Sendable {

    private let defaults: UserDefaults
    private let userIDKey = "com.subly.auth.userID"
    private let displayNameKey = "com.subly.auth.displayName"
    private let emailKey = "com.subly.auth.email"

    private var continuations: [UUID: AsyncStream<AuthState>.Continuation] = [:]
    private var inFlightContinuation: CheckedContinuation<AuthState, Error>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    func currentState() -> AuthState {
        guard let userID = defaults.string(forKey: userIDKey) else { return .signedOut }
        return .signedIn(
            userID: userID,
            fullName: defaults.string(forKey: displayNameKey),
            email: defaults.string(forKey: emailKey)
        )
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws -> AuthState {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = PresentationContextProvider(anchor: presentationAnchor)

        return try await withCheckedThrowingContinuation { continuation in
            inFlightContinuation = continuation
            controller.performRequests()
        }
    }

    func signOut() {
        defaults.removeObject(forKey: userIDKey)
        defaults.removeObject(forKey: displayNameKey)
        defaults.removeObject(forKey: emailKey)
        broadcast(.signedOut)
    }

    nonisolated func observe() -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            let token = UUID()
            Task { @MainActor in
                self.register(token: token, continuation: continuation)
            }
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.unregister(token: token)
                }
            }
        }
    }

    private func register(token: UUID, continuation: AsyncStream<AuthState>.Continuation) {
        continuations[token] = continuation
        continuation.yield(currentState())
    }

    private func unregister(token: UUID) {
        continuations.removeValue(forKey: token)
    }

    private func broadcast(_ state: AuthState) {
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.inFlightContinuation?.resume(throwing: AuthServiceError.failed)
                self.inFlightContinuation = nil
                return
            }
            let userID = credential.user
            let fullName = credential.fullName?.formatted()
            let email = credential.email

            self.defaults.set(userID, forKey: self.userIDKey)
            if let fullName, !fullName.isEmpty {
                self.defaults.set(fullName, forKey: self.displayNameKey)
            }
            if let email {
                self.defaults.set(email, forKey: self.emailKey)
            }

            let state = AuthState.signedIn(userID: userID, fullName: fullName, email: email)
            self.broadcast(state)
            self.inFlightContinuation?.resume(returning: state)
            self.inFlightContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                self.inFlightContinuation?.resume(throwing: AuthServiceError.cancelled)
            } else {
                self.inFlightContinuation?.resume(throwing: AuthServiceError.failed)
            }
            self.inFlightContinuation = nil
        }
    }
}

private final class PresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {

    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor
    }
}

struct NoOpAuthService: AuthService {
    func currentState() -> AuthState { .signedOut }
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws -> AuthState { .signedOut }
    func signOut() {}
    func observe() -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            continuation.yield(.signedOut)
            continuation.finish()
        }
    }
}
