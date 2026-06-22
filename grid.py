#!/usr/bin/env python3
"""
Driveabout reference: grid cell encoding, visit merge, fog opacity.

Run: python3 grid.py
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, Optional, Tuple

# --- Config (match DESIGN.md) ---

CELL_SIZE_M = 100
MIN_ACCURACY_M = 50
MIN_SPEED_MPS = 2.0
REENTRY_MINUTES = 10


# --- Grid ---

def _meters_per_degree_lat() -> float:
    return 111_320.0


def _meters_per_degree_lng(lat: float) -> float:
    return 111_320.0 * math.cos(math.radians(lat))


def cell_id_for(lat: float, lng: float, cell_size_m: int = CELL_SIZE_M) -> str:
    lat_idx = math.floor(lat * _meters_per_degree_lat() / cell_size_m)
    lng_idx = math.floor(lng * _meters_per_degree_lng(lat) / cell_size_m)
    return f"{lat_idx}:{lng_idx}"


def cell_centroid(cell_id: str, cell_size_m: int = CELL_SIZE_M) -> Tuple[float, float]:
    lat_idx, lng_idx = (int(x) for x in cell_id.split(":"))
    lat = (lat_idx + 0.5) * cell_size_m / _meters_per_degree_lat()
    lng = (lng_idx + 0.5) * cell_size_m / _meters_per_degree_lng(lat)
    return lat, lng


# --- Visit model ---

@dataclass
class CellVisit:
    cell_id: str
    profile_id: str
    first_visited_at: datetime
    last_visited_at: datetime
    visit_count: int
    centroid_lat: float = 0.0
    centroid_lng: float = 0.0

    def __post_init__(self) -> None:
        if not self.centroid_lat and not self.centroid_lng:
            self.centroid_lat, self.centroid_lng = cell_centroid(self.cell_id)


@dataclass
class VisitStore:
    """In-memory store; iOS v1 uses SQLite with the same shape."""

    profile_id: str
    cells: Dict[str, CellVisit] = field(default_factory=dict)
    _last_cell_id: Optional[str] = None

    def process_sample(
        self,
        lat: float,
        lng: float,
        recorded_at: datetime,
        *,
        accuracy_m: float = 10.0,
        speed_mps: float = 10.0,
        cell_size_m: int = CELL_SIZE_M,
    ) -> Optional[CellVisit]:
        if accuracy_m > MIN_ACCURACY_M:
            return None
        if speed_mps < MIN_SPEED_MPS:
            return None

        cid = cell_id_for(lat, lng, cell_size_m)
        existing = self.cells.get(cid)
        reentry_threshold = timedelta(minutes=REENTRY_MINUTES)

        if existing is None:
            visit = CellVisit(
                cell_id=cid,
                profile_id=self.profile_id,
                first_visited_at=recorded_at,
                last_visited_at=recorded_at,
                visit_count=1,
            )
            self.cells[cid] = visit
            self._last_cell_id = cid
            return visit

        same_cell = cid == self._last_cell_id
        long_enough = recorded_at - existing.last_visited_at >= reentry_threshold

        if not same_cell or long_enough:
            existing.visit_count += 1
            existing.last_visited_at = recorded_at
            self._last_cell_id = cid
            return existing

        return None


# --- Fog opacity ---

def fog_opacity(visit: Optional[CellVisit]) -> float:
    if visit is None:
        return 1.0
    if visit.visit_count == 1:
        return 0.35
    if visit.visit_count <= 4:
        return 0.15
    return 0.0


def neighbour_soften(
    cell_id: str,
    store: VisitStore,
    base_opacity: float,
) -> float:
    """Reduce fog slightly near explored cells."""
    lat_idx, lng_idx = (int(x) for x in cell_id.split(":"))
    for dlat in (-1, 0, 1):
        for dlng in (-1, 0, 1):
            if dlat == 0 and dlng == 0:
                continue
            neighbour = f"{lat_idx + dlat}:{lng_idx + dlng}"
            if neighbour in store.cells:
                return max(0.0, base_opacity - 0.1)
    return base_opacity


# --- Demo ---

def _demo() -> None:
    store = VisitStore(profile_id="learner-1")
    t0 = datetime(2026, 6, 22, 10, 0, 0)
    base_lat, base_lng = -33.8688, 151.2093  # Sydney

    points = [
        (base_lat, base_lng),
        (base_lat + 0.0004, base_lng),
        (base_lat + 0.0008, base_lng),
        (base_lat + 0.0012, base_lng),
        (base_lat + 0.0016, base_lng),
    ]

    print("Drive simulation (Sydney)\n" + "-" * 40)
    for i, (lat, lng) in enumerate(points):
        visit = store.process_sample(
            lat, lng, t0 + timedelta(seconds=i * 30), speed_mps=8.0
        )
        cid = cell_id_for(lat, lng)
        if visit:
            op = fog_opacity(store.cells.get(cid))
            print(f"  sample {i}: cell {cid} visits={visit.visit_count} fog={op}")

    print("\nSecond drive (next day)\n" + "-" * 40)
    t1 = t0 + timedelta(days=1)
    for i, (lat, lng) in enumerate(points):
        store.process_sample(
            lat, lng, t1 + timedelta(seconds=i * 30), speed_mps=8.0
        )
        cid = cell_id_for(lat, lng)
        v = store.cells.get(cid)
        if v:
            op = fog_opacity(v)
            print(f"  sample {i}: cell {cid} visits={v.visit_count} fog={op}")

    explored = len(store.cells)
    well_known = sum(1 for v in store.cells.values() if v.visit_count >= 5)
    print(f"\nStats: {explored} cells explored, {well_known} well known")


if __name__ == "__main__":
    _demo()
