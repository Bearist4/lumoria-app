# GTFS → Lumoria line catalog

One-shot converter that turns an operator's GTFS feed into the compact
JSON catalog the subway-ticket flow reads to offer line suggestions
(name, color, operator, station count) given two selected stations.

## Why

MapKit exposes station POIs but not line membership. Every ticket
operator of interest publishes a free GTFS feed though, so we bundle
a small per-city line graph with the app and do the "which lines
serve both stations" intersection locally — zero API costs, zero
data leaves the device.

## Run

Requires Python 3.9+. Standard library only — no pip installs.

```bash
# Vienna — subway lines (route_type 1)
python3 scripts/gtfs-import/import.py \
  http://www.wienerlinien.at/ogd_realtime/doku/ogd/gtfs/gtfs.zip \
  --city Vienna \
  --operator "Wiener Linien" \
  --route-types 1 \
  --output "Lumoria App/resources/transit/Vienna.json"

# Paris — Metro + RER
python3 scripts/gtfs-import/import.py \
  https://eu.ftp.opendatasoft.com/stif/GTFS/IDFM-gtfs.zip \
  --city Paris \
  --operator "RATP / SNCF" \
  --route-types 1,2 \
  --output "Lumoria App/resources/transit/Paris.json"

# London — Tube only, filtered by line short name
python3 scripts/gtfs-import/import.py \
  ./tfl-gtfs.zip \
  --city London \
  --operator "Transport for London" \
  --route-short-names "Bakerloo,Central,Circle,District,Jubilee,Metropolitan,Northern,Piccadilly,Victoria,Waterloo & City" \
  --output "Lumoria App/resources/transit/London.json"
```

## Filters

| Flag | Purpose |
|------|---------|
| `--route-types` | GTFS `route_type` ints (see table below) |
| `--routes` | Exact `route_id` whitelist |
| `--route-short-names` | Whitelist by human-readable line code ("U1", "Central") |

### GTFS route_type reference

| Value | Mode |
|------:|------|
| 0 | Tram / Light rail |
| 1 | Subway / Metro |
| 2 | Rail (intercity, RER, commuter) |
| 3 | Bus |
| 4 | Ferry |
| 5 | Cable tram |
| 6 | Aerial lift |
| 7 | Funicular |
| 11 | Trolleybus |
| 12 | Monorail |

## Output

```json
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
        { "id": "at:1:60201010", "name": "Leopoldau",
          "lat": 48.2620, "lng": 16.4633 }
      ]
    }
  ]
}
```

Bundle the JSON under `Lumoria App/resources/transit/<City>.json` and
add it to the app target. The runtime loader (to be built) picks a
catalog based on the user's selected city or the MapKit-resolved
station country.

## Known GTFS quirks

- **Parent stations.** Subway feeds usually list one `stop_id` per
  platform and a `parent_station` pointing at the station row. The
  importer walks `parent_station` chains so a line's station list
  collapses to one entry per station, not one per platform.
- **Colors.** `route_color` / `route_text_color` are optional and often
  missing on smaller operators. We default to a neutral grey on white
  when missing — override by editing the output JSON by hand.
- **Long trip selection.** A single `route_id` can have dozens of
  short-tripped variants (weekend diversions, first-stop-only trains).
  We pick the trip with the most stops as the canonical sequence; it
  is usually the through-running service.
- **IDFM (Paris).** The feed ships as a huge zip (~200 MB). The
  script holds it in memory — you'll want ~2 GB free RAM. Consider
  pre-downloading and passing the local path.
- **ODPT (Tokyo).** No single unified feed. Download per-operator
  (Tokyo Metro, Toei, JR East) and run the script once per feed, then
  concatenate the `lines` arrays manually.
