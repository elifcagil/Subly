import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration

/// Lock screen ring: one subscription per widget. Pin one, or leave it empty
/// and pick a slot (1–4) to show the n-th soonest renewal.
struct LockRingConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Renewal Ring"
    static var description = IntentDescription("One subscription's renewal ring. Leave empty to show the next renewal; use the slot number when placing several side by side.")

    @Parameter(title: "Subscription")
    var subscription: PinnedSubscription?

    @Parameter(title: "Slot", default: 1, inclusiveRange: (1, 4))
    var slot: Int
}

// MARK: - Entry + provider

struct LockRingEntry: TimelineEntry {
    let date: Date
    /// The subscription this widget shows (nil → empty state).
    let item: WidgetItem?
    /// Other renewals on the same day as `item` (rectangular: "Netflix +1").
    let sameDayExtra: Int
    /// Total of all renewals on that day, in `item`'s currency.
    let sameDayTotal: Decimal
    /// Active renewals in the next 7 days (inline multi variant).
    let weekCount: Int
}

struct LockRingProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> LockRingEntry {
        LockRingEntry(date: Date(), item: LockPreviewData.item(name: "Netflix", amount: 15.49, inDays: 1), sameDayExtra: 0, sameDayTotal: 15.49, weekCount: 3)
    }

    func snapshot(for configuration: LockRingConfigurationIntent, in context: Context) async -> LockRingEntry {
        if context.isPreview { return placeholder(in: context) }
        return await makeEntry(for: Date(), configuration: configuration)
    }

    func timeline(for configuration: LockRingConfigurationIntent, in context: Context) async -> Timeline<LockRingEntry> {
        let calendar = Calendar.current
        let now = Date()
        var entries = [await makeEntry(for: now, configuration: configuration)]
        for day in 1...7 {
            guard let midnight = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: now)),
                  let date = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: midnight) else { continue }
            entries.append(await makeEntry(for: date, configuration: configuration))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    @MainActor
    private func makeEntry(for date: Date, configuration: LockRingConfigurationIntent) async -> LockRingEntry {
        let builder = WidgetItemBuilder()
        let calendar = Calendar.current
        do {
            let subscriptions = try await SharedSubscriptionProvider.make().snapshot()
            let all = builder.items(from: subscriptions, limit: .max, on: date)
            let item: WidgetItem?
            if let pinned = configuration.subscription?.id {
                item = all.first { $0.id == pinned }
            } else {
                let index = max(0, configuration.slot - 1)
                item = index < all.count ? all[index] : nil
            }
            var extra = 0
            var total = item?.amount ?? 0
            if let item {
                let sameDay = all.filter {
                    $0.id != item.id && $0.currencyCode == item.currencyCode
                        && calendar.isDate($0.renewalDate, inSameDayAs: item.renewalDate)
                }
                extra = sameDay.count
                total += sameDay.reduce(Decimal(0)) { $0 + $1.amount }
            }
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: date)) ?? date
            let weekCount = all.filter { $0.renewalDate < weekEnd }.count
            return LockRingEntry(date: date, item: item, sameDayExtra: extra, sameDayTotal: total, weekCount: weekCount)
        } catch {
            return LockRingEntry(date: date, item: nil, sameDayExtra: 0, sameDayTotal: 0, weekCount: 0)
        }
    }
}

// MARK: - Monochrome ring

/// Lock screen ring: `.primary` arc on a `.primary.opacity(0.28)` track; the
/// system tints both. Outside `.vibrant` the arc may take the accent.
struct LockRing<Center: View>: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    @ViewBuilder let center: () -> Center

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(1, max(0.03, progress)) }

    var body: some View {
        let inset = lineWidth / 2
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.28), lineWidth: lineWidth)
                .padding(inset)
            RingArc(progress: clamped)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .foregroundStyle(renderingMode == .vibrant ? AnyShapeStyle(.primary) : AnyShapeStyle(Color(hex: "#C8F169")))
                .padding(inset)
                .animation(reduceMotion ? nil : .spring(duration: 1.1, bounce: 0), value: clamped)
            center()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Stack mark in monochrome for the empty circular state.
struct LockStackMark: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, _ in
            let unit = size / 100
            for (index, bar) in [(30.0, 26.0), (27.0, 43.0), (24.0, 60.0)].enumerated() {
                let rect = CGRect(x: bar.0 * unit, y: bar.1 * unit, width: 46 * unit, height: 15 * unit)
                let opacity = [0.45, 0.7, 1.0][index]
                context.fill(Path(roundedRect: rect, cornerRadius: 6 * unit, style: .continuous), with: .color(.primary.opacity(opacity)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Views

struct LockRingWidgetView: View {
    let entry: LockRingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            LockInlineView(entry: entry)
        case .accessoryRectangular:
            LockRectangularView(entry: entry)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            LockCircularView(entry: entry)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        }
    }
}

struct LockCircularView: View {
    let entry: LockRingEntry

    var body: some View {
        if let item = entry.item {
            LockRing(progress: item.progress.fraction, size: 72, lineWidth: 5) {
                VStack(spacing: 2) {
                    Text(item.tile.initial)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.primary)
                    Text(WidgetCopy.shortWhen(daysLeft: item.daysLeft))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(WidgetCopy.accessibilityLabel(item))
            .widgetURL(WidgetCopy.subscriptionURL(item.id))
        } else {
            LockStackMark(size: 40)
                .accessibilityLabel("Subly")
                .widgetURL(WidgetCopy.addURL)
        }
    }
}

struct LockRectangularView: View {
    let entry: LockRingEntry

    var body: some View {
        if let item = entry.item {
            HStack(spacing: 10) {
                LockRing(progress: item.progress.fraction, size: 52, lineWidth: 5) {
                    Text(item.tile.initial)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.primary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.sameDayExtra > 0 ? "\(item.name) +\(entry.sameDayExtra)" : item.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(WidgetCopy.when(daysLeft: item.daysLeft))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    Text(CurrencyFormatter().string(from: entry.sameDayTotal, currencyCode: item.currencyCode))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(WidgetCopy.accessibilityLabel(item))
            .widgetURL(WidgetCopy.subscriptionURL(item.id))
        } else {
            HStack(spacing: 10) {
                LockStackMark(size: 28)
                Text(WidgetCopy.lockAdd)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .widgetURL(WidgetCopy.addURL)
        }
    }
}

struct LockInlineView: View {
    let entry: LockRingEntry

    var body: some View {
        if let item = entry.item {
            let ring = Image(uiImage: InlineRingImage.make(progress: item.progress.fraction))
            let price = WidgetCopy.price(item)
            let when = WidgetCopy.when(daysLeft: item.daysLeft)
            ViewThatFits {
                Text("\(ring) \(item.name) · \(when) · \(price)")
                Text("\(ring) \(item.name) · \(when)")
            }
            .widgetURL(WidgetCopy.subscriptionURL(item.id))
        } else {
            Text("Subly · \(WidgetCopy.lockEmptyInline)")
                .widgetURL(WidgetCopy.addURL)
        }
    }
}

/// Inline widgets take text plus one image: a template ring at 25% steps.
enum InlineRingImage {
    static func make(progress: Double) -> UIImage {
        let steps: [Double] = [0, 0.25, 0.5, 0.75, 0.9, 1]
        let snapped = steps.min { abs($0 - progress) < abs($1 - progress) } ?? 1
        let side: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let center = CGPoint(x: side / 2, y: side / 2)
            let radius = side / 2 - 1.5
            let track = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            track.lineWidth = 2.4
            UIColor.black.withAlphaComponent(0.3).setStroke()
            track.stroke()
            if snapped > 0 {
                let arc = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: -.pi / 2 + 2 * .pi * snapped, clockwise: true)
                arc.lineWidth = 2.4
                arc.lineCapStyle = .round
                UIColor.black.setStroke()
                arc.stroke()
            }
            _ = context
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}

// MARK: - Widget

struct LockScreenRingWidget: Widget {
    let kind = "LockScreenRingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LockRingConfigurationIntent.self, provider: LockRingProvider()) { entry in
            LockRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Renewal Ring")
        .description("A subscription's renewal countdown on your Lock Screen.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Previews

enum LockPreviewData {
    static func item(name: String, amount: Decimal, inDays: Int) -> WidgetItem? {
        let now = Date()
        let calendar = Calendar.current
        let renewal = calendar.date(byAdding: .day, value: inDays, to: now) ?? now
        let sub = Subscription(name: name, amount: amount, currencyCode: "USD", billingCycle: .monthly,
                               startDate: calendar.date(byAdding: .month, value: -1, to: renewal) ?? now, nextRenewalDate: renewal)
        return WidgetItemBuilder().items(from: [sub], limit: 1, on: now).first
    }

    static func entry(_ name: String, _ amount: Decimal, inDays: Int, extra: Int = 0) -> LockRingEntry {
        let item = item(name: name, amount: amount, inDays: inDays)
        return LockRingEntry(date: .now, item: item, sameDayExtra: extra, sameDayTotal: amount + Decimal(extra) * 10, weekCount: 3)
    }
}

#if DEBUG
#Preview("Circular", as: .accessoryCircular) {
    LockScreenRingWidget()
} timeline: {
    LockPreviewData.entry("YouTube", 13.99, inDays: 14)
    LockPreviewData.entry("Spotify", 10.99, inDays: 3)
    LockPreviewData.entry("Netflix", 15.49, inDays: 1)
    LockPreviewData.entry("Netflix", 15.49, inDays: 0)
    LockRingEntry(date: .now, item: nil, sameDayExtra: 0, sameDayTotal: 0, weekCount: 0)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    LockScreenRingWidget()
} timeline: {
    LockPreviewData.entry("Netflix", 15.49, inDays: 1)
    LockPreviewData.entry("Netflix", 15.49, inDays: 1, extra: 1)
    LockRingEntry(date: .now, item: nil, sameDayExtra: 0, sameDayTotal: 0, weekCount: 0)
}

#Preview("Inline", as: .accessoryInline) {
    LockScreenRingWidget()
} timeline: {
    LockPreviewData.entry("Netflix", 15.49, inDays: 1)
    LockRingEntry(date: .now, item: nil, sameDayExtra: 0, sameDayTotal: 0, weekCount: 0)
}
#endif
