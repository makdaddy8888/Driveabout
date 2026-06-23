import Foundation
import MapKit

/// Precomputed fog cells covering the Eastern Suburbs play envelope.
/// Uses a coarser grid than visit tracking (200 m) to keep map overlays responsive.
enum FogGrid {
    static let displayCellSizeM = 500

    struct Cell: Identifiable {
        let id: String
        let bounds: MapBounds

        var polygonCoordinates: [CLLocationCoordinate2D] {
            [
                CLLocationCoordinate2D(latitude: bounds.minLat, longitude: bounds.minLng),
                CLLocationCoordinate2D(latitude: bounds.minLat, longitude: bounds.maxLng),
                CLLocationCoordinate2D(latitude: bounds.maxLat, longitude: bounds.maxLng),
                CLLocationCoordinate2D(latitude: bounds.maxLat, longitude: bounds.minLng),
            ]
        }

        var center: CLLocationCoordinate2D {
            CLLocationCoordinate2D(
                latitude: (bounds.minLat + bounds.maxLat) / 2,
                longitude: (bounds.minLng + bounds.maxLng) / 2
            )
        }
    }

    static let cells: [Cell] = buildCells()
    private static let cellsByID: [String: Cell] = Dictionary(uniqueKeysWithValues: cells.map { ($0.id, $0) })

    static func cellID(lat: Double, lng: Double) -> String {
        Grid.cellID(lat: lat, lng: lng, cellSizeM: displayCellSizeM)
    }

    static func opacity(
        for cellID: String,
        visits: [String: CellVisit],
        visitCellSizeM: Int = Grid.defaultCellSizeM
    ) -> Double {
        let base = baseOpacity(for: cellID, visits: visits, visitCellSizeM: visitCellSizeM)
        guard base >= 1.0 else { return base }

        let (latIdx, lngIdx) = parseIndices(cellID)
        for dLat in -1...1 {
            for dLng in -1...1 where dLat != 0 || dLng != 0 {
                let neighbourID = "\(latIdx + dLat):\(lngIdx + dLng)"
                if baseOpacity(for: neighbourID, visits: visits, visitCellSizeM: visitCellSizeM) < 1.0 {
                    return max(0.0, base - 0.1)
                }
            }
        }
        return base
    }

    static func buildOpacityMap(
        visits: [String: CellVisit],
        visitCellSizeM: Int = Grid.defaultCellSizeM
    ) -> [String: Double] {
        var map: [String: Double] = [:]
        map.reserveCapacity(cells.count)
        for cell in cells {
            map[cell.id] = opacity(for: cell.id, visits: visits, visitCellSizeM: visitCellSizeM)
        }
        return map
    }

    // MARK: - Private

    private static func buildCells() -> [Cell] {
        let envelope = EasternSuburbs.envelope
        let refLat = (envelope.minLat + envelope.maxLat) / 2
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLng = 111_320.0 * cos(refLat * .pi / 180)
        let size = Double(displayCellSizeM)

        let minLatIdx = Int(floor(envelope.minLat * metersPerDegreeLat / size))
        let maxLatIdx = Int(floor(envelope.maxLat * metersPerDegreeLat / size))
        let minLngIdx = Int(floor(envelope.minLng * metersPerDegreeLng / size))
        let maxLngIdx = Int(floor(envelope.maxLng * metersPerDegreeLng / size))

        var result: [Cell] = []
        result.reserveCapacity((maxLatIdx - minLatIdx + 1) * (maxLngIdx - minLngIdx + 1))

        for latIdx in minLatIdx...maxLatIdx {
            for lngIdx in minLngIdx...maxLngIdx {
                let id = "\(latIdx):\(lngIdx)"
                let bounds = bounds(forLatIdx: latIdx, lngIdx: lngIdx, refLat: refLat)
                guard bounds.intersects(envelope) else { continue }
                result.append(Cell(id: id, bounds: bounds))
            }
        }
        return result
    }

    private static func bounds(forLatIdx latIdx: Int, lngIdx: Int, refLat: Double) -> MapBounds {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLng = 111_320.0 * cos(refLat * .pi / 180)
        let size = Double(displayCellSizeM)

        return MapBounds(
            minLat: Double(latIdx) * size / metersPerDegreeLat,
            minLng: Double(lngIdx) * size / metersPerDegreeLng,
            maxLat: Double(latIdx + 1) * size / metersPerDegreeLat,
            maxLng: Double(lngIdx + 1) * size / metersPerDegreeLng
        )
    }

    private static func baseOpacity(
        for cellID: String,
        visits: [String: CellVisit],
        visitCellSizeM: Int
    ) -> Double {
        guard let cell = cellsByID[cellID] else { return 1.0 }

        var bestVisitCount = 0
        var hasVisit = false
        for visit in visits.values where cell.bounds.contains(lat: visit.centroidLat, lng: visit.centroidLng) {
            hasVisit = true
            bestVisitCount = max(bestVisitCount, visit.visitCount)
        }

        guard hasVisit else { return 1.0 }
        return FogLevel(visitCount: bestVisitCount).opacity
    }

    private static func parseIndices(_ cellID: String) -> (Int, Int) {
        let parts = cellID.split(separator: ":")
        guard parts.count == 2,
              let latIdx = Int(parts[0]),
              let lngIdx = Int(parts[1]) else {
            return (0, 0)
        }
        return (latIdx, lngIdx)
    }
}

private extension MapBounds {
    func intersects(_ other: MapBounds) -> Bool {
        minLat <= other.maxLat && maxLat >= other.minLat
            && minLng <= other.maxLng && maxLng >= other.minLng
    }
}
