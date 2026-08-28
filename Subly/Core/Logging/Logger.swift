import Foundation
import os

protocol Logging: Sendable {
    func debug(_ message: String, category: String)
    func info(_ message: String, category: String)
    func warning(_ message: String, category: String)
    func error(_ message: String, category: String)
}

extension Logging {
    func debug(_ message: String) { debug(message, category: "app") }
    func info(_ message: String) { info(message, category: "app") }
    func warning(_ message: String) { warning(message, category: "app") }
    func error(_ message: String) { error(message, category: "app") }
}

struct ConsoleLogger: Logging {

    private let subsystem: String

    init(subsystem: String = "com.elifcagil.subly") {
        self.subsystem = subsystem
    }

    func debug(_ message: String, category: String) {
        logger(category).debug("\(message, privacy: .public)")
    }

    func info(_ message: String, category: String) {
        logger(category).info("\(message, privacy: .public)")
    }

    func warning(_ message: String, category: String) {
        logger(category).warning("\(message, privacy: .public)")
    }

    func error(_ message: String, category: String) {
        logger(category).error("\(message, privacy: .public)")
    }

    private func logger(_ category: String) -> os.Logger {
        os.Logger(subsystem: subsystem, category: category)
    }
}
