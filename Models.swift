// Driveabout — iOS data models (reference for SwiftUI app)

import Foundation

// MARK: - Grid

enum Grid {
    static let defaultCellSizeM: Int = 100
    static let minAccuracyM: Double = 50
    static let minSpeedMps: Double = 2.0
    static let reentryMinutes: Int = 10

    static func cellID(lat: Double, lng: Double, cellSizeM: Int = defaultCellSizeM) -> String {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLng = 111_320.0 * cos(lat * .pi / 180)
        let latIdx = Int(floor(lat * metersPerDegreeLat / Double(cellSizeM)))
        let lngIdx = Int(floor(lng * metersPerDegreeLng / Double(cellSizeM)))
        return "\(latIdx):\(lngIdx)"
    }
}

// MARK: - Records

struct DriverProfile: Identifiable, Codable {
    let id: UUID
    var displayName: String
    let createdAt: Date
    var homeRegion: MapBounds?
}

struct MapBounds: Codable {
    let minLat: Double
    let minLng: Double
    let maxLat: Double
    let maxLng: Double
}

struct CellVisit: Identifiable, Codable {
    var id: String { cellID }
    let cellID: String
    let profileID: UUID
    var firstVisitedAt: Date
    var lastVisitedAt: Date
    var visitCount: Int
    var centroidLat: Double
    var centroidLng: Double
}

struct Trip: Identifiable, Codable {
    let id: UUID
    let profileID: UUID
    let startedAt: Date
    var endedAt: Date?
    var newCells: Int
    var repeatCells: Int
}

struct GpsSample: Codable {
    let recordedAt: Date
    let lat: Double
    let lng: Double
    let speedMps: Double?
    let accuracyM: Double?
    let tripID: UUID?
}

// MARK: - Fog

enum FogLevel {
    case unexplored
    case discovered   // visitCount == 1
    case familiar     // 2...4
    case wellKnown    // >= 5

    init(visitCount: Int) {
        switch visitCount {
        case 0: self = .unexplored
        case 1: self = .discovered
        case 2...4: self = .familiar
        default: self = .wellKnown
        }
    }

    /// 1.0 = fully hidden, 0.0 = fully clear
    var opacity: Double {
        switch self {
        case .unexplored: return 1.0
        case .discovered: return 0.35
        case .familiar: return 0.15
        case .wellKnown: return 0.0
        }
    }
}

// MARK: - Visit processing

struct VisitProcessor {
    let profileID: UUID
    let cellSizeM: Int
    private var lastCellID: String?

    mutating func process(
        lat: Double,
        lng: Double,
        at recordedAt: Date,
        accuracyM: Double,
        speedMps: Double
    ) -> CellVisit? {
        guard accuracyM <= Grid.minAccuracyM else { return nil }
        guard speedMps >= Grid.minSpeedMps else { return nil }

        let cid = Grid.cellID(lat: lat, lng: lng, cellSizeM: cellSizeM)
        _ = (cid, recordedAt, lastCellID)
        lastCellID = cid
        return nil // Wire to VisitStore in app layer
    }
}
