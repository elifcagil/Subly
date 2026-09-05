import Foundation

struct SubscriptionDraft: Equatable {
    /// A subscription can carry at most this many categories.
    static let maxCategories = 2

    var id: UUID
    var name: String
    var amountText: String
    var currencyCode: String
    var billingCycle: BillingCycle
    var startDate: Date
    var nextRenewalDate: Date
    var categoryIDs: [UUID]
    var notes: String
    var reminderLeadDays: Set<Int>

    static func new(
        currencyCode: String,
        today: Date,
        defaultReminderLeadDays: Set<Int> = [1]
    ) -> SubscriptionDraft {
        SubscriptionDraft(
            id: UUID(),
            name: "",
            amountText: "",
            currencyCode: currencyCode,
            billingCycle: .monthly,
            startDate: today,
            nextRenewalDate: today,
            categoryIDs: [],
            notes: "",
            reminderLeadDays: defaultReminderLeadDays
        )
    }

    static func from(
        entry: CatalogEntry,
        fallbackCurrency: String,
        today: Date,
        defaultReminderLeadDays: Set<Int> = [1]
    ) -> SubscriptionDraft {
        let amountString = NSDecimalNumber(decimal: entry.suggestedAmount).stringValue
        return SubscriptionDraft(
            id: UUID(),
            name: entry.name,
            amountText: amountString,
            currencyCode: entry.currencyCode.isEmpty ? fallbackCurrency : entry.currencyCode,
            billingCycle: entry.billingCycle,
            startDate: today,
            nextRenewalDate: today,
            categoryIDs: [],
            notes: "",
            reminderLeadDays: defaultReminderLeadDays
        )
    }

    static func from(_ subscription: Subscription) -> SubscriptionDraft {
        let amountString = NSDecimalNumber(decimal: subscription.amount).stringValue
        return SubscriptionDraft(
            id: subscription.id,
            name: subscription.name,
            amountText: amountString,
            currencyCode: subscription.currencyCode,
            billingCycle: subscription.billingCycle,
            startDate: subscription.startDate,
            nextRenewalDate: subscription.nextRenewalDate,
            categoryIDs: subscription.categoryIDs,
            notes: subscription.notes ?? "",
            reminderLeadDays: Set(subscription.reminderLeadDays)
        )
    }
}

extension SubscriptionDraft {

    enum ValidationError: Error, UserFacingError {
        case missingName
        case invalidAmount

        var userMessage: String {
            switch self {
            case .missingName: return Strings.AddEdit.missingName
            case .invalidAmount: return Strings.AddEdit.invalidAmount
            }
        }
    }

    func validated() -> Result<Subscription, ValidationError> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.missingName) }
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else {
            return .failure(.invalidAmount)
        }

        let subscription = Subscription(
            id: id,
            name: trimmedName,
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: billingCycle,
            startDate: startDate,
            nextRenewalDate: nextRenewalDate,
            categoryIDs: categoryIDs,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            isArchived: false,
            reminderLeadDays: reminderLeadDays.sorted()
        )
        return .success(subscription)
    }
}
