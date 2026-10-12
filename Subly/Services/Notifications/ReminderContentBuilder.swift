import Foundation

// MARK: - Vocabulary shared by the builder, scheduler and action handler

/// `UNNotificationCategory` identifiers. Which one a request carries decides
/// the action list iOS shows under it; a Notification Content Extension
/// targets the same identifiers.
enum ReminderCategory {
    /// Keep · Remind me tomorrow · Review (renewal ≥ 2 days away).
    static let standard = "RENEWAL_REMINDER"
    /// Keep · Review (renewal is today or tomorrow — "tomorrow" makes no sense).
    static let imminent = "RENEWAL_REMINDER_IMMINENT"
    /// Review only (one notification about several subscriptions).
    static let grouped = "RENEWAL_REMINDER_GROUPED"
    /// `threadIdentifier` on every reminder so Notification Center stacks them.
    static let thread = "renewals"
    /// "Your recap is ready" — tap opens the Recap story.
    static let recap = "RECAP"
}

enum ReminderAction {
    static let keep = "subly.reminder.keep"
    static let remindTomorrow = "subly.reminder.remind_tomorrow"
    static let review = "subly.reminder.review"
}

/// Identifier shapes. `rebuilt` are the ones a full resync replaces;
/// `snoozed` survives a rebuild (the user asked for it explicitly) and
/// `legacy` covers requests left by builds before this scheduler existed.
enum ReminderIdentifierPrefix {
    static let lead = "reminder."
    static let sameDay = "sameday."
    static let grouped = "grouped."
    static let snoozed = "snoozed."
    static let recap = "recap."
    static let rebuilt = [lead, sameDay, grouped]
    static let legacy = ["renewal.", "subscription."]
    static let all = rebuilt + [snoozed, recap] + legacy

    static func isReminder(_ identifier: String) -> Bool {
        all.contains { identifier.hasPrefix($0) }
    }
}

enum ReminderUserInfoKey {
    static let subscriptionID = "subscriptionId"
    static let subscriptionIDs = "subscriptionIds"
    static let renewalDate = "renewalDate"
    static let amount = "amount"
    static let currency = "currency"
    static let offsetDays = "offsetDays"
    static let name = "name"
    static let categoryID = "categoryId"
    /// Minute of day the reminder fires at (snooze keeps the same time).
    static let fireMinute = "fireMinute"
}

/// One local notification to schedule. Pure data so the builder can be unit
/// tested without `UserNotifications`.
struct ReminderRequest: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case lead(offsetDays: Int)
        case sameDay
        case grouped
        case snoozed
        case recap
    }

    let identifier: String
    let kind: Kind
    let title: String
    let body: String
    let fireDate: Date
    let categoryIdentifier: String
    /// Sound + interruption level, decided at scheduling time from the quiet
    /// window (`QuietHours.deliveryStyle`).
    let deliveryStyle: DeliveryStyle
    let userInfo: [String: String]

    var threadIdentifier: String { ReminderCategory.thread }
}

// MARK: - Builder

/// Turns subscriptions into the reminder requests for the next N days
/// (handoff: `CLAUDE_CODE_PROMPT_REMINDER_NOTIFICATION.md`).
///
/// Rules, in order:
/// 1. For each renewal date inside the horizon and each "remind me" offset N
///    on the subscription, one reminder N days before at `deliveryHour`.
/// 2. Plus a same-day reminder on the renewal date, unless N already includes
///    "same day" or the user tapped **Keep** for that renewal.
/// 3. A delivery inside quiet hours keeps its time but goes out silently
///    (`.passive`, no sound) — see `QuietHours.deliveryStyle`.
/// 4. Two or more subscriptions due for delivery on the same day collapse
///    into ONE grouped notification.
/// 5. Soonest first, capped at `limit` (iOS keeps at most 64 pending).
///
/// Pure: no clock, no notification center, no repository.
struct ReminderContentBuilder: Sendable {

    static let defaultHorizonDays = 60
    static let pendingRequestCap = 64

    let calendar: Calendar
    let locale: Locale
    let deliveryHour: Int
    private let currencyFormatter: CurrencyFormatting
    private let renewalCalculator: RenewalDateCalculator

    init(
        calendar: Calendar = .current,
        locale: Locale = .current,
        currencyFormatter: CurrencyFormatting = CurrencyFormatter(),
        deliveryHour: Int = 9
    ) {
        self.calendar = calendar
        self.locale = locale
        self.currencyFormatter = currencyFormatter
        self.deliveryHour = deliveryHour
        self.renewalCalculator = RenewalDateCalculator(calendar: calendar)
    }

    // MARK: Plan

    /// - Parameters:
    ///   - acknowledged: renewal day-keys the user tapped **Keep** on, by
    ///     subscription — their same-day reminder is skipped.
    ///   - limit: how many requests may be scheduled (64 minus whatever else
    ///     is pending).
    func plan(
        subscriptions: [Subscription],
        acknowledged: [UUID: String] = [:],
        quietHours: QuietHours = .default,
        now: Date,
        horizonDays: Int = ReminderContentBuilder.defaultHorizonDays,
        limit: Int = ReminderContentBuilder.pendingRequestCap
    ) -> [ReminderRequest] {
        let startOfToday = calendar.startOfDay(for: now)
        guard limit > 0,
              let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: startOfToday)
        else { return [] }

        var candidates: [Candidate] = []
        for subscription in subscriptions
        where !subscription.isArchived && !subscription.reminderLeadDays.isEmpty {
            let leads = Set(subscription.reminderLeadDays.filter { $0 >= 0 })
            for renewal in renewalDates(for: subscription, from: startOfToday, until: horizonEnd) {
                let renewalDay = calendar.startOfDay(for: renewal)
                var deliveryDays = Set<Date>()

                let minute = fireMinute(for: subscription)
                for lead in leads.sorted() {
                    guard let deliveryDay = calendar.date(byAdding: .day, value: -lead, to: renewalDay) else { continue }
                    let fire = fireDate(on: deliveryDay, minuteOfDay: minute)
                    guard fire > now, deliveryDays.insert(deliveryDay).inserted else { continue }
                    candidates.append(Candidate(
                        subscription: subscription, renewalDay: renewalDay,
                        offsetDays: lead, isSameDay: lead == 0, fireDate: fire
                    ))
                }

                let isAcknowledged = acknowledged[subscription.id] == dayKey(renewalDay)
                if !leads.contains(0), !isAcknowledged, !deliveryDays.contains(renewalDay) {
                    let fire = fireDate(on: renewalDay, minuteOfDay: minute)
                    if fire > now {
                        candidates.append(Candidate(
                            subscription: subscription, renewalDay: renewalDay,
                            offsetDays: 0, isSameDay: true, fireDate: fire
                        ))
                    }
                }
            }
        }

        var requests: [ReminderRequest] = []
        // Reminders fire at each subscription's own time of day, so only
        // those due at the very same moment are merged into one notification.
        let byFireMoment = Dictionary(grouping: candidates, by: \.fireDate)
        for (fireMoment, items) in byFireMoment {
            let deliveryDay = calendar.startOfDay(for: fireMoment)
            // One subscription, one reminder per day: keep the most urgent.
            let perSubscription = Dictionary(grouping: items, by: \.subscription.id)
                .values
                .compactMap { $0.min { $0.offsetDays < $1.offsetDays } }
                .sorted { ($0.renewalDay, $0.subscription.name) < ($1.renewalDay, $1.subscription.name) }

            if perSubscription.count >= 2 {
                requests.append(groupedRequest(perSubscription, deliveryDay: deliveryDay, fireDate: fireMoment, quietHours: quietHours))
            } else {
                requests.append(contentsOf: perSubscription.map { request(for: $0, quietHours: quietHours) })
            }
        }

        return Array(requests.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }

    // MARK: Snooze ("Remind me tomorrow")

    /// Rebuilds a reminder from a delivered notification's `userInfo` for
    /// tomorrow at `deliveryHour`, with the day count recomputed. `nil` when
    /// the payload is incomplete or the renewal is already behind us.
    func snoozedRequest(from userInfo: [String: String], quietHours: QuietHours = .default, now: Date) -> ReminderRequest? {
        guard let idText = userInfo[ReminderUserInfoKey.subscriptionID],
              let id = UUID(uuidString: idText),
              let name = userInfo[ReminderUserInfoKey.name],
              let amountText = userInfo[ReminderUserInfoKey.amount],
              let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")),
              let currency = userInfo[ReminderUserInfoKey.currency],
              let renewalKey = userInfo[ReminderUserInfoKey.renewalDate],
              let renewalDay = date(fromDayKey: renewalKey),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        else { return nil }

        let offset = daysBetween(tomorrow, renewalDay)
        guard offset >= 0 else { return nil }
        let categoryID = userInfo[ReminderUserInfoKey.categoryID].flatMap(UUID.init(uuidString:))
        let minute = userInfo[ReminderUserInfoKey.fireMinute].flatMap(Int.init) ?? deliveryHour * 60

        return makeRequest(
            kind: .snoozed,
            subscriptionID: id, name: name, amount: amount, currencyCode: currency,
            categoryID: categoryID, renewalDay: renewalDay, offsetDays: offset,
            fireDate: fireDate(on: tomorrow, minuteOfDay: minute), quietHours: quietHours
        )
    }

    // MARK: - Internals

    private struct Candidate {
        let subscription: Subscription
        let renewalDay: Date
        let offsetDays: Int
        let isSameDay: Bool
        let fireDate: Date
    }

    private func request(for candidate: Candidate, quietHours: QuietHours) -> ReminderRequest {
        let sub = candidate.subscription
        return makeRequest(
            kind: candidate.isSameDay ? .sameDay : .lead(offsetDays: candidate.offsetDays),
            subscriptionID: sub.id, name: sub.name, amount: sub.amount, currencyCode: sub.currencyCode,
            categoryID: sub.categoryID, renewalDay: candidate.renewalDay,
            offsetDays: candidate.offsetDays, fireDate: candidate.fireDate, quietHours: quietHours
        )
    }

    private func makeRequest(
        kind: ReminderRequest.Kind,
        subscriptionID: UUID,
        name: String,
        amount: Decimal,
        currencyCode: String,
        categoryID: UUID?,
        renewalDay: Date,
        offsetDays: Int,
        fireDate: Date,
        quietHours: QuietHours
    ) -> ReminderRequest {
        let amountText = currencyFormatter.string(from: amount, currencyCode: currencyCode)
        let dateText = shortDate(renewalDay)
        let renewalKey = dayKey(renewalDay)

        let title: String
        let body: String
        switch offsetDays {
        case 0:
            title = Strings.Reminders.titleToday(name: name)
            body = Strings.Reminders.bodyToday(amount: amountText)
        case 1:
            title = Strings.Reminders.titleTomorrow(name: name)
            body = Strings.Reminders.bodyTomorrow(amount: amountText)
        case 7:
            title = Strings.Reminders.titleWeek(name: name)
            body = Strings.Reminders.bodyWeek(amount: amountText, date: dateText)
        default:
            title = Strings.Reminders.titleInDays(name: name, days: offsetDays)
            body = Strings.Reminders.bodyInDays(amount: amountText, date: dateText, verb: verb(for: categoryID))
        }

        let prefix: String
        switch kind {
        case .lead: prefix = ReminderIdentifierPrefix.lead
        case .sameDay: prefix = ReminderIdentifierPrefix.sameDay
        case .snoozed: prefix = ReminderIdentifierPrefix.snoozed
        case .grouped: prefix = ReminderIdentifierPrefix.grouped
        case .recap: prefix = ReminderIdentifierPrefix.recap
        }

        var userInfo: [String: String] = [
            ReminderUserInfoKey.subscriptionID: subscriptionID.uuidString,
            ReminderUserInfoKey.renewalDate: renewalKey,
            ReminderUserInfoKey.amount: "\(amount)",
            ReminderUserInfoKey.currency: currencyCode,
            ReminderUserInfoKey.offsetDays: "\(offsetDays)",
            ReminderUserInfoKey.name: name,
            ReminderUserInfoKey.fireMinute: "\(minuteOfDay(fireDate))"
        ]
        if let categoryID { userInfo[ReminderUserInfoKey.categoryID] = categoryID.uuidString }

        return ReminderRequest(
            identifier: "\(prefix)\(subscriptionID.uuidString).\(renewalKey)",
            kind: kind,
            title: title,
            body: body,
            fireDate: fireDate,
            categoryIdentifier: offsetDays >= 2 ? ReminderCategory.standard : ReminderCategory.imminent,
            deliveryStyle: quietHours.deliveryStyle(for: fireDate, isSameDay: offsetDays == 0, calendar: calendar),
            userInfo: userInfo
        )
    }

    private func groupedRequest(_ items: [Candidate], deliveryDay: Date, fireDate fire: Date, quietHours: QuietHours) -> ReminderRequest {
        let days = items.map { daysBetween(deliveryDay, $0.renewalDay) }.max() ?? 0
        let count = items.count

        let title: String
        switch days {
        case 0: title = Strings.Reminders.groupedTitleToday(count: count)
        case 1: title = Strings.Reminders.groupedTitleTomorrow(count: count)
        default: title = Strings.Reminders.groupedTitleInDays(count: count, days: days)
        }

        // Never mixes currencies into one number: one total per currency.
        let totals = Dictionary(grouping: items, by: \.subscription.currencyCode)
            .sorted { $0.key < $1.key }
            .map { code, subs in
                currencyFormatter.string(
                    from: subs.reduce(Decimal(0)) { $0 + $1.subscription.amount },
                    currencyCode: code
                )
            }
            .joined(separator: " + ")

        let names = items.map(\.subscription.name)
        let body: String
        switch names.count {
        case 2: body = Strings.Reminders.groupedBodyTwo(names[0], names[1], total: totals)
        case 3: body = Strings.Reminders.groupedBodyThree(names[0], names[1], names[2], total: totals)
        default: body = Strings.Reminders.groupedBodyMore(names[0], names[1], more: names.count - 2, total: totals)
        }

        return ReminderRequest(
            identifier: "\(ReminderIdentifierPrefix.grouped)\(dayKey(deliveryDay)).\(minuteOfDay(fire))",
            kind: .grouped,
            title: title,
            body: body,
            fireDate: fire,
            categoryIdentifier: ReminderCategory.grouped,
            deliveryStyle: quietHours.deliveryStyle(for: fire, isSameDay: days == 0, calendar: calendar),
            userInfo: [
                ReminderUserInfoKey.subscriptionIDs: items.map(\.subscription.id.uuidString).joined(separator: ","),
                ReminderUserInfoKey.renewalDate: dayKey(deliveryDay),
                ReminderUserInfoKey.offsetDays: "\(days)"
            ]
        )
    }

    /// Renewal dates in `[from, until)`, starting from the subscription's
    /// next renewal (projected forward if the store is stale).
    private func renewalDates(for subscription: Subscription, from: Date, until: Date) -> [Date] {
        var date = subscription.nextRenewalDate
        if date < from {
            date = renewalCalculator.upcomingRenewalDate(
                from: date, cycle: subscription.billingCycle, relativeTo: from
            )
        }
        var dates: [Date] = []
        var steps = 0
        while date < until && steps < 100 {
            dates.append(date)
            let next = renewalCalculator.nextRenewalDate(after: date, cycle: subscription.billingCycle)
            guard next > date else { break }
            date = next
            steps += 1
        }
        return dates
    }

    /// `deliveryHour:00` on `day` (recap notification). Quiet hours no longer
    /// move the time — a delivery inside the window is simply silent.
    func deliveryDate(on day: Date) -> Date { fireDate(on: day, minuteOfDay: deliveryHour * 60) }

    /// Renewal reminders fire at the time of day the subscription was added
    /// ("1 day before" = exactly 24h before that moment on the renewal day),
    /// falling back to `deliveryHour:00` for rows without a creation time.
    func fireMinute(for subscription: Subscription) -> Int {
        guard let created = subscription.createdAt else { return deliveryHour * 60 }
        return minuteOfDay(created)
    }

    private func fireDate(on day: Date, minuteOfDay minute: Int) -> Date {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day) ?? day
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private func verb(for categoryID: UUID?) -> String {
        switch categoryID {
        case Category.streamingID: return Strings.Reminders.verbWatching
        case Category.musicID: return Strings.Reminders.verbListening
        default: return Strings.Reminders.verbUsing
        }
    }

    private func daysBetween(_ from: Date, _ to: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    private func dayKey(_ date: Date) -> String {
        NotificationIdentifierFormatter.dayKey(for: date, calendar: calendar)
    }

    private func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// "Tue, Jul 7" in the user's locale.
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return formatter.string(from: date)
    }
}

extension Category {
    /// Stable default-category IDs the reminder copy adapts its verb to.
    static let streamingID = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    static let musicID = UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!
}
