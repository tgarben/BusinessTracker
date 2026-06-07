import SwiftUI

struct IncomeView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            PlaceholderView(
                icon: "dollarsign.circle",
                title: "Income & Tax",
                description: "Record income, project earnings, and estimate your tax obligations."
            )
            .navigationTitle("Income")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

#Preview { IncomeView() }
