import Foundation

enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(message: String)
}

extension ViewState: Equatable where Value: Equatable {}
extension ViewState: Sendable where Value: Sendable {}
