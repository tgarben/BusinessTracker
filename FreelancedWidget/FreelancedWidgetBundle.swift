import WidgetKit
import SwiftUI

@main
struct FreelancedWidgetBundle: WidgetBundle {
    var body: some Widget {
        FreelancedSmallWidget()
        FreelancedMediumWidget()
        FreelancedTaxWidget()
        FreelancedLiveActivity()
    }
}
