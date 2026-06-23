import SwiftUI

struct TripHUDView: View {
    @EnvironmentObject private var visitStore: VisitStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var achievementStore: AchievementStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trip = visitStore.activeTrip {
                Label("Trip active", systemImage: "car.fill")
                    .font(.headline)
                Text("New cells: \(trip.newCells) · Revisits: \(trip.repeatCells)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start a trip when the learner is ready to drive.")
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

            HStack {
                if visitStore.activeTrip == nil {
                    Button("Start trip") {
                        visitStore.startTrip()
                        locationManager.startUpdating()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("End trip") {
                        visitStore.endTrip()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TripHUDView()
        .padding()
        .environmentObject(VisitStore())
        .environmentObject(LocationManager())
        .environmentObject(AchievementStore())
}
