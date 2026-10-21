//
//  EvaluateInspectionDue.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

struct EvaluateInspectionDue {
    enum Status: Equatable, Sendable {
        case notRequired
        case neverInspected
        case needsAttention
        case upToDate(nextDueDate: Date)
        case dueSoon(dueDate: Date)
        case dueToday(dueDate: Date)
        case overdue(dueDate: Date)
    }

    enum EvaluationError: Error, Equatable, LocalizedError {
        case wrongBattery
        case futureInspectionDate
        case dateCalculationFailed

        var errorDescription: String? {
            switch self {
            case .wrongBattery:
                return "This inspection belongs to a different battery."

            case .futureInspectionDate:
                return "The inspection date cannot be in the future."

            case .dateCalculationFailed:
                return "The next inspection date could not be calculated."
            }
        }
    }

    private let calendar: Calendar
    private let now: () -> Date

    init(
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.calendar = calendar
        self.now = now
    }

    func execute(
        battery: Battery,
        latestInspection: Inspection?
    ) throws -> Status {
        // Retired batteries do not receive routine inspection reminders.
        guard !battery.isRetired else {
            return .notRequired
        }

        guard let inspection = latestInspection else {
            return .neverInspected
        }

        guard inspection.batteryID == battery.id else {
            throw EvaluationError.wrongBattery
        }

        let currentDate = now()
        let today = calendar.startOfDay(for: currentDate)
        let inspectionDay = calendar.startOfDay(
            for: inspection.inspectedAt
        )

        guard inspection.inspectedAt <= currentDate else {
            throw EvaluationError.futureInspectionDate
        }

        // Reported concerns take priority over a routine due date.
        guard inspection.result == .pass,
              !inspection.hasReportedProblem else {
            return .needsAttention
        }

        guard let dueDate = calendar.date(
            byAdding: .day,
            value: 30,
            to: inspectionDay
        ) else {
            throw EvaluationError.dateCalculationFailed
        }

        guard let daysRemaining = calendar.dateComponents(
            [.day],
            from: today,
            to: dueDate
        ).day else {
            throw EvaluationError.dateCalculationFailed
        }

        if daysRemaining < 0 {
            return .overdue(dueDate: dueDate)
        }

        if daysRemaining == 0 {
            return .dueToday(dueDate: dueDate)
        }

        if daysRemaining <= 7 {
            return .dueSoon(dueDate: dueDate)
        }

        return .upToDate(nextDueDate: dueDate)
    }
}
