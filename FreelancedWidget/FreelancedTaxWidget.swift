import SwiftUI
import WidgetKit

// MARK: - Quarterly tax due dates (mirrors SettingsView logic; widget can't import main app)

struct TaxDueDate: Identifiable {
    let id = UUID()
    let label: String
    let period: String
    let date: Date
    let isNext: Bool
}

enum QuarterlyTaxDates {
    static func upcoming(reference: Date = .now, calendar: Calendar = .current) -> [TaxDueDate] {
        let year = calendar.component(.year, from: reference)
        let specs: [(label: String, period: String, month: Int, day: Int, nextYear: Bool)] = [
            ("Q1", "Jan–Mar", 4, 15, false),
            ("Q2", "Apr–May", 6, 15, false),
            ("Q3", "Jun–Aug", 9, 15, false),
            ("Q4", "Sep–Dec", 1, 15, true),
        ]
        let dates: [Date] = specs.map { spec in
            var comps = DateComponents()
            comps.year = spec.nextYear ? year + 1 : year
            comps.month = spec.month
            comps.day = spec.day
            return calendar.date(from: comps) ?? reference
        }
        let today = calendar.startOfDay(for: reference)
        let nextIndex = dates.firstIndex { $0 >= today } ?? 0
        return specs.enumerated().map { i, spec in
            TaxDueDate(label: spec.label, period: spec.period, date: dates[i], isNext: i == nextIndex)
        }
    }
}

// MARK: - Timeline

struct TaxEntry: TimelineEntry {
    let date: Date
    let dueDates: [TaxDueDate]
}

struct TaxProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaxEntry {
        TaxEntry(date: .now, dueDates: QuarterlyTaxDates.upcoming())
    }

    func getSnapshot(in context: Context, completion: @escaping (TaxEntry) -> Void) {
        completion(TaxEntry(date: .now, dueDates: QuarterlyTaxDates.upcoming()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaxEntry>) -> Void) {
        let entry = TaxEntry(date: .now, dueDates: QuarterlyTaxDates.upcoming())
        // Refresh at the start of tomorrow so the "next due" highlight and countdown stay current.
        let nextMidnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - View

struct TaxWidgetView: View {
    let entry: TaxEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var next: TaxDueDate? { entry.dueDates.first { $0.isNext } }

    private func daysUntil(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: date).day ?? 0
    }

    var body: some View {
        if family == .systemSmall {
            smallLayout
        } else {
            mediumLayout
        }
    }

    // MARK: Small — fills the whole widget

    @ViewBuilder
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "building.columns.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Est. Tax Due")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let next {
                Text(next.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(next.date, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(next.date, format: .dateTime.year())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            if let next {
                let days = daysUntil(next.date)
                let label = days == 0 ? "Due today" : (days == 1 ? "Due tomorrow" : "in \(days) days")
                Group {
                    if renderingMode == .fullColor {
                        // Solid orange pill with white text reads well in full color.
                        Text(label)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(.orange, in: Capsule())
                    } else {
                        // Tinted / vibrant (mono) mode flattens solid fills into opaque
                        // blobs that hide the text — use a translucent pill so the label
                        // stays legible against the monochrome tint.
                        Text(label)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(.secondary.opacity(0.25), in: Capsule())
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium — all four quarters

    @ViewBuilder
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("Estimated Tax Due")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let next {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(next.date, format: .dateTime.month(.abbreviated).day())
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                    Text(next.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    let days = daysUntil(next.date)
                    Text(days == 0 ? "Today" : "\(days)d")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
            }

            Divider()
            ForEach(entry.dueDates) { due in
                HStack(spacing: 6) {
                    Circle()
                        .fill(due.isNext ? Color.orange : Color.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text(due.label).font(.caption2.weight(.medium))
                    Text(due.period).font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text(due.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(due.isNext ? .orange : .secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Widget

struct FreelancedTaxWidget: Widget {
    let kind = "FreelancedTaxWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaxProvider()) { entry in
            TaxWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tax Due Dates")
        .description("Quarterly IRS estimated tax deadlines, with the next one highlighted.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Tax", as: .systemMedium) {
    FreelancedTaxWidget()
} timeline: {
    TaxEntry(date: .now, dueDates: QuarterlyTaxDates.upcoming())
}
