import Foundation
import MapKit

/// Fog-of-war grid: 100 m cells for both GPS tracking and map display.
enum FogMap {
    static let cellSizeM = 100
    /// Above this latitude span, draw one black sheet over the play area instead of per-cell fog.
    static let detailedFogMaxSpan = 0.08

    struct Cell: Identifiable {
        let id: String
        let bounds: MapBounds

        var polygon: [CLLocationCoordinate2D] {
            [
                CLLocationCoordinate2D(latitude: bounds.minLat, longitude: bounds.minLng),
                CLLocationCoordinate2D(latitude: bounds.minLat, longitude: bounds.maxLng),
                CLLocationCoordinate2D(latitude: bounds.maxLat, longitude: bounds.maxLng),
                CLLocationCoordinate2D(latitude: bounds.maxLat, longitude: bounds.minLng),
            ]
        }
    }

    static func cellID(lat: Double, lng: Double) -> String {
        Grid.cellID(lat: lat, lng: lng, cellSizeM: cellSizeM)
    }

    static func isExplored(cellID: String, visits: [String: CellVisit]) -> Bool {
        visits[cellID] != nil
    }

    static func usesDetailedFog(for region: MKCoordinateRegion) -> Bool {
        region.span.latitudeDelta <= detailedFogMaxSpan
    }

    /// Grid cells covering the current map camera region, with extra padding so edges stay fogged.
    static func cells(onMap region: MKCoordinateRegion, paddingRatio: Double = 0.3) -> [Cell] {
        let padded = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * (1 + paddingRatio),
                longitudeDelta: region.span.longitudeDelta * (1 + paddingRatio)
            )
        )
        return cells(in: padded)
    }

    /// Every grid cell intersecting the visible map region (plus one-cell padding).
    static func cells(in region: MKCoordinateRegion) -> [Cell] {
        let refLat = region.center.latitude
        let halfLat = region.span.latitudeDelta / 2
        let halfLng = region.span.longitudeDelta / 2

        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        let minLng = region.center.longitude - halfLng
        let maxLng = region.center.longitude + halfLng

        let minLatIdx = index(forLatitude: minLat, refLat: refLat) - 1
        let maxLatIdx = index(forLatitude: maxLat, refLat: refLat) + 1
        let minLngIdx = index(forLongitude: minLng, refLat: refLat) - 1
        let maxLngIdx = index(forLongitude: maxLng, refLat: refLat) + 1

        var cells: [Cell] = []
        cells.reserveCapacity((maxLatIdx - minLatIdx + 1) * (maxLngIdx - minLngIdx + 1))

        for latIdx in minLatIdx...maxLatIdx {
            for lngIdx in minLngIdx...maxLngIdx {
                let cell = makeCell(latIdx: latIdx, lngIdx: lngIdx, refLat: refLat)
                guard EasternSuburbs.envelope.intersects(cell.bounds) else { continue }
                cells.append(cell)
            }
        }
        return cells
    }

    // MARK: - Private

    private static func makeCell(latIdx: Int, lngIdx: Int, refLat: Double) -> Cell {
        Cell(
            id: "\(latIdx):\(lngIdx)",
            bounds: bounds(forLatIdx: latIdx, lngIdx: lngIdx, refLat: refLat)
        )
    }

    private static func index(forLatitude lat: Double, refLat: Double) -> Int {
        Int(floor(lat * metersPerDegreeLat / Double(cellSizeM)))
    }

    private static func index(forLongitude lng: Double, refLat: Double) -> Int {
        Int(floor(lng * metersPerDegreeLng(at: refLat) / Double(cellSizeM)))
    }

    private static var metersPerDegreeLat: Double { 111_320.0 }

    private static func metersPerDegreeLng(at lat: Double) -> Double {
        111_320.0 * cos(lat * .pi / 180)
    }

    private static func bounds(forLatIdx latIdx: Int, lngIdx: Int, refLat: Double) -> MapBounds {
        let size = Double(cellSizeM)
        let lngScale = metersPerDegreeLng(at: refLat)

        return MapBounds(
            minLat: Double(latIdx) * size / metersPerDegreeLat,
            minLng: Double(lngIdx) * size / lngScale,
            maxLat: Double(latIdx + 1) * size / metersPerDegreeLat,
            maxLng: Double(lngIdx + 1) * size / lngScale
        )
    }
}

private extension MapBounds {
    func intersects(_ other: MapBounds) -> Bool {
        minLat <= other.maxLat && maxLat >= other.minLat
            && minLng <= other.maxLng && maxLng >= other.minLng
    }
}
