# Driveabout

**Gamify learner driving in Sydney's Eastern Suburbs.**

*See where you've driven. Unlock the map, bit by bit.*

Driveabout helps supervising adults turn practice drives into a game — fog-of-war map exploration, NSW logbook-aligned skill badges, and curated waypoints for real Sydney driving challenges (narrow streets, car parks, hills, and more).

> **Not an official logbook.** Use alongside [Roundtrip](https://www.roundtripapp.com/) for Transport for NSW hour submission. The learner drives; the supervisor runs the app.

---

## Why Driveabout?

| Problem | Driveabout's approach |
|---------|----------------------|
| 120 hours feels like a chore | Map fog clears as you explore — repeat drives sharpen familiar areas |
| Learners avoid tricky skills | Pokémon-style waypoints: hill starts, narrow streets, car parks |
| Parents don't know what's left | Progress toward NSW's 20 learning goals and condition badges (night, wet, …) |
| Generic maps aren't learner-focused | Built for **Eastern Suburbs Sydney** first — Watsons Bay to La Perouse |

**Safety first:** the supervising adult holds the phone. The learner keeps both hands on the wheel.

---

## How it works

```
GPS while driving  →  grid cells visited  →  fog lifts on the map
                   →  waypoints collected  →  skill & exploration badges
                   →  supervisor confirms  →  logbook goal progress
```

1. **Explore** — unrevealed map areas stay under fog until you drive through them.
2. **Revisit** — drive the same roads again; areas become clearer (familiar → well known).
3. **Collect** — navigate curated waypoints (e.g. ten narrow streets, ten car parks).
4. **Unlock zones** — Sydney City is free; other Eastern Suburbs zones via in-app purchase.

---

## v1 play area — Eastern Suburbs, Sydney

| Edge | Anchor |
|------|--------|
| North | Watsons Bay |
| South | La Perouse |
| West | City of Sydney (CBD) |
| East | Coast / harbour |

| Zone | Access | Covers (approx.) |
|------|--------|------------------|
| **Sydney City** | **Free** | CBD, The Rocks, Woolloomooloo |
| Harbour & Watsons Bay | Paid | Rose Bay, Vaucluse, Watsons Bay |
| Inner East | Paid | Paddington, Bondi Junction, Randwick |
| Coastal | Paid | Bondi, Coogee, Maroubra |
| La Perouse & Botany Bay | Paid | La Perouse, Phillip Bay |

---

## Achievements (in design)

| Collection | Example |
|------------|---------|
| **Narrow Street Navigator** | Chaleyer St, Shadforth St, Atherden St, Argyle Lane — [full list](waypoints/narrow-streets.json) |
| Parking Lot Explorer | *planned* — navigate 10 car parks |
| Hill Start Hero | *planned* — curated gradient waypoints |
| Roundabout Ranger | *planned* — stamp collection per roundabout |

---

## Repository

| Path | Description |
|------|-------------|
| [`DESIGN.md`](DESIGN.md) | Data model, GPS rules, fog-of-war, zones, security |
| [`regions.py`](regions.py) | Eastern Suburbs bounds, paid/free zone gates |
| [`grid.py`](grid.py) | Reference logic — grid cells, visits, fog opacity |
| [`Models.swift`](Models.swift) | iOS data models (SwiftUI / MapKit) |
| [`waypoints/`](waypoints/) | Curated achievement locations with geofences |

---

## Quick start

```bash
git clone https://github.com/makdaddy8888/Driveabout.git
cd Driveabout
python3 grid.py
```

The demo simulates drives in the free City zone and shows locked-zone behaviour at Bondi.

---

## Tech direction

- **Platform** — iOS (SwiftUI + MapKit + Core Location)
- **Storage** — on-device SQLite / Core Data (v1)
- **Privacy** — grid cells over raw GPS; encrypted local storage
- **Map data** — TfNSW open data for speed zones (planned); OSM / MapKit for basemap

---

## Status

Early design phase — architecture, reference Python, waypoint data. **No App Store build yet.**

Contributions and feedback welcome. Eastern Suburbs parents and driving instructors especially.

---

## License

TBD
