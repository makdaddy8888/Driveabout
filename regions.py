#!/usr/bin/env python3
"""
Eastern Suburbs (Sydney) play area and monetisation zones.

Bounds: Watsons Bay → La Perouse along the coast, west to the City of Sydney.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import FrozenSet, Optional, Tuple

LatLng = Tuple[float, float]


@dataclass(frozen=True)
class Bounds:
    min_lat: float
    min_lng: float
    max_lat: float
    max_lng: float

    def contains(self, lat: float, lng: float) -> bool:
        return (
            self.min_lat <= lat <= self.max_lat
            and self.min_lng <= lng <= self.max_lng
        )


# Master envelope — all GPS processing stays inside this box.
EASTERN_SUBURBS = Bounds(
    min_lat=-33.995,  # south — La Perouse
    min_lng=151.198,  # west — City of Sydney
    max_lat=-33.835,  # north — Watsons Bay
    max_lng=151.292,  # east — harbour heads
)


@dataclass(frozen=True)
class PlayRegion:
    id: str
    name: str
    bounds: Bounds
    free: bool = False
    product_id: Optional[str] = None  # StoreKit product id

    def contains(self, lat: float, lng: float) -> bool:
        return self.bounds.contains(lat, lng)

# Priority order: first match wins at overlaps (city checked first).
REGIONS: tuple[PlayRegion, ...] = (
    PlayRegion(
        id="city",
        name="Sydney City",
        bounds=Bounds(-33.882, 151.198, -33.858, 151.228),
        free=True,
    ),
    PlayRegion(
        id="harbour",
        name="Harbour & Watsons Bay",
        bounds=Bounds(-33.858, 151.220, -33.835, 151.292),
        product_id="au.driveabout.region.harbour",
    ),
    PlayRegion(
        id="inner_east",
        name="Inner East",
        bounds=Bounds(-33.920, 151.198, -33.858, 151.255),
        product_id="au.driveabout.region.inner_east",
    ),
    PlayRegion(
        id="coast",
        name="Coastal",
        bounds=Bounds(-33.975, 151.230, -33.885, 151.278),
        product_id="au.driveabout.region.coast",
    ),
    PlayRegion(
        id="botany_bay",
        name="La Perouse & Botany Bay",
        bounds=Bounds(-33.995, 151.198, -33.965, 151.255),
        product_id="au.driveabout.region.botany_bay",
    ),
)

REGION_BY_ID = {r.id: r for r in REGIONS}
DEFAULT_UNLOCKED: FrozenSet[str] = frozenset({r.id for r in REGIONS if r.free})


def in_play_area(lat: float, lng: float) -> bool:
    return EASTERN_SUBURBS.contains(lat, lng)


def region_for(lat: float, lng: float) -> Optional[PlayRegion]:
    if not in_play_area(lat, lng):
        return None
    for region in REGIONS:
        if region.contains(lat, lng):
            return region
    return None


def region_unlocked(region_id: str, unlocked: FrozenSet[str]) -> bool:
    region = REGION_BY_ID.get(region_id)
    if region is None:
        return False
    return region.free or region_id in unlocked


def can_track(lat: float, lng: float, unlocked: FrozenSet[str]) -> tuple[bool, Optional[str]]:
    """
    Returns (allowed, reason).
    reason is None when tracking proceeds; otherwise a short code for UI.
    """
    if not in_play_area(lat, lng):
        return False, "outside_play_area"
    region = region_for(lat, lng)
    if region is None:
        return False, "unzoned"  # inside envelope but between zone boxes
    if not region_unlocked(region.id, unlocked):
        return False, f"locked:{region.id}"
    return True, None
