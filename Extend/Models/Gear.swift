////
////  Gear.swift
////  Extend
////

import Foundation

/// A piece of wearable/consumable gear (shoes, bikes, straps, etc.) tracked
/// independently from `Equipment`. Unlike equipment, gear is not stored on
/// individual `LoggedExercise` entries; instead its usage is resolved at read
/// time by matching the log's date against `[startDate, retiredDate]` and the
/// log's exercises against `linkedExerciseIDs`. That way a new pair of shoes
/// starts tracking from the day you got them, and past runs before that date
/// stay associated with their old (or no) pair — no historical mutation.
public struct Gear: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var brand: String
    public var sfSymbol: String?
    public var isFavorite: Bool
    /// Exercises that this gear should attach to when their logs fall inside
    /// the active window (e.g. the "Running" exercise UUID for a pair of
    /// running shoes).
    public var linkedExerciseIDs: [UUID]
    /// When the user started using this gear. Required — the whole point of
    /// gear is to bound a mileage/session count to a specific ownership period.
    public var startDate: Date
    /// Optional retirement date. `nil` means still in use.
    public var retiredDate: Date?
    /// Optional retirement threshold in meters (e.g. 500 mi ≈ 804 672 m).
    /// UI can surface a warning as cumulative distance approaches this value.
    public var retirementThresholdMeters: Double?

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        sfSymbol: String? = nil,
        isFavorite: Bool = false,
        linkedExerciseIDs: [UUID] = [],
        startDate: Date = Date(),
        retiredDate: Date? = nil,
        retirementThresholdMeters: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.sfSymbol = sfSymbol
        self.isFavorite = isFavorite
        self.linkedExerciseIDs = linkedExerciseIDs
        self.startDate = startDate
        self.retiredDate = retiredDate
        self.retirementThresholdMeters = retirementThresholdMeters
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        sfSymbol = try c.decodeIfPresent(String.self, forKey: .sfSymbol)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        linkedExerciseIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedExerciseIDs) ?? []
        startDate = try c.decode(Date.self, forKey: .startDate)
        retiredDate = try c.decodeIfPresent(Date.self, forKey: .retiredDate)
        retirementThresholdMeters = try c.decodeIfPresent(Double.self, forKey: .retirementThresholdMeters)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, brand, sfSymbol, isFavorite, linkedExerciseIDs,
             startDate, retiredDate, retirementThresholdMeters
    }

    /// Whether this gear was in-use on the given date (start ≤ date ≤ retired).
    public func isActive(on date: Date) -> Bool {
        if date < startDate { return false }
        if let retired = retiredDate, date > retired { return false }
        return true
    }
}
