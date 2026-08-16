import Foundation

/// v5 Register (screen 00B): explains the anonymous device-ID model. One
/// primary action; no back. The device ID itself stays internal (Keychain) —
/// it is never shown to the user.
@MainActor
final class RegisterViewModel {

    struct TrustRow {
        let systemIcon: String
        let title: String
        let body: String
    }

    let trustRows: [TrustRow] = [
        TrustRow(
            systemIcon: "shuffle",
            title: Strings.Registration.trust1Title,
            body: Strings.Registration.trust1Body
        ),
        TrustRow(
            systemIcon: "hand.raised.fill",
            title: Strings.Registration.trust2Title,
            body: Strings.Registration.trust2Body
        ),
        TrustRow(
            systemIcon: "checkmark.seal.fill",
            title: Strings.Registration.trust3Title,
            body: Strings.Registration.trust3Body
        )
    ]

    var onContinue: (() -> Void)?

    func didTapContinue() {
        onContinue?()
    }
}
