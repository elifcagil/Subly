import AppIntents
import Foundation

struct NextRenewalIntent: AppIntent {

    static var title: LocalizedStringResource = "When is my next renewal?"
    static var description = IntentDescription("Shows the next upcoming subscription renewal.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let provider = try SharedSubscriptionProvider.make()
        let subscriptions = try await provider.snapshot()

        let upcoming = subscriptions
            .filter { $0.nextRenewalDate >= Date() }
            .sorted { $0.nextRenewalDate < $1.nextRenewalDate }

        guard let next = upcoming.first else {
            return .result(dialog: "You have no upcoming renewals.")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        let dateText = formatter.string(from: next.nextRenewalDate)
        let amount = CurrencyFormatter().string(from: next.amount, currencyCode: next.currencyCode)

        return .result(
            dialog: "\(next.name) renews on \(dateText) for \(amount)."
        )
    }
}
