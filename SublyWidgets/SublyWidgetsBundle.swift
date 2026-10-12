import WidgetKit
import SwiftUI

@main
struct SublyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RenewalRingWidget()
        LockScreenRingWidget()
        UpcomingRenewalsWidget()
        MonthlyTotalWidget()
    }
}
