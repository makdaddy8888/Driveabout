import CoreLocation
import Foundation

@MainActor
final class VisitStore: ObservableObject {
    @Published private(set) var learners: [DriverProfile] = []
    @Published private(set) var profile: DriverProfile
    @Published private(set) var visits: [String: CellVisit] = [:]
    @Published private(set) var unlockedRegions: UnlockedRegions = .default
    @Published private(set) var activeTrip: Trip?
    @Published private(set) var lastProcessedRegionName: String?
    @Published private(set) var trackingBlockedReason: String?
    @Published var showingLearnerPicker = true
    @Published var walkTestingMode = false
    @Published private(set) var isSimulationActive = false

    private var tripLogStore: TripLogStore?
    private var achievementStore: AchievementStore?
    private var visitsByLearnerID: [UUID: [String: CellVisit]] = [:]
    private var lastCellID: String?
    private var lastCellEnteredAt: Date?
    private var tripNewCellIDs: [String] = []
    private var tripRepeatCellIDs: [String] = []
    private var tripRegionsVisited: Set<String> = []
    private var tripStartBadgeIDs: Set<String> = []
    private var tripStartWaypointKeys: Set<String> = []
    private var tripStartUnlockedRegionIDs: Set<String> = []
    private var saveTask: Task<Void, Never>?
    private let cellSizeM: Int

    private enum StorageKey {
        static let learners = "driveabout.learners"
        static let visitsByLearner = "driveabout.visitsByLearner"
        static let lastLearnerID = "driveabout.lastLearnerID"
        static let walkTestingMode = "driveabout.walkTestingMode"
    }

    init(cellSizeM: Int = Grid.defaultCellSizeM) {
        self.cellSizeM = cellSizeM
        self.profile = DriverProfile(
            id: UUID(),
            displayName: "Learner",
            createdAt: Date(),
            homeRegion: nil
        )
        loadFromDisk()
        walkTestingMode = UserDefaults.standard.bool(forKey: StorageKey.walkTestingMode)
        if learners.isEmpty {
            profile = DriverProfile(
                id: UUID(),
                displayName: "Learner",
                createdAt: Date(),
                homeRegion: nil
            )
        } else if let lastID = UserDefaults.standard.string(forKey: StorageKey.lastLearnerID).flatMap(UUID.init),
                  let existing = learners.first(where: { $0.id == lastID }) {
            applyLearner(existing, persistSelection: false)
            showingLearnerPicker = false
        } else if let first = learners.first {
            applyLearner(first, persistSelection: false)
            showingLearnerPicker = false
        }
    }

    var exploredCellCount: Int { visits.count }
    var wellKnownCellCount: Int { visits.values.filter { $0.visitCount >= 5 }.count }

    func exploredCellCount(for learnerID: UUID) -> Int {
        visitsByLearnerID[learnerID]?.count ?? 0
    }

    func isExplored(cellID: String) -> Bool {
        FogMap.isExplored(cellID: cellID, visits: visits)
    }

    func configureTripLogging(_ store: TripLogStore) {
        tripLogStore = store
    }

    func configureAchievementTracking(_ store: AchievementStore) {
        achievementStore = store
    }

    func logGpsSample(_ sample: GpsSample) {
        tripLogStore?.append(sample)
    }

    func selectLearner(_ learnerID: UUID) {
        guard let learner = learners.first(where: { $0.id == learnerID }) else { return }
        if activeTrip != nil {
            endTrip()
        }
        applyLearner(learner, persistSelection: true)
        showingLearnerPicker = false
        saveToDisk()
    }

    func addLearner(named displayName: String) {
        let learner = DriverProfile(
            id: UUID(),
            displayName: displayName,
            createdAt: Date(),
            homeRegion: nil
        )
        learners.append(learner)
        visitsByLearnerID[learner.id] = [:]
        selectLearner(learner.id)
        saveToDisk()
    }

    #if targetEnvironment(simulator)
    func addLearnerForSimulator(name: String) {
        addLearner(named: name)
        unlockAllRegionsForDevelopment()
        setWalkTestingMode(true)
    }
    #endif

    func presentLearnerPicker() {
        if activeTrip != nil {
            endTrip()
        }
        showingLearnerPicker = true
    }

    func resetMapForCurrentLearner() {
        visits = [:]
        visitsByLearnerID[profile.id] = [:]
        lastCellID = nil
        lastCellEnteredAt = nil
        saveToDisk()
    }

    /// Replays locally stored GPS history to rebuild fog cells for the current learner.
    @discardableResult
    func rebuildMapFromTripLogs() -> Int {
        guard let tripLogStore else { return 0 }
        let logs = tripLogStore.loadTrips(for: profile.id)
        return rebuildMap(from: logs, profileID: profile.id)
    }

    /// Replays trip logs for a learner using current grid rules.
    @discardableResult
    func rebuildMap(from logs: [LoggedTrip], profileID: UUID) -> Int {
        var rebuilt: [String: CellVisit] = [:]
        var lastCellID: String?
        var lastCellEnteredAt: Date?

        let orderedTrips = logs.sorted { $0.startedAt < $1.startedAt }
        for trip in orderedTrips {
            let orderedSamples = trip.samples.sorted { $0.recordedAt < $1.recordedAt }
            for sample in orderedSamples {
                replaySample(
                    sample,
                    walkMode: trip.walkMode,
                    profileID: profileID,
                    visits: &rebuilt,
                    lastCellID: &lastCellID,
                    lastCellEnteredAt: &lastCellEnteredAt
                )
            }
        }

        visitsByLearnerID[profileID] = rebuilt
        if profile.id == profileID {
            visits = rebuilt
            lastCellID = nil
            lastCellEnteredAt = nil
        }
        saveToDisk()
        return rebuilt.count
    }

    func startTrip() {
        guard activeTrip == nil else { return }
        let trip = Trip(
            id: UUID(),
            profileID: profile.id,
            startedAt: Date(),
            endedAt: nil,
            newCells: 0,
            repeatCells: 0
        )
        activeTrip = trip
        lastCellID = nil
        lastCellEnteredAt = nil
        trackingBlockedReason = nil
        tripNewCellIDs = []
        tripRepeatCellIDs = []
        tripRegionsVisited = []
        tripStartBadgeIDs = Set(achievementStore?.earnedBadges.map(\.id) ?? [])
        tripStartWaypointKeys = Set(
            achievementStore?.confirmedVisits.map {
                "\($0.collectionID)::\($0.waypointID)"
            } ?? []
        )
        tripStartUnlockedRegionIDs = unlockedRegions.regionIDs
        tripLogStore?.beginTrip(
            id: trip.id,
            profileID: profile.id,
            walkMode: walkTestingMode,
            simulated: isSimulationActive,
            gridCellSizeM: cellSizeM
        )
    }

    func ingestCurrentLocation(_ location: CLLocation) {
        guard activeTrip != nil else { return }
        lastCellID = nil
        lastCellEnteredAt = nil
        ingest(location.asGpsSample(tripID: activeTrip?.id))
    }

    func simulateRevealAroundCurrentLocation(lat: Double, lng: Double) {
        ensureTripForSimulation()
        unlockAllRegionsForDevelopment()
        ingestSimulated(lat: lat, lng: lng, speedMps: 1.4)
        saveToDisk()
    }

    func simulateShortWalk(fromLat lat: Double, lng: Double) {
        ensureTripForSimulation()
        unlockAllRegionsForDevelopment()

        var timestamp = Date()
        for step in 0..<5 {
            ingestSimulated(
                lat: lat + Double(step) * 0.0009,
                lng: lng,
                recordedAt: timestamp,
                speedMps: 1.4
            )
            timestamp = timestamp.addingTimeInterval(4)
        }
        saveToDisk()
    }

    func ingestSimulated(
        lat: Double,
        lng: Double,
        recordedAt: Date = Date(),
        speedMps: Double = 11
    ) {
        ensureTripForSimulation()
        lastCellID = nil
        lastCellEnteredAt = nil

        let sample = sample(lat: lat, lng: lng, recordedAt: recordedAt, speedMps: speedMps)
        logGpsSample(sample)
        guard activeTrip != nil else { return }
        guard EasternSuburbs.envelope.contains(lat: sample.lat, lng: sample.lng) else {
            trackingBlockedReason = "Simulation point outside the play area."
            return
        }

        lastProcessedRegionName = PlayRegion.region(for: sample.lat, lng: sample.lng)?.name ?? "Eastern Suburbs"
        trackingBlockedReason = nil

        if let region = PlayRegion.region(for: sample.lat, lng: sample.lng) {
            tripRegionsVisited.insert(region.id)
        }

        let cellID = Grid.cellID(lat: sample.lat, lng: sample.lng, cellSizeM: cellSizeM)
        lastCellID = cellID
        lastCellEnteredAt = sample.recordedAt
        recordVisit(cellID: cellID, sample: sample)
    }

    func setSimulationActive(_ active: Bool) {
        isSimulationActive = active
        if active {
            trackingBlockedReason = nil
        }
    }

    func endTrip() {
        DriveSimulator.shared.cancel()
        guard var trip = activeTrip else { return }
        trip.endedAt = Date()
        let outcome = buildTripOutcome(for: trip)
        tripLogStore?.endTrip(id: trip.id, endedAt: trip.endedAt ?? Date(), outcome: outcome)
        activeTrip = nil
        lastCellID = nil
        lastCellEnteredAt = nil
        tripNewCellIDs = []
        tripRepeatCellIDs = []
        tripRegionsVisited = []
    }

    func ingest(_ sample: GpsSample) {
        logGpsSample(sample)
        guard activeTrip != nil else { return }

        let accuracy = sample.accuracyM ?? maxAllowedAccuracyM
        guard accuracy <= maxAllowedAccuracyM else {
            trackingBlockedReason = "GPS accuracy too low (\(Int(accuracy)) m)."
            return
        }

        if !walkTestingMode,
           let speed = sample.speedMps, speed >= 0, speed < Grid.minSpeedMps {
            trackingBlockedReason = "Moving too slowly to record — keep walking or driving."
            return
        }
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
        tripRegionsVisited.insert(region.id)

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

    func unlockAllRegionsForDevelopment() {
        unlockedRegions.regionIDs = Set(PlayRegion.all.map(\.id))
    }

    func setWalkTestingMode(_ enabled: Bool) {
        walkTestingMode = enabled
        UserDefaults.standard.set(enabled, forKey: StorageKey.walkTestingMode)
    }

    func flushPendingSave() {
        saveTask?.cancel()
        saveTask = nil
        saveToDisk()
        tripLogStore?.flushPendingWrites()
    }

    // MARK: - Private

    private func replaySample(
        _ sample: GpsSample,
        walkMode: Bool,
        profileID: UUID,
        visits: inout [String: CellVisit],
        lastCellID: inout String?,
        lastCellEnteredAt: inout Date?
    ) {
        let accuracy = sample.accuracyM ?? (walkMode ? 100 : Grid.minAccuracyM)
        guard accuracy <= (walkMode ? 100 : Grid.minAccuracyM) else { return }

        if !walkMode,
           let speed = sample.speedMps, speed >= 0, speed < Grid.minSpeedMps {
            return
        }
        guard EasternSuburbs.envelope.contains(lat: sample.lat, lng: sample.lng) else { return }

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
            recordReplayVisit(
                cellID: cellID,
                sample: sample,
                profileID: profileID,
                visits: &visits
            )
        }
    }

    private func recordReplayVisit(
        cellID: String,
        sample: GpsSample,
        profileID: UUID,
        visits: inout [String: CellVisit]
    ) {
        if var existing = visits[cellID] {
            existing.lastVisitedAt = sample.recordedAt
            existing.visitCount += 1
            visits[cellID] = existing
        } else {
            visits[cellID] = CellVisit(
                cellID: cellID,
                profileID: profileID,
                firstVisitedAt: sample.recordedAt,
                lastVisitedAt: sample.recordedAt,
                visitCount: 1,
                centroidLat: sample.lat,
                centroidLng: sample.lng
            )
        }
    }

    private var maxAllowedAccuracyM: Double {
        walkTestingMode ? 100 : Grid.minAccuracyM
    }

    private func ensureTripForSimulation() {
        if activeTrip == nil {
            startTrip()
        }
        trackingBlockedReason = nil
    }

    private func sample(
        lat: Double,
        lng: Double,
        recordedAt: Date = Date(),
        speedMps: Double = 1.4
    ) -> GpsSample {
        GpsSample(
            recordedAt: recordedAt,
            lat: lat,
            lng: lng,
            speedMps: speedMps,
            accuracyM: 8,
            tripID: activeTrip?.id
        )
    }

    private func scheduleSaveToDisk() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            saveToDisk()
        }
    }

    private func applyLearner(_ learner: DriverProfile, persistSelection: Bool) {
        persistActiveLearnerVisits()
        profile = learner
        visits = visitsByLearnerID[learner.id] ?? [:]
        lastCellID = nil
        lastCellEnteredAt = nil
        trackingBlockedReason = nil
        lastProcessedRegionName = nil
        if persistSelection {
            UserDefaults.standard.set(learner.id.uuidString, forKey: StorageKey.lastLearnerID)
        }
    }

    private func persistActiveLearnerVisits() {
        visitsByLearnerID[profile.id] = visits
    }

    private func recordVisit(cellID: String, sample: GpsSample) {
        if var existing = visits[cellID] {
            existing.lastVisitedAt = sample.recordedAt
            existing.visitCount += 1
            visits[cellID] = existing
            tripRepeatCellIDs.append(cellID)
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
            tripNewCellIDs.append(cellID)
            bumpTrip(repeat: false)
        }
        visitsByLearnerID[profile.id] = visits
        scheduleSaveToDisk()
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

    private func buildTripOutcome(for trip: Trip) -> LoggedTripOutcome? {
        guard let loggedTrip = tripLogStore?.activeTripSnapshot(), loggedTrip.id == trip.id else {
            return nil
        }

        let endedAt = trip.endedAt ?? Date()
        let samples = loggedTrip.samples
        let badgesEarned = (achievementStore?.earnedBadges ?? [])
            .filter { !tripStartBadgeIDs.contains($0.id) }
            .map {
                TripLoggedBadge(
                    collectionID: $0.collectionID,
                    collectionName: $0.collectionName,
                    tierID: $0.tierID,
                    tierName: $0.tierName,
                    earnedAt: $0.earnedAt
                )
            }

        let waypointsConfirmed = (achievementStore?.confirmedVisits ?? [])
            .filter { !tripStartWaypointKeys.contains("\($0.collectionID)::\($0.waypointID)") }
            .map { visit in
                let collectionName = achievementStore?.collections.first(where: { $0.id == visit.collectionID })?.name
                let waypointName = achievementStore?.collections
                    .first(where: { $0.id == visit.collectionID })?
                    .items.first(where: { $0.id == visit.waypointID })?
                    .name
                return TripLoggedWaypoint(
                    waypointID: visit.waypointID,
                    collectionID: visit.collectionID,
                    waypointName: waypointName,
                    collectionName: collectionName,
                    confirmedAt: visit.confirmedAt
                )
            }

        let regionsVisited = tripRegionsVisited.sorted()
        let fallbackRegions = TripLogMetrics.regionsVisited(in: samples)

        return LoggedTripOutcome(
            newCells: trip.newCells,
            repeatCells: trip.repeatCells,
            newCellIDs: tripNewCellIDs,
            repeatCellIDs: tripRepeatCellIDs,
            regionsVisited: regionsVisited.isEmpty ? fallbackRegions : regionsVisited,
            unlockedRegionIDsAtStart: tripStartUnlockedRegionIDs.sorted(),
            distanceM: TripLogMetrics.distanceMeters(for: samples),
            durationSeconds: TripLogMetrics.durationSeconds(startedAt: trip.startedAt, endedAt: endedAt),
            averageSpeedMps: TripLogMetrics.averageSpeedMps(for: samples),
            maxSpeedMps: TripLogMetrics.maxSpeedMps(for: samples),
            badgesEarned: badgesEarned,
            waypointsConfirmed: waypointsConfirmed
        )
    }

    private func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: StorageKey.learners),
           let decoded = try? decoder.decode([DriverProfile].self, from: data) {
            learners = decoded
        }

        if let data = UserDefaults.standard.data(forKey: StorageKey.visitsByLearner),
           let decoded = try? decoder.decode([String: [String: CellVisit]].self, from: data) {
            visitsByLearnerID = decoded.reduce(into: [:]) { result, entry in
                guard let learnerID = UUID(uuidString: entry.key) else { return }
                result[learnerID] = entry.value
            }
        }
    }

    private func saveToDisk() {
        persistActiveLearnerVisits()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(learners) {
            UserDefaults.standard.set(data, forKey: StorageKey.learners)
        }

        let encodedVisits = visitsByLearnerID.reduce(into: [String: [String: CellVisit]]()) { result, entry in
            result[entry.key.uuidString] = entry.value
        }
        if let data = try? encoder.encode(encodedVisits) {
            UserDefaults.standard.set(data, forKey: StorageKey.visitsByLearner)
        }
    }
}
