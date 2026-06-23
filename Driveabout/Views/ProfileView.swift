import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var visitStore: VisitStore
    @EnvironmentObject private var achievementStore: AchievementStore

    var body: some View {
        NavigationStack {
            List {
                Section("Learner") {
                    LabeledContent("Name", value: visitStore.profile.displayName)
                    LabeledContent("Explored cells", value: "\(visitStore.exploredCellCount)")
                    LabeledContent("Well known cells", value: "\(visitStore.wellKnownCellCount)")
                    LabeledContent("Confirmed waypoints", value: "\(achievementStore.confirmedVisits.count)")
                    LabeledContent("Earned badges", value: "\(achievementStore.earnedBadges.count)")
                }

                Section("Zones") {
                    ForEach(PlayRegion.all) { region in
                        HStack {
                            Text(region.name)
                            Spacer()
                            if visitStore.unlockedRegions.isUnlocked(region.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if region.free {
                                Text("Free")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Locked")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Section("Development") {
                    Button("Unlock all zones (dev)") {
                        visitStore.unlockAllRegionsForDevelopment()
                    }
                    #if DEBUG
                    Button("Reset badge progress (dev)", role: .destructive) {
                        achievementStore.resetAllProgress()
                    }
                    #endif
                    Text("StoreKit IAP is not wired in v1 scaffold. Use dev unlocks to test outside the free City zone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Safety") {
                    Text("The supervising adult holds the phone. The learner keeps both hands on the wheel. Driveabout is not an official NSW logbook.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(VisitStore())
        .environmentObject(AchievementStore())
}
