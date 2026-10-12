import SwiftUI
import WidgetKit

/// Widget design tokens from `CLAUDE_CODE_PROMPT_WIDGETS.md`. Resolved per
/// trait collection so the same token serves dark and light home screens.
enum WidgetTheme {

    static let background = dynamic(dark: "#16181C", light: "#FFFFFF")
    static let inkPrimary = dynamic(dark: "#F4F5F7", light: "#16181C")
    static let inkSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 235/255, green: 238/255, blue: 245/255, alpha: 0.58)
            : UIColor(red: 28/255, green: 30/255, blue: 36/255, alpha: 0.58)
    })
    /// Lime in dark; a deeper lime on white, where `#C8F169` is too faint.
    static let ringProgress = dynamic(dark: "#C8F169", light: "#8CB33A")
    static let ringTrack = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 0, alpha: 0.08)
    })
    /// "When" label: lime in dark, olive on light surfaces.
    static let accentText = dynamic(dark: "#C8F169", light: "#5F7F1C")
    static let neutralTile = dynamic(dark: "#22242A", light: "#E4E4E9")

    /// Stack-mark bars, top → bottom.
    static let markBars: [Color] = [
        Color(hex: "#4A5240"),
        Color(hex: "#8CA85B"),
        dynamic(dark: "#C8F169", light: "#8CB33A")
    ]

    private static func dynamic(dark: String, light: String) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

extension UIColor {
    /// `#RRGGBB` → color (widget-local copy; the app's DesignSystem is UIKit-only).
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        guard s.count == 6 else { self.init(white: 0, alpha: 0); return }
        self.init(
            red: CGFloat((value & 0xFF0000) >> 16) / 255,
            green: CGFloat((value & 0x00FF00) >> 8) / 255,
            blue: CGFloat(value & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Components

/// Three stacked rounded bars stepping left as they descend (README app
/// mark, 100×100 grid: 46×15 bars at (30,26) / (27,43) / (24,60), r6).
struct StackMark: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, _ in
            let unit = size / 100
            let bars: [(x: CGFloat, y: CGFloat)] = [(30, 26), (27, 43), (24, 60)]
            for (index, bar) in bars.enumerated() {
                let rect = CGRect(x: bar.x * unit, y: bar.y * unit, width: 46 * unit, height: 15 * unit)
                let path = Path(roundedRect: rect, cornerRadius: 6 * unit, style: .continuous)
                context.fill(path, with: .color(WidgetTheme.markBars[index]))
            }
        }
        .frame(width: size, height: size)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// Brand-colored tile with the service initial; neutral tile for custom services.
struct ServiceTileView: View {
    let tile: BrandTile
    let size: CGFloat
    let cornerRadius: CGFloat
    let fontSize: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay(
                Text(tile.initial)
                    .font(.system(size: fontSize, weight: .heavy))
                    .foregroundStyle(foreground)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            )
            .widgetAccentable()
    }

    private var background: Color {
        tile.backgroundHex.map(Color.init(hex:)) ?? WidgetTheme.neutralTile
    }

    private var foreground: Color {
        tile.foregroundHex.map(Color.init(hex:)) ?? WidgetTheme.inkPrimary
    }
}

/// Arc from 12 o'clock, clockwise, animatable so the sweep tweens between
/// timeline entries.
struct RingArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * progress),
            clockwise: false
        )
        return path
    }
}

/// Track + progress ring with the service tile centered inside. The arc
/// sweeps to its new value whenever the widget reloads; with Reduce Motion
/// it just snaps.
struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let tile: BrandTile
    let tileSize: CGFloat
    let tileRadius: CGFloat
    let tileFont: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let inset = lineWidth / 2
        ZStack {
            Circle()
                .stroke(WidgetTheme.ringTrack, lineWidth: lineWidth)
                .padding(inset)
            RingArc(progress: progress)
                .stroke(
                    WidgetTheme.ringProgress,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .padding(inset)
                .animation(reduceMotion ? nil : .spring(duration: 1.1, bounce: 0), value: progress)
                .widgetAccentable()
            ServiceTileView(tile: tile, size: tileSize, cornerRadius: tileRadius, fontSize: tileFont)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Copy helpers

enum WidgetCopy {
    static func when(daysLeft: Int) -> String {
        switch daysLeft {
        case 0: return String(localized: "widget.when.today")
        case 1: return String(localized: "widget.when.tomorrow")
        default: return String(format: String(localized: "widget.when.in_days_format"), daysLeft)
        }
    }

    /// Circular lock screen countdown: "14d", "3d", "Today".
    static func shortWhen(daysLeft: Int) -> String {
        daysLeft == 0 ? String(localized: "widget.when.today") : String(format: String(localized: "widget.when.short_days_format"), daysLeft)
    }
    static var lockAdd: String { String(localized: "widget.lock.add") }
    static var lockEmptyInline: String { String(localized: "widget.lock.empty_inline") }

    static var upcoming: String { String(localized: "widget.upcoming") }
    static var thisWeek: String { String(localized: "widget.this_week") }
    static var nextRenewal: String { String(localized: "widget.next_renewal") }
    static var addFirst: String { String(localized: "widget.add_first") }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    static func price(_ item: WidgetItem) -> String {
        CurrencyFormatter().string(from: item.amount, currencyCode: item.currencyCode)
    }

    static func accessibilityLabel(_ item: WidgetItem) -> String {
        let percent = Int((item.progress.fraction * 100).rounded())
        return String(format: String(localized: "widget.accessibility_format"), item.name, price(item), when(daysLeft: item.daysLeft).lowercased(), percent)
    }

    static func subscriptionURL(_ id: UUID) -> URL {
        URL(string: "subly://subscription/\(id.uuidString)")!
    }

    static let addURL = URL(string: "subly://add")!
}
