# Cluster Flapping — Root Cause Diagnosis
**Date:** 2026-04-25  
**Symptom:** Apps go offline for ~1–3 minutes at a time, then recover. Grafana graphs have missing chunks. Periodic scheduling failures.

---

## TL;DR

Three problems form a chain. Fix them in order:

1. **osd.2 (duwerk-1 NVMe) is having I/O stalls** — the physical trigger
2. **Prometheus runs on Ceph-backed storage** — turns disk stalls into monitoring outages
3. **KEDA scales all apps to 0 when Prometheus is unavailable** — turns monitoring outages into full application outages

---

## Evidence

### Ceph — HEALTH_WARN (primary cause)
```
[WRN] BLUESTORE_SLOW_OP_ALERT: osd.2 observed slow operation indications in BlueStore
[WRN] DB_DEVICE_STALLED_READ_ALERT: osd.2 observed stalled read indications in DB device
[WRN] RECENT_CRASH: mds.ceph-filesystem-b crashed at 03:11 and 14:50 UTC today
```
- **osd.2 lives on: duwerk-1, device `nvme0n1` (Acer SSD FA100 1TB, serial ASBD42440400189)**
- The "stalled read in DB device" means the NVMe backing osd.2's RocksDB WAL is hanging on I/O — all Ceph operations touching osd.2's PGs freeze until it clears
- OSDs only came up 16 minutes before diagnosis (recently restarted/recovered)
- MDS crashed twice today — CephFS layer is also destabilised

### Prometheus — 66 restarts in 12 days
```
Warning  Unhealthy  pod/prometheus-kube-prometheus-stack-0
  Liveness probe failed: Get "http://10.244.2.237:9090/-/healthy": context deadline exceeded
```
- **Prometheus PVC is on `ceph-block` (50 GiB)**
- When osd.2 stalls, Prometheus data I/O hangs
- The liveness probe (HTTP GET /-/healthy) times out → kubelet kills Prometheus → restart
- 66 restarts over 12 days = roughly 5–6 per day, each causing 1–3 min of Prometheus unavailability

### KEDA — scales all apps to 0 during every Prometheus restart
```
Warning  FailedGetExternalMetric  keda-hpa-radarr: unable to fetch metrics from external metrics API
Warning  KEDAScalerFailed         scaledobject/radarr: prometheus metrics target may be lost, result is empty
```
The shared `nfs-scaler` component applied to every media app:
```yaml
spec:
  minReplicaCount: 0        # can go to zero
  cooldownPeriod: 0         # no grace period — instant scale-down
  triggers:
    - type: prometheus
      metadata:
        query: probe_success{instance=~".+:2049"}
        threshold: "1"
        ignoreNullValues: "0"   # null metric = treat as 0 = scale to zero
```
`ignoreNullValues: "0"` is the critical setting. When Prometheus restarts, KEDA gets an empty/null response and immediately treats it as `probe_success = 0` → scales everything to 0 replicas at once.

Apps affected by this ScaledObject: **radarr, sonarr, jellyfin, bazarr, qbittorrent, qui, kopia** (and agregarr via its own mechanism).

### The flapping cycle (repeating ~5–6x/day)
```
osd.2 I/O stall
  → Prometheus liveness probe times out
    → kubelet kills Prometheus (~1–3 min restart)
      → KEDA gets null metrics (ignoreNullValues:"0")
        → KEDA scales radarr, sonarr, jellyfin, bazarr, qbittorrent, qui, kopia → 0 replicas
          → apps go offline
            → Prometheus comes back
              → KEDA sees probe_success=1
                → KEDA scales apps back to 1
                  → apps come back (+ pod scheduling + startup time)
```
Total round-trip: ~2–5 minutes of full outage per Prometheus restart.

### CPU overload on duwerk-3 (secondary aggravator)
At time of diagnosis duwerk-3 was at 100% actual CPU. Contributing pods:
| Pod | CPU |
|-----|-----|
| minecraft-java | 706m |
| rook-ceph-operator | 680m (scrub/repair work triggered by Ceph health events) |
| qbittorrent | 440m (active downloads) |
| sonarr + radarr | ~640m combined (post-restart library scans) |

CPU saturation on the node running osd.0 worsens Ceph I/O latency, amplifying the initial osd.2 problem.

### Restart counts (proof of chronic instability)
| Pod | Restarts | Notes |
|-----|----------|-------|
| agregarr | 178 in 13d | ~13/day — most affected |
| cloudflare-tunnel | 152 in 13d | chronic, possibly pre-existing |
| prometheus | 66 in 12d | directly caused by osd.2 stalls |
| qui | 7 in 25h | scaled-to-0 events |
| autobrr | 2 in 6h | instability-related |

### VolumeFailedDelete (cleanup residue)
~15 PVCs reported "still attached to node" across duwerk-1/2/3. These are left over from forced pod terminations during previous instability cycles. Not causing active outages but indicate the volume detach path has been unreliable.

---

## Node CPU requests vs actual usage (at time of diagnosis)
| Node | CPU Requests | Actual CPU | Delta |
|------|-------------|------------|-------|
| duwerk-1 | 86% | 56% | 30pp headroom |
| duwerk-2 | 88% | 53% | 35pp headroom |
| duwerk-3 | 88% | 100% | **saturated** |

Requests are now 86–88% (down from 95–100% after today's reductions). The requests overcommit is real but not the cause of the app flapping — that's KEDA + Ceph.

---

## Fixes Required

### Fix 1 — Stop KEDA from scaling to 0 on Prometheus unavailability
Change `ignoreNullValues` to `"false"` in the nfs-scaler ScaledObject, or add a fallback block:
```yaml
spec:
  advanced:
    restoreToOriginalReplicaCount: true
    fallback:
      failureThreshold: 3      # tolerate 3 consecutive failures before acting
      replicas: 1              # keep at 1, not 0
  cooldownPeriod: 300          # 5 min grace before scale-down
  minReplicaCount: 0
  triggers:
    - type: prometheus
      metadata:
        ignoreNullValues: "false"   # CHANGE: null = don't scale, not scale-to-0
```
File: `kubernetes/components/nfs-scaler/scaledobject.yaml`

### Fix 2 — Move Prometheus off Ceph-backed storage
Prometheus should not depend on the same storage layer it monitors. Move it to `openebs-hostpath` (node-local SSD, no Ceph dependency). This breaks the chain where an osd stall kills monitoring.  
File: `kubernetes/apps/observability/kube-prometheus-stack/app/helmrelease.yaml` — change `storageClassName: ceph-block` to `openebs-hostpath`.  
**Note:** This requires deleting and recreating the PVC (data migration needed or accept losing 12d of metrics).

### Fix 3 — Investigate osd.2's NVMe health
The Acer SSD FA100 1TB on duwerk-1 (`nvme0n1`) is having BlueFS stalled reads. Check NVMe SMART data:
```bash
talosctl -n 10.90.3.101 read /sys/class/nvme/nvme0/device/nvme0n1/device/state
# Or via a debug pod on duwerk-1:
kubectl run nvme-debug --image=alpine --rm -it --overrides='{"spec":{"nodeName":"duwerk-1"}}' -- sh
# then: smartctl -a /dev/nvme0
```
If the drive is failing, plan to replace it and rebalance Ceph before it causes data loss.

### Fix 4 — Clean up stuck VolumeAttachments
```bash
kubectl get volumeattachments -A | grep -v "true"
kubectl delete volumeattachment <name>   # for any stuck ones
```

---

## Priority Order
1. **Fix 1 (KEDA fallback)** — stops the visible flapping immediately, low risk, GitOps change
2. **Fix 3 (NVMe health check)** — understand if the drive is failing before it becomes a data loss event
3. **Fix 2 (Prometheus storage)** — breaks the dependency chain, slightly more invasive
4. **Fix 4 (cleanup)** — cosmetic, low urgency
