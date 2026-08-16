import WidgetKit
import SwiftUI

struct UpcomingRenewalsEntry: TimelineEntry {
    let date: Date
    let rows: [Row]

    struct Row: Identifiable {
        let id: UUID
        let name: String
        let dateText: String
        let amountText: String
    }
}

struct UpcomingRenewalsProvider: TimelineProvider {

    func placeholder(in context: Context) -> UpcomingRenewalsEntry {
        UpcomingRenewalsEntry(date: Date(), rows: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingRenewalsEntry) -> Void) {
        Task { @MainActor in
            completion(await makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingRenewalsEntry>) -> Void) {
        Task { @MainActor in
            let entry = await makeEntry()
            let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(3600 * 6)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    @MainActor
    private func makeEntry() async -> UpcomingRenewalsEntry {
        let formatter = CurrencyFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        do {
            let provider = try SharedSubscriptionProvider.make()
            let subs = try await provider.snapshot()
            let useCase = UpcomingRenewalsUseCase()
            let upcoming = useCase(subs, withinDays: 14).prefix(3)
            let rows = upcoming.map { sub in
                UpcomingRenewalsEntry.Row(
                    id: sub.id,
                    name: sub.name,
                    dateText: dateFormatter.string(from: sub.nextRenewalDate),
                    amountText: formatter.string(from: sub.amount, currencyCode: sub.currencyCode)
                )
            }
            return UpcomingRenewalsEntry(date: Date(), rows: Array(rows))
        } catch {
            return UpcomingRenewalsEntry(date: Date(), rows: [])
        }
    }
}

struct UpcomingRenewalsWidgetView: View {
    let entry: UpcomingRenewalsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if entry.rows.isEmpty {
                Spacer()
                Text("No renewals in 14 days")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                ForEach(entry.rows) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(row.dateText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(row.amountText)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UpcomingRenewalsWidget: Widget {
    let kind = "UpcomingRenewalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingRenewalsProvider()) { entry in
            UpcomingRenewalsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Upcoming Renewals")
        .description("See what's renewing in the next two weeks.")
        .supportedFamilies([.systemMedium])
    }
}
