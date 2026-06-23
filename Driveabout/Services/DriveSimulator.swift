import CoreLocation
import Foundation

@MainActor
final class DriveSimulator: ObservableObject {
    static let shared = DriveSimulator()

    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage: String?

    private var activeTask: Task<Void, Never>?
    private var runGeneration = 0

    private init() {}

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        isRunning = false
        statusMessage = nil
    }

    /// Animates a fake drive: moves the car marker and clears fog as if GPS recorded a real trip.
    func runTestDrive(
        route: DriveSimulationRoute = .innerEastToCoast,
        visitStore: VisitStore,
        locationManager: LocationManager,
        achievementStore: AchievementStore,
        stepDelaySeconds: Double = 0.12
    ) {
        cancel()

        runGeneration += 1
        let generation = runGeneration
        isRunning = true
        statusMessage = "Starting \(route.displayName)…"

        activeTask = Task { @MainActor in
            defer {
                if generation == runGeneration {
                    activeTask = nil
                    isRunning = false
                    statusMessage = nil
                    visitStore.setSimulationActive(false)
                }
            }

            visitStore.unlockAllRegionsForDevelopment()
            visitStore.setSimulationActive(true)
            locationManager.stopTripTracking()

            if visitStore.activeTrip == nil {
                visitStore.startTrip()
            }

            let points = route.samplePoints(spacingM: 80)
            guard let firstPoint = points.first else {
                statusMessage = "Simulation route is empty."
                return
            }

            locationManager.injectSimulatedLocation(
                lat: firstPoint.latitude,
                lng: firstPoint.longitude,
                speedMps: 11
            )

            var timestamp = Date()
            var recordedCells = 0

            for (index, point) in points.enumerated() {
                guard !Task.isCancelled, visitStore.activeTrip != nil else { break }

                let nextPoint = index + 1 < points.count ? points[index + 1] : nil
                let course = nextPoint.map { point.bearing(to: $0) } ?? -1

                locationManager.injectSimulatedLocation(
                    lat: point.latitude,
                    lng: point.longitude,
                    course: course,
                    speedMps: 11
                )

                let beforeCount = visitStore.exploredCellCount
                visitStore.ingestSimulated(
                    lat: point.latitude,
                    lng: point.longitude,
                    recordedAt: timestamp,
                    speedMps: 11
                )
                if visitStore.exploredCellCount > beforeCount {
                    recordedCells += 1
                }

                if let trip = visitStore.activeTrip {
                    let sample = GpsSample(
                        recordedAt: timestamp,
                        lat: point.latitude,
                        lng: point.longitude,
                        speedMps: 11,
                        accuracyM: 8,
                        tripID: trip.id
                    )
                    achievementStore.evaluate(sample: sample, tripActive: true)
                }

                statusMessage = "Simulating \(route.displayName) · \(recordedCells) patches cleared"
                timestamp = timestamp.addingTimeInterval(3)

                do {
                    try await Task.sleep(nanoseconds: UInt64(stepDelaySeconds * 1_000_000_000))
                } catch {
                    break
                }
            }

            visitStore.flushPendingSave()
            #if DEBUG
            print("[DriveSimulator] finished route=\(route.displayName) patches=\(recordedCells) explored=\(visitStore.exploredCellCount)")
            #endif
            if generation == runGeneration {
                statusMessage = recordedCells > 0
                    ? "Simulation finished · \(recordedCells) patches cleared"
                    : "Simulation finished with no map changes."
            }
        }
    }
}

private extension CLLocationCoordinate2D {
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLng = (other.longitude - longitude) * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return degrees >= 0 ? degrees : degrees + 360
    }
}
