# Session Journal

A living journal that persists across compactions. Captures decisions, progress, and context.

## Current State
- **Focus:** Talos v1.12.7 upgrade complete across all 6 nodes; cluster healthy
- **Blocked:** Prometheus still on ceph-block storage (migration deferred); blackbox exporter not deployed (nfs-scaler scale-to-0-on-NAS-offline feature inert)

## Log
<!-- Newest entries at top. Format: ### YYYY-MM-DD HH:MM — Event type: brief description -->

### 2026-04-25 21:50 — Completed: Talos v1.12.7 upgrade on all 6 nodes
- duwerk-2 was stuck at unmountPodMounts for 35+ min — libceph can't reach Ceph monitor ClusterIP after kubelet stops
- Required user to physically power-cycle duwerk-2 (talosctl reboot rejected; upgrade lock held by active sequence)
- After power cycle: restarted osd.2 to clear stale BlueStore/BlueFS warnings; waited for Ceph HEALTH_OK (tuppr health gate)
- Tuppr then created fresh job; upgrade completed successfully on second attempt
- All 6 nodes now on v1.12.7, kernel 6.18.24-talos, containerd 2.1.7; Ceph HEALTH_OK
- Root cause of stuck unmount: Ceph RBD volumes remain kernel-mounted after drain because kubelet PVC unmount isn't fully flushed before upgrade stops services

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
