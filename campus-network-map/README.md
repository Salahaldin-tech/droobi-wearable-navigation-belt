# Campus network map (JOSM edit + OSRM test build)

Working files for the updated AAUP campus pedestrian network. The V5 map in
`docs/campus-mapping/osm/aaup-campus.osm` is left unchanged; the live OSRM
server (port 5001) still serves that V5 map.

Nothing here is uploaded to public OpenStreetMap. The JOSM file carries
`upload="never"`, so JOSM refuses to upload it.

| Path | What it is |
|---|---|
| `josm/aaup-campus-edit.osm` | Map edited in JOSM (2026-11-18): faculty entrances with names/refs, new and improved footways, adjusted Engineering loop geometry. Source of the Uni screen coordinates in `lib/models/campus_destination.dart`. |
| `osrm-5002/aaup-campus.osm` | Build copy served by the test OSRM server on port 5002 (see below). |
| `osrm-5002/id_map.csv` | JOSM temporary (negative) id -> permanent build id. |
| `osrm-5002/prepare_build_copy.py` | Script that produced the build copy from the JOSM file. |
| `engineering_footway_editor.html`, `open_footway_editor.bat` | Browser drawing tool used before switching to JOSM. |
| `campus_network_*.geojson`, `campus_network_map.html`, `tested_routes.geojson` | Earlier campus network exports and viewer. |

## Build copy changes (relative to the JOSM file)

`prepare_build_copy.py` makes only these changes:

1. Removes the 22 elements JOSM kept with `action='delete'`.
2. Connects footway `-1024` (build id `14368505224`):
   - new node `14368505221` where it crosses south link way `1573510575`;
   - new node `14368505222` where it crosses parking aisle `1573528467`;
   - new node `14368505223` on the parking aisle, joined to endpoint `-26507` (1.96 m).
3. Renumbers all negative ids to positive ids from `14368505158` and drops
   JOSM `action` attributes.

Regenerate:

```
python -I campus-network-map/osrm-5002/prepare_build_copy.py campus-network-map/josm/aaup-campus-edit.osm campus-network-map/osrm-5002/aaup-campus.osm campus-network-map/osrm-5002/id_map.csv
```

## Test OSRM server on port 5002

The `.osrm*` files are build output and are not committed. From the repo root
(PowerShell), with Docker Desktop running:

```
$D = "$PWD\campus-network-map\osrm-5002"
$IMG = "ghcr.io/project-osrm/osrm-backend:latest"
docker run --rm -v "${D}:/data" $IMG osrm-extract -p /opt/foot.lua /data/aaup-campus.osm
docker run --rm -v "${D}:/data" $IMG osrm-partition /data/aaup-campus.osrm
docker run --rm -v "${D}:/data" $IMG osrm-customize /data/aaup-campus.osrm
docker run -d --name droobi-campus-osrm-test -p 5002:5000 -v "${D}:/data:ro" $IMG osrm-routed --algorithm mld /data/aaup-campus.osrm --port 5000
```

Stop and remove it with `docker rm -f droobi-campus-osrm-test`.

The stock `foot.lua` profile is used unchanged. It uses
`oneway_handling = 'specific'`: only `oneway:foot` restricts walking direction,
so `oneway=yes` (car direction) and roundabouts are walkable both ways.
