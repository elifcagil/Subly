import Foundation

protocol APIClient: Sendable {
    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint<Response>) async throws -> Response
}

struct Endpoint<Response: Decodable & Sendable>: Sendable {
    let path: String
    let method: HTTPMethod
    let query: [String: String]
    let body: Data?

    init(path: String, method: HTTPMethod = .get, query: [String: String] = [:], body: Data? = nil) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
    }
}

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum NetworkError: Error, UserFacingError {
    case offline
    case invalidResponse
    case decodingFailed
    case server(status: Int)

    var userMessage: String {
        switch self {
        case .offline: return "You appear to be offline. Please check your connection."
        case .invalidResponse: return "Something went wrong. Please try again."
        case .decodingFailed: return "We couldn't read the server's response."
        case .server: return "The server is temporarily unavailable."
        }
    }
}
