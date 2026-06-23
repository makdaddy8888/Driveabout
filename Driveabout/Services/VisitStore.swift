import Foundation

@MainActor
final class VisitStore: ObservableObject {
    @Published private(set) var profile: DriverProfile
    @Published private(set) var visits: [String: CellVisit] = [:] {
        didSet { refreshFogOpacityMap() }
    }
    @Published private(set) var fogOpacityByCellID: [String: Double] = [:]
    @Published private(set) var unlockedRegions: UnlockedRegions = .default
    @Published private(set) var activeTrip: Trip?
    @Published private(set) var lastProcessedRegionName: String?
    @Published private(set) var trackingBlockedReason: String?

    private var lastCellID: String?
    private var lastCellEnteredAt: Date?
    private let cellSizeM: Int

    init(
        profile: DriverProfile = DriverProfile(
            id: UUID(),
            displayName: "Learner",
            createdAt: Date(),
            homeRegion: nil
        ),
        cellSizeM: Int = Grid.defaultCellSizeM
    ) {
        self.profile = profile
        self.cellSizeM = cellSizeM
        refreshFogOpacityMap()
        #if DEBUG
        seedDemoVisitsIfNeeded()
        #endif
    }

    func fogOpacity(for cellID: String) -> Double {
        fogOpacityByCellID[cellID] ?? 1.0
    }

    private func refreshFogOpacityMap() {
        fogOpacityByCellID = FogGrid.buildOpacityMap(visits: visits, visitCellSizeM: cellSizeM)
    }

    #if DEBUG
    /// Small CBD patch so fog-of-war is visible in the simulator without a drive.
    private func seedDemoVisitsIfNeeded() {
        guard visits.isEmpty else { return }
        let samples: [(Double, Double)] = [
            (-33.8688, 151.2093),
            (-33.8692, 151.2098),
            (-33.8684, 151.2088),
            (-33.8696, 151.2102),
            (-33.8678, 151.2082),
        ]
        let now = Date()
        var seeded: [String: CellVisit] = [:]
        for (lat, lng) in samples {
            let cellID = Grid.cellID(lat: lat, lng: lng, cellSizeM: cellSizeM)
            seeded[cellID] = CellVisit(
                cellID: cellID,
                profileID: profile.id,
                firstVisitedAt: now,
                lastVisitedAt: now,
                visitCount: 1,
                centroidLat: lat,
                centroidLng: lng
            )
        }
        visits = seeded
    }
    #endif

    var exploredCellCount: Int { visits.count }
    var wellKnownCellCount: Int { visits.values.filter { $0.visitCount >= 5 }.count }

    func startTrip() {
        guard activeTrip == nil else { return }
        activeTrip = Trip(
            id: UUID(),
            profileID: profile.id,
            startedAt: Date(),
            endedAt: nil,
            newCells: 0,
            repeatCells: 0
        )
        lastCellID = nil
        lastCellEnteredAt = nil
    }

    func endTrip() {
        guard var trip = activeTrip else { return }
        trip.endedAt = Date()
        activeTrip = nil
        lastCellID = nil
        lastCellEnteredAt = nil
    }

    func ingest(_ sample: GpsSample) {
        guard activeTrip != nil else { return }

        let accuracy = sample.accuracyM ?? Grid.minAccuracyM
        let speed = sample.speedMps ?? 0
        guard accuracy <= Grid.minAccuracyM else { return }
        guard speed >= Grid.minSpeedMps else { return }
        guard EasternSuburbs.envelope.contains(lat: sample.lat, lng: sample.lng) else {
            trackingBlockedReason = "Outside the Eastern Suburbs play area."
            lastProcessedRegionName = nil
            return
        }

        guard let region = PlayRegion.region(for: sample.lat, lng: sample.lng) else {
            trackingBlockedReason = "No zone matched for this location."
            return
        }

        lastProcessedRegionName = region.name

        guard unlockedRegions.canTrack(lat: sample.lat, lng: sample.lng) else {
            trackingBlockedReason = "Unlock \(region.name) to track this area."
            return
        }

        trackingBlockedReason = nil

        let cellID = Grid.cellID(lat: sample.lat, lng: sample.lng, cellSizeM: cellSizeM)
        let reentryInterval = TimeInterval(Grid.reentryMinutes * 60)

        if lastCellID == cellID,
           let enteredAt = lastCellEnteredAt,
           sample.recordedAt.timeIntervalSince(enteredAt) < reentryInterval {
            return
        }

        if lastCellID != cellID {
            lastCellID = cellID
            lastCellEnteredAt = sample.recordedAt
            recordVisit(cellID: cellID, sample: sample)
        }
    }

    private func recordVisit(cellID: String, sample: GpsSample) {
        if var existing = visits[cellID] {
            existing.lastVisitedAt = sample.recordedAt
            existing.visitCount += 1
            visits[cellID] = existing
            bumpTrip(repeat: true)
        } else {
            visits[cellID] = CellVisit(
                cellID: cellID,
                profileID: profile.id,
                firstVisitedAt: sample.recordedAt,
                lastVisitedAt: sample.recordedAt,
                visitCount: 1,
                centroidLat: sample.lat,
                centroidLng: sample.lng
            )
            bumpTrip(repeat: false)
        }
    }

    private func bumpTrip(repeat isRepeat: Bool) {
        guard var trip = activeTrip else { return }
        if isRepeat {
            trip.repeatCells += 1
        } else {
            trip.newCells += 1
        }
        activeTrip = trip
    }

    /// Dev helper — unlock all zones without StoreKit wired yet.
    func unlockAllRegionsForDevelopment() {
        unlockedRegions.regionIDs = Set(PlayRegion.all.map(\.id))
    }
}
