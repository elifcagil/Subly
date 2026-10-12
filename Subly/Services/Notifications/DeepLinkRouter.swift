import Foundation

/// Where `subly://` links and notification taps land.
///
/// - `subly://subscription/<uuid>` → Subscription Detail
/// - `subly://add` → the Add flow
///
/// Created before any scene exists (AppDelegate / widget launch), so a link
/// that starts the app is parked until `TabBarCoordinator` installs the
/// handlers.
@MainActor
final class DeepLinkRouter {

    enum Link: Equatable {
        case subscription(UUID)
        case add
        /// `subly://recap` (latest) or `subly://recap/<n>`.
        case recap(index: Int?)
    }

    static let shared = DeepLinkRouter()
    static let scheme = "subly"

    var onOpenSubscription: ((UUID) -> Void)? { didSet { flush() } }
    var onAddSubscription: (() -> Void)? { didSet { flush() } }
    var onOpenRecap: ((Int?) -> Void)? { didSet { flush() } }

    private var pending: Link?

    static func link(from url: URL) -> Link? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let parts = ([url.host] + url.pathComponents).compactMap { $0 }.filter { $0 != "/" }
        switch parts.first?.lowercased() {
        case "subscription":
            return parts.dropFirst().first.flatMap(UUID.init(uuidString:)).map(Link.subscription)
        case "add":
            return .add
        case "recap":
            return .recap(index: parts.dropFirst().first.flatMap { Int($0) })
        default:
            return nil
        }
    }

    func open(_ url: URL) {
        guard let link = Self.link(from: url) else { return }
        open(link)
    }

    func open(_ link: Link) {
        switch link {
        case .subscription(let id):
            if let onOpenSubscription { onOpenSubscription(id) } else { pending = link }
        case .add:
            if let onAddSubscription { onAddSubscription() } else { pending = link }
        case .recap(let index):
            if let onOpenRecap { onOpenRecap(index) } else { pending = link }
        }
    }

    private func flush() {
        guard let link = pending else { return }
        switch link {
        case .subscription where onOpenSubscription != nil, .add where onAddSubscription != nil,
             .recap where onOpenRecap != nil:
            pending = nil
            open(link)
        default:
            break
        }
    }
}
