import UIKit

/// Feeds the Recap cards to the shared `StoryViewController`.
@MainActor
final class RecapStoryContent: StoryContent {

    private let viewModel: RecapViewModel
    private let haptics: HapticsService

    init(viewModel: RecapViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
    }

    var player: StoryPlayer { viewModel.player }
    var headerTitle: String { Strings.Recap.header(period: viewModel.periodLabel) }

    func palette(at index: Int, theme: StoryIntroTheme) -> RecapPalette {
        RecapPalette.palette(for: viewModel.cards[index], theme: theme)
    }

    func hint(at index: Int) -> String? {
        viewModel.cards[index] == .summary ? nil : Strings.Recap.tapToContinue
    }

    func makeCard(at index: Int, palette: RecapPalette) -> StoryCardView {
        switch viewModel.cards[index] {
        case .total:
            return RecapTotalCardView(viewModel: viewModel, palette: palette)
        case .mostExpensive:
            return RecapMostExpensiveCardView(viewModel: viewModel, palette: palette)
        case .priceIncreases:
            let view = RecapPriceIncreasesCardView(viewModel: viewModel, palette: palette)
            view.onReview = { [weak self] in
                self?.haptics.play(.lightImpact)
                self?.viewModel.reviewSubscriptions()
            }
            return view
        case .longestRunning:
            return RecapLongestRunningCardView(viewModel: viewModel, palette: palette)
        case .summary:
            let view = RecapSummaryCardView(viewModel: viewModel, palette: palette)
            view.onShare = { [weak self] in
                self?.haptics.play(.lightImpact)
                self?.viewModel.share()
            }
            view.onDone = { [weak self] in
                self?.haptics.play(.lightImpact)
                self?.viewModel.finish()
            }
            return view
        }
    }

    func close() {
        viewModel.close()
    }
}
