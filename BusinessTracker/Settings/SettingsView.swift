import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("mileage_ratePerMile") private var mileageRate: Double = MileageTrip.defaultRatePerMile
    @AppStorage("default_hourlyRate") private var defaultHourlyRate: Double = 0
    @AppStorage("report_mpg") private var mpg: Double = 30.0
    @AppStorage("report_gasPrice") private var gasPrice: Double = 3.80
    @AppStorage("tax_selfEmploymentRate") private var selfEmploymentRate: Double = 15.3
    @AppStorage("tax_incomeBracketRate") private var incomeBracketRate: Double = 22.0
    @AppStorage("tax_businessStructure") private var businessStructure: String = "Sole Proprietor"

    @State private var showClients = false

    private let businessStructures = [
        "Sole Proprietor", "Single-Member LLC", "Multi-Member LLC",
        "S-Corp", "C-Corp", "Partnership"
    ]

    var body: some View {
        NavigationStack {
            List {

                // MARK: Business
                Section("Business") {
                    Button {
                        showClients = true
                    } label: {
                        HStack {
                            SettingsIcon(symbol: "person.2.fill", color: .indigo)
                            Text("Clients & Projects")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // MARK: Rates & Defaults
                Section {
                    LabeledContent {
                        TextField("0.000", value: $mileageRate, format: .number.precision(.fractionLength(3)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "car.fill", color: .blue)
                            Text("IRS Mileage Rate")
                        }
                    }

                    LabeledContent {
                        TextField("0.00", value: $defaultHourlyRate, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "clock.fill", color: .indigo)
                            Text("Default Hourly Rate")
                        }
                    }
                } header: {
                    Text("Rates & Defaults")
                } footer: {
                    Text("Mileage rate defaults to the current IRS standard ($\(String(format: "%.2f", MileageTrip.defaultRatePerMile))/mi). Update each January.")
                }

                // MARK: Fuel
                Section {
                    LabeledContent {
                        TextField("30", value: $mpg, format: .number.precision(.fractionLength(0)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "fuelpump.fill", color: .orange)
                            Text("Vehicle MPG")
                        }
                    }

                    LabeledContent {
                        TextField("3.80", value: $gasPrice, format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "dollarsign.circle.fill", color: .orange)
                            Text("Gas Price / Gallon")
                        }
                    }
                } header: {
                    Text("Fuel")
                } footer: {
                    Text("Used in Reports to estimate fuel cost vs. mileage reimbursement.")
                }

                // MARK: Tax Information
                Section {
                    // Business structure — full-width picker via LabeledContent
                    LabeledContent {
                        Picker("", selection: $businessStructure) {
                            ForEach(businessStructures, id: \.self) { Text($0) }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "building.columns.fill", color: .green)
                            Text("Structure")
                        }
                    }

                    LabeledContent {
                        HStack(spacing: 4) {
                            TextField("15.3", value: $selfEmploymentRate, format: .number.precision(.fractionLength(1)))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 56)
                            Text("%").foregroundStyle(.secondary)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "percent", color: .green)
                            Text("SE Tax Rate")
                        }
                    }

                    LabeledContent {
                        HStack(spacing: 4) {
                            TextField("22", value: $incomeBracketRate, format: .number.precision(.fractionLength(1)))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 56)
                            Text("%").foregroundStyle(.secondary)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: "chart.line.uptrend.xyaxis", color: .green)
                            Text("Income Bracket")
                        }
                    }
                } header: {
                    Text("Tax Information")
                } footer: {
                    Text("Used in Reports to estimate your quarterly tax liability. These are estimates — consult a tax professional for advice.")
                }

                // MARK: App
                Section("App") {
                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "dollarsign", color: .gray)
                        Text("Currency")
                        Spacer()
                        Text("USD").foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        SettingsIcon(symbol: "info.circle.fill", color: .gray)
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Settings")
            .sheet(isPresented: $showClients) {
                ClientListView()
            }
        }
    }
}

// MARK: - Settings icon helper

struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: RoundedRectangle(cornerRadius: 7))
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Client.self, Project.self], inMemory: true)
}
