import WidgetKit
import SwiftUI

@main
struct SublyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MonthlyTotalWidget()
        UpcomingRenewalsWidget()
    }
}
