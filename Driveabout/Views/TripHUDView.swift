import CoreLocation
import SwiftUI

struct TripHUDView: View {
    @EnvironmentObject private var visitStore: VisitStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var achievementStore: AchievementStore
    @ObservedObject private var driveSimulator = DriveSimulator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if driveSimulator.isRunning {
                Label("Simulation running", systemImage: "location.fill.viewfinder")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if let trip = visitStore.activeTrip {
                Label("Trip with \(visitStore.profile.displayName)", systemImage: "car.fill")
                    .font(.headline)
                Text("New cells: \(trip.newCells) · Revisits: \(trip.repeatCells)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Explored cells: \(visitStore.exploredCellCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(
                    visitStore.walkTestingMode
                        ? "Start a walk test with \(visitStore.profile.displayName)."
                        : "Start a trip with \(visitStore.profile.displayName) when ready to drive."
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let pending = achievementStore.pendingConfirm {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Waypoint ready", systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                    Text("\(pending.waypointName)\(pending.suburb.map { ", \($0)" } ?? "")")
                        .font(.caption)
                    Text(pending.collectionName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Confirm visit") {
                            achievementStore.confirmPending()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Not yet") {
                            achievementStore.dismissPending()
                        }
                        .buttonStyle(.bordered)
                    }
                    Text("Supervisor confirms when parked — learner keeps hands on the wheel.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let regionName = visitStore.lastProcessedRegionName {
                Text("Zone: \(regionName)")
                    .font(.caption)
            }

            if let reason = visitStore.trackingBlockedReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let error = locationManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if driveSimulator.isRunning {
                Button("Stop simulation", role: .destructive) {
                    stopSimulation()
                }
                .buttonStyle(.borderedProminent)
            }

            HStack {
                if visitStore.activeTrip == nil {
                    Button(visitStore.walkTestingMode ? "Start walk test" : "Start trip") {
                        visitStore.startTrip()
                        locationManager.startTripTracking(walkMode: visitStore.walkTestingMode)
                        if let location = locationManager.lastLocation {
                            visitStore.ingestCurrentLocation(location)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(driveSimulator.isRunning)
                } else {
                    Button("End trip") {
                        stopSimulation()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                if visitStore.walkTestingMode, !driveSimulator.isRunning {
                    Button("Simulate drive") {
                        runSimulatedDrive()
                    }
                    .buttonStyle(.bordered)

                    if visitStore.activeTrip != nil {
                        Button("Simulate walk") {
                            runSimulatedWalk()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func stopSimulation() {
        driveSimulator.cancel()
        visitStore.endTrip()
        locationManager.stopTripTracking()
    }

    private func runSimulatedWalk() {
        let center = simulationOrigin
        visitStore.simulateShortWalk(fromLat: center.latitude, lng: center.longitude)

        for step in 0..<6 {
            locationManager.injectSimulatedLocation(
                lat: center.latitude + Double(step) * 0.000027,
                lng: center.longitude + (step.isMultiple(of: 2) ? 0 : 0.000022)
            )
        }
    }

    private func runSimulatedDrive() {
        if visitStore.activeTrip == nil {
            visitStore.startTrip()
        }
        driveSimulator.runTestDrive(
            route: .innerEastToCoast,
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
    TripHUDView()
        .padding()
        .environmentObject(VisitStore())
        .environmentObject(LocationManager())
        .environmentObject(AchievementStore())
}
