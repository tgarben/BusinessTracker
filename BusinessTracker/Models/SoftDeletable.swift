import Foundation

/// Models that support 30-day "Recently Deleted" soft-delete.
/// A non-nil `deletedDate` means the record is in the trash and is hidden from
/// all normal queries (each `@Query` filters `deletedDate == nil`). Items are
/// permanently purged 30 days after `deletedDate` — see `BusinessTrackerApp.purgeExpiredTrash()`.
protocol SoftDeletable: AnyObject {
    var deletedDate: Date? { get set }
}

extension SoftDeletable {
    /// Number of whole days remaining before this trashed item is permanently purged (0...30).
    var trashDaysRemaining: Int {
        guard let deletedDate else { return 30 }
        let elapsed = Calendar.current.dateComponents([.day], from: deletedDate, to: .now).day ?? 0
        return max(0, 30 - elapsed)
    }
}
