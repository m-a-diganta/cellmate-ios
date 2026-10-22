//
//  FixedWording.swift
//  CellMate
//
//  Fixed on-screen wording from the brief (Technical approach):
//  "Copy the exact wording." These strings must never be rephrased.
//

import Foundation

enum FixedWording {
    /// Shown on the Charging screen while a charge runs.
    static let reminderOnly = "Reminder only · charging won’t stop automatically"

    /// Shown when a completed charge is scored Low.
    static let lowRiskDisclaimer = "Low risk reflects logged checks, not a safety guarantee"

    /// Shown wherever risk is displayed (Charge complete, Charge details).
    static let cantTellSafe = "CellMate can’t tell you a battery is safe"

    /// Shown with guidance content (Ask result, Stop using, risk reasons).
    static let guidanceDisclaimer = "Guidance can be wrong. Follow the maker’s advice."
}
