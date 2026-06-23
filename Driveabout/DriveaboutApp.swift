import SwiftUI

@main
struct DriveaboutApp: App {
    @StateObject private var visitStore = VisitStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var achievementStore = AchievementStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(visitStore)
                .environmentObject(locationManager)
                .environmentObject(achievementStore)
        }
    }
}
