import AppIntents
import Foundation
import SwiftData

struct AddSubscriptionIntent: AppIntent {

    static var title: LocalizedStringResource = "Add subscription"
    static var description = IntentDescription("Quickly add a new subscription with a name, amount, and renewal date.")
    static var openAppWhenRun = false

    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Monthly amount")
    var amount: Double

    @Parameter(title: "Next renewal date")
    var renewalDate: Date

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount > 0 else {
            return .result(dialog: "Please provide a name and a positive amount.")
        }

        let schema = Schema([SubscriptionEntity.self])
        let configuration: ModelConfiguration
        if let storeURL = AppGroup.storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }

        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let subscription = Subscription(
            name: trimmed,
            amount: Decimal(amount),
            currencyCode: Locale.current.currency?.identifier ?? "USD",
            billingCycle: .monthly,
            startDate: renewalDate,
            nextRenewalDate: renewalDate,
            reminderLeadDays: [1]
        )
        context.insert(SubscriptionEntity.make(from: subscription, now: Date()))
        try context.save()

        return .result(dialog: "Added \(trimmed) renewing on \(renewalDate.formatted(date: .long, time: .omitted)).")
    }
}
