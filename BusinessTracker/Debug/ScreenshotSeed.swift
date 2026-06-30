import Foundation
import SwiftData

#if DEBUG
/// Seeds the app with realistic sample data for App Store screenshots / demos.
///
/// Runs **only** on the iOS Simulator, in DEBUG builds, and **only** when the app is
/// launched with the `--seed-screenshots` argument (Scheme → Run → Arguments, or
/// `xcrun simctl launch … --seed-screenshots`). It never runs in normal use, never in
/// release builds, and the simulator guard means it can't touch a real iCloud-backed
/// store on a device. Each run wipes the simulator's local store and rebuilds a fixed
/// dataset so screenshots are deterministic.
enum ScreenshotSeed {
    static let launchArg = "--seed-screenshots"

    @MainActor
    static func runIfRequested(container: ModelContainer) {
        #if targetEnvironment(simulator)
        guard CommandLine.arguments.contains(launchArg) else { return }
        seedSettings()
        seedModels(container)
        seedRunningTimer()
        #endif
    }

    #if targetEnvironment(simulator)
    // MARK: - Settings / profile / business

    private static func seedSettings() {
        let d = UserDefaults.standard
        d.set(true, forKey: "hasCompletedOnboarding")
        d.set("Jack", forKey: "user_name")
        d.set("Rivera", forKey: "user_lastName")
        d.set("Time Tracking,Mileage,Expenses,Invoicing", forKey: "user_primaryUse")

        d.set("Rivera Design Co.", forKey: "business_name")
        d.set("742 Mill Ave, Suite 210", forKey: "business_address")
        d.set("Tempe, AZ 85281", forKey: "business_address2")
        d.set("(480) 555-0142", forKey: "business_phone")
        d.set("jack@riveradesign.co", forKey: "business_email")
        d.set("riveradesign.co", forKey: "business_website")
        d.set("47-1832910", forKey: "business_taxID")
        d.set(8.6, forKey: "business_defaultTaxRate")
        d.set("Net 30", forKey: "business_defaultPaymentTerms")
        d.set("Bank transfer, Check, Card", forKey: "business_acceptedPayments")

        d.set(0.70, forKey: "mileage_ratePerMile")
        d.set(85.0, forKey: "default_hourlyRate")
        d.set(28.0, forKey: "report_mpg")
        d.set(3.85, forKey: "report_gasPrice")
        d.set("USD", forKey: "app_currencyCode")
    }

    // MARK: - Model data

    private static func seedModels(_ container: ModelContainer) {
        let ctx = ModelContext(container)
        wipe(ctx)

        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: .now) ?? .now }
        func hoursAgo(_ n: Int) -> Date { cal.date(byAdding: .hour, value: -n, to: .now) ?? .now }

        // Clients + projects
        let clancy = Client(name: "Clancy Brothers")
        clancy.companyName = "Clancy Brothers Brewing"
        clancy.billingAddress = "1100 Grand Ave"
        clancy.billingAddress2 = "Phoenix, AZ 85007"
        clancy.email = "ap@clancybros.com"
        clancy.phone = "(602) 555-0190"
        let clancyWeb = Project(name: "Website Redesign", hourlyRate: 85, client: clancy)
        let clancyBrand = Project(name: "Brand Identity", hourlyRate: 95, client: clancy)

        let summit = Client(name: "Summit Cafe")
        summit.companyName = "Summit Cafe LLC"
        summit.email = "owner@summitcafe.com"
        let summitMenu = Project(name: "Menu Design", hourlyRate: 75, client: summit)

        let northgate = Client(name: "Northgate Realty")
        northgate.email = "marketing@northgate.com"
        let northgatePhotos = Project(name: "Listing Photos", hourlyRate: 120, client: northgate)

        [clancy, summit, northgate].forEach { ctx.insert($0) }
        [clancyWeb, clancyBrand, summitMenu, northgatePhotos].forEach { ctx.insert($0) }

        // Time entries — spread across this week (some today)
        let times: [(Date, Client, Project, Double, String)] = [
            (hoursAgo(3),  clancy, clancyWeb,   3.5, "Homepage layout + hero section"),
            (daysAgo(1),   clancy, clancyWeb,   5.0, "Responsive breakpoints"),
            (daysAgo(1),   summit, summitMenu,  2.5, "Dinner menu typesetting"),
            (daysAgo(2),   northgate, northgatePhotos, 4.0, "Downtown listing shoot"),
            (daysAgo(3),   clancy, clancyBrand, 3.0, "Logo concepts round 2"),
            (daysAgo(4),   summit, summitMenu,  2.0, "Brunch menu revisions"),
        ]
        for (date, client, project, hours, notes) in times {
            ctx.insert(TimeEntry(date: date, client: client, project: project,
                                 hours: hours, hourlyRate: project.hourlyRate, notes: notes))
        }

        // Mileage trips
        func trip(_ date: Date, _ purpose: String, _ from: String, _ to: String, _ miles: Double, _ client: Client?) -> MileageTrip {
            let t = MileageTrip(date: date, startLocation: from, endLocation: to, miles: miles, purpose: purpose)
            t.startAddress = from; t.endAddress = to; t.client = client
            return t
        }
        ctx.insert(trip(hoursAgo(5), "Client Visit", "Office, Tempe AZ", "Clancy Brothers, Phoenix AZ", 12.4, clancy))
        ctx.insert(trip(daysAgo(2),  "Photo Shoot", "Office, Tempe AZ", "Downtown Phoenix, AZ", 18.2, northgate))
        ctx.insert(trip(daysAgo(3),  "Errand",      "Office, Tempe AZ", "Print Shop, Mesa AZ", 9.1, nil))
        ctx.insert(trip(daysAgo(5),  "Client Visit", "Office, Tempe AZ", "Summit Cafe, Scottsdale AZ", 14.7, summit))

        // Expenses
        func exp(_ date: Date, _ amount: Double, _ category: String, _ notes: String, _ client: Client? = nil) {
            ctx.insert(Expense(date: date, amount: amount, category: category, notes: notes, client: client))
        }
        exp(hoursAgo(6), 59.99, "Software", "Adobe Creative Cloud", clancy)
        exp(daysAgo(1),  42.50, "Supplies", "Print paper + ink")
        exp(daysAgo(2),  18.75, "Meals", "Client lunch — Summit", summit)
        exp(daysAgo(3),  120.00, "Equipment", "Lighting softbox", northgate)
        exp(daysAgo(6),  14.20, "Travel", "Parking — downtown")

        // Income
        ctx.insert(IncomeEntry(date: daysAgo(4), source: "Invoice Payment", amount: 1700, notes: "INV-001 deposit", client: clancy))
        ctx.insert(IncomeEntry(date: daysAgo(8), source: "Retainer", amount: 900, notes: "Monthly retainer", client: summit))

        // Invoice — issued, partially due (shows in lists + overdue logic off)
        let inv = Invoice(invoiceNumber: 1, issueDate: daysAgo(10),
                          dueDate: daysAgo(-20), client: clancy,
                          notes: "Thank you for your business!")
        inv.taxRate = 8.6
        inv.paymentTerms = "Net 30"
        inv.acceptedPayments = "Bank transfer, Check, Card"
        ctx.insert(inv)
        ctx.insert(InvoiceLineItem(itemDescription: "Website redesign — design phase", quantity: 24, unitPrice: 85, sortOrder: 0, invoice: inv))
        ctx.insert(InvoiceLineItem(itemDescription: "Stock photography license", quantity: 1, unitPrice: 180, sortOrder: 1, invoice: inv))

        // An overdue invoice so the Home overdue card shows
        let inv2 = Invoice(invoiceNumber: 2, issueDate: daysAgo(45),
                           dueDate: daysAgo(15), client: northgate,
                           notes: "")
        inv2.taxRate = 8.6
        ctx.insert(inv2)
        ctx.insert(InvoiceLineItem(itemDescription: "Listing photo package (12 homes)", quantity: 12, unitPrice: 120, sortOrder: 0, invoice: inv2))

        // Quote — sent, awaiting acceptance
        let quote = Quote(quoteNumber: 1, issueDate: daysAgo(3),
                          validUntil: daysAgo(-25), client: summit,
                          notes: "Valid for 30 days.")
        quote.status = QuoteStatus.sent.rawValue
        quote.taxRate = 8.6
        ctx.insert(quote)
        ctx.insert(QuoteLineItem(itemDescription: "Full menu redesign (4 menus)", quantity: 4, unitPrice: 450, sortOrder: 0, quote: quote))
        ctx.insert(QuoteLineItem(itemDescription: "Print-ready export + proofs", quantity: 1, unitPrice: 200, sortOrder: 1, quote: quote))

        try? ctx.save()
    }

    private static func wipe(_ ctx: ModelContext) {
        try? ctx.delete(model: TimeEntry.self)
        try? ctx.delete(model: MileageTrip.self)
        try? ctx.delete(model: Expense.self)
        try? ctx.delete(model: IncomeEntry.self)
        try? ctx.delete(model: InvoiceLineItem.self)
        try? ctx.delete(model: Invoice.self)
        try? ctx.delete(model: QuoteLineItem.self)
        try? ctx.delete(model: Quote.self)
        try? ctx.delete(model: Project.self)
        try? ctx.delete(model: Client.self)
        try? ctx.save()
    }

    // MARK: - Running timer (so the Home active-timer card shows)

    private static func seedRunningTimer() {
        guard let shared = UserDefaults(suiteName: "group.com.garbenTechnologies.BusinessTracker") else { return }
        let startedAgo = Date().addingTimeInterval(-(60 * 84 + 36)) // 1:24:36
        shared.set(startedAgo.timeIntervalSince1970, forKey: "timerRunningSince")
        shared.set(0.0, forKey: "timerAccumulated")
        shared.set(false, forKey: "timerPaused")
    }
    #endif
}
#endif
