import CoreLocation
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var visitStore: VisitStore
    @EnvironmentObject private var achievementStore: AchievementStore
    @EnvironmentObject private var locationManager: LocationManager
    @ObservedObject private var driveSimulator = DriveSimulator.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Learner") {
                    LabeledContent("Name", value: visitStore.profile.displayName)
                    LabeledContent("Explored cells", value: "\(visitStore.exploredCellCount)")
                    LabeledContent("Well known cells", value: "\(visitStore.wellKnownCellCount)")
                    LabeledContent("Confirmed waypoints", value: "\(achievementStore.confirmedVisits.count)")
                    LabeledContent("Earned badges", value: "\(achievementStore.earnedBadges.count)")

                    Button("Switch learner") {
                        visitStore.presentLearnerPicker()
                    }
                }

                if visitStore.learners.count > 1 {
                    Section("All learners") {
                        ForEach(visitStore.learners) { learner in
                            HStack {
                                Text(learner.displayName)
                                Spacer()
                                if learner.id == visitStore.profile.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                } else {
                                    Text("\(visitStore.exploredCellCount(for: learner.id)) areas")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
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
                    if driveSimulator.isRunning, let status = driveSimulator.statusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Toggle("Walk testing mode", isOn: Binding(
                        get: { visitStore.walkTestingMode },
                        set: { visitStore.setWalkTestingMode($0) }
                    ))
                    Button("Unlock all zones (dev)") {
                        visitStore.unlockAllRegionsForDevelopment()
                    }
                    Button("Reveal fog here (dev)") {
                        let center = locationManager.lastLocation?.coordinate
                            ?? CLLocationCoordinate2D(
                                latitude: EasternSuburbs.mapCenter.lat,
                                longitude: EasternSuburbs.mapCenter.lng
                            )
                        visitStore.simulateRevealAroundCurrentLocation(
                            lat: center.latitude,
                            lng: center.longitude
                        )
                        locationManager.injectSimulatedLocation(lat: center.latitude, lng: center.longitude)
                    }
                    Button("Simulate short walk (dev)") {
                        let center = simulationOrigin
                        visitStore.simulateShortWalk(fromLat: center.latitude, lng: center.longitude)
                        locationManager.injectSimulatedLocation(
                            lat: center.latitude + 0.003,
                            lng: center.longitude + 0.0008
                        )
                    }
                    Button("Simulate test drive (dev)") {
                        startSimulatedDrive(route: .innerEastToCoast)
                    }
                    .disabled(driveSimulator.isRunning)

                    Button("Simulate city → Bondi Junction (dev)") {
                        startSimulatedDrive(route: .cityToBondiJunction)
                    }
                    .disabled(driveSimulator.isRunning)

                    if driveSimulator.isRunning {
                        Button("Stop simulation", role: .destructive) {
                            driveSimulator.cancel()
                            visitStore.endTrip()
                            locationManager.stopTripTracking()
                        }
                    }
                    Button("Reset map for learner (dev)", role: .destructive) {
                        visitStore.resetMapForCurrentLearner()
                    }
                    #if DEBUG
                    Button("Reset badge progress (dev)", role: .destructive) {
                        achievementStore.resetAllProgress()
                    }
                    #endif
                    Text("Fog uses 100 m squares. Zoom in or start a trip to see black fog clear as you drive. Use Reset map for a clean test.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func startSimulatedDrive(route: DriveSimulationRoute) {
        driveSimulator.runTestDrive(
            route: route,
            visitStore: visitStore,
            locationManager: locationManager,
            achievementStore: achievementStore
        )
    }

    private var simulationOrigin: CLLocationCoordinate2D {
        locationManager.lastLocation?.coordinate
            ?? CLLocationCoordinate2D(
                latitude: EasternSuburbs.mapCenter.lat,
                longitude: EasternSuburbs.mapCenter.lng
            )
    }
}

#Preview {
    ProfileView()
        .environmentObject(VisitStore())
        .environmentObject(AchievementStore())
        .environmentObject(LocationManager())
}
