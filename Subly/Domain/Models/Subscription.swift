import Foundation

struct Subscription: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var amount: Decimal
    var currencyCode: String
    var billingCycle: BillingCycle
    var startDate: Date
    var nextRenewalDate: Date
    var categoryID: Category.ID?
    var notes: String?
    var isArchived: Bool
    var reminderLeadDays: [Int]

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        currencyCode: String,
        billingCycle: BillingCycle,
        startDate: Date,
        nextRenewalDate: Date,
        categoryID: Category.ID? = nil,
        notes: String? = nil,
        isArchived: Bool = false,
        reminderLeadDays: [Int] = []
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.billingCycle = billingCycle
        self.startDate = startDate
        self.nextRenewalDate = nextRenewalDate
        self.categoryID = categoryID
        self.notes = notes
        self.isArchived = isArchived
        self.reminderLeadDays = reminderLeadDays
    }
}
