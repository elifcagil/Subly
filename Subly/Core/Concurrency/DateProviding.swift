import Foundation

protocol DateProviding: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
    var calendar: Calendar { .current }
}
