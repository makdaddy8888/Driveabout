# iOS app — first run on Mac

## Requirements

- macOS with **Xcode 16** (or Xcode 15.4+)
- Apple Developer account (free or paid — paid needed for TestFlight)
- iPhone for on-road GPS testing (Simulator location is fine for UI only)

## Open the project

```bash
git clone git@github.com:makdaddy8888/Driveabout.git
cd Driveabout
open Driveabout.xcodeproj
```

## Signing (one-time)

1. Select the **Driveabout** project in the navigator → **Driveabout** target → **Signing & Capabilities**.
2. Check **Automatically manage signing**.
3. Choose your **Team** from the dropdown (your Apple Developer account).
4. Confirm bundle identifier: `au.driveabout.app` (change if you already use this ID elsewhere).

Xcode creates a development certificate and provisioning profile locally — nothing to paste into chat.

## Run on your iPhone

1. Connect your iPhone via USB (or enable wireless debugging).
2. Select your device in the Xcode toolbar scheme menu.
3. Press **Run** (⌘R).
4. On first launch, allow **location when in use** when prompted.

## v1 scaffold behaviour

| Tab | What works |
|-----|------------|
| **Map** | Eastern Suburbs map, zone outlines, start/end trip, GPS → grid cells |
| **Badges** | Geofence unlocks, bronze/silver/gold tiers, supervisor confirm, earned awards |
| **Profile** | Cell counts, zone lock state, dev unlock |

## Bundled data

The `waypoints/` folder at the repo root is copied into the app bundle as a **folder reference** (blue folder in Xcode). Edit JSON in the repo; rebuild to refresh.

## Simulator vs device

- **Simulator**: UI, badges list, trip flow — use **Features → Location → Custom Location** (e.g. `-33.8688, 151.2093` for Sydney CBD).
- **Device**: Real speed, accuracy, and drive testing.

## Achievement flow

1. **Start trip** on the Map tab.
2. Drive into a waypoint geofence below the speed limit for the required dwell time.
3. **Confirm visit** appears on the map HUD — supervisor taps when parked.
4. Bronze / silver / gold tiers unlock automatically at the thresholds in each JSON collection.
5. View progress and earned awards on the **Badges** tab.

Expeditions (coast-to-coast) are not wired in this scaffold yet.

## Next build steps

- [ ] Persist map cell visits (Core Data / SQLite)
- [ ] Fog overlay rendering per cell
- [ ] Expedition multi-endpoint achievements
- [ ] StoreKit region IAP
- [ ] App icon asset

## Project layout

```
Driveabout.xcodeproj
Driveabout/
  DriveaboutApp.swift      App entry
  ContentView.swift        Tab shell
  Models/Models.swift      Grid, regions, fog
  Services/                Location, visits, waypoints
  Views/                   Map, trip HUD, badges, profile
  Assets.xcassets
waypoints/                 Bundled JSON (repo root)
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Signing failed | Set Team under Signing & Capabilities |
| No waypoint data in Badges tab | Confirm `waypoints` folder is blue (folder reference) in Xcode, not yellow (group) |
| Location never updates on device | Settings → Privacy → Location → Driveabout → While Using |
| Locked zone message at Bondi | Profile → **Unlock all zones (dev)** until StoreKit is wired |
