import SwiftUI

struct MileageView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(
                icon: "car",
                title: "Mileage",
                description: "Log business trips, track miles, and calculate tax deductions automatically."
            )
            .navigationTitle("Mileage")
        }
    }
}

#Preview { MileageView() }
