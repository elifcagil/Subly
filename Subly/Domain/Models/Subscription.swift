import Foundation

struct Subscription: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var amount: Decimal
    var currencyCode: String
    var billingCycle: BillingCycle
    var startDate: Date
    var nextRenewalDate: Date
    /// Zero or more categories, tag-style. The first one is the "primary"
    /// category used wherever only a single one fits (icons, grouping).
    var categoryIDs: [Category.ID]
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
        categoryIDs: [Category.ID] = [],
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
        self.categoryIDs = categoryIDs
        self.notes = notes
        self.isArchived = isArchived
        self.reminderLeadDays = reminderLeadDays
    }

    /// Primary category (first selected), or nil when uncategorized.
    var categoryID: Category.ID? { categoryIDs.first }

    // MARK: - Codable (accepts the legacy single `categoryID` key)

    private enum CodingKeys: String, CodingKey {
        case id, name, amount, currencyCode, billingCycle, startDate, nextRenewalDate
        case categoryIDs, categoryID, notes, isArchived, reminderLeadDays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        amount = try c.decode(Decimal.self, forKey: .amount)
        currencyCode = try c.decode(String.self, forKey: .currencyCode)
        billingCycle = try c.decode(BillingCycle.self, forKey: .billingCycle)
        startDate = try c.decode(Date.self, forKey: .startDate)
        nextRenewalDate = try c.decode(Date.self, forKey: .nextRenewalDate)
        if let ids = try c.decodeIfPresent([Category.ID].self, forKey: .categoryIDs) {
            categoryIDs = ids
        } else if let legacy = try c.decodeIfPresent(Category.ID.self, forKey: .categoryID) {
            categoryIDs = [legacy]
        } else {
            categoryIDs = []
        }
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        reminderLeadDays = try c.decodeIfPresent([Int].self, forKey: .reminderLeadDays) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(amount, forKey: .amount)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encode(billingCycle, forKey: .billingCycle)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(nextRenewalDate, forKey: .nextRenewalDate)
        try c.encode(categoryIDs, forKey: .categoryIDs)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(isArchived, forKey: .isArchived)
        try c.encode(reminderLeadDays, forKey: .reminderLeadDays)
    }
}
