import WidgetKit
import SwiftUI

struct MonthlyTotalEntry: TimelineEntry {
    let date: Date
    let monthlyTotalText: String
    let activeCount: Int
}

struct MonthlyTotalProvider: TimelineProvider {

    func placeholder(in context: Context) -> MonthlyTotalEntry {
        MonthlyTotalEntry(date: Date(), monthlyTotalText: "$0.00", activeCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthlyTotalEntry) -> Void) {
        Task { @MainActor in
            completion(await makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthlyTotalEntry>) -> Void) {
        Task { @MainActor in
            let entry = await makeEntry()
            let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(3600 * 6)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    @MainActor
    private func makeEntry() async -> MonthlyTotalEntry {
        let calculator = MonthlySpendCalculator()
        let formatter = CurrencyFormatter()
        do {
            let provider = try SharedSubscriptionProvider.make()
            let subs = try await provider.snapshot()
            let monthly = calculator(subs)
            let currency = subs.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
            return MonthlyTotalEntry(
                date: Date(),
                monthlyTotalText: formatter.string(from: monthly, currencyCode: currency),
                activeCount: subs.count
            )
        } catch {
            return MonthlyTotalEntry(date: Date(), monthlyTotalText: "—", activeCount: 0)
        }
    }
}

struct MonthlyTotalWidgetView: View {
    let entry: MonthlyTotalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monthly")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(entry.monthlyTotalText)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(entry.activeCount) active")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MonthlyTotalWidget: Widget {
    let kind = "MonthlyTotalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthlyTotalProvider()) { entry in
            MonthlyTotalWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Monthly Total")
        .description("Your monthly subscription spend at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
