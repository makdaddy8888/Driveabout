import Foundation

@MainActor
final class AchievementStore: ObservableObject {
    @Published private(set) var collections: [WaypointCollection] = []
    @Published private(set) var confirmedVisits: [ConfirmedWaypointVisit] = []
    @Published private(set) var earnedBadges: [EarnedBadge] = []
    @Published private(set) var pendingConfirm: PendingWaypointConfirm?
    @Published private(set) var recentlyEarnedBadge: EarnedBadge?
    @Published private(set) var loadError: String?

    private var dwellStartByWaypoint: [String: Date] = [:]
    private var pendingReadySince: [String: Date] = [:]
    private let storageKeyVisits = "driveabout.confirmedVisits"
    private let storageKeyBadges = "driveabout.earnedBadges"

    init() {
        reload()
    }

    func reload() {
        let result = WaypointLoader.loadCollections()
        collections = result.collections
        loadError = result.errors.isEmpty ? nil : result.errors.joined(separator: "\n")
        loadFromDisk()
        recomputeBadges()
    }

    var collectionProgress: [CollectionProgress] {
        collections.map { collection in
            let confirmed = confirmedCount(for: collection.id)
            let earned = earnedTierDefinitions(for: collection.id)
            let next = collection.tiers.first { tier in
                !earned.contains(where: { $0.id == tier.id }) && confirmed < tier.requiredCount
            } ?? collection.tiers.first { tier in
                !earned.contains(where: { $0.id == tier.id })
            }
            return CollectionProgress(
                collection: collection,
                confirmedCount: confirmed,
                earnedTiers: earned,
                nextTier: next
            )
        }
    }

    func isConfirmed(waypointID: String, collectionID: String) -> Bool {
        confirmedVisits.contains { $0.waypointID == waypointID && $0.collectionID == collectionID }
    }

    func confirmedCount(for collectionID: String) -> Int {
        let collection = collections.first { $0.id == collectionID }
        guard let itemIDs = collection?.items.map(\.id) else { return 0 }
        let idSet = Set(itemIDs)
        return Set(confirmedVisits.filter { $0.collectionID == collectionID && idSet.contains($0.waypointID) }.map(\.waypointID)).count
    }

    func evaluate(sample: GpsSample, tripActive: Bool) {
        guard tripActive else {
            clearTransientState()
            return
        }

        let speedKmh = (sample.speedMps ?? 0) * 3.6
        var bestPending: PendingWaypointConfirm?

        for collection in collections {
            for item in collection.items {
                let key = compositeKey(collectionID: collection.id, waypointID: item.id)

                guard item.geofence.contains(lat: sample.lat, lng: sample.lng) else {
                    dwellStartByWaypoint.removeValue(forKey: key)
                    if pendingConfirm?.waypointID != item.id || pendingConfirm?.collectionID != collection.id {
                        pendingReadySince.removeValue(forKey: key)
                    }
                    continue
                }

                guard speedKmh <= collection.unlockRules.effectiveMaxSpeedKmh else {
                    dwellStartByWaypoint.removeValue(forKey: key)
                    continue
                }

                if isConfirmed(waypointID: item.id, collectionID: collection.id),
                   collection.unlockRules.repeatVisitsIncreaseFamiliarity != true {
                    continue
                }

                let dwellStart = dwellStartByWaypoint[key] ?? sample.recordedAt
                dwellStartByWaypoint[key] = dwellStart

                let dwellSeconds = sample.recordedAt.timeIntervalSince(dwellStart)
                guard dwellSeconds >= Double(collection.unlockRules.effectiveMinDwellSeconds) else {
                    continue
                }

                if collection.unlockRules.requiresSupervisorConfirm {
                    if !isConfirmed(waypointID: item.id, collectionID: collection.id) {
                        let readyAt = pendingReadySince[key] ?? sample.recordedAt
                        pendingReadySince[key] = readyAt
                        bestPending = PendingWaypointConfirm(
                            waypointID: item.id,
                            collectionID: collection.id,
                            collectionName: collection.name,
                            waypointName: item.name,
                            suburb: item.suburb,
                            readyAt: readyAt
                        )
                    }
                } else {
                    confirm(
                        waypointID: item.id,
                        collectionID: collection.id,
                        at: sample.recordedAt,
                        silent: true
                    )
                }
            }
        }

        if let bestPending {
            pendingConfirm = bestPending
        } else if pendingConfirm != nil {
            pendingConfirm = nil
        }
    }

    func confirmPending() {
        guard let pending = pendingConfirm else { return }
        confirm(waypointID: pending.waypointID, collectionID: pending.collectionID, at: Date())
        pendingConfirm = nil
        let key = compositeKey(collectionID: pending.collectionID, waypointID: pending.waypointID)
        pendingReadySince.removeValue(forKey: key)
    }

    func dismissPending() {
        pendingConfirm = nil
    }

    func dismissRecentBadge() {
        recentlyEarnedBadge = nil
    }

    private func confirm(waypointID: String, collectionID: String, at date: Date, silent: Bool = false) {
        guard !isConfirmed(waypointID: waypointID, collectionID: collectionID) else { return }

        confirmedVisits.append(ConfirmedWaypointVisit(
            waypointID: waypointID,
            collectionID: collectionID,
            confirmedAt: date
        ))
        saveToDisk()
        let newBadges = recomputeBadges()
        if !silent, let badge = newBadges.last {
            recentlyEarnedBadge = badge
        } else if let badge = newBadges.last {
            recentlyEarnedBadge = badge
        }
    }

    @discardableResult
    private func recomputeBadges() -> [EarnedBadge] {
        var newlyEarned: [EarnedBadge] = []
        var allBadges = earnedBadges

        for collection in collections {
            let count = confirmedCount(for: collection.id)
            for tier in collection.tiers where count >= tier.requiredCount {
                let badge = EarnedBadge(
                    collectionID: collection.id,
                    collectionName: collection.name,
                    tierID: tier.id,
                    tierName: tier.name,
                    earnedAt: Date()
                )
                if !allBadges.contains(where: { $0.id == badge.id }) {
                    allBadges.append(badge)
                    newlyEarned.append(badge)
                }
            }
        }

        if allBadges.count != earnedBadges.count {
            earnedBadges = allBadges.sorted { $0.earnedAt > $1.earnedAt }
            saveToDisk()
        }

        return newlyEarned
    }

    private func earnedTierDefinitions(for collectionID: String) -> [AchievementTierDefinition] {
        guard let collection = collections.first(where: { $0.id == collectionID }) else { return [] }
        let earnedIDs = Set(earnedBadges.filter { $0.collectionID == collectionID }.map(\.tierID))
        return collection.tiers.filter { earnedIDs.contains($0.id) }
    }

    private func compositeKey(collectionID: String, waypointID: String) -> String {
        "\(collectionID)::\(waypointID)"
    }

    private func clearTransientState() {
        dwellStartByWaypoint.removeAll()
        pendingReadySince.removeAll()
        pendingConfirm = nil
    }

    private func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: storageKeyVisits),
           let visits = try? decoder.decode([ConfirmedWaypointVisit].self, from: data) {
            confirmedVisits = visits
        }

        if let data = UserDefaults.standard.data(forKey: storageKeyBadges),
           let badges = try? decoder.decode([EarnedBadge].self, from: data) {
            earnedBadges = badges
        }
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(confirmedVisits) {
            UserDefaults.standard.set(data, forKey: storageKeyVisits)
        }
        if let data = try? encoder.encode(earnedBadges) {
            UserDefaults.standard.set(data, forKey: storageKeyBadges)
        }
    }

    #if DEBUG
    func resetAllProgress() {
        confirmedVisits = []
        earnedBadges = []
        pendingConfirm = nil
        recentlyEarnedBadge = nil
        dwellStartByWaypoint.removeAll()
        pendingReadySince.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKeyVisits)
        UserDefaults.standard.removeObject(forKey: storageKeyBadges)
    }
    #endif
}
