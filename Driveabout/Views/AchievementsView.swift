import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var achievementStore: AchievementStore

    var body: some View {
        NavigationStack {
            Group {
                if achievementStore.collections.isEmpty {
                    ContentUnavailableView(
                        "No waypoint data",
                        systemImage: "map",
                        description: Text(achievementStore.loadError ?? "Bundled waypoint JSON was not found.")
                    )
                } else {
                    List {
                        if !achievementStore.earnedBadges.isEmpty {
                            Section("Earned awards") {
                                ForEach(achievementStore.earnedBadges) { badge in
                                    HStack {
                                        Image(systemName: "rosette")
                                            .foregroundStyle(.yellow)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(badge.tierName)
                                                .font(.headline)
                                            Text(badge.collectionName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        Section("Collections") {
                            ForEach(achievementStore.collectionProgress) { progress in
                                NavigationLink {
                                    CollectionDetailView(progress: progress)
                                } label: {
                                    CollectionProgressRow(progress: progress)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Badges")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reload") {
                        achievementStore.reload()
                    }
                }
            }
        }
    }
}

private struct CollectionProgressRow: View {
    let progress: CollectionProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(progress.collection.name)
                    .font(.headline)
                Spacer()
                Text("\(progress.confirmedCount)/\(progress.collection.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress.progressFraction)

            if let next = progress.nextTier {
                Text("Next: \(next.name) at \(next.requiredCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !progress.earnedTiers.isEmpty {
                Text("All levels earned")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if !progress.earnedTiers.isEmpty {
                HStack(spacing: 4) {
                    ForEach(progress.earnedTiers) { tier in
                        Text(tier.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.yellow.opacity(0.25), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AchievementsView()
        .environmentObject(AchievementStore())
}
