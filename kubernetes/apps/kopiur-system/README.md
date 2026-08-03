# Backups with kopiur

Every application's data is snapshotted hourly and stored, encrypted, on the NAS. This is
handled by [kopiur](https://github.com/home-operations/kopiur), a Kubernetes backup
operator built around [Kopia](https://kopia.io). Protecting a new app is one line in its
Flux Kustomization; restoring after a disaster is automatic when the volume is recreated.

This guide explains how the system works, how to protect an app, how to restore data, and
how to operate it day to day.

> [!NOTE]
> Values here are for **this** cluster (repository `lil-nas` on `lil-nas.dovis.me`,
> 1Password vault item `kopiur`, backups mounted at `/data`). Lines marked ⭐ are the ones
> you'd change for your own setup.

---

## How backups work

**The repository.** All snapshots go to one encrypted [Kopia](https://kopia.io)
repository on an NFS export, defined by the `ClusterRepository` named `lil-nas`
([`repository/clusterrepository.yaml`](kopiur/repository/clusterrepository.yaml)):

- **Backend:** the NFS share `lil-nas.dovis.me:/mnt/seagate-data/k8s/backup`, mounted into
  each backup pod. kopiur speaks to it as a plain filesystem — no S3, no separate server.
- **Encryption:** the repository password lives only in 1Password (item `kopiur`, field
  `KOPIA_PASSWORD`) and is pulled into the cluster by External Secrets
  ([`repository/externalsecret.yaml`](kopiur/repository/externalsecret.yaml)). Without it
  the repository is unreadable — keep it safe.
- **Adopted, not created:** `create.enabled: false` means kopiur attached to the
  pre-existing repository (previously written by VolSync) rather than initializing a new
  one, so no snapshot history was lost in the migration.

> [!IMPORTANT]
> The 1Password `kopiur` item is the repository encryption key. If you lose it, every
> backup becomes unrecoverable.

**What gets backed up.** Each protected app has one PersistentVolumeClaim named after the
app (e.g. `radarr`), holding its data and mounted at `/data`. kopiur snapshots that PVC.
It uses `copyMethod: Snapshot`, so it takes a Ceph `VolumeSnapshot` first and backs up
from that — the app keeps running and its data stays consistent.

**Policies and schedule.** The reusable component
[`kubernetes/components/kopiur/`](../../components/kopiur) gives each app a matching set
of resources (all named after the app):

| Resource                | What it does                                                                                            |
| ----------------------- | ------------------------------------------------------------------------------------------------------- |
| `SnapshotPolicy`        | _How_ to back up: hourly retention `24`, daily `7`, `zstd-fastest` compression, source path `/data`     |
| `SnapshotSchedule`      | _When_: `H * * * *` — once an hour, at a per-app hashed minute so all apps don't run at once            |
| `PersistentVolumeClaim` | The app's data volume, wired to restore from backup on creation (see [Restoring data](#restoring-data)) |
| `Restore`               | The passive restore source the PVC pulls from                                                           |

**Identity and history.** kopiur records each app's snapshots under the identity
`<app>@<namespace>:/data` (set by `identityDefaults` on the repository plus
`sourcePathOverride: /data` in the policy). This exactly matches the identity VolSync used,
so the migration continued each app's history as one unbroken timeline instead of starting
over.

**Maintenance.** kopiur owns repository maintenance itself (`maintenance.enabled: true`),
compacting and pruning on a schedule. Because 20 apps snapshot hourly, the repository is
busy, so `parameters.epoch.minDuration: 6h` lets Kopia close epochs sooner than its 24h
default and keep index compaction ahead of the churn.

> ⭐ Your NFS server/path, the identity convention, and the schedule timezone
> (`America/New_York`) all live in
> [`clusterrepository.yaml`](kopiur/repository/clusterrepository.yaml).

---

## Protecting an app

To back up a new app, add the kopiur component to its Flux Kustomization (`ks.yaml`) and
tell it how big the volume is. Using `radarr` as the example
([`kubernetes/apps/default/radarr/ks.yaml`](../default/radarr/ks.yaml)):

```yaml
spec:
    components:
        - ../../../../components/common
        - ../../../../components/kopiur # add this
    postBuild:
        substitute:
            APP: *app
            KOPIUR_CAPACITY: 10Gi # size of the app's data volume
```

Two requirements for the app itself:

1. Its data must be on a PVC **named after the app** (`APP`), which the component creates.
   Reference it in the HelmRelease with `existingClaim: <app>`.
2. That PVC must be mounted at **`/data`** in the container, because the snapshot identity
   is pinned to `/data`.

> [!TIP]
> `KOPIUR_CAPACITY` sets both the volume size and the mover cache size. Other knobs
> (`KOPIUR_SCHEDULE`, `KOPIUR_STORAGECLASS`, `KOPIUR_SNAPSHOTCLASS`, `KOPIUR_PUID/PGID`)
> have sensible defaults in [`snapshotpolicy.yaml`](../../components/kopiur/snapshotpolicy.yaml)
> and [`pvc.yaml`](../../components/kopiur/pvc.yaml) — override them in `substitute` only
> when you need to.

After Flux reconciles, confirm the policy exists and is taking snapshots:

```sh
kubectl get snapshotpolicy,snapshotschedule -n default <app>
kopiur snapshots list -n default | grep <app>
```

---

## Restoring data

There are two ways to restore, for two different situations.

### Disaster recovery — automatic on volume recreation

This is the path the [bootstrap guide](../../../bootstrap/README.md) relies on. The
component's PVC declares its data source as the app's `Restore`:

```yaml
dataSourceRef:
    apiGroup: kopiur.home-operations.com
    kind: Restore
    name: <app>
```

So whenever the PVC is created **fresh and empty** — a rebuilt cluster, a deleted volume —
Kubernetes hands it to kopiur's volume populator, which hydrates it from the app's
**latest** snapshot before the pod starts. You don't run anything; bringing the app back
up restores its data.

> [!CAUTION]
> The PVC carries the label `kustomize.toolkit.fluxcd.io/ssa: IfNotPresent`, so Flux never
> modifies a PVC that already exists — it only restores into **new** volumes. To force a
> restore of a running app you must delete its PVC first, which means deleting the app's
> data. Do that deliberately, not by accident.

### Ad-hoc — point-in-time restore with the CLI

To recover an older version, inspect a snapshot, or restore into a throwaway volume, use
the `kopiur` CLI. Restore the latest `radarr` snapshot into a new PVC:

```sh
kopiur restore --from-policy radarr -n default \
  --create-pvc radarr-restore --size 10Gi --storage-class ceph-block --wait
```

Useful variations:

- `--offset 1` (or `2`, …) — a previous snapshot instead of the latest.
- `--as-of 2026-07-30T00:00:00Z` — the newest snapshot at or before a point in time.
- `--to-pvc <existing>` — restore into a PVC that already exists.

To look **inside** a snapshot without restoring it:

```sh
kopiur browse --from-policy radarr -n default     # interactive ls/cd/cat
kopiur ls   --from-policy radarr -n default /
kopiur cat  --from-policy radarr -n default /some/file
```

---

## Operations

**Health.** `kopiur doctor` is the one-command check — CRDs, the operator, the webhook,
repository connectivity, credentials, and stuck work. Run it first whenever something
looks off:

```sh
kopiur doctor
kopiur status -A          # repositories, policies, schedules, in-flight work
```

**The web UI.** A read-only Kopia UI is served at
[`kopia.dovis.me`](https://kopia.dovis.me) for browsing the repository. It connects
read-only, so it can look but never mutate backups. Get its login:

```sh
kubectl get secret lil-nas-kopia-ui-auth -n kopiur-system \
  -o jsonpath='{.data.password}' | base64 -d   # username is "kopia"
```

**Back up now.** To take a snapshot outside the schedule:

```sh
kopiur snapshot now --policy <app> -n <namespace> --wait
```

**Maintenance.** kopiur runs maintenance automatically, but you can trigger it:

```sh
kopiur maintenance run lil-nas -n kopiur-system
```

> [!NOTE]
> Install the CLI with `brew install home-operations/tap/kopiur` (or the krew plugin,
> invoked as `kubectl kopiur`). It uses your `KUBECONFIG` to reach the cluster.

---

## Troubleshooting

| Symptom                                                                           | Cause and fix                                                                                                                                                                                 |
| --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `doctor` warns **TooManyIndexBlobs**                                              | Maintenance is behind on a busy repo. It should drain on its own with `epoch.minDuration: 6h`; if it persists, run `kopiur maintenance run lil-nas -n kopiur-system` and re-check in a while. |
| Snapshots stuck **Pending** with an HTTP 403 about a projected credentials Secret | The operator lacks RBAC to project credentials. `features.credentialProjection.enabled: true` must be set in the [HelmRelease](kopiur/app/helmrelease.yaml).                                  |
| `doctor` reports **stuck restores** (one per app)                                 | Expected. The passive populator `Restore` objects sit idle by design, waiting to hydrate a volume that may never be recreated. Not a fault.                                                   |
| Snapshot waits on a **VolumeSnapshot** to become `readyToUse`                     | Normal per-run staging while Ceph creates the CSI snapshot; it clears in a minute or two. Only a problem if a snapshot never reaches `Succeeded`.                                             |
| Mover pod can't write to the NFS repo (permission denied)                         | The export must be writable by UID/GID `1000` (the `moverDefaults` security context). Fix ownership on the NAS, not in Kubernetes.                                                            |

For anything the table doesn't cover, `kopiur doctor` and the mover Job logs
(`kopiur logs snapshot <name> -n <ns>`) are the fastest way in.
