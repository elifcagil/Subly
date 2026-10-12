import Foundation

/// The "What's New" story for one app version (handoff
/// `CLAUDE_CODE_PROMPT_WHATS_NEW.md`). Shipped in the bundle, keyed by
/// `CFBundleShortVersionString`; UIKit-free.
struct WhatsNewPayload: Equatable, Sendable {
    let version: String
    let cards: [WhatsNewCard]

    /// One intro feature row: number, name and the colour of the card it
    /// leads to.
    struct Feature: Equatable, Sendable {
        let number: Int
        let name: String
        /// Hex colours of the numbered circle and its digit.
        let circleHex: String
        let digitHex: String
    }

    struct FeatureCard: Equatable, Sendable {
        enum Visual: Equatable, Sendable {
            case homeWidgets
            case lockScreenWidgets
            case reminders
            case quietHours
        }

        let visual: Visual
        /// "NEW · 1 OF 5"
        let label: String
        let title: String
        let body: String
        /// "HOW TO ADD"
        let howToTitle: String
        let steps: [String]
        /// Radial background stops, light → dark.
        let gradientHex: [String]
        /// The card's base colour, used for the step digits.
        let baseHex: String
    }

    /// All payloads this build knows, by version.
    static let payloads: [String: WhatsNewPayload] = [
        "1.0.1": release101
    ]

    static func payload(for version: String) -> WhatsNewPayload? {
        payloads[version]
    }

    // MARK: - 1.0.1

    static var release101: WhatsNewPayload {
        let features = [
            Feature(number: 1, name: Strings.WhatsNew.featureHomeWidgets, circleHex: "#B4624F", digitHex: "#FFFFFF"),
            Feature(number: 2, name: Strings.WhatsNew.featureLockWidgets, circleHex: "#4A5C9E", digitHex: "#FFFFFF"),
            Feature(number: 3, name: Strings.WhatsNew.featureReminders, circleHex: "#C98E3E", digitHex: "#FFFFFF"),
            Feature(number: 4, name: Strings.WhatsNew.featureQuietHours, circleHex: "#54468A", digitHex: "#FFFFFF"),
            Feature(number: 5, name: Strings.WhatsNew.featureRecap, circleHex: "#C8F169", digitHex: "#141609")
        ]
        return WhatsNewPayload(version: "1.0.1", cards: [
            .intro(features: features),
            .feature(FeatureCard(
                visual: .homeWidgets,
                label: Strings.WhatsNew.newLabel(1, of: 5),
                title: Strings.WhatsNew.homeWidgetsTitle,
                body: Strings.WhatsNew.homeWidgetsBody,
                howToTitle: Strings.WhatsNew.howToAdd,
                steps: [Strings.WhatsNew.homeWidgetsStep1, Strings.WhatsNew.homeWidgetsStep2, Strings.WhatsNew.homeWidgetsStep3],
                gradientHex: ["#C0705A", "#6A3448", "#261426"],
                baseHex: "#6A3448"
            )),
            .feature(FeatureCard(
                visual: .lockScreenWidgets,
                label: Strings.WhatsNew.newLabel(2, of: 5),
                title: Strings.WhatsNew.lockWidgetsTitle,
                body: Strings.WhatsNew.lockWidgetsBody,
                howToTitle: Strings.WhatsNew.howToAdd,
                steps: [Strings.WhatsNew.lockWidgetsStep1, Strings.WhatsNew.lockWidgetsStep2, Strings.WhatsNew.lockWidgetsStep3],
                gradientHex: ["#5A6FB0", "#2E3A6A", "#141A33"],
                baseHex: "#2E3A6A"
            )),
            .feature(FeatureCard(
                visual: .reminders,
                label: Strings.WhatsNew.newLabel(3, of: 5),
                title: Strings.WhatsNew.remindersTitle,
                body: Strings.WhatsNew.remindersBody,
                howToTitle: Strings.WhatsNew.howToUse,
                steps: [Strings.WhatsNew.remindersStep1, Strings.WhatsNew.remindersStep2, Strings.WhatsNew.remindersStep3],
                gradientHex: ["#E7B65C", "#9A5A2C", "#2E1B12"],
                baseHex: "#9A5A2C"
            )),
            .feature(FeatureCard(
                visual: .quietHours,
                label: Strings.WhatsNew.newLabel(4, of: 5),
                title: Strings.WhatsNew.quietHoursTitle,
                body: Strings.WhatsNew.quietHoursBody,
                howToTitle: Strings.WhatsNew.howToSet,
                steps: [Strings.WhatsNew.quietHoursStep1, Strings.WhatsNew.quietHoursStep2, Strings.WhatsNew.quietHoursStep3],
                gradientHex: ["#5B4E92", "#2B2450", "#120F22"],
                baseHex: "#2B2450"
            )),
            .recapFinale
        ])
    }
}

enum WhatsNewCard: Equatable, Sendable {
    case intro(features: [WhatsNewPayload.Feature])
    case feature(WhatsNewPayload.FeatureCard)
    case recapFinale
}
