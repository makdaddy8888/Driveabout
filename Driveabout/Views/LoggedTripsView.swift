import SwiftUI

struct LoggedTripsView: View {
    @EnvironmentObject private var visitStore: VisitStore
    @EnvironmentObject private var tripLogStore: TripLogStore

    private var trips: [LoggedTripSummary] {
        tripLogStore.trips(for: visitStore.profile.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView {
                        Label("No logged trips yet", systemImage: "road.lanes")
                    } description: {
                        Text("Start a trip on the map. Every drive saves GPS, speed, areas unlocked, and badges so the fog map can be rebuilt later.")
                    }
                } else {
                    List {
                        Section {
                            LabeledContent("Logged trips", value: "\(trips.count)")
                            LabeledContent("GPS points saved", value: "\(tripLogStore.totalSampleCount(for: visitStore.profile.id))")
                            Button("Rebuild map from all trip logs") {
                                visitStore.rebuildMapFromTripLogs()
                            }
                        } footer: {
                            Text("Rebuild recalculates fog cells from saved GPS history using the current 100 m grid.")
                        }

                        Section("Trips") {
                            ForEach(trips) { summary in
                                NavigationLink {
                                    LoggedTripDetailView(tripID: summary.id)
                                } label: {
                                    LoggedTripRow(summary: summary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Logged trips")
        }
    }
}

private struct LoggedTripRow: View {
    let summary: LoggedTripSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.startedAt, format: .dateTime.day().month(.wide).year())
                    .font(.headline)
                Spacer()
                if summary.simulated {
                    Text("Simulated")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            Text(summary.startedAt, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(formattedDuration(summary.durationSeconds), systemImage: "clock")
                Label(formattedDistance(summary.distanceM), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if summary.newCells > 0 || summary.badgesEarnedCount > 0 {
                HStack(spacing: 12) {
                    if summary.newCells > 0 {
                        Label("\(summary.newCells) new areas", systemImage: "square.grid.3x3.bottomleft.filled")
                    }
                    if summary.badgesEarnedCount > 0 {
                        Label("\(summary.badgesEarnedCount) badges", systemImage: "rosette")
                    }
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(max(total, 1))s"
    }

    private func formattedDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}

struct LoggedTripDetailView: View {
    @EnvironmentObject private var visitStore: VisitStore
    @EnvironmentObject private var tripLogStore: TripLogStore

    let tripID: UUID

    private var trip: LoggedTrip? {
        tripLogStore.loadTrip(id: tripID)
    }

    var body: some View {
        Group {
            if let trip {
                List {
                    Section("When") {
                        LabeledContent("Date", value: trip.startedAt.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Start", value: trip.startedAt.formatted(date: .omitted, time: .shortened))
                        if let endedAt = trip.endedAt {
                            LabeledContent("End", value: endedAt.formatted(date: .omitted, time: .shortened))
                        }
                        LabeledContent("Duration", value: formattedDuration(trip.durationSeconds))
                    }

                    Section("Drive") {
                        LabeledContent("Distance", value: formattedDistance(trip.distanceM))
                        LabeledContent("GPS points", value: "\(trip.sampleCount)")
                        LabeledContent("Mode", value: trip.walkMode ? "Walk testing" : "Drive")
                        if trip.simulated {
                            LabeledContent("Source", value: "Simulated")
                        }
                        if let maxSpeed = trip.maxSpeedMps {
                            LabeledContent("Top speed", value: String(format: "%.0f km/h", maxSpeed * 3.6))
                        }
                        if let avgSpeed = trip.averageSpeedMps {
                            LabeledContent("Average speed", value: String(format: "%.0f km/h", avgSpeed * 3.6))
                        }
                    }

                    if let outcome = trip.outcome {
                        Section("Map progress") {
                            LabeledContent("New areas", value: "\(outcome.newCells)")
                            LabeledContent("Revisited areas", value: "\(outcome.repeatCells)")
                            if !outcome.regionsVisitedNames.isEmpty {
                                LabeledContent("Zones visited", value: outcome.regionsVisitedNames.joined(separator: ", "))
                            }
                            LabeledContent("Grid cell size", value: "\(trip.gridCellSizeM) m")
                        }

                        if !outcome.badgesEarned.isEmpty {
                            Section("Badges earned") {
                                ForEach(outcome.badgesEarned) { badge in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(badge.tierName)
                                            .font(.headline)
                                        Text(badge.collectionName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(badge.earnedAt.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        if !outcome.waypointsConfirmed.isEmpty {
                            Section("Waypoints confirmed") {
                                ForEach(outcome.waypointsConfirmed) { waypoint in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(waypoint.waypointName ?? waypoint.waypointID)
                                            .font(.headline)
                                        if let collectionName = waypoint.collectionName {
                                            Text(collectionName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(waypoint.confirmedAt.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        if !outcome.newCellIDs.isEmpty {
                            Section("New cell IDs (\(outcome.newCellIDs.count))") {
                                Text(outcome.newCellIDs.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        Button("Rebuild map from this trip") {
                            if let loaded = tripLogStore.loadTrip(id: tripID) {
                                visitStore.rebuildMap(from: [loaded], profileID: visitStore.profile.id)
                            }
                        }
                    } footer: {
                        Text("Trip files include full GPS history plus cell IDs, zones, and badges — everything needed to restore fog progress.")
                    }
                }
            } else {
                ContentUnavailableView("Trip not found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Trip detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, secs)
        }
        return "\(max(total, 1))s"
    }

    private func formattedDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}

#Preview {
    LoggedTripsView()
        .environmentObject(VisitStore())
        .environmentObject(TripLogStore())
}
