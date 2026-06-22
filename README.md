# Driveabout

*See where you've driven. Unlock the map, bit by bit.*

Gamify learner driving in Australia — track where you've been, revisit routes, and reveal the map as you explore. Built for supervisors, not drivers behind the wheel.

## Concept

Driveabout turns practice drives into exploration. As a learner and their supervising adult drive around, GPS tracks where they've been. Unexplored areas stay under fog; each visit clears the map a little more. Drive the same roads again and those areas become sharper — rewarding repeat practice.

**Safety first:** the supervising adult runs the app. The learner keeps their hands on the wheel.

## Status

Early design phase. No iOS app yet — architecture and reference logic only.

## Repository

| Path | Description |
|------|-------------|
| [`DESIGN.md`](DESIGN.md) | Data model, GPS rules, fog-of-war, map stack, security |
| [`grid.py`](grid.py) | Reference implementation — grid cells, visits, fog opacity |
| [`Models.swift`](Models.swift) | iOS data models for the SwiftUI app |

## Quick start

Run the grid reference demo:

```bash
python3 grid.py
```

## Tech direction

- **iOS** — SwiftUI + MapKit + Core Location
- **Storage** — on-device SQLite/Core Data (no backend in v1)
- **Privacy** — grid cells over raw GPS; encrypted local storage

## License

TBD
