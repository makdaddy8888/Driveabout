import Foundation

/// Persists raw GPS samples for every trip on disk so the fog map can be rebuilt from history.
@MainActor
final class TripLogStore: ObservableObject {
    @Published private(set) var summaries: [LoggedTripSummary] = []

    private var activeTrip: LoggedTrip?
    private var flushTask: Task<Void, Never>?
    private let fileManager = FileManager.default

    private var logsDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Driveabout/TripLogs", isDirectory: true)
    }

    private var indexURL: URL {
        logsDirectory.appendingPathComponent("index.json")
    }

    private var activeTripURL: URL {
        logsDirectory.appendingPathComponent("active-trip.json")
    }

    init() {
        loadIndex()
        recoverActiveTripIfNeeded()
    }

    func beginTrip(
        id: UUID,
        profileID: UUID,
        walkMode: Bool,
        simulated: Bool,
        gridCellSizeM: Int
    ) {
        activeTrip = LoggedTrip(
            id: id,
            profileID: profileID,
            startedAt: Date(),
            endedAt: nil,
            walkMode: walkMode,
            simulated: simulated,
            gridCellSizeM: gridCellSizeM,
            samples: [],
            outcome: nil
        )
        persistActiveTrip()
    }

    func append(_ sample: GpsSample) {
        guard var trip = activeTrip else { return }
        trip.samples.append(sample)
        activeTrip = trip
        scheduleFlushActiveTrip()
    }

    func activeTripSnapshot() -> LoggedTrip? {
        activeTrip
    }

    func endTrip(id: UUID, endedAt: Date = Date(), outcome: LoggedTripOutcome?) {
        guard var trip = activeTrip, trip.id == id else { return }
        trip.endedAt = endedAt
        trip.outcome = outcome ?? inferredOutcome(for: trip)
        finalizeTrip(trip)
        activeTrip = nil
        try? fileManager.removeItem(at: activeTripURL)
    }

    func cancelActiveTrip() {
        flushTask?.cancel()
        flushTask = nil
        activeTrip = nil
        try? fileManager.removeItem(at: activeTripURL)
    }

    func trips(for profileID: UUID) -> [LoggedTripSummary] {
        summaries
            .filter { $0.profileID == profileID }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func totalSampleCount(for profileID: UUID) -> Int {
        trips(for: profileID).reduce(0) { $0 + $1.sampleCount }
    }

    func loadTrips(for profileID: UUID) -> [LoggedTrip] {
        trips(for: profileID).compactMap { loadTrip(id: $0.id) }
    }

    func loadTrip(id: UUID) -> LoggedTrip? {
        let url = tripFileURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LoggedTrip.self, from: data)
    }

    func flushPendingWrites() {
        flushTask?.cancel()
        flushTask = nil
        persistActiveTrip()
    }

    // MARK: - Private

    private func tripFileURL(for id: UUID) -> URL {
        logsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func loadIndex() {
        ensureLogsDirectory()
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        summaries = (try? decoder.decode([LoggedTripSummary].self, from: data)) ?? []
    }

    private func saveIndex() {
        ensureLogsDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(summaries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func recoverActiveTripIfNeeded() {
        guard let data = try? Data(contentsOf: activeTripURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var trip = try? decoder.decode(LoggedTrip.self, from: data) else {
            try? fileManager.removeItem(at: activeTripURL)
            return
        }

        if trip.endedAt == nil {
            trip.endedAt = trip.samples.last?.recordedAt ?? trip.startedAt
        }
        if trip.outcome == nil {
            trip.outcome = inferredOutcome(for: trip)
        }
        finalizeTrip(trip)
        activeTrip = nil
        try? fileManager.removeItem(at: activeTripURL)
    }

    private func inferredOutcome(for trip: LoggedTrip) -> LoggedTripOutcome {
        LoggedTripOutcome(
            newCells: 0,
            repeatCells: 0,
            newCellIDs: [],
            repeatCellIDs: [],
            regionsVisited: TripLogMetrics.regionsVisited(in: trip.samples),
            unlockedRegionIDsAtStart: [],
            distanceM: TripLogMetrics.distanceMeters(for: trip.samples),
            durationSeconds: TripLogMetrics.durationSeconds(startedAt: trip.startedAt, endedAt: trip.endedAt),
            averageSpeedMps: TripLogMetrics.averageSpeedMps(for: trip.samples),
            maxSpeedMps: TripLogMetrics.maxSpeedMps(for: trip.samples),
            badgesEarned: [],
            waypointsConfirmed: []
        )
    }

    private func finalizeTrip(_ trip: LoggedTrip) {
        ensureLogsDirectory()
        writeTripFile(trip)

        let outcome = trip.outcome ?? inferredOutcome(for: trip)
        let summary = LoggedTripSummary(
            id: trip.id,
            profileID: trip.profileID,
            startedAt: trip.startedAt,
            endedAt: trip.endedAt,
            sampleCount: trip.sampleCount,
            walkMode: trip.walkMode,
            simulated: trip.simulated,
            gridCellSizeM: trip.gridCellSizeM,
            durationSeconds: outcome.durationSeconds,
            distanceM: outcome.distanceM,
            newCells: outcome.newCells,
            repeatCells: outcome.repeatCells,
            regionsVisited: outcome.regionsVisited,
            maxSpeedMps: outcome.maxSpeedMps,
            averageSpeedMps: outcome.averageSpeedMps,
            badgesEarnedCount: outcome.badgesEarned.count,
            waypointsConfirmedCount: outcome.waypointsConfirmed.count
        )
        summaries.removeAll { $0.id == trip.id }
        summaries.append(summary)
        summaries.sort { $0.startedAt > $1.startedAt }
        saveIndex()
    }

    private func writeTripFile(_ trip: LoggedTrip) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(trip) else { return }
        try? data.write(to: tripFileURL(for: trip.id), options: .atomic)
    }

    private func persistActiveTrip() {
        guard let trip = activeTrip else { return }
        ensureLogsDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(trip) else { return }
        try? data.write(to: activeTripURL, options: .atomic)
    }

    private func scheduleFlushActiveTrip() {
        flushTask?.cancel()
        flushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            persistActiveTrip()
        }
    }

    private func ensureLogsDirectory() {
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }
}
