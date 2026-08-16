import Foundation

protocol UserFacingError: Error {
    var userMessage: String { get }
}

enum SubscriptionError: Error, UserFacingError {
    case notFound
    case invalidAmount
    case invalidName

    var userMessage: String {
        switch self {
        case .notFound: return "We couldn't find that subscription."
        case .invalidAmount: return "Please enter a valid amount."
        case .invalidName: return "Please enter a name."
        }
    }
}

enum StorageError: Error, UserFacingError {
    case notFound
    case writeFailed
    case readFailed

    var userMessage: String {
        switch self {
        case .notFound: return "The item could not be found."
        case .writeFailed: return "We couldn't save your changes. Please try again."
        case .readFailed: return "We couldn't load your data. Please try again."
        }
    }
}

enum NotificationError: Error, UserFacingError {
    case permissionDenied
    case schedulingFailed

    var userMessage: String {
        switch self {
        case .permissionDenied: return "Notifications are turned off for Subly. Enable them in Settings to receive renewal reminders."
        case .schedulingFailed: return "We couldn't schedule that reminder. Please try again."
        }
    }
}
