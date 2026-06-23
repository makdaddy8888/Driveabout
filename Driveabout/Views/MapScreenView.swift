import Combine
import MapKit
import SwiftUI

struct MapScreenView: View {
    @EnvironmentObject private var visitStore: VisitStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var achievementStore: AchievementStore

    @ObservedObject private var driveSimulator = DriveSimulator.shared

    @State private var cameraPosition: MapCameraPosition = .region(Self.defaultRegion)
    @State private var showRegionOverlays = false
    @State private var mapRegion = Self.defaultRegion
    @State private var fogCells: [FogMap.Cell] = []
    @State private var markerHeading: Double?

    private static let minimumMarkerSpeedMps = 2.5
    private static let tripMapSpan = 0.018

    private static var defaultRegion: MKCoordinateRegion {
        let center = EasternSuburbs.mapCenter
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: center.lat, longitude: center.lng),
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.12)
        )
    }

    private var showDetailedFog: Bool {
        visitStore.activeTrip != nil
            || driveSimulator.isRunning
            || FogMap.usesDetailedFog(for: mapRegion)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $cameraPosition) {
                    MapPolygon(coordinates: EasternSuburbs.envelope.polygonCoordinates)
                        .foregroundStyle(.clear)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1.5)

                    if showRegionOverlays {
                        ForEach(PlayRegion.all) { region in
                            MapPolygon(coordinates: region.bounds.polygonCoordinates)
                                .foregroundStyle(regionOverlayColor(for: region))
                                .stroke(regionStrokeColor(for: region), lineWidth: 1.5)
                        }
                    }

                    fogLayer

                    if let location = locationManager.lastLocation {
                        Annotation("You", coordinate: location.coordinate, anchor: .center) {
                            CarLocationMarker(rotationDegrees: markerHeading)
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    mapRegion = context.region
                    refreshFogCellsIfNeeded()
                }

                TripHUDView()
                    .padding()
            }
            .navigationTitle(visitStore.profile.displayName)
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
                refreshFogCellsIfNeeded()
            }
            .onReceive(locationManager.$lastLocation) { location in
                updateMarkerHeading(from: location)
                if visitStore.activeTrip != nil || driveSimulator.isRunning {
                    followUserIfOnTrip()
                    refreshFogCellsIfNeeded()
                }
            }
            .onChange(of: visitStore.exploredCellCount) { _, _ in
                refreshFogCellsIfNeeded()
            }
            .onChange(of: visitStore.activeTrip?.id) { _, _ in
                refreshFogCellsIfNeeded()
                followUserIfOnTrip()
            }
            .onChange(of: driveSimulator.isRunning) { _, _ in
                refreshFogCellsIfNeeded()
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

    @MapContentBuilder
    private var fogLayer: some MapContent {
        if showDetailedFog {
            ForEach(fogCells) { cell in
                if !visitStore.isExplored(cellID: cell.id) {
                    MapPolygon(coordinates: cell.polygon)
                        .foregroundStyle(Color.black.opacity(0.88))
                }
            }
        } else {
            MapPolygon(coordinates: EasternSuburbs.envelope.polygonCoordinates)
                .foregroundStyle(Color.black.opacity(0.88))
        }
    }

    private func fogSamplingRegion() -> MKCoordinateRegion {
        if visitStore.activeTrip != nil || driveSimulator.isRunning,
           let coordinate = locationManager.lastLocation?.coordinate {
            return MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: Self.tripMapSpan,
                    longitudeDelta: Self.tripMapSpan
                )
            )
        }
        return mapRegion
    }

    private func refreshFogCellsIfNeeded() {
        guard showDetailedFog else {
            fogCells = []
            return
        }
        fogCells = FogMap.cells(onMap: fogSamplingRegion(), paddingRatio: 0.35)
    }

    private func updateMarkerHeading(from location: CLLocation?) {
        guard let location else { return }
        let speed = location.speed >= 0 ? location.speed : 0
        guard speed >= Self.minimumMarkerSpeedMps, location.course >= 0 else { return }
        markerHeading = location.course
    }

    private func followUserIfOnTrip() {
        guard visitStore.activeTrip != nil || driveSimulator.isRunning,
              let coordinate = locationManager.lastLocation?.coordinate else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: Self.tripMapSpan,
                    longitudeDelta: Self.tripMapSpan
                )
            )
        )
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
        return Color.orange.opacity(0.10)
    }

    private func regionStrokeColor(for region: PlayRegion) -> Color {
        visitStore.unlockedRegions.isUnlocked(region.id) ? .green : .orange
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
