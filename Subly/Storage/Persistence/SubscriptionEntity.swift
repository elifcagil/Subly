import Foundation
import SwiftData

@Model
final class SubscriptionEntity {

    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var currencyCode: String
    var billingCycleRaw: String
    var startDate: Date
    var nextRenewalDate: Date
    var categoryID: UUID?
    var notes: String?
    var isArchived: Bool
    var reminderLeadDaysData: Data
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        name: String,
        amount: Decimal,
        currencyCode: String,
        billingCycleRaw: String,
        startDate: Date,
        nextRenewalDate: Date,
        categoryID: UUID?,
        notes: String?,
        isArchived: Bool,
        reminderLeadDaysData: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.billingCycleRaw = billingCycleRaw
        self.startDate = startDate
        self.nextRenewalDate = nextRenewalDate
        self.categoryID = categoryID
        self.notes = notes
        self.isArchived = isArchived
        self.reminderLeadDaysData = reminderLeadDaysData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension SubscriptionEntity {

    static func make(from subscription: Subscription, now: Date) -> SubscriptionEntity {
        SubscriptionEntity(
            id: subscription.id,
            name: subscription.name,
            amount: subscription.amount,
            currencyCode: subscription.currencyCode,
            billingCycleRaw: subscription.billingCycle.rawValue,
            startDate: subscription.startDate,
            nextRenewalDate: subscription.nextRenewalDate,
            categoryID: subscription.categoryID,
            notes: subscription.notes,
            isArchived: subscription.isArchived,
            reminderLeadDaysData: encode(subscription.reminderLeadDays),
            createdAt: now,
            updatedAt: now
        )
    }

    func apply(_ subscription: Subscription, now: Date) {
        name = subscription.name
        amount = subscription.amount
        currencyCode = subscription.currencyCode
        billingCycleRaw = subscription.billingCycle.rawValue
        startDate = subscription.startDate
        nextRenewalDate = subscription.nextRenewalDate
        categoryID = subscription.categoryID
        notes = subscription.notes
        isArchived = subscription.isArchived
        reminderLeadDaysData = Self.encode(subscription.reminderLeadDays)
        updatedAt = now
    }

    func toDomain() -> Subscription {
        Subscription(
            id: id,
            name: name,
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: BillingCycle(rawValue: billingCycleRaw) ?? .monthly,
            startDate: startDate,
            nextRenewalDate: nextRenewalDate,
            categoryID: categoryID,
            notes: notes,
            isArchived: isArchived,
            reminderLeadDays: Self.decode(reminderLeadDaysData)
        )
    }

    private static func encode(_ days: [Int]) -> Data {
        (try? JSONEncoder().encode(days)) ?? Data()
    }

    private static func decode(_ data: Data) -> [Int] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
    }
}
