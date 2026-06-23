import Foundation

// MARK: - Grid

enum Grid {
    static let defaultCellSizeM: Int = 100
    static let minAccuracyM: Double = 50
    static let minSpeedMps: Double = 1.0
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

    var speedKmh: Double? {
        guard let speedMps, speedMps >= 0 else { return nil }
        return speedMps * 3.6
    }
}

// MARK: - Trip logs

struct TripLoggedBadge: Codable, Identifiable, Hashable {
    var id: String { "\(collectionID):\(tierID)" }
    let collectionID: String
    let collectionName: String
    let tierID: String
    let tierName: String
    let earnedAt: Date
}

struct TripLoggedWaypoint: Codable, Identifiable, Hashable {
    var id: String { "\(collectionID)::\(waypointID)" }
    let waypointID: String
    let collectionID: String
    let waypointName: String?
    let collectionName: String?
    let confirmedAt: Date
}

/// Snapshot of everything a trip changed — used to rebuild fog and review history.
struct LoggedTripOutcome: Codable {
    var newCells: Int
    var repeatCells: Int
    var newCellIDs: [String]
    var repeatCellIDs: [String]
    var regionsVisited: [String]
    var unlockedRegionIDsAtStart: [String]
    var distanceM: Double
    var durationSeconds: Double
    var averageSpeedMps: Double?
    var maxSpeedMps: Double?
    var badgesEarned: [TripLoggedBadge]
    var waypointsConfirmed: [TripLoggedWaypoint]

    var regionsVisitedNames: [String] {
        regionsVisited.compactMap { id in
            PlayRegion.all.first(where: { $0.id == id })?.name
        }
    }
}

/// Raw GPS history for one drive — kept locally so the fog map can be rebuilt later.
struct LoggedTrip: Identifiable, Codable {
    let id: UUID
    let profileID: UUID
    let startedAt: Date
    var endedAt: Date?
    var walkMode: Bool
    var simulated: Bool
    var gridCellSizeM: Int
    var samples: [GpsSample]
    var outcome: LoggedTripOutcome?

    var sampleCount: Int { samples.count }

    var durationSeconds: TimeInterval {
        if let outcome { return outcome.durationSeconds }
        guard let endedAt else { return 0 }
        return endedAt.timeIntervalSince(startedAt)
    }

    var distanceM: Double {
        outcome?.distanceM ?? TripLogMetrics.distanceMeters(for: samples)
    }

    var maxSpeedMps: Double? {
        outcome?.maxSpeedMps ?? TripLogMetrics.maxSpeedMps(for: samples)
    }

    var averageSpeedMps: Double? {
        outcome?.averageSpeedMps ?? TripLogMetrics.averageSpeedMps(for: samples)
    }

    var newCells: Int { outcome?.newCells ?? 0 }
    var repeatCells: Int { outcome?.repeatCells ?? 0 }
}

struct LoggedTripSummary: Identifiable, Codable {
    let id: UUID
    let profileID: UUID
    let startedAt: Date
    let endedAt: Date?
    let sampleCount: Int
    let walkMode: Bool
    let simulated: Bool
    let gridCellSizeM: Int
    let durationSeconds: Double
    let distanceM: Double
    let newCells: Int
    let repeatCells: Int
    let regionsVisited: [String]
    let maxSpeedMps: Double?
    let averageSpeedMps: Double?
    let badgesEarnedCount: Int
    let waypointsConfirmedCount: Int

    var regionsVisitedNames: [String] {
        regionsVisited.compactMap { id in
            PlayRegion.all.first(where: { $0.id == id })?.name
        }
    }
}

enum TripLogMetrics {
    static func distanceMeters(for samples: [GpsSample]) -> Double {
        let ordered = samples.sorted { $0.recordedAt < $1.recordedAt }
        guard ordered.count >= 2 else { return 0 }

        var total = 0.0
        for index in 1..<ordered.count {
            let previous = ordered[index - 1]
            let current = ordered[index]
            total += haversineMeters(
                lat1: previous.lat, lng1: previous.lng,
                lat2: current.lat, lng2: current.lng
            )
        }
        return total
    }

    static func maxSpeedMps(for samples: [GpsSample]) -> Double? {
        samples.compactMap(\.speedMps).filter { $0 >= 0 }.max()
    }

    static func averageSpeedMps(for samples: [GpsSample]) -> Double? {
        let speeds = samples.compactMap(\.speedMps).filter { $0 >= 0 }
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    static func regionsVisited(in samples: [GpsSample]) -> [String] {
        var regionIDs = Set<String>()
        for sample in samples {
            if let region = PlayRegion.region(for: sample.lat, lng: sample.lng) {
                regionIDs.insert(region.id)
            }
        }
        return regionIDs.sorted()
    }

    static func durationSeconds(startedAt: Date, endedAt: Date?) -> TimeInterval {
        guard let endedAt else { return 0 }
        return max(0, endedAt.timeIntervalSince(startedAt))
    }

    private static func haversineMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
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
        case .discovered: return 0.08
        case .familiar: return 0.03
        case .wellKnown: return 0.0
        }
    }
}
