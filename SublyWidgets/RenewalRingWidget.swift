import SwiftUI
import WidgetKit

// MARK: - Entry + provider

struct RenewalRingEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
    /// "$46.48 this week" — one total per currency, joined with " + ".
    let weeklyTotalText: String?
}

struct RenewalRingProvider: AppIntentTimelineProvider {

    private static let previewItems: [WidgetItem] = {
        let now = Date()
        let calendar = Calendar.current
        func sub(_ name: String, _ amount: Decimal, inDays: Int) -> Subscription {
            let renewal = calendar.date(byAdding: .day, value: inDays, to: now) ?? now
            return Subscription(
                name: name, amount: amount, currencyCode: "USD", billingCycle: .monthly,
                startDate: calendar.date(byAdding: .month, value: -6, to: renewal) ?? now,
                nextRenewalDate: renewal
            )
        }
        return WidgetItemBuilder().items(
            from: [sub("Netflix", 15.49, inDays: 1), sub("Spotify", 10.99, inDays: 3), sub("ChatGPT", 20, inDays: 6)],
            limit: 3, on: now
        )
    }()

    func placeholder(in context: Context) -> RenewalRingEntry {
        RenewalRingEntry(date: Date(), items: Array(Self.previewItems.prefix(limit(for: context))), weeklyTotalText: "$46.48")
    }

    func snapshot(for configuration: RenewalRingConfigurationIntent, in context: Context) async -> RenewalRingEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        return await makeEntry(for: Date(), configuration: configuration, limit: limit(for: context))
    }

    /// One entry per day at 00:01 local for the next 7 days, so the ring and
    /// the day count step forward overnight. `.atEnd` asks for a fresh set.
    func timeline(for configuration: RenewalRingConfigurationIntent, in context: Context) async -> Timeline<RenewalRingEntry> {
        let calendar = Calendar.current
        let now = Date()
        let limit = limit(for: context)
        var entries: [RenewalRingEntry] = [await makeEntry(for: now, configuration: configuration, limit: limit)]
        for day in 1...7 {
            guard let midnight = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: now)),
                  let date = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: midnight) else { continue }
            entries.append(await makeEntry(for: date, configuration: configuration, limit: limit))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func limit(for context: Context) -> Int {
        context.family == .systemSmall ? 1 : 3
    }

    @MainActor
    private func makeEntry(for date: Date, configuration: RenewalRingConfigurationIntent, limit: Int) async -> RenewalRingEntry {
        let builder = WidgetItemBuilder()
        do {
            let provider = try SharedSubscriptionProvider.make()
            let subscriptions = try await provider.snapshot()
            let items = builder.items(from: subscriptions, pinned: configuration.pinnedIDs, limit: limit, on: date)
            // "This week" counts every active renewal, not only the shown ones.
            let all = builder.items(from: subscriptions, limit: .max, on: date)
            let totals = builder.weeklyTotals(of: all, on: date)
            let formatter = CurrencyFormatter()
            let text = totals.isEmpty ? nil
                : totals.map { formatter.string(from: $0.total, currencyCode: $0.currencyCode) }.joined(separator: " + ")
            return RenewalRingEntry(date: date, items: items, weeklyTotalText: text)
        } catch {
            return RenewalRingEntry(date: date, items: [], weeklyTotalText: nil)
        }
    }
}

// MARK: - Views

struct RenewalRingWidgetView: View {
    let entry: RenewalRingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.items.isEmpty {
                EmptyRingView()
            } else if family == .systemSmall {
                SmallRingView(item: entry.items[0])
            } else {
                MediumRingView(items: entry.items, weeklyTotalText: entry.weeklyTotalText)
            }
        }
        .containerBackground(WidgetTheme.background, for: .widget)
    }
}

/// Small: one subscription — ring top-left, mark top-right, name + when/price.
struct SmallRingView: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ProgressRing(progress: item.progress.fraction, size: 84, lineWidth: 7,
                             tile: item.tile, tileSize: 44, tileRadius: 13, tileFont: 19)
                Spacer(minLength: 0)
                StackMark(size: 18)
            }
            Spacer(minLength: 4)
            Text(item.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(WidgetTheme.inkPrimary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline) {
                Text(WidgetCopy.when(daysLeft: item.daysLeft))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetTheme.accentText)
                    .contentTransition(.numericText())
                Spacer(minLength: 4)
                Text(WidgetCopy.price(item))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.inkSecondary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
        }
        .padding(14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetCopy.accessibilityLabel(item))
        .widgetURL(WidgetCopy.subscriptionURL(item.id))
    }
}

/// Medium: adapts to 1, 2 or 3 items.
struct MediumRingView: View {
    let items: [WidgetItem]
    let weeklyTotalText: String?

    var body: some View {
        switch items.count {
        case 1:
            SingleItemMediumView(item: items[0])
        case 2:
            VStack(spacing: 10) {
                UpcomingHeader(weeklyTotalText: weeklyTotalText)
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        Link(destination: WidgetCopy.subscriptionURL(item.id)) {
                            TwoColumnItem(item: item)
                        }
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        default:
            VStack(spacing: 10) {
                UpcomingHeader(weeklyTotalText: weeklyTotalText)
                HStack(alignment: .top, spacing: 6) {
                    ForEach(items.prefix(3)) { item in
                        Link(destination: WidgetCopy.subscriptionURL(item.id)) {
                            ThreeColumnItem(item: item)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
    }
}

struct UpcomingHeader: View {
    let weeklyTotalText: String?

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                StackMark(size: 14)
                Text(WidgetCopy.upcoming)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WidgetTheme.inkSecondary)
            }
            Spacer()
            if let weeklyTotalText {
                (Text(weeklyTotalText).foregroundStyle(WidgetTheme.inkPrimary).fontWeight(.bold)
                 + Text(" \(WidgetCopy.thisWeek)").foregroundStyle(WidgetTheme.inkSecondary).fontWeight(.semibold))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ThreeColumnItem: View {
    let item: WidgetItem

    var body: some View {
        VStack(spacing: 6) {
            ProgressRing(progress: item.progress.fraction, size: 68, lineWidth: 6,
                         tile: item.tile, tileSize: 36, tileRadius: 11, tileFont: 15)
            VStack(spacing: 0) {
                Text(item.name)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(WidgetTheme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(WidgetCopy.when(daysLeft: item.daysLeft))
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(WidgetTheme.accentText)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetCopy.accessibilityLabel(item))
    }
}

struct TwoColumnItem: View {
    let item: WidgetItem

    var body: some View {
        HStack(spacing: 10) {
            ProgressRing(progress: item.progress.fraction, size: 68, lineWidth: 6,
                         tile: item.tile, tileSize: 36, tileRadius: 11, tileFont: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WidgetTheme.inkPrimary)
                    .lineLimit(1)
                Text(WidgetCopy.when(daysLeft: item.daysLeft))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(WidgetTheme.accentText)
                    .contentTransition(.numericText())
                Text(WidgetCopy.price(item))
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetCopy.accessibilityLabel(item))
    }
}

struct SingleItemMediumView: View {
    let item: WidgetItem

    var body: some View {
        HStack(spacing: 18) {
            ProgressRing(progress: item.progress.fraction, size: 118, lineWidth: 9,
                         tile: item.tile, tileSize: 56, tileRadius: 16, tileFont: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(WidgetCopy.nextRenewal)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WidgetTheme.inkSecondary)
                Text(item.name)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(WidgetTheme.inkPrimary)
                    .lineLimit(1)
                Text(WidgetCopy.price(item))
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
                    .contentTransition(.numericText())
                Text("\(WidgetCopy.when(daysLeft: item.daysLeft)) · \(WidgetCopy.shortDate(item.renewalDate))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetTheme.accentText)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetCopy.accessibilityLabel(item))
        .widgetURL(WidgetCopy.subscriptionURL(item.id))
    }
}

/// No subscriptions yet: mark + one line + deep link to Add.
struct EmptyRingView: View {
    var body: some View {
        VStack(spacing: 10) {
            StackMark(size: 28)
            Text(WidgetCopy.addFirst)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetTheme.inkPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
        .widgetURL(WidgetCopy.addURL)
    }
}

// MARK: - Widget

struct RenewalRingWidget: Widget {
    let kind = "RenewalRingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RenewalRingConfigurationIntent.self, provider: RenewalRingProvider()) { entry in
            RenewalRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Renewal Rings")
        .description("Your next renewals, each ring filling as the date approaches.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#if DEBUG
private enum PreviewData {
    static func items(_ count: Int) -> [WidgetItem] {
        let now = Date()
        let calendar = Calendar.current
        func sub(_ name: String, _ amount: Decimal, inDays: Int) -> Subscription {
            let renewal = calendar.date(byAdding: .day, value: inDays, to: now) ?? now
            return Subscription(name: name, amount: amount, currencyCode: "USD", billingCycle: .monthly,
                                startDate: now, nextRenewalDate: renewal)
        }
        let all = [sub("Netflix", 15.49, inDays: 1), sub("Spotify", 10.99, inDays: 3), sub("ChatGPT", 20, inDays: 6)]
        return WidgetItemBuilder().items(from: Array(all.prefix(count)), limit: 3, on: now)
    }
}

#Preview("Small · 1 day left", as: .systemSmall) {
    RenewalRingWidget()
} timeline: {
    RenewalRingEntry(date: .now, items: PreviewData.items(1), weeklyTotalText: "$46.48")
}

#Preview("Medium · 3", as: .systemMedium) {
    RenewalRingWidget()
} timeline: {
    RenewalRingEntry(date: .now, items: PreviewData.items(3), weeklyTotalText: "$46.48")
}

#Preview("Medium · 2", as: .systemMedium) {
    RenewalRingWidget()
} timeline: {
    RenewalRingEntry(date: .now, items: PreviewData.items(2), weeklyTotalText: "$26.48")
}

#Preview("Medium · 1", as: .systemMedium) {
    RenewalRingWidget()
} timeline: {
    RenewalRingEntry(date: .now, items: PreviewData.items(1), weeklyTotalText: "$15.49")
}

#Preview("Empty", as: .systemMedium) {
    RenewalRingWidget()
} timeline: {
    RenewalRingEntry(date: .now, items: [], weeklyTotalText: nil)
}
#endif
