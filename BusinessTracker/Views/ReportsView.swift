import SwiftUI

struct ReportsView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(
                icon: "chart.bar",
                title: "Reports",
                description: "Visualize cash flow, spending trends, and income summaries across all your data."
            )
            .navigationTitle("Reports")
        }
    }
}

#Preview { ReportsView() }
