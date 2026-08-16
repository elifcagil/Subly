import Foundation

protocol CategoryRepository: Sendable {
    func fetchAll() async throws -> [Category]
    func category(with id: UUID) async throws -> Category
}

struct InMemoryCategoryRepository: CategoryRepository {

    private let categories: [Category]

    init(categories: [Category] = Category.defaults) {
        self.categories = categories
    }

    func fetchAll() async throws -> [Category] { categories }

    func category(with id: UUID) async throws -> Category {
        guard let value = categories.first(where: { $0.id == id }) else {
            throw StorageError.notFound
        }
        return value
    }
}
