import Foundation

struct GeofenceBBox: Codable, Hashable {
    let type: String
    let minLat: Double
    let minLng: Double
    let maxLat: Double
    let maxLng: Double

    enum CodingKeys: String, CodingKey {
        case type
        case minLat = "min_lat"
        case minLng = "min_lng"
        case maxLat = "max_lat"
        case maxLng = "max_lng"
    }

    func contains(lat: Double, lng: Double) -> Bool {
        minLat <= lat && lat <= maxLat && minLng <= lng && lng <= maxLng
    }
}

struct UnlockRules: Codable {
    let maxSpeedKmh: Double?
    let supervisorConfirmRequired: Bool?
    let minTimeInGeofenceSeconds: Int?
    let repeatVisitsIncreaseFamiliarity: Bool?

    enum CodingKeys: String, CodingKey {
        case maxSpeedKmh = "max_speed_kmh"
        case supervisorConfirmRequired = "supervisor_confirm_required"
        case minTimeInGeofenceSeconds = "min_time_in_geofence_seconds"
        case repeatVisitsIncreaseFamiliarity = "repeat_visits_increase_familiarity"
    }

    var effectiveMaxSpeedKmh: Double { maxSpeedKmh ?? 40 }
    var effectiveMinDwellSeconds: Int { minTimeInGeofenceSeconds ?? 20 }
    var requiresSupervisorConfirm: Bool { supervisorConfirmRequired ?? true }
}

struct AchievementTierDefinition: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let requiredCount: Int
}

struct WaypointItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let suburb: String?
    let geofence: GeofenceBBox
}

struct WaypointCollection: Identifiable {
    let id: String
    let name: String
    let description: String
    let sourceFile: String
    let unlockRules: UnlockRules
    let tiers: [AchievementTierDefinition]
    let items: [WaypointItem]
}

struct ConfirmedWaypointVisit: Codable, Identifiable, Hashable {
    var id: String { waypointID }
    let waypointID: String
    let collectionID: String
    let confirmedAt: Date
}

struct EarnedBadge: Codable, Identifiable, Hashable {
    var id: String { "\(collectionID):\(tierID)" }
    let collectionID: String
    let collectionName: String
    let tierID: String
    let tierName: String
    let earnedAt: Date
}

struct PendingWaypointConfirm: Identifiable, Equatable {
    var id: String { waypointID }
    let waypointID: String
    let collectionID: String
    let collectionName: String
    let waypointName: String
    let suburb: String?
    let readyAt: Date
}

struct CollectionProgress: Identifiable {
    let collection: WaypointCollection
    let confirmedCount: Int
    let earnedTiers: [AchievementTierDefinition]
    let nextTier: AchievementTierDefinition?

    var id: String { collection.id }

    var progressFraction: Double {
        guard let next = nextTier else { return 1.0 }
        guard next.requiredCount > 0 else { return 0 }
        return min(1.0, Double(confirmedCount) / Double(next.requiredCount))
    }
}

enum WaypointLoader {
    private static let manifests: [(file: String, itemsKey: String)] = [
        ("narrow-streets", "streets"),
        ("car-parks", "car_parks"),
        ("hills", "hills"),
        ("roundabouts", "roundabouts"),
        ("service-nsw", "locations"),
        ("parks", "parks"),
        ("partner-destinations", "destinations"),
        ("ice-cream", "shops"),
        ("petrol-care", "stations"),
    ]

    static func loadCollections() -> (collections: [WaypointCollection], errors: [String]) {
        var collections: [WaypointCollection] = []
        var errors: [String] = []

        for manifest in manifests {
            let fileName = manifest.file
            guard let url = bundleURL(for: fileName) else {
                errors.append("Missing \(fileName).json")
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                guard let collectionID = json["collection_id"] as? String,
                      let collectionName = json["collection_name"] as? String else {
                    errors.append("\(fileName).json: missing collection metadata")
                    continue
                }

                let description = json["description"] as? String ?? ""
                let rulesJSON = json["unlock_rules"] as? [String: Any] ?? json["eligibility_rules"] as? [String: Any] ?? [:]
                let rulesData = try JSONSerialization.data(withJSONObject: rulesJSON)
                let unlockRules = try JSONDecoder().decode(UnlockRules.self, from: rulesData)

                let items = parseItems(json[manifest.itemsKey], fileName: fileName, errors: &errors)
                let tiers = parseTiers(json["achievement_tiers"], totalItems: items.count)

                collections.append(WaypointCollection(
                    id: collectionID,
                    name: collectionName,
                    description: description,
                    sourceFile: "\(fileName).json",
                    unlockRules: unlockRules,
                    tiers: tiers,
                    items: items
                ))
            } catch {
                errors.append("\(fileName).json: \(error.localizedDescription)")
            }
        }

        return (collections.sorted { $0.name < $1.name }, errors)
    }

    private static func bundleURL(for fileName: String) -> URL? {
        Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "waypoints")
            ?? Bundle.main.url(forResource: fileName, withExtension: "json")
    }

    private static func parseItems(_ raw: Any?, fileName: String, errors: inout [String]) -> [WaypointItem] {
        guard let array = raw as? [[String: Any]] else { return [] }

        var items: [WaypointItem] = []
        for entry in array {
            guard let id = entry["id"] as? String,
                  let name = entry["name"] as? String,
                  let geofenceJSON = entry["geofence"] as? [String: Any] else {
                continue
            }
            do {
                let geofenceData = try JSONSerialization.data(withJSONObject: geofenceJSON)
                let geofence = try JSONDecoder().decode(GeofenceBBox.self, from: geofenceData)
                items.append(WaypointItem(
                    id: id,
                    name: name,
                    suburb: entry["suburb"] as? String,
                    geofence: geofence
                ))
            } catch {
                errors.append("\(fileName): invalid geofence for \(entry["id"] ?? "?")")
            }
        }
        return items
    }

    private static func parseTiers(_ raw: Any?, totalItems: Int) -> [AchievementTierDefinition] {
        guard let array = raw as? [[String: Any]] else { return [] }

        return array.compactMap { tier in
            guard let id = tier["id"] as? String,
                  let name = tier["name"] as? String else { return nil }

            var required: Int?
            for (key, value) in tier {
                if key.hasSuffix("_required") {
                    if let count = value as? Int {
                        required = count
                    } else if let token = value as? String, token == "all_eligible" {
                        required = totalItems
                    }
                    break
                }
            }

            guard let required else { return nil }
            return AchievementTierDefinition(id: id, name: name, requiredCount: required)
        }
        .sorted { $0.requiredCount < $1.requiredCount }
    }
}
