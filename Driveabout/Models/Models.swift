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

    func contains(lat: Double, lng: Double) -> Bool {
        minLat <= lat && lat <= maxLat && minLng <= lng && lng <= maxLng
    }
}

// MARK: - Eastern Suburbs play area

enum EasternSuburbs {
    /// Watsons Bay → La Perouse, west to City of Sydney
    static let envelope = MapBounds(
        minLat: -33.995,
        minLng: 151.198,
        maxLat: -33.835,
        maxLng: 151.292
    )

    static var mapCenter: (lat: Double, lng: Double) {
        (
            (envelope.minLat + envelope.maxLat) / 2,
            (envelope.minLng + envelope.maxLng) / 2
        )
    }
}

struct PlayRegion: Identifiable, Codable {
    let id: String
    let name: String
    let bounds: MapBounds
    let free: Bool
    let productID: String?

    static let all: [PlayRegion] = [
        PlayRegion(
            id: "city",
            name: "Sydney City",
            bounds: MapBounds(minLat: -33.882, minLng: 151.198, maxLat: -33.858, maxLng: 151.228),
            free: true,
            productID: nil
        ),
        PlayRegion(
            id: "harbour",
            name: "Harbour & Watsons Bay",
            bounds: MapBounds(minLat: -33.858, minLng: 151.220, maxLat: -33.835, maxLng: 151.292),
            free: false,
            productID: "au.driveabout.region.harbour"
        ),
        PlayRegion(
            id: "inner_east",
            name: "Inner East",
            bounds: MapBounds(minLat: -33.920, minLng: 151.198, maxLat: -33.858, maxLng: 151.255),
            free: false,
            productID: "au.driveabout.region.inner_east"
        ),
        PlayRegion(
            id: "coast",
            name: "Coastal",
            bounds: MapBounds(minLat: -33.975, minLng: 151.230, maxLat: -33.885, maxLng: 151.278),
            free: false,
            productID: "au.driveabout.region.coast"
        ),
        PlayRegion(
            id: "botany_bay",
            name: "La Perouse & Botany Bay",
            bounds: MapBounds(minLat: -33.995, minLng: 151.198, maxLat: -33.965, maxLng: 151.255),
            free: false,
            productID: "au.driveabout.region.botany_bay"
        ),
    ]

    static func region(for lat: Double, lng: Double) -> PlayRegion? {
        guard EasternSuburbs.envelope.contains(lat: lat, lng: lng) else { return nil }
        for region in all where region.bounds.contains(lat: lat, lng: lng) {
            return region
        }
        return nil
    }
}

struct UnlockedRegions: Codable {
    var regionIDs: Set<String>

    static var `default`: UnlockedRegions {
        UnlockedRegions(regionIDs: Set(PlayRegion.all.filter(\.free).map(\.id)))
    }

    func isUnlocked(_ regionID: String) -> Bool {
        PlayRegion.all.first { $0.id == regionID }?.free == true || regionIDs.contains(regionID)
    }

    func canTrack(lat: Double, lng: Double) -> Bool {
        guard let region = PlayRegion.region(for: lat, lng: lng) else { return false }
        return isUnlocked(region.id)
    }
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

    var fogLevel: FogLevel { FogLevel(visitCount: visitCount) }
}

struct Trip: Identifiable, Codable {
    let id: UUID
    let profileID: UUID
    let startedAt: Date
    var endedAt: Date?
    var newCells: Int
    var repeatCells: Int

    var isActive: Bool { endedAt == nil }
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
    case discovered
    case familiar
    case wellKnown

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
