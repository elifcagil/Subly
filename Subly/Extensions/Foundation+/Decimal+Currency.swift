import Foundation

extension Decimal {
    var asPlainDouble: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
