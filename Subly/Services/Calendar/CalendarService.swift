import Foundation
@preconcurrency import EventKit

protocol CalendarService: Sendable {
    func authorizationStatus() -> CalendarAuthorizationStatus
    func requestAccess() async throws -> Bool
    func export(_ subscription: Subscription) async throws -> String
    func remove(eventIdentifier: String) async throws
}

enum CalendarAuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case authorized
    case unsupported
}

enum CalendarServiceError: Error, UserFacingError {
    case accessDenied
    case eventNotFound
    case saveFailed

    var userMessage: String {
        switch self {
        case .accessDenied: return "Subly needs calendar access. Enable it in Settings to export renewals."
        case .eventNotFound: return "We couldn't find that calendar event."
        case .saveFailed: return "We couldn't save the event to your calendar."
        }
    }
}

struct EventKitCalendarService: CalendarService {

    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func authorizationStatus() -> CalendarAuthorizationStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess: return .authorized
        case .denied, .restricted, .writeOnly: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .unsupported
        }
    }

    func requestAccess() async throws -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            throw CalendarServiceError.accessDenied
        }
    }

    func export(_ subscription: Subscription) async throws -> String {
        guard authorizationStatus() == .authorized else {
            throw CalendarServiceError.accessDenied
        }

        let event = EKEvent(eventStore: store)
        event.title = "\(subscription.name) renews"
        event.startDate = subscription.nextRenewalDate
        event.endDate = subscription.nextRenewalDate.addingTimeInterval(3600)
        event.isAllDay = true
        event.calendar = store.defaultCalendarForNewEvents
        event.notes = "Subly · \(subscription.billingCycle.displayName)"

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            throw CalendarServiceError.saveFailed
        }
    }

    func remove(eventIdentifier: String) async throws {
        guard let event = store.event(withIdentifier: eventIdentifier) else {
            throw CalendarServiceError.eventNotFound
        }
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            throw CalendarServiceError.saveFailed
        }
    }
}

struct NoOpCalendarService: CalendarService {
    func authorizationStatus() -> CalendarAuthorizationStatus { .unsupported }
    func requestAccess() async throws -> Bool { false }
    func export(_ subscription: Subscription) async throws -> String { "" }
    func remove(eventIdentifier: String) async throws {}
}
