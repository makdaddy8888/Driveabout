import Foundation

#if targetEnvironment(simulator)
@MainActor
enum SimulatorBootstrap {
    /// Fresh simulator installs start with no learners — auto-create one so dev tools are reachable.
    static func configureIfNeeded(visitStore: VisitStore) {
        guard visitStore.learners.isEmpty else { return }

        visitStore.addLearnerForSimulator(name: "Chloe")
    }

    /// When `SIMULATE_DRIVE=1` is set, run a short test drive after launch (for automated checks).
    static func runAutomatedDriveTestIfRequested(
        visitStore: VisitStore,
        locationManager: LocationManager,
        achievementStore: AchievementStore
    ) {
        guard ProcessInfo.processInfo.environment["SIMULATE_DRIVE"] == "1" else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            DriveSimulator.shared.runTestDrive(
                route: .cityToBondiJunction,
                visitStore: visitStore,
                locationManager: locationManager,
                achievementStore: achievementStore,
                stepDelaySeconds: 0.05
            )
        }
    }
}
#endif
