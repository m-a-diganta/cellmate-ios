//
//  Inspection.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

struct Inspection: Identifiable, Equatable, Sendable {
    enum Source: String, Equatable, Sendable {
        case manual
        case assistant
    }

    enum Result: String, Equatable, Sendable {
        case pass
        case caution
        case fail
    }

    struct Item: Identifiable, Equatable, Sendable {
        enum Kind: String, CaseIterable, Equatable, Sendable {
            case swelling
            case heat
            case smell
            case damage
            case charger
        }

        enum Finding: String, Equatable, Sendable {
            case ok
            case problem
        }

        let id: UUID
        let kind: Kind
        let finding: Finding
        let note: String?

        init(
            id: UUID = UUID(),
            kind: Kind,
            finding: Finding,
            note: String? = nil
        ) {
            self.id = id
            self.kind = kind
            self.finding = finding
            self.note = note
        }
    }

    struct PhotoEvidence: Identifiable, Equatable, Sendable {
        let id: UUID
        let filename: String
        let capturedAt: Date

        init(
            id: UUID = UUID(),
            filename: String,
            capturedAt: Date
        ) {
            self.id = id
            self.filename = filename
            self.capturedAt = capturedAt
        }
    }

    let id: UUID
    let batteryID: UUID
    let inspectedAt: Date
    let source: Source
    let result: Result
    let items: [Item]
    let photos: [PhotoEvidence]

    init(
        id: UUID = UUID(),
        batteryID: UUID,
        inspectedAt: Date,
        source: Source,
        result: Result,
        items: [Item],
        photos: [PhotoEvidence] = []
    ) {
        self.id = id
        self.batteryID = batteryID
        self.inspectedAt = inspectedAt
        self.source = source
        self.result = result
        self.items = items
        self.photos = photos
    }

    var hasReportedProblem: Bool {
        items.contains { $0.finding == .problem }
    }
}
