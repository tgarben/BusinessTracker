import Foundation
import SwiftData

/// Full-fidelity JSON backup of every record (and synced settings), so a user can
/// export a complete copy to Files/email and re-import it on a fresh install "in a
/// pinch". Relationships are preserved via export-scoped UUIDs (the SwiftData
/// `persistentModelID` isn't portable across stores). **Import is additive** — it
/// inserts the backed-up records alongside whatever's already there.
enum DataBackup {

    static let fileVersion = 1

    // MARK: - Settings value (typed, for the synced @AppStorage keys)

    enum SettingValue: Codable {
        case string(String), double(Double), bool(Bool), data(Data)

        private enum CodingKeys: String, CodingKey { case type, value }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .string(let v): try c.encode("string", forKey: .type); try c.encode(v, forKey: .value)
            case .double(let v): try c.encode("double", forKey: .type); try c.encode(v, forKey: .value)
            case .bool(let v):   try c.encode("bool", forKey: .type);   try c.encode(v, forKey: .value)
            case .data(let v):   try c.encode("data", forKey: .type);   try c.encode(v, forKey: .value)
            }
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(String.self, forKey: .type) {
            case "string": self = .string(try c.decode(String.self, forKey: .value))
            case "double": self = .double(try c.decode(Double.self, forKey: .value))
            case "bool":   self = .bool(try c.decode(Bool.self, forKey: .value))
            case "data":   self = .data(try c.decode(Data.self, forKey: .value))
            default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown setting type")
            }
        }
    }

    // MARK: - DTOs

    struct ClientDTO: Codable { var id: UUID; var name = ""; var photoData: Data?; var deletedDate: Date?; var companyName = ""; var billingAddress = ""; var billingAddress2 = ""; var email = ""; var phone = "" }
    struct ProjectDTO: Codable { var id: UUID; var name = ""; var hourlyRate = 0.0; var clientId: UUID? }
    struct TimeEntryDTO: Codable { var id: UUID; var date = Date.now; var hours = 0.0; var hourlyRate = 0.0; var notes = ""; var deletedDate: Date?; var clientId: UUID?; var projectId: UUID?; var invoiceId: UUID? }
    struct MileageTripDTO: Codable { var id: UUID; var date = Date.now; var startLocation = ""; var endLocation = ""; var miles = 0.0; var purpose = ""; var notes = ""; var waypoints: [String] = []; var startAddress = ""; var endAddress = ""; var deletedDate: Date?; var clientId: UUID? }
    struct ExpenseDTO: Codable { var id: UUID; var date = Date.now; var amount = 0.0; var category = ""; var notes = ""; var receiptImageData: Data?; var receiptImagesData: [Data] = []; var deletedDate: Date?; var clientId: UUID? }
    struct IncomeEntryDTO: Codable { var id: UUID; var date = Date.now; var source = ""; var amount = 0.0; var notes = ""; var deletedDate: Date?; var clientId: UUID? }
    struct InvoiceDTO: Codable { var id: UUID; var invoiceNumber = 0; var issueDate = Date.now; var dueDate = Date.now; var notes = ""; var isPaid = false; var paidDate: Date?; var additionalAmount = 0.0; var additionalDescription = ""; var deletedDate: Date?; var discountAmount = 0.0; var discountIsPercent = false; var taxRate = 0.0; var paymentTerms = ""; var paymentInstructions = ""; var acceptedPayments = ""; var poNumber = ""; var includeTaxID: Bool? = true; var clientId: UUID? }
    struct InvoiceLineItemDTO: Codable { var id: UUID; var itemDescription = ""; var quantity = 1.0; var unitPrice = 0.0; var sortOrder = 0; var invoiceId: UUID? }
    struct QuoteDTO: Codable { var id: UUID; var quoteNumber = 0; var issueDate = Date.now; var validUntil = Date.now; var notes = ""; var status = "Draft"; var convertedInvoiceNumber = 0; var deletedDate: Date?; var discountAmount = 0.0; var discountIsPercent = false; var taxRate = 0.0; var paymentTerms = ""; var paymentInstructions = ""; var acceptedPayments = ""; var poNumber = ""; var includeTaxID: Bool? = true; var clientId: UUID? }
    struct QuoteLineItemDTO: Codable { var id: UUID; var itemDescription = ""; var quantity = 1.0; var unitPrice = 0.0; var sortOrder = 0; var quoteId: UUID? }
    struct TimePresetDTO: Codable { var id: UUID; var name = ""; var sortOrder = 0; var hourlyRateOverride: Double?; var notesTemplate = ""; var clientId: UUID?; var projectId: UUID? }
    struct MileagePresetDTO: Codable { var id: UUID; var name = ""; var startLocation = ""; var endLocation = ""; var purpose = ""; var notes = ""; var sortOrder = 0; var clientId: UUID? }
    struct ExpensePresetDTO: Codable { var id: UUID; var name = ""; var amount: Double?; var category = ""; var notes = ""; var sortOrder = 0; var instantLog = false }

    struct BackupFile: Codable {
        var version = DataBackup.fileVersion
        var exportedAt = Date.now
        var settings: [String: SettingValue] = [:]
        var clients: [ClientDTO] = []
        var projects: [ProjectDTO] = []
        var timeEntries: [TimeEntryDTO] = []
        var mileageTrips: [MileageTripDTO] = []
        var expenses: [ExpenseDTO] = []
        var incomeEntries: [IncomeEntryDTO] = []
        var invoices: [InvoiceDTO] = []
        var invoiceLineItems: [InvoiceLineItemDTO] = []
        var quotes: [QuoteDTO] = []
        var quoteLineItems: [QuoteLineItemDTO] = []
        var timePresets: [TimePresetDTO] = []
        var mileagePresets: [MileagePresetDTO] = []
        var expensePresets: [ExpensePresetDTO] = []
    }

    // MARK: - Export

    @MainActor
    static func export(context: ModelContext) throws -> Data {
        func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }
        let clients = fetchAll(Client.self)
        let projects = fetchAll(Project.self)
        let timeEntries = fetchAll(TimeEntry.self)
        let trips = fetchAll(MileageTrip.self)
        let expenses = fetchAll(Expense.self)
        let income = fetchAll(IncomeEntry.self)
        let invoices = fetchAll(Invoice.self)
        let invoiceItems = fetchAll(InvoiceLineItem.self)
        let quotes = fetchAll(Quote.self)
        let quoteItems = fetchAll(QuoteLineItem.self)
        let timePresets = fetchAll(TimePreset.self)
        let mileagePresets = fetchAll(MileagePreset.self)
        let expensePresets = fetchAll(ExpensePreset.self)

        // Assign an export UUID to every record for cross-referencing.
        var ids: [PersistentIdentifier: UUID] = [:]
        for m in clients { ids[m.persistentModelID] = UUID() }
        for m in projects { ids[m.persistentModelID] = UUID() }
        for m in timeEntries { ids[m.persistentModelID] = UUID() }
        for m in trips { ids[m.persistentModelID] = UUID() }
        for m in expenses { ids[m.persistentModelID] = UUID() }
        for m in income { ids[m.persistentModelID] = UUID() }
        for m in invoices { ids[m.persistentModelID] = UUID() }
        for m in invoiceItems { ids[m.persistentModelID] = UUID() }
        for m in quotes { ids[m.persistentModelID] = UUID() }
        for m in quoteItems { ids[m.persistentModelID] = UUID() }
        for m in timePresets { ids[m.persistentModelID] = UUID() }
        for m in mileagePresets { ids[m.persistentModelID] = UUID() }
        for m in expensePresets { ids[m.persistentModelID] = UUID() }

        func ref(_ model: (any PersistentModel)?) -> UUID? {
            guard let model else { return nil }
            return ids[model.persistentModelID]
        }
        func selfID(_ model: any PersistentModel) -> UUID { ids[model.persistentModelID] ?? UUID() }

        var file = BackupFile()
        file.settings = exportSettings()
        file.clients = clients.map { ClientDTO(id: selfID($0), name: $0.name, photoData: $0.photoData, deletedDate: $0.deletedDate, companyName: $0.companyName, billingAddress: $0.billingAddress, billingAddress2: $0.billingAddress2, email: $0.email, phone: $0.phone) }
        file.projects = projects.map { ProjectDTO(id: selfID($0), name: $0.name, hourlyRate: $0.hourlyRate, clientId: ref($0.client)) }
        file.timeEntries = timeEntries.map { TimeEntryDTO(id: selfID($0), date: $0.date, hours: $0.hours, hourlyRate: $0.hourlyRate, notes: $0.notes, deletedDate: $0.deletedDate, clientId: ref($0.client), projectId: ref($0.project), invoiceId: ref($0.invoice)) }
        file.mileageTrips = trips.map { MileageTripDTO(id: selfID($0), date: $0.date, startLocation: $0.startLocation, endLocation: $0.endLocation, miles: $0.miles, purpose: $0.purpose, notes: $0.notes, waypoints: $0.waypoints, startAddress: $0.startAddress, endAddress: $0.endAddress, deletedDate: $0.deletedDate, clientId: ref($0.client)) }
        file.expenses = expenses.map { ExpenseDTO(id: selfID($0), date: $0.date, amount: $0.amount, category: $0.category, notes: $0.notes, receiptImageData: $0.receiptImageData, receiptImagesData: $0.receiptImagesData, deletedDate: $0.deletedDate, clientId: ref($0.client)) }
        file.incomeEntries = income.map { IncomeEntryDTO(id: selfID($0), date: $0.date, source: $0.source, amount: $0.amount, notes: $0.notes, deletedDate: $0.deletedDate, clientId: ref($0.client)) }
        file.invoices = invoices.map { InvoiceDTO(id: selfID($0), invoiceNumber: $0.invoiceNumber, issueDate: $0.issueDate, dueDate: $0.dueDate, notes: $0.notes, isPaid: $0.isPaid, paidDate: $0.paidDate, additionalAmount: $0.additionalAmount, additionalDescription: $0.additionalDescription, deletedDate: $0.deletedDate, discountAmount: $0.discountAmount, discountIsPercent: $0.discountIsPercent, taxRate: $0.taxRate, paymentTerms: $0.paymentTerms, paymentInstructions: $0.paymentInstructions, acceptedPayments: $0.acceptedPayments, poNumber: $0.poNumber, includeTaxID: $0.includeTaxID, clientId: ref($0.client)) }
        file.invoiceLineItems = invoiceItems.map { InvoiceLineItemDTO(id: selfID($0), itemDescription: $0.itemDescription, quantity: $0.quantity, unitPrice: $0.unitPrice, sortOrder: $0.sortOrder, invoiceId: ref($0.invoice)) }
        file.quotes = quotes.map { QuoteDTO(id: selfID($0), quoteNumber: $0.quoteNumber, issueDate: $0.issueDate, validUntil: $0.validUntil, notes: $0.notes, status: $0.status, convertedInvoiceNumber: $0.convertedInvoiceNumber, deletedDate: $0.deletedDate, discountAmount: $0.discountAmount, discountIsPercent: $0.discountIsPercent, taxRate: $0.taxRate, paymentTerms: $0.paymentTerms, paymentInstructions: $0.paymentInstructions, acceptedPayments: $0.acceptedPayments, poNumber: $0.poNumber, includeTaxID: $0.includeTaxID, clientId: ref($0.client)) }
        file.quoteLineItems = quoteItems.map { QuoteLineItemDTO(id: selfID($0), itemDescription: $0.itemDescription, quantity: $0.quantity, unitPrice: $0.unitPrice, sortOrder: $0.sortOrder, quoteId: ref($0.quote)) }
        file.timePresets = timePresets.map { TimePresetDTO(id: selfID($0), name: $0.name, sortOrder: $0.sortOrder, hourlyRateOverride: $0.hourlyRateOverride, notesTemplate: $0.notesTemplate, clientId: ref($0.client), projectId: ref($0.project)) }
        file.mileagePresets = mileagePresets.map { MileagePresetDTO(id: selfID($0), name: $0.name, startLocation: $0.startLocation, endLocation: $0.endLocation, purpose: $0.purpose, notes: $0.notes, sortOrder: $0.sortOrder, clientId: ref($0.client)) }
        file.expensePresets = expensePresets.map { ExpensePresetDTO(id: selfID($0), name: $0.name, amount: $0.amount, category: $0.category, notes: $0.notes, sortOrder: $0.sortOrder, instantLog: $0.instantLog) }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    private static func exportSettings() -> [String: SettingValue] {
        var out: [String: SettingValue] = [:]
        for key in CloudKeyValueSync.syncedKeys {
            guard let obj = UserDefaults.standard.object(forKey: key) else { continue }
            if let d = obj as? Data { out[key] = .data(d) }
            else if let s = obj as? String { out[key] = .string(s) }
            else if let num = obj as? NSNumber {
                out[key] = CFGetTypeID(num) == CFBooleanGetTypeID() ? .bool(num.boolValue) : .double(num.doubleValue)
            }
        }
        return out
    }

    // MARK: - Import (additive)

    /// Inserts every record from the backup. Returns the number of records added.
    @MainActor
    @discardableResult
    static func importBackup(_ data: Data, into context: ModelContext, restoreSettings: Bool = true) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)

        if restoreSettings {
            for (key, value) in file.settings {
                switch value {
                case .string(let v): UserDefaults.standard.set(v, forKey: key)
                case .double(let v): UserDefaults.standard.set(v, forKey: key)
                case .bool(let v):   UserDefaults.standard.set(v, forKey: key)
                case .data(let v):   UserDefaults.standard.set(v, forKey: key)
                }
            }
        }

        var count = 0
        var clientByID: [UUID: Client] = [:]
        var projectByID: [UUID: Project] = [:]
        var invoiceByID: [UUID: Invoice] = [:]
        var quoteByID: [UUID: Quote] = [:]

        for dto in file.clients {
            let c = Client(name: dto.name)
            c.photoData = dto.photoData; c.deletedDate = dto.deletedDate
            c.companyName = dto.companyName; c.billingAddress = dto.billingAddress
            c.billingAddress2 = dto.billingAddress2; c.email = dto.email; c.phone = dto.phone
            context.insert(c); clientByID[dto.id] = c; count += 1
        }
        for dto in file.projects {
            let p = Project(name: dto.name, hourlyRate: dto.hourlyRate, client: dto.clientId.flatMap { clientByID[$0] })
            context.insert(p); projectByID[dto.id] = p; count += 1
        }
        for dto in file.invoices {
            let inv = Invoice(invoiceNumber: dto.invoiceNumber, issueDate: dto.issueDate, dueDate: dto.dueDate, client: dto.clientId.flatMap { clientByID[$0] }, notes: dto.notes)
            inv.isPaid = dto.isPaid; inv.paidDate = dto.paidDate
            inv.additionalAmount = dto.additionalAmount; inv.additionalDescription = dto.additionalDescription
            inv.deletedDate = dto.deletedDate; inv.discountAmount = dto.discountAmount; inv.discountIsPercent = dto.discountIsPercent; inv.taxRate = dto.taxRate
            inv.paymentTerms = dto.paymentTerms; inv.paymentInstructions = dto.paymentInstructions
            inv.acceptedPayments = dto.acceptedPayments; inv.poNumber = dto.poNumber; inv.includeTaxID = dto.includeTaxID ?? true
            context.insert(inv); invoiceByID[dto.id] = inv; count += 1
        }
        for dto in file.quotes {
            let q = Quote(quoteNumber: dto.quoteNumber, issueDate: dto.issueDate, validUntil: dto.validUntil, client: dto.clientId.flatMap { clientByID[$0] }, notes: dto.notes)
            q.status = dto.status; q.convertedInvoiceNumber = dto.convertedInvoiceNumber; q.deletedDate = dto.deletedDate
            q.discountAmount = dto.discountAmount; q.discountIsPercent = dto.discountIsPercent; q.taxRate = dto.taxRate
            q.paymentTerms = dto.paymentTerms; q.paymentInstructions = dto.paymentInstructions
            q.acceptedPayments = dto.acceptedPayments; q.poNumber = dto.poNumber; q.includeTaxID = dto.includeTaxID ?? true
            context.insert(q); quoteByID[dto.id] = q; count += 1
        }
        for dto in file.timeEntries {
            let e = TimeEntry(date: dto.date, client: dto.clientId.flatMap { clientByID[$0] }, project: dto.projectId.flatMap { projectByID[$0] }, hours: dto.hours, hourlyRate: dto.hourlyRate, notes: dto.notes)
            e.invoice = dto.invoiceId.flatMap { invoiceByID[$0] }
            e.deletedDate = dto.deletedDate
            context.insert(e); count += 1
        }
        for dto in file.expenses {
            let ex = Expense(date: dto.date, amount: dto.amount, category: dto.category, notes: dto.notes, client: dto.clientId.flatMap { clientByID[$0] })
            ex.receiptImageData = dto.receiptImageData; ex.receiptImagesData = dto.receiptImagesData
            ex.deletedDate = dto.deletedDate
            context.insert(ex); count += 1
        }
        for dto in file.incomeEntries {
            let i = IncomeEntry(date: dto.date, source: dto.source, amount: dto.amount, notes: dto.notes, client: dto.clientId.flatMap { clientByID[$0] })
            i.deletedDate = dto.deletedDate
            context.insert(i); count += 1
        }
        for dto in file.invoiceLineItems {
            let li = InvoiceLineItem(itemDescription: dto.itemDescription, quantity: dto.quantity, unitPrice: dto.unitPrice, sortOrder: dto.sortOrder, invoice: dto.invoiceId.flatMap { invoiceByID[$0] })
            context.insert(li); count += 1
        }
        for dto in file.quoteLineItems {
            let li = QuoteLineItem(itemDescription: dto.itemDescription, quantity: dto.quantity, unitPrice: dto.unitPrice, sortOrder: dto.sortOrder, quote: dto.quoteId.flatMap { quoteByID[$0] })
            context.insert(li); count += 1
        }
        for dto in file.timePresets {
            let p = TimePreset(name: dto.name, client: dto.clientId.flatMap { clientByID[$0] }, project: dto.projectId.flatMap { projectByID[$0] })
            p.sortOrder = dto.sortOrder; p.hourlyRateOverride = dto.hourlyRateOverride; p.notesTemplate = dto.notesTemplate
            context.insert(p); count += 1
        }
        for dto in file.mileageTrips {
            let t = MileageTrip(date: dto.date, startLocation: dto.startLocation, endLocation: dto.endLocation, miles: dto.miles, purpose: dto.purpose, notes: dto.notes)
            t.waypoints = dto.waypoints; t.startAddress = dto.startAddress; t.endAddress = dto.endAddress
            t.deletedDate = dto.deletedDate
            t.client = dto.clientId.flatMap { clientByID[$0] }
            context.insert(t); count += 1
        }
        for dto in file.mileagePresets {
            let p = MileagePreset(name: dto.name, startLocation: dto.startLocation, endLocation: dto.endLocation, purpose: dto.purpose, notes: dto.notes, sortOrder: dto.sortOrder, client: dto.clientId.flatMap { clientByID[$0] })
            context.insert(p); count += 1
        }
        for dto in file.expensePresets {
            let p = ExpensePreset(name: dto.name, amount: dto.amount, category: dto.category, notes: dto.notes, sortOrder: dto.sortOrder, instantLog: dto.instantLog)
            context.insert(p); count += 1
        }

        try context.save()
        return count
    }
}
