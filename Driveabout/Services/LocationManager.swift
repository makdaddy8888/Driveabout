import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var lastError: String?
    @Published private(set) var isTripTracking = false

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
    }

    /// Ask for When In Use permission only — does not start continuous GPS.
    func requestPermissionIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            lastError = nil
            refreshSnapshotLocation()
        case .denied, .restricted:
            lastError = "Location access is off. Enable it in Settings to track drives."
        @unknown default:
            break
        }
    }

    /// Continuous GPS for an active trip — 10 m accuracy is enough for 100 m grid cells.
    func startTripTracking(walkMode: Bool = false) {
        guard CLLocationManager.locationServicesEnabled() else {
            lastError = "Location services are disabled on this device."
            return
        }
        guard isAuthorized else {
            lastError = "Location access is required to track a trip."
            requestPermissionIfNeeded()
            return
        }
        guard !isTripTracking else { return }

        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = walkMode ? 50 : 50
        manager.activityType = walkMode ? .fitness : .automotiveNavigation
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        manager.startUpdatingLocation()
        isTripTracking = true
        lastError = nil

        if walkMode {
            Task { @MainActor in
                guard isTripTracking else { return }
                manager.allowsBackgroundLocationUpdates = true
                manager.showsBackgroundLocationIndicator = true
            }
        }
    }

    func injectSimulatedLocation(lat: Double, lng: Double, course: Double = -1, speedMps: Double = 1.4) {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            altitude: 0,
            horizontalAccuracy: 8,
            verticalAccuracy: -1,
            course: course,
            speed: speedMps,
            timestamp: Date()
        )
        lastLocation = location
        lastError = nil
    }

    func stopTripTracking() {
        guard isTripTracking else { return }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        isTripTracking = false
        refreshSnapshotLocation()
    }

    /// One-shot fix for map user dot when not driving.
    func refreshSnapshotLocation() {
        guard isAuthorized, !isTripTracking else { return }
        manager.requestLocation()
    }

    private var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                lastError = nil
                if !isTripTracking {
                    refreshSnapshotLocation()
                }
            case .denied, .restricted:
                lastError = "Location access is off. Enable it in Settings to track drives."
                if isTripTracking {
                    stopTripTracking()
                }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            lastLocation = location
            lastError = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError, clError.code == .denied {
                lastError = "Location access is off. Enable it in Settings to track drives."
                stopTripTracking()
            } else if !isTripTracking, let clError = error as? CLError, clError.code == .locationUnknown {
                // Ignore transient errors from one-shot snapshot requests.
                return
            } else {
                lastError = error.localizedDescription
            }
        }
    }
}

extension CLLocation {
    func asGpsSample(tripID: UUID?) -> GpsSample {
        GpsSample(
            recordedAt: timestamp,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            speedMps: speed >= 0 ? speed : nil,
            accuracyM: horizontalAccuracy >= 0 ? horizontalAccuracy : nil,
            tripID: tripID
        )
    }
}
