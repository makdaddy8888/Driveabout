# Driveabout waypoints

Curated locations for skill-based achievements. Each collection is a JSON file with geofences, difficulty, and supervisor notes.

## Collections

| File | Achievement set |
|------|-----------------|
| [`narrow-streets.json`](narrow-streets.json) | **Narrow Street Navigator** — 10 tight streets (Chaleyer St, Shadforth St, Atherden St, Argyle Lane, …) |
| [`car-parks.json`](car-parks.json) | **Parking Lot Explorer** — 10 car parks (Bondi Beach, Westfield Bondi Junction, East Village, …) |
| [`hills.json`](hills.json) | **Hill Start Hero** — 10 Eastern Suburbs hill starts (Vaucluse, Bellevue Hill, Dover Heights, Coogee, …) |
| [`roundabouts.json`](roundabouts.json) | **Roundabout Ranger** — 10 roundabouts (Centennial Park, Bondi Junction, Coogee, Woolloomooloo, …) |
| [`expeditions.json`](expeditions.json) | **Coast Expedition** — Watsons Bay ↔ La Perouse in one drive (day + night) |
| [`service-nsw.json`](service-nsw.json) | **Service NSW Trail** — all street-front Service NSW in the play area (no Westfield branches) |
| [`parks.json`](parks.json) | **Park Explorer** — 10 popular parks (Centennial, Queens Park, Nielsen Park, …) |
| [`partner-destinations.json`](partner-destinations.json) | **Destination Drive** — 20 **street-front / drive-thru** teen destinations (no Westfield food courts); optional partner coupons |
| [`petrol-care.json`](petrol-care.json) | **Vehicle Care Cadet** — 8 petrol stations; unlock tyre, washer-fluid, and under-bonnet checklists |
| [`ice-cream.json`](ice-cream.json) | **Scoop Seeker** — 8 street-front gelato & ice cream shops (Messina, Anita, Gelatissimo, …) |

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

## Expedition unlock flow

For [`expeditions.json`](expeditions.json) (coast-to-coast):

1. Start a single trip (supervisor).
2. Enter **Watsons Bay** extreme geofence (Military Road wharf tip).
3. Continue the **same trip** without ending it.
4. Enter **La Perouse** extreme geofence (Anzac Parade point) — order can be reversed.
5. Elapsed time between endpoints must be ≥ 25 minutes (anti-cheat).
6. **Day** variant: both visits between sunrise and sunset.
7. **Night** variant: both visits between sunset and sunrise (NSW logbook night).
8. Complete **both** day and night for the **Coast Commander** badge.

## Partner destination unlock flow

For [`partner-destinations.json`](partner-destinations.json):

1. Destination must have **street frontage** — shopping-centre food courts and mall cinemas are excluded (same rule as Service NSW).
2. GPS enters the road / forecourt geofence while moving below `max_speed_kmh`.
3. Dwell for `min_time_in_geofence_seconds`.
4. Supervisor confirms visit when **parked** (or after drive-thru window — supervisor holds phone).
5. If **sponsored**, an in-app coupon or QR code unlocks; see `advertising_model` in the JSON for B2B packages.
6. Bronze / silver / gold tiers at 5 / 12 / 20 destinations.

Krispy Kreme Mascot is `in_play_envelope: false` — expedition partner just west of the GPS box.

## Vehicle care unlock flow

For [`petrol-care.json`](petrol-care.json):

1. Park in the servo forecourt; engine off.
2. GPS confirms location; supervisor opens the checklist for that visit.
3. Complete modules in order (tyre pressure → washer fluid → tread → wipers/lights → oil basics).
4. Each new module unlocks after visiting enough **unique** stations (see `unlocks_after_stations` in the JSON).
5. **Three Servos** combo badge for spreading checks across three different brands/locations.

## Planned collections

- ~~`car-parks.json`~~ — Parking Lot Explorer (10 navigate) ✓
- ~~`hills.json`~~ — Hill Start Hero ✓
- ~~`roundabouts.json`~~ — Roundabout Ranger ✓
- ~~`partner-destinations.json`~~ — Destination Drive ✓
- ~~`petrol-care.json`~~ — Vehicle Care Cadet ✓
