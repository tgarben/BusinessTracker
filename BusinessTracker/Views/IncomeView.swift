import SwiftUI

struct IncomeView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(
                icon: "dollarsign.circle",
                title: "Income & Tax",
                description: "Record income, project earnings, and estimate your tax obligations."
            )
            .navigationTitle("Income")
        }
    }
}

#Preview { IncomeView() }
