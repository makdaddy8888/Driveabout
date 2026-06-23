import Combine
import SwiftUI

@main
struct DriveaboutApp: App {
    @StateObject private var visitStore = VisitStore()
    @StateObject private var tripLogStore = TripLogStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var achievementStore = AchievementStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(visitStore)
                .environmentObject(tripLogStore)
                .environmentObject(locationManager)
                .environmentObject(achievementStore)
                .onAppear {
                    visitStore.configureTripLogging(tripLogStore)
                    visitStore.configureAchievementTracking(achievementStore)
                    #if targetEnvironment(simulator)
                    SimulatorBootstrap.configureIfNeeded(visitStore: visitStore)
                    SimulatorBootstrap.runAutomatedDriveTestIfRequested(
                        visitStore: visitStore,
                        locationManager: locationManager,
                        achievementStore: achievementStore
                    )
                    #endif
                }
                .onReceive(locationManager.$lastLocation) { location in
                    guard !visitStore.isSimulationActive else { return }
                    guard let location, let trip = visitStore.activeTrip else { return }
                    let sample = location.asGpsSample(tripID: trip.id)
                    visitStore.ingest(sample)
                    achievementStore.evaluate(sample: sample, tripActive: true)
                }
        }
    }
}
