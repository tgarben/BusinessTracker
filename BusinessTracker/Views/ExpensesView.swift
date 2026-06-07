import SwiftUI

struct ExpensesView: View {
    var body: some View {
        NavigationStack {
            PlaceholderView(
                icon: "creditcard",
                title: "Expenses",
                description: "Track and categorize business expenses, upload receipts, and monitor spending."
            )
            .navigationTitle("Expenses")
        }
    }
}

#Preview { ExpensesView() }
