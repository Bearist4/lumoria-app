#!/usr/bin/env python3
"""
GTFS → Lumoria line catalog converter.

Takes a GTFS zip (URL or local path) and produces a compact JSON file
that the app bundles per city. The output is a stations + lines graph
that the subway-ticket form can use to:
  * list lines that serve two selected stations,
  * fill in line name / operator / color automatically,
  * count intermediate stops between two stations on a line.

Only the files we need are read from the GTFS zip (stops.txt,
routes.txt, trips.txt, stop_times.txt). For each route we pick the
longest trip as the canonical stop ordering, giving us a representative
station sequence per line.

Usage
-----
    python3 import.py <gtfs-zip-or-url> \
        --city Vienna \
        --operator "Wiener Linien" \
        --routes U1,U2,U3,U4,U6,U5 \
        --output ../../Lumoria\ App/resources/transit/Vienna.json

Examples
--------
    # Vienna — subway lines only, from the Wiener Linien open data feed
    python3 import.py \
        http://www.wienerlinien.at/ogd_realtime/doku/ogd/gtfs/gtfs.zip \
        --city Vienna \
        --operator "Wiener Linien" \
        --route-types 1 \
        --output Vienna.json

    # Paris Metro — all underground lines
    python3 import.py \
        https://eu.ftp.opendatasoft.com/stif/GTFS/IDFM-gtfs.zip \
        --city Paris \
        --operator "RATP" \
        --route-types 1 \
        --output Paris.json

Output shape
------------
    {
      "city": "Vienna",
      "operator": "Wiener Linien",
      "generatedAt": "2026-04-23T14:00:00Z",
      "source": "http://...",
      "lines": [
        {
          "id": "U1",
          "shortName": "U1",
          "longName": "Leopoldau – Reumannplatz",
          "color": "#E4002B",
          "textColor": "#FFFFFF",
          "stations": [
            {
              "id": "at:w:U1:leopoldau",
              "name": "Leopoldau",
              "lat": 48.2620,
              "lng": 16.4633
            }, …
          ]
        }, …
      ]
    }

Requirements
------------
Python 3.9+. Standard library only (csv, io, json, zipfile, argparse,
urllib). No pandas / requests dependency so this runs anywhere without
pip installs.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import io
import json
import os
import sys
import urllib.request
import zipfile
from collections import defaultdict
from typing import Dict, Iterable, List, Optional, Sequence


# MARK: - GTFS route_type reference
# https://developers.google.com/transit/gtfs/reference#routestxt
#   0  Tram / Light rail
#   1  Subway / Metro
#   2  Rail (intercity)
#   3  Bus
#   4  Ferry
#   5  Cable tram
#   6  Aerial lift
#   7  Funicular
#   11 Trolleybus
#   12 Monorail


# ---------------------------------------------------------------------------
# 1. Loading
# ---------------------------------------------------------------------------

def load_zip(source: str) -> zipfile.ZipFile:
    """Accepts a URL (http/https) or a local file path and returns a
    ZipFile pointed at the GTFS bundle. For URLs the content is fetched
    fully into memory; GTFS feeds are small enough (a few MB to ~200 MB
    for the largest networks) that this is fine for a build-time tool.
    """
    if source.startswith(("http://", "https://")):
        print(f"[gtfs] downloading {source}", file=sys.stderr)
        # Send a real-looking User-Agent — some operator servers
        # (Wiener Linien among them) 429 the default `Python-urllib`
        # one because it looks like a bot scrape.
        request = urllib.request.Request(
            source,
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/124.0.0.0 Safari/537.36"
                ),
                "Accept": "application/zip,*/*",
            },
        )
        with urllib.request.urlopen(request) as response:
            data = response.read()
        return zipfile.ZipFile(io.BytesIO(data))
    return zipfile.ZipFile(source)


def read_csv(zf: zipfile.ZipFile, name: str) -> Iterable[Dict[str, str]]:
    """Iterates rows of a CSV file inside the GTFS zip as dicts. Strips
    BOMs and whitespace from headers so the rest of the script can rely
    on clean keys regardless of the producer agency's quirks.
    """
    with zf.open(name) as raw:
        text = io.TextIOWrapper(raw, encoding="utf-8-sig", newline="")
        reader = csv.DictReader(text)
        reader.fieldnames = [(h or "").strip() for h in (reader.fieldnames or [])]
        for row in reader:
            yield {k: (v or "").strip() for k, v in row.items()}


# ---------------------------------------------------------------------------
# 2. Parsing
# ---------------------------------------------------------------------------

def parse_routes(
    zf: zipfile.ZipFile,
    route_types: Optional[Sequence[int]],
    include_ids: Optional[Sequence[str]],
    include_short_names: Optional[Sequence[str]],
) -> Dict[str, dict]:
    """Returns `route_id → metadata`, filtered to the requested types
    and/or short-name whitelist.
    """
    type_set = set(route_types) if route_types else None
    id_set = set(include_ids) if include_ids else None
    sn_set = {s.upper() for s in include_short_names} if include_short_names else None

    out: Dict[str, dict] = {}
    for row in read_csv(zf, "routes.txt"):
        route_type_raw = row.get("route_type") or "0"
        try:
            route_type = int(route_type_raw)
        except ValueError:
            continue

        if type_set is not None and route_type not in type_set:
            continue

        route_id = row.get("route_id") or ""
        short_name = row.get("route_short_name") or ""
        if id_set is not None and route_id not in id_set:
            continue
        if sn_set is not None and short_name.upper() not in sn_set:
            continue

        out[route_id] = {
            "route_id": route_id,
            "short_name": short_name,
            "long_name": row.get("route_long_name") or short_name,
            "color": _normalize_hex(row.get("route_color")) or "#666666",
            "text_color": _normalize_hex(row.get("route_text_color")) or "#FFFFFF",
            "route_type": route_type,
        }
    return out


def parse_stops(zf: zipfile.ZipFile) -> Dict[str, dict]:
    """Returns `stop_id → metadata`. Includes both parent stations and
    child platform stops; the caller decides which layer it wants.
    """
    out: Dict[str, dict] = {}
    for row in read_csv(zf, "stops.txt"):
        stop_id = row.get("stop_id") or ""
        if not stop_id:
            continue
        lat = _safe_float(row.get("stop_lat"))
        lng = _safe_float(row.get("stop_lon"))
        if lat is None or lng is None:
            continue
        out[stop_id] = {
            "stop_id": stop_id,
            "name": row.get("stop_name") or "",
            "lat": lat,
            "lng": lng,
            "parent_station": row.get("parent_station") or None,
        }
    return out


def parse_trips(
    zf: zipfile.ZipFile,
    route_ids: Iterable[str],
) -> Dict[str, List[str]]:
    """Returns `route_id → list of trip_ids` for the requested routes.
    We need this to know which trip rows in `stop_times.txt` to look at
    without paging the whole (often enormous) stop_times file into
    memory twice.
    """
    wanted = set(route_ids)
    out: Dict[str, List[str]] = defaultdict(list)
    for row in read_csv(zf, "trips.txt"):
        route_id = row.get("route_id") or ""
        if route_id not in wanted:
            continue
        trip_id = row.get("trip_id") or ""
        if trip_id:
            out[route_id].append(trip_id)
    return out


def longest_stop_sequence(
    zf: zipfile.ZipFile,
    trip_ids_by_route: Dict[str, List[str]],
) -> Dict[str, List[str]]:
    """For each route, finds the trip with the most stops and returns
    its ordered `stop_id` list. One pass over `stop_times.txt`.
    """
    wanted_trips = set()
    trip_to_route: Dict[str, str] = {}
    for route_id, trips in trip_ids_by_route.items():
        for trip_id in trips:
            wanted_trips.add(trip_id)
            trip_to_route[trip_id] = route_id

    # trip_id → list of (stop_sequence, stop_id) tuples
    accum: Dict[str, List[tuple]] = defaultdict(list)
    for row in read_csv(zf, "stop_times.txt"):
        trip_id = row.get("trip_id") or ""
        if trip_id not in wanted_trips:
            continue
        stop_id = row.get("stop_id") or ""
        seq = _safe_int(row.get("stop_sequence"))
        if not stop_id or seq is None:
            continue
        accum[trip_id].append((seq, stop_id))

    best_per_route: Dict[str, List[str]] = {}
    for trip_id, rows in accum.items():
        route_id = trip_to_route.get(trip_id)
        if not route_id:
            continue
        rows.sort(key=lambda pair: pair[0])
        stops = [stop_id for _, stop_id in rows]
        current = best_per_route.get(route_id)
        if current is None or len(stops) > len(current):
            best_per_route[route_id] = stops
    return best_per_route


# ---------------------------------------------------------------------------
# 3. Stop normalisation
# ---------------------------------------------------------------------------

def resolve_station(
    stop_id: str,
    stops: Dict[str, dict],
) -> dict:
    """Walks `parent_station` chains so every platform-level stop
    collapses to its station. Falls back to the stop itself if no
    parent is defined.
    """
    seen = set()
    current = stops.get(stop_id)
    while current and current.get("parent_station") and current["parent_station"] not in seen:
        parent_id = current["parent_station"]
        seen.add(parent_id)
        parent = stops.get(parent_id)
        if not parent:
            break
        current = parent
    return current or {}


def dedup_ordered(sequence: List[dict]) -> List[dict]:
    """Removes consecutive duplicate stations by id — a train can stop
    at the same platform for scheduling reasons but the traveller sees
    one station.
    """
    out: List[dict] = []
    last_id: Optional[str] = None
    for station in sequence:
        sid = station.get("id")
        if sid == last_id:
            continue
        out.append(station)
        last_id = sid
    return out


# ---------------------------------------------------------------------------
# 4. Compose output
# ---------------------------------------------------------------------------

def build_catalog(
    zf: zipfile.ZipFile,
    *,
    city: str,
    operator: str,
    source: str,
    route_types: Optional[Sequence[int]],
    route_ids: Optional[Sequence[str]],
    route_short_names: Optional[Sequence[str]],
) -> dict:
    print("[gtfs] parsing routes", file=sys.stderr)
    routes = parse_routes(zf, route_types, route_ids, route_short_names)
    if not routes:
        raise SystemExit("No routes matched the filters.")
    print(f"[gtfs]   {len(routes)} routes selected", file=sys.stderr)

    print("[gtfs] parsing stops", file=sys.stderr)
    stops = parse_stops(zf)
    print(f"[gtfs]   {len(stops)} stops indexed", file=sys.stderr)

    print("[gtfs] parsing trips", file=sys.stderr)
    trips_by_route = parse_trips(zf, routes.keys())
    print(
        f"[gtfs]   {sum(len(v) for v in trips_by_route.values())} trips across {len(trips_by_route)} routes",
        file=sys.stderr,
    )

    print("[gtfs] parsing stop_times (this is the slow one)", file=sys.stderr)
    stop_sequences = longest_stop_sequence(zf, trips_by_route)

    # Aggregate routes that share a short_name — producers often ship
    # multiple `route_id`s per visible line (regular, event, holiday,
    # construction timetable…). Keep the variant with the most stops
    # so the catalog has one row per rider-facing line.
    candidates: Dict[str, dict] = {}
    for route_id, meta in routes.items():
        stop_ids = stop_sequences.get(route_id) or []
        stations: List[dict] = []
        for stop_id in stop_ids:
            station = resolve_station(stop_id, stops)
            if not station:
                continue
            stations.append({
                "id": station["stop_id"],
                "name": station["name"],
                "lat": round(station["lat"], 6),
                "lng": round(station["lng"], 6),
            })
        stations = dedup_ordered(stations)
        if not stations:
            continue

        key = (meta["short_name"] or meta["route_id"]).strip()
        entry = {
            "id": key,
            "shortName": meta["short_name"],
            "longName": meta["long_name"],
            "color": meta["color"],
            "textColor": meta["text_color"],
            # GTFS route_type: 0 tram, 1 subway, 2 rail, 3 bus,
            # 5 cable tram, 6 aerial lift, 7 funicular, 11 trolleybus,
            # 12 monorail. Surfaces on the catalog line so the app can
            # show mode-appropriate icons and filter per mode.
            "mode": meta["route_type"],
            "stations": stations,
        }
        existing = candidates.get(key)
        if existing is None or len(stations) > len(existing["stations"]):
            candidates[key] = entry

    out_lines = sorted(candidates.values(), key=lambda line: line["id"])

    return {
        "city": city,
        "operator": operator,
        "generatedAt": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": source,
        "lines": out_lines,
    }


# ---------------------------------------------------------------------------
# 5. Helpers
# ---------------------------------------------------------------------------

def _normalize_hex(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    value = value.strip().lstrip("#")
    if len(value) == 6:
        try:
            int(value, 16)
            return "#" + value.upper()
        except ValueError:
            return None
    return None


def _safe_float(value: Optional[str]) -> Optional[float]:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def _safe_int(value: Optional[str]) -> Optional[int]:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# 6. CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="GTFS → Lumoria line catalog")
    parser.add_argument("source", help="GTFS zip URL or local path")
    parser.add_argument("--city", required=True, help="City name (display only)")
    parser.add_argument("--operator", required=True, help="Operator / agency name")
    parser.add_argument(
        "--route-types",
        default="",
        help="Comma-separated GTFS route_type ints to keep (e.g. '0,1' for tram + subway)",
    )
    parser.add_argument(
        "--routes",
        default="",
        help="Comma-separated route_id values to whitelist (overrides types)",
    )
    parser.add_argument(
        "--route-short-names",
        default="",
        help="Comma-separated route_short_name values (e.g. 'U1,U2,U3')",
    )
    parser.add_argument("--output", required=True, help="Output JSON file path")
    return parser.parse_args()


def _split_csv(raw: str) -> List[str]:
    return [x.strip() for x in raw.split(",") if x.strip()]


def main() -> None:
    args = parse_args()

    route_types_raw = _split_csv(args.route_types)
    try:
        route_types = [int(x) for x in route_types_raw] if route_types_raw else None
    except ValueError:
        raise SystemExit(f"--route-types must be comma-separated ints, got {args.route_types!r}")

    route_ids = _split_csv(args.routes) or None
    route_short_names = _split_csv(args.route_short_names) or None

    zf = load_zip(args.source)
    catalog = build_catalog(
        zf,
        city=args.city,
        operator=args.operator,
        source=args.source,
        route_types=route_types,
        route_ids=route_ids,
        route_short_names=route_short_names,
    )

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    print(
        f"[gtfs] wrote {args.output} — {len(catalog['lines'])} lines, "
        f"{sum(len(l['stations']) for l in catalog['lines'])} station entries total",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
