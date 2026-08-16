import UIKit

protocol HapticsService: Sendable {
    @MainActor func play(_ event: HapticEvent)
}

enum HapticEvent: Sendable {
    case selection
    case lightImpact
    case mediumImpact
    case success
    case warning
    case error
}

@MainActor
final class SystemHapticsService: HapticsService {

    private let selection = UISelectionFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    init() {
        selection.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }

    func play(_ event: HapticEvent) {
        switch event {
        case .selection:
            selection.selectionChanged()
            selection.prepare()
        case .lightImpact:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .mediumImpact:
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        case .success:
            notification.notificationOccurred(.success)
            notification.prepare()
        case .warning:
            notification.notificationOccurred(.warning)
            notification.prepare()
        case .error:
            notification.notificationOccurred(.error)
            notification.prepare()
        }
    }
}

struct NoOpHapticsService: HapticsService {
    func play(_ event: HapticEvent) {}
}
