import XCTest
@testable import Subly

@MainActor
final class RecapShareRendererTests: XCTestCase {

    func testShareImageIs1080x1920() {
        let sub = Subscription(name: "Netflix", amount: 15.49, currencyCode: "USD", billingCycle: .monthly,
                               startDate: Date(timeIntervalSince1970: 0), nextRenewalDate: Date())
        let recap = Recap(
            index: 1, period: DateInterval(start: Date(), duration: 90 * 86_400), currencyCode: "USD",
            total: 74.20, subscriptionCount: 6, perDay: 0.82, monthBars: [], comparison: nil,
            topItem: Recap.TopItem(subscription: sub, paid: 46.47, share: 0.27),
            priceIncreases: [], longestRunning: Recap.LongestRunning(subscription: sub, months: 83, totalPaid: 812)
        )

        let image = RecapShareRenderer.render(recap: recap, periodLabel: "Apr–Jun", currencyFormatter: CurrencyFormatter())

        XCTAssertEqual(image.size.width * image.scale, 1080)
        XCTAssertEqual(image.size.height * image.scale, 1920)
    }
}
