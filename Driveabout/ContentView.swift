import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MapScreenView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            AchievementsView()
                .tabItem {
                    Label("Badges", systemImage: "rosette")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VisitStore())
        .environmentObject(LocationManager())
        .environmentObject(AchievementStore())
}
