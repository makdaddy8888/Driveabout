# Driveabout waypoints

Curated locations for skill-based achievements. Each collection is a JSON file with geofences, difficulty, and supervisor notes.

## Collections

| File | Achievement set |
|------|-----------------|
| [`narrow-streets.json`](narrow-streets.json) | **Narrow Street Navigator** — 10 tight streets (Chaleyer St, Shadforth St, Atherden St, Argyle Lane, …) |

## Geofence format

```json
{
  "id": "chaleyer-street-rose-bay",
  "geofence": {
    "type": "bbox",
    "min_lat": -33.8768,
    "min_lng": 151.2695,
    "max_lat": -33.8732,
    "max_lng": 151.2775
  }
}
```

v2 may use `polyline` geofences snapped to NSW road segment data.

## Unlock flow

1. GPS enters geofence while moving below `max_speed_kmh`
2. Dwell for `min_time_in_geofence_seconds`
3. Supervisor taps confirm on first visit
4. Badge awarded; repeats add familiarity (optional)

## Planned collections

- `car-parks.json` — Parking Lot Explorer (10 navigate)
- `hills.json` — Hill Start Hero
- `roundabouts.json` — Roundabout Ranger
