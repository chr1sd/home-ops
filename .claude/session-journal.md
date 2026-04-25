# Session Journal

A living journal that persists across compactions. Captures decisions, progress, and context.

## Current State
- **Focus:** Cluster instability diagnosed; fixes documented, not yet implemented
- **Blocked:** NVMe health check requires node-level access; Prometheus storage migration requires data decision

## Log
<!-- Newest entries at top. Format: ### YYYY-MM-DD HH:MM — Event type: brief description -->

### 2026-04-25 14:30 — Completed: Cluster flapping root cause diagnosis
- Full chain identified: osd.2 NVMe stalls → Prometheus hangs → KEDA scales all apps to 0
- osd.2 on duwerk-1 (Acer SSD FA100 1TB nvme0n1) has BlueStore slow ops + BlueFS stalled DB reads
- Prometheus has 66 restarts in 12d; uses ceph-block storage — direct dependency on the sick OSD
- KEDA nfs-scaler has `ignoreNullValues:"0"` — null Prometheus response → immediate scale-to-0 for radarr, sonarr, jellyfin, bazarr, qbittorrent, qui, kopia
- mds.ceph-filesystem-b crashed twice today (03:11, 14:50 UTC)
- agregarr: 178 restarts in 13d; cloudflare-tunnel: 152 restarts
- Findings documented at `.claude/cluster-flapping-diagnosis-2026-04-25.md`
- Also reduced CPU requests on radarr/sonarr/prowlarr from 100m→25m (workers were at 95–100% requests)

### 2026-04-25 12:00 — Completed: Radarr CPU request fix
- Workers at 95–100% CPU requests despite 21–44% actual usage
- Changed radarr, sonarr, prowlarr from 100m→25m CPU request
- Files: `kubernetes/apps/default/{radarr,sonarr,prowlarr}/app/helmrelease.yaml`
