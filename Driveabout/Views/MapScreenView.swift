import Combine
import MapKit
import SwiftUI

struct MapScreenView: View {
    @EnvironmentObject private var visitStore: VisitStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var achievementStore: AchievementStore

    @State private var cameraPosition: MapCameraPosition = .region(Self.defaultRegion)
    @State private var showRegionOverlays = true

    private static var defaultRegion: MKCoordinateRegion {
        let center = EasternSuburbs.mapCenter
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: center.lat, longitude: center.lng),
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.12)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    ForEach(visitStore.visits.values) { visit in
                        Annotation("", coordinate: visit.coordinate, anchor: .center) {
                            Circle()
                                .fill(Color.accentColor.opacity(1 - visit.fogLevel.opacity))
                                .frame(width: 8, height: 8)
                        }
                    }

                    if showRegionOverlays {
                        ForEach(PlayRegion.all) { region in
                            MapPolygon(coordinates: region.bounds.polygonCoordinates)
                                .foregroundStyle(regionOverlayColor(for: region))
                                .stroke(regionStrokeColor(for: region), lineWidth: 1.5)
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }

                TripHUDView()
                    .padding()
            }
            .navigationTitle("Driveabout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRegionOverlays.toggle()
                    } label: {
                        Image(systemName: showRegionOverlays ? "square.3.layers.3d.top.filled" : "square.3.layers.3d")
                    }
                    .accessibilityLabel("Toggle zone outlines")
                }
            }
            .onAppear {
                locationManager.requestPermissionIfNeeded()
            }
            .onReceive(locationManager.$lastLocation) { location in
                guard let location else { return }
                let sample = location.asGpsSample(tripID: visitStore.activeTrip?.id)
                if visitStore.activeTrip != nil {
                    visitStore.ingest(sample)
                }
                achievementStore.evaluate(sample: sample, tripActive: visitStore.activeTrip != nil)
            }
            .alert("Badge unlocked!", isPresented: badgeAlertBinding) {
                Button("Nice!") {
                    achievementStore.dismissRecentBadge()
                }
            } message: {
                if let badge = achievementStore.recentlyEarnedBadge {
                    Text("\(badge.tierName)\n\(badge.collectionName)")
                }
            }
        }
    }

    private var badgeAlertBinding: Binding<Bool> {
        Binding(
            get: { achievementStore.recentlyEarnedBadge != nil },
            set: { if !$0 { achievementStore.dismissRecentBadge() } }
        )
    }

    private func regionOverlayColor(for region: PlayRegion) -> Color {
        if visitStore.unlockedRegions.isUnlocked(region.id) {
            return Color.green.opacity(0.08)
        }
        return Color.orange.opacity(0.12)
    }

    private func regionStrokeColor(for region: PlayRegion) -> Color {
        visitStore.unlockedRegions.isUnlocked(region.id) ? .green : .orange
    }
}

private extension CellVisit {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centroidLat, longitude: centroidLng)
    }
}

private extension MapBounds {
    var polygonCoordinates: [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLng),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLng),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLng),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLng),
        ]
    }
}

#Preview {
    MapScreenView()
        .environmentObject(VisitStore())
        .environmentObject(LocationManager())
        .environmentObject(AchievementStore())
}
