import Foundation
import SwiftUI
import Combine

/// History filter segments.
enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case charges = "Charges"
    case inspections = "Inspections"

    var id: String { rawValue }
}

/// One row in History: a charge or an inspection.
struct HistoryEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case charge(ChargeSession)
        case inspection(Inspection)
    }

    let id: UUID
    let date: Date
    let kind: Kind
    let batteryName: String

    var title: String {
        switch kind {
        case .charge: "Charge · \(batteryName)"
        case .inspection: "Inspection · \(batteryName)"
        }
    }

    var subtitle: String {
        switch kind {
        case .charge(let session):
            if session.status == .running {
                return "Charge in progress · started \(session.startedAt.formatted(date: .omitted, time: .shortened))"
            }
            return "\(session.timeRangeText) · \(session.place.displayName)"
        case .inspection(let inspection):
            let problems = inspection.items
                .filter { $0.finding == .problem }
                .map { $0.kind.rawValue }
            switch inspection.result {
            case .pass:
                return "No issues reported"
            case .caution, .fail:
                return problems.isEmpty ? "Something needs attention" : "Problem: \(problems.joined(separator: ", "))"
            }
        }
    }

    /// Chip level. Charges use their saved risk. Inspections: pass is Low, caution Medium, fail High.
    var riskLevel: RiskLevel? {
        switch kind {
        case .charge(let session):
            return session.riskLevel
        case .inspection(let inspection):
            switch inspection.result {
            case .pass: return .low
            case .caution: return .medium
            case .fail: return .high
            }
        }
    }

    var chargeSession: ChargeSession? {
        if case .charge(let session) = kind { return session }
        return nil
    }
}

struct DayGroup: Identifiable, Equatable {
    let day: Date
    let entries: [HistoryEntry]

    var id: Date { day }
}

@MainActor
final class HistoryViewModel: ObservableObject {

    @Published var filter: HistoryFilter = .all { didSet { rebuild() } }
    @Published private(set) var groups: [DayGroup] = []

    private let chargeRepository: any ChargeRepository
    private let garageRepository: any GarageRepository
    private let inspectionRepository: any InspectionRepository

    private var sessions: [ChargeSession] = []
    private var inspections: [Inspection] = []
    private var batteryNames: [UUID: String] = [:]
    private var chargerNames: [UUID: String] = [:]

    init(
        chargeRepository: any ChargeRepository,
        garageRepository: any GarageRepository,
        inspectionRepository: any InspectionRepository
    ) {
        self.chargeRepository = chargeRepository
        self.garageRepository = garageRepository
        self.inspectionRepository = inspectionRepository
    }

    /// Reads charges and inspections, then groups them by day.
    func load() async {
        let batteries = (try? await garageRepository.fetchBatteries()) ?? []
        let chargers = (try? await garageRepository.fetchChargers()) ?? []
        batteryNames = [:]
        for battery in batteries { batteryNames[battery.id] = battery.name }
        chargerNames = [:]
        for charger in chargers { chargerNames[charger.id] = charger.name }

        sessions = chargeRepository.allSessions()

        var found: [Inspection] = []
        for battery in batteries {
            if let list = try? await inspectionRepository.fetchInspections(for: battery.id) {
                found += list
            }
        }
        inspections = found
        rebuild()
    }

    func batteryName(for id: UUID) -> String { batteryNames[id] ?? "Battery" }

    func chargerName(for id: UUID) -> String { chargerNames[id] ?? "Charger" }

    private func rebuild() {
        var entries: [HistoryEntry] = []

        if filter == .all || filter == .charges {
            entries += sessions.map {
                HistoryEntry(id: $0.id, date: $0.startedAt, kind: .charge($0), batteryName: batteryName(for: $0.batteryID))
            }
        }
        if filter == .all || filter == .inspections {
            entries += inspections.map {
                HistoryEntry(id: $0.id, date: $0.inspectedAt, kind: .inspection($0), batteryName: batteryName(for: $0.batteryID))
            }
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        groups = grouped
            .map { DayGroup(day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    /// "Today", "Yesterday" or "20 Oct 2026".
    static func dayLabel(for day: Date, relativeTo now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}
