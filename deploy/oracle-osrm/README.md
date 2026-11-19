# Campus OSRM on Oracle Cloud (Always Free)

Moves the campus walking server from the PC to an always-on Oracle VM. The
OSRM engine, stock `foot.lua` profile, campus map
(`campus-network-map/osrm-5002/aaup-campus.osm`) and the app's routing code
are unchanged; only the server address changes.

```
phone ──HTTPS 443──> Caddy (droobi-caddy) ──> OSRM 127.0.0.1:5000 (droobi-campus-osrm)
```

| Item | Value |
|---|---|
| Region / shape | `il-jerusalem-1`, `VM.Standard.E2.1.Micro` (x86_64, 1 GB) |
| Image | Canonical Ubuntu 24.04 (standard, not Minimal) |
| Public IP | `84.13.85.192` |
| Domain | `droobi-campus.duckdns.org` (DuckDNS, IPv4 only; leave its IPv6 empty) |
| OCI security list | ingress TCP 22, 80, 443; port 5000 never opened |

## Deployment record (2026-11-19)
- `swap.sh`, `firewall.sh`, `setup_server.sh droobi-campus.duckdns.org` all succeeded.
- Map commit `571b45e`; OSRM image digest
  `sha256:e1929ae2818226284d7ef007329098a30851c11528ab3712bc9c8d68da78278b`
  (same image as the PC's port 5002 test server); Caddy `caddy:2`.
- Certificate: Let's Encrypt, TLS 1.3.
- External checks: `/nearest` and `/route` return `Ok`; `/`, `/table`,
  `POST` and `/route/v1/driving` return 404; HTTP redirects to HTTPS;
  port 5000 times out from outside.
- 60 routes (3 origins x 21 Uni destinations) match the port 5002 results
  within 0.5 m, walking mode only, each ending at its entrance.
- Reboot test: containers, swap, firewall rules and HTTPS return automatically.
- Usage after deployment: about 311 MiB RAM, 4.2 GB disk.

## Files
| File | Purpose |
|---|---|
| `swap.sh` | 1 GB swap file, persistent, `vm.swappiness=10` |
| `firewall.sh` | Opens TCP 80/443 in the Ubuntu instance firewall, above Oracle's REJECT rule, live and in `/etc/iptables/rules.v4` |
| `setup_server.sh` | Checks swap, firewall, x86_64 and DNS; installs Docker; builds the map; starts OSRM and Caddy; waits for HTTPS |
| `update_map.sh` | Rebuilds after a map change; restores the previous data if the new data fails a test route |
| `Caddyfile` | HTTPS front; forwards only `GET /route/v1/foot/*` and `/nearest/v1/foot/*` |

All scripts are safe to run again.

## Deploy (from the PC, PowerShell, in the repo folder)
```
$KEY = "$env:USERPROFILE\.ssh\droobi-oracle.key"
scp -i $KEY -r deploy\oracle-osrm ubuntu@84.13.85.192:~
ssh -i $KEY ubuntu@84.13.85.192
```

On the server, one step at a time:

```
cd ~/oracle-osrm
sudo bash swap.sh                 # expect: Swap 1.0Gi in `free -h`
sudo bash firewall.sh             # expect: ACCEPT tcp dpt:80 and dpt:443 above REJECT
sudo bash setup_server.sh droobi-campus.duckdns.org
```

Between `firewall.sh` and `setup_server.sh`, from the PC:
`curl http://84.13.85.192` should say **connection refused** (firewall open,
nothing listening yet). A timeout means something still blocks port 80.

`setup_server.sh` ends with `SUCCESS: https://droobi-campus.duckdns.org is
serving campus walking routes.` It looks up the server's own public IP with
api.ipify.org to confirm DNS before Caddy requests a certificate.

## Verify (from the PC)
| Check | Expected |
|---|---|
| `curl https://droobi-campus.duckdns.org/nearest/v1/foot/35.34562605184,32.40828122459` | `"code":"Ok"` |
| `curl -i https://droobi-campus.duckdns.org/` | `404` |
| `curl --max-time 5 http://84.13.85.192:5000` | times out (OSRM is private) |

Then on the server: `sudo reboot`, wait a minute, reconnect and check
`sudo docker ps` (both containers Up), `free -h` (swap present) and
`sudo iptables -L INPUT -n` (ports 80/443 still allowed).

## App
```
flutter run --dart-define=CAMPUS_OSRM_URL=https://droobi-campus.duckdns.org
flutter build apk --release --dart-define=CAMPUS_OSRM_URL=https://droobi-campus.duckdns.org
```

## Updating the map
Edit in JOSM, regenerate the build copy (`campus-network-map/README.md`),
push to `experiment/campus-public-osrm-v5`, then on the server:
`sudo bash ~/oracle-osrm/update_map.sh`.

## Notes
- Oracle may stop Always Free instances that stay idle (CPU and network
  under 20% for 7 days). If that happens, start the instance in the console;
  Docker and both containers start automatically.
- Logs: `sudo docker logs droobi-caddy`, `sudo docker logs droobi-campus-osrm`
  (each capped at 3 x 10 MB).
- The OSRM image is `ghcr.io/project-osrm/osrm-backend:latest`. To pin a
  version: `sudo OSRM_IMAGE=ghcr.io/project-osrm/osrm-backend:<tag> bash setup_server.sh ...`
  (and the same for `update_map.sh`).
