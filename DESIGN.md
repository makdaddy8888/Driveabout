# Driveabout — Design Sketch

Gamify driving by tracking where someone has been and revealing the map over time. The supervising adult runs the app; the car's route drives progress.

## Core loop

1. GPS samples arrive while the vehicle moves.
2. Each sample maps to a **grid cell**.
3. Cell visits are stored (first seen, count, last seen).
4. The map renders a **fog overlay**: unexplored cells stay hidden; explored cells clear; frequently visited cells sharpen.

All of this is scoped to **Eastern Suburbs, Sydney** — keeping data volume and build effort small for v1.

---

## Play area — Eastern Suburbs, Sydney

v1 is bounded to a single corridor along the coast:

| Edge | Approximate anchor |
|------|-------------------|
| **North** | Watsons Bay |
| **South** | La Perouse |
| **West** | City of Sydney (CBD) |
| **East** | Coast / harbour heads |

Master bounding box (see `regions.py`):

```
min_lat -33.995  (La Perouse)
min_lng  151.198  (City of Sydney)
max_lat -33.835  (Watsons Bay)
max_lng  151.292  (harbour)
```

GPS samples **outside** this envelope are discarded — no storage, no map updates.

### Sub-regions (monetisation zones)

The play area is split into five zones. Overlaps resolve by priority (city first).

| Zone | ID | Default | Covers (approx.) |
|------|-----|---------|------------------|
| **Sydney City** | `city` | **Free** | CBD, The Rocks, Woolloomooloo |
| **Harbour & Watsons Bay** | `harbour` | Paid | Rose Bay, Vaucluse, Watsons Bay |
| **Inner East** | `inner_east` | Paid | Paddington, Bondi Junction, Randwick |
| **Coastal** | `coast` | Paid | Bondi, Coogee, Maroubra |
| **La Perouse & Botany Bay** | `botany_bay` | Paid | La Perouse, Phillip Bay, Little Bay |

### Monetisation model

- **First area free** — `city` unlocks on install. Users can explore and gamify the CBD without paying.
- **Paid zones** — other regions unlock via **StoreKit** non-consumable IAP (buy once, keep forever).
- **Locked-zone behaviour** — driving through a paid zone without owning it:
  - Map shows the zone outline (teaser) but fog does not clear.
  - Visits are **not recorded** until the zone is purchased.
  - UI prompts: *"Unlock Coastal to track this area."*
- **Bundle (later)** — optional single IAP for all Eastern Suburbs zones.

This keeps storage bounded (finite cell count per zone), gives a clear free trial, and creates a natural upgrade path as learners venture beyond the city.

---

## Visit data model

### GridCellID

Stable identifier for a map square. Use a fixed cell size in metres (default **100 m**).

```
cell_id = "{lat_index}:{lng_index}"
```

Where indices are computed from WGS84 coordinates (see `grid.py`).

### CellVisit

One row per explored cell per driver profile.

| Field | Type | Description |
|-------|------|-------------|
| `cell_id` | string | Primary key with `profile_id` |
| `profile_id` | uuid | Driver whose map this belongs to |
| `first_visited_at` | ISO datetime | First time this cell was entered |
| `last_visited_at` | ISO datetime | Most recent visit |
| `visit_count` | int | Times the cell was entered (see entry rule below) |
| `centroid_lat` | float | Centre of cell (for map rendering) |
| `centroid_lng` | float | Centre of cell |

### GpsSample (ephemeral / optional persist)

Raw points for trip replay or debugging. Not required for fog logic.

| Field | Type | Description |
|-------|------|-------------|
| `recorded_at` | ISO datetime | Sample timestamp |
| `lat`, `lng` | float | WGS84 |
| `speed_mps` | float? | Metres per second |
| `accuracy_m` | float? | Horizontal accuracy |
| `trip_id` | uuid? | Active trip, if any |

### Trip (optional v1)

Groups samples for stats ("today you explored 12 new cells").

| Field | Type | Description |
|-------|------|-------------|
| `trip_id` | uuid | Primary key |
| `profile_id` | uuid | Driver |
| `started_at` | ISO datetime | |
| `ended_at` | ISO datetime? | Null while active |
| `new_cells` | int | Cells first visited this trip |
| `repeat_cells` | int | Re-visits this trip |

### DriverProfile

| Field | Type | Description |
|-------|------|-------------|
| `profile_id` | uuid | Primary key |
| `display_name` | string | e.g. learner name |
| `created_at` | ISO datetime | |
| `home_region` | bbox? | Defaults to owned zones within Eastern Suburbs |

### AppState (singleton)

| Field | Type | Description |
|-------|------|-------------|
| `active_profile_id` | uuid? | Whose map is unlocking |
| `active_trip_id` | uuid? | Current session |
| `tracking_enabled` | bool | User toggle |
| `cell_size_m` | int | Default 100 |

---

## When does a cell count as "visited"?

### Entry rule (debounce re-entry)

A **visit** increments `visit_count` only when:

1. GPS accuracy ≤ **50 m** (discard worse fixes).
2. Speed ≥ **2 m/s** (~7 km/h) — ignore parking-lot drift when stationary.
3. The cell differs from the **previous recorded cell**, OR
4. The same cell but **≥ 10 minutes** since `last_visited_at` (counts as a new trip through the area).

First time a cell is entered: create `CellVisit` with `visit_count = 1`.

### Sampling

| Setting | Value | Rationale |
|---------|-------|-----------|
| Distance filter | 25 m | Balance battery vs trail quality |
| Time filter (fallback) | 15 s | Catch slow traffic |
| Background updates | Yes | Screen-off tracking |
| Pause when stationary | 5 min no movement | Save battery |

---

## Fog-of-war rules

Opacity is per cell, derived only from `CellVisit` (no server needed).

| State | Condition | Fog opacity | Visual |
|-------|-----------|-------------|--------|
| **Unexplored** | No `CellVisit` | **1.0** (fully hidden) | Dark fog |
| **Discovered** | `visit_count == 1` | **0.35** | Area visible but muted |
| **Familiar** | `visit_count` 2–4 | **0.15** | Clearer |
| **Well known** | `visit_count ≥ 5` | **0.0** | Fully clear |

### Neighbour soften (optional polish)

Explored cells **soften fog on adjacent unexplored cells** by up to 0.1 opacity within 1 ring. Hints at nearby roads without unlocking them.

### Stats (gamification)

- **Explored cells** — count where `visit_count ≥ 1`
- **Coverage %** — explored cells ÷ cells in **owned zones** (per region and total)
- **New today** — cells with `first_visited_at` today
- **Streak** — consecutive days with ≥ 1 new cell

---

## Map stack (iOS)

| Layer | Technology |
|-------|------------|
| Basemap | MapKit (`MKMapView` or MapKit SwiftUI) |
| Fog | `MKPolygon` or tile overlay per cell, fill colour with computed opacity |
| Markers | Optional centroid dots for "well known" cells |

Start with MapKit only. Mapbox later if custom styling is needed.

---

## Security & privacy

| Concern | Approach |
|---------|----------|
| Sensitive data | Location history is PII — treat as highest sensitivity |
| Storage | SQLite/Core Data on device, iOS Data Protection (`.completeUnlessOpen`) |
| Cloud | None in v1; add CloudKit later with E2E or Apple-managed encryption |
| App access | Face ID / passcode gate on launch (optional setting) |
| Export / delete | User can export JSON and wipe all visits |
| Collection minimisation | Store grid cells, not raw GPS, in production |
| Permissions | `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription` with plain-language copy |
| Retention | Configurable auto-purge of `GpsSample` after 30 days; keep `CellVisit` until user deletes |

---

## Suggested build order

1. Grid encoding + region gates (`grid.py`, `regions.py`)
2. Local SQLite store for `CellVisit` + `UnlockedRegion`
3. MapKit view clipped to Eastern Suburbs envelope, fog per owned zone
4. Core Location pipeline with distance filter + entry rules
5. Stats screen (% explored per zone, new cells, visit heat)
6. StoreKit — free `city` + paid region unlocks
7. Profile switcher (multiple learners on one supervisor device)

---

## Open decisions

- **Cell size**: 100 m default; 50 m for dense cities.
- **Zone pricing**: per-region IAP vs bundle (defer until beta feedback).
- **Repeat-visit visuals**: opacity only vs colour heat map.
- **Expansion**: additional Sydney areas or other cities as separate play-area packs (post v1).
