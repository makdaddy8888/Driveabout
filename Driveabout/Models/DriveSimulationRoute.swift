import CoreLocation
import Foundation

/// Predefined Eastern Suburbs routes for dev GPS simulation.
enum DriveSimulationRoute: String, CaseIterable, Identifiable {
    case innerEastToCoast
    case cityToBondiJunction

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .innerEastToCoast:
            return "Inner East → Coogee → Bronte"
        case .cityToBondiJunction:
            return "City → Paddington → Bondi Junction"
        }
    }

    /// Major junctions along the route.
    var waypoints: [CLLocationCoordinate2D] {
        switch self {
        case .innerEastToCoast:
            return [
                CLLocationCoordinate2D(latitude: -33.8795, longitude: 151.2310), // Rushcutters Bay
                CLLocationCoordinate2D(latitude: -33.8860, longitude: 151.2280), // Paddington
                CLLocationCoordinate2D(latitude: -33.8940, longitude: 151.2480), // Bondi Junction
                CLLocationCoordinate2D(latitude: -33.9050, longitude: 151.2520), // Waverley
                CLLocationCoordinate2D(latitude: -33.9145, longitude: 151.2415), // Randwick
                CLLocationCoordinate2D(latitude: -33.9208, longitude: 151.2558), // Coogee
                CLLocationCoordinate2D(latitude: -33.9105, longitude: 151.2620), // Bronte
                CLLocationCoordinate2D(latitude: -33.8995, longitude: 151.2645), // Tamarama
                CLLocationCoordinate2D(latitude: -33.8940, longitude: 151.2480), // Bondi Junction return
            ]
        case .cityToBondiJunction:
            return [
                CLLocationCoordinate2D(latitude: -33.8738, longitude: 151.2120), // Hyde Park
                CLLocationCoordinate2D(latitude: -33.8785, longitude: 151.2180), // Darlinghurst
                CLLocationCoordinate2D(latitude: -33.8845, longitude: 151.2250), // Paddington
                CLLocationCoordinate2D(latitude: -33.8895, longitude: 151.2360), // Centennial
                CLLocationCoordinate2D(latitude: -33.8940, longitude: 151.2480), // Bondi Junction
            ]
        }
    }

    /// GPS samples roughly every `spacingM` metres along the route.
    func samplePoints(spacingM: Double = 80) -> [CLLocationCoordinate2D] {
        guard waypoints.count >= 2 else { return waypoints }

        var points: [CLLocationCoordinate2D] = [waypoints[0]]
        for index in 0..<(waypoints.count - 1) {
            let start = waypoints[index]
            let end = waypoints[index + 1]
            let segmentLength = start.distance(to: end)
            let steps = max(1, Int(ceil(segmentLength / spacingM)))

            for step in 1...steps {
                let fraction = Double(step) / Double(steps)
                points.append(start.interpolated(to: end, fraction: fraction))
            }
        }
        return points
    }
}

private extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    func interpolated(to other: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude + (other.latitude - latitude) * fraction,
            longitude: longitude + (other.longitude - longitude) * fraction
        )
    }

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
