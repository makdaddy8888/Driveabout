import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var visitStore: VisitStore

    var body: some View {
        Group {
            if visitStore.showingLearnerPicker {
                LearnerPickerView()
            } else {
                MainTabView()
            }
        }
        .environmentObject(DriveSimulator.shared)
    }
}

private struct MainTabView: View {
    @ObservedObject private var driveSimulator = DriveSimulator.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapScreenView()
                .tag(0)
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            AchievementsView()
                .tag(1)
                .tabItem {
                    Label("Badges", systemImage: "rosette")
                }

            LoggedTripsView()
                .tag(2)
                .tabItem {
                    Label("Logged trips", systemImage: "road.lanes")
                }

            ProfileView()
                .tag(3)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .onChange(of: driveSimulator.isRunning) { _, running in
            if running {
                selectedTab = 0
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VisitStore())
        .environmentObject(TripLogStore())
        .environmentObject(LocationManager())
        .environmentObject(AchievementStore())
}
