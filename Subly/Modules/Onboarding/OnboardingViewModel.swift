import Foundation

/// v5 Onboarding (screen 01): a single calm screen — logo, headline, subcopy
/// and one primary action. "Explore with sample data" seeds the fixture set
/// before entering the app.
@MainActor
final class OnboardingViewModel {

    enum Outcome {
        /// User chose "Add your first subscription" — open the Add flow.
        case addFirst
        /// User chose "Explore with sample data" — fixtures already seeded.
        case sampleData
    }

    private let sampleDataSeeder: SampleDataSeeding
    private var isSeeding = false

    var onCompleted: ((Outcome) -> Void)?

    init(sampleDataSeeder: SampleDataSeeding) {
        self.sampleDataSeeder = sampleDataSeeder
    }

    func didTapAddFirst() {
        onCompleted?(.addFirst)
    }

    func didTapSampleData() {
        guard !isSeeding else { return }
        isSeeding = true
        Task { [weak self] in
            guard let self else { return }
            await sampleDataSeeder.seedIfEmpty()
            self.isSeeding = false
            self.onCompleted?(.sampleData)
        }
    }
}
