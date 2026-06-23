import SwiftUI

struct CollectionDetailView: View {
    @EnvironmentObject private var achievementStore: AchievementStore
    let progress: CollectionProgress

    var body: some View {
        List {
            Section {
                Text(progress.collection.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Levels") {
                ForEach(progress.collection.tiers) { tier in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.name)
                                .font(.headline)
                            Text("\(tier.requiredCount) locations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if progress.earnedTiers.contains(where: { $0.id == tier.id }) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else if progress.confirmedCount >= tier.requiredCount {
                            Image(systemName: "checkmark.seal")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section("Locations") {
                ForEach(progress.collection.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                            if let suburb = item.suburb {
                                Text(suburb)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if achievementStore.isConfirmed(waypointID: item.id, collectionID: progress.collection.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle(progress.collection.name)
    }
}

#Preview {
    NavigationStack {
        CollectionDetailView(progress: CollectionProgress(
            collection: WaypointCollection(
                id: "demo",
                name: "Demo",
                description: "Example collection",
                sourceFile: "demo.json",
                unlockRules: UnlockRules(
                    maxSpeedKmh: 30,
                    supervisorConfirmRequired: true,
                    minTimeInGeofenceSeconds: 20,
                    repeatVisitsIncreaseFamiliarity: false
                ),
                tiers: [
                    AchievementTierDefinition(id: "bronze", name: "Bronze", requiredCount: 3)
                ],
                items: []
            ),
            confirmedCount: 0,
            earnedTiers: [],
            nextTier: AchievementTierDefinition(id: "bronze", name: "Bronze", requiredCount: 3)
        ))
    }
    .environmentObject(AchievementStore())
}
