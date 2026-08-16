import AppIntents
import Foundation

struct SpendInCategoryIntent: AppIntent {

    static var title: LocalizedStringResource = "How much do I spend on a category?"
    static var description = IntentDescription("Returns your monthly spend in a chosen category.")
    static var openAppWhenRun = false

    @Parameter(title: "Category")
    var categoryName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let provider = try SharedSubscriptionProvider.make()
        let subscriptions = try await provider.snapshot()

        let categories = Category.defaults
        let needle = categoryName.lowercased()
        let matchedCategory = categories.first { $0.name.lowercased() == needle }

        let filtered: [Subscription]
        let label: String

        if let category = matchedCategory {
            filtered = subscriptions.filter { $0.categoryID == category.id }
            label = category.name
        } else {
            filtered = subscriptions
            label = "all subscriptions"
        }

        let total = MonthlySpendCalculator()(filtered)
        let currency = filtered.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        let formatted = CurrencyFormatter().string(from: total, currencyCode: currency)

        return .result(
            dialog: "You spend \(formatted) per month on \(label)."
        )
    }
}
