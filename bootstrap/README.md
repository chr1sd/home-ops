# Bootstrapping the Cluster

This is the start-to-finish guide for turning bare machines into a running Kubernetes
cluster that manages itself through Git. The whole thing comes down to one command —
`just bootstrap cluster` — but that command only works once the machines, your
workstation, and a handful of 1Password secrets are in place. This document walks
through all of it, in order.

If you are reading this to learn how the setup works (rather than to rebuild it), read
[What you're building](#what-youre-building) and [How secrets work](#how-secrets-work)
and skip the stages.

> [!NOTE]
> The commands and values here are for **this** cluster (nodes `kvrnts-*` on
> `10.13.17.0/24`, 1Password vault `k8s`, repo `chr1sd/home-ops`). Lines marked
> ⭐ are the ones you would change to adapt this to your own hardware and accounts.

---

## What you're building

Three machines running [Talos Linux](https://www.talos.dev) (an immutable, API-driven OS
built only for Kubernetes) — each a combined control-plane and worker. Talos has no
shell and no SSH; every machine is configured by pushing a declarative config to its API.

Once the cluster is up, [Flux](https://fluxcd.io) takes over and reconciles everything
under [`kubernetes/`](../kubernetes) from Git. [Cilium](https://cilium.io) is the
network. [External Secrets](https://external-secrets.io) pulls application secrets from
1Password. [kopiur](https://github.com/home-operations/kopiur) handles backups.

Two ideas make the bootstrap work:

- **No secrets live in this repo.** Every secret is an `op://…` reference that is
  resolved from 1Password at apply time with `op inject`. See
  [How secrets work](#how-secrets-work).
- **Machine configs are rendered, not stored.** Talos configs are Jinja templates in
  [`talos/`](../talos) rendered by `minijinja-cli`, with secrets injected from 1Password.

The bootstrap does the minimum needed to get Flux running, then Flux does the rest.

---

## Prerequisites

**Knowledge.** You should be comfortable with containers, YAML, and Git. You do not need
to be a Kubernetes expert, but you will get more out of this if the words "pod",
"namespace", and "manifest" are not brand new.

**Hardware.** Any x86-64 machines with wired networking will do. This cluster runs:

| Role                   | Nodes                              | IPs                 | Disks                                        |
| ---------------------- | ---------------------------------- | ------------------- | -------------------------------------------- |
| Control plane + worker | `kvrnts-1`, `kvrnts-2`, `kvrnts-3` | `10.13.17.22`–`.24` | 2× NVMe per node (one OS/etcd, one Ceph OSD) |

The control-plane endpoint is a shared virtual IP, `10.13.17.17`, that floats across the
three control-plane nodes. The gateway is `10.13.17.1`.

> [!TIP]
> Three control-plane nodes gives you a highly-available cluster (etcd tolerates one
> node down). One control-plane node works fine for a lab; you just lose that tolerance.

> ⭐ Your node names, IPs, disks, and VIP are defined in
> [`talos/nodes/`](../talos/nodes), [`talos/machineconfig.yaml.j2`](../talos/machineconfig.yaml.j2),
> and [`talos/controlplane.yaml.j2`](../talos/controlplane.yaml.j2). Find your disk IDs
> with `talosctl get disks -n <ip> --insecure` once a node is in maintenance mode
> (Stage 1).

**Tools.** Everything is pinned in [`.mise.toml`](../.mise.toml) and installed by
[mise](https://mise.jdx.dev). You do not install tools by hand. The set includes
`talosctl`, `just`, `minijinja-cli`, the 1Password CLI (`op`), `kubectl`, `helmfile`,
`kustomize`, `flux`, `cilium`, `yq`, `jq`, and `gum`.

**A domain** is optional and only needed later, for exposing apps to the internet. The
bootstrap itself needs no domain and no DNS beyond your LAN.

---

## Stage 1 — Prepare the machines

Goal: every node booted into Talos **maintenance mode** and reachable on the network.
In maintenance mode a node is running Talos from removable media with no config yet,
waiting to be told what to be.

1. **Get your schematic ID.** The schematic is the Talos image customization (kernel
   args + system extensions) defined in
   [`talos/schematic.yaml.j2`](../talos/schematic.yaml.j2). Print its ID:

    ```sh
    just talos schematic-id
    ```

    For this cluster that returns `7361710113bd943edd751852342b1ccaa283d00a7257476a53eb4f10dcae8b02`
    (Intel iGPU + NFS extensions).

    > ⭐ If your hardware differs (AMD, no iGPU, different storage drivers), edit
    > `talos/schematic.yaml.j2` first — the ID changes with its contents.

2. **Download the installer ISO** from the [Talos Image Factory](https://factory.talos.dev),
   substituting your schematic ID and the Talos version from
   [`talos/mod.just`](mod.just) (`talos_version`, currently `v1.13.7`):

    ```sh
    curl -fLO "https://factory.talos.dev/image/$(just talos schematic-id)/v1.13.7/metal-amd64.iso"
    ```

3. **Flash the ISO** to a USB stick (e.g. with [balenaEtcher](https://etcher.balena.io))
   and boot each machine from it. The machine boots Talos into maintenance mode.

4. **Verify** each node is up and in maintenance mode (it listens on port 50000):

    ```sh
    nmap -Pn -n -p 50000 10.13.17.0/24 -vv | grep 'Discovered'
    # or, per node:
    talosctl get disks -n 10.13.17.22 --insecure
    ```

> [!IMPORTANT]
> Note each node's real install-disk ID (`talosctl get disks -n <ip> --insecure`) and
> make sure it matches what's in `talos/nodes/<node>.yaml.j2`. Installing to the wrong
> disk is the most common bare-metal mistake.

---

## Stage 2 — Prepare your workstation

1. **Clone the repo** and enter it:

    ```sh
    git clone https://github.com/chr1sd/home-ops && cd home-ops
    ```

2. **Install the tools** with mise:

    ```sh
    mise trust && mise install
    ```

    > [!NOTE]
    > The first `mise trust` is required — mise will not run a repo's config or set its
    > environment (`KUBECONFIG`, `TALOSCONFIG`, `MINIJINJA_CONFIG_FILE`) until you trust it.

3. **Sign in to 1Password** so `op inject` can resolve secrets:

    ```sh
    eval "$(op signin)"
    op whoami   # confirm you're signed in
    ```

4. **Generate your `talosconfig`** from 1Password (skip if you already have it at the
   repo root):

    ```sh
    just talos talosconfig
    ```

    This mints an admin `talosconfig` — the credential `talosctl` uses to reach the
    Talos API — from the cluster CA stored in the 1Password `talos` item. It's written to
    the repo root and gitignored (mise points `TALOSCONFIG` there). The `etcd` and
    `kubeconfig` bootstrap stages need it.

---

## Stage 3 — Populate 1Password

All secrets live in the `k8s` vault. The bootstrap needs the three items below to exist
**before** you run it — everything else (app passwords, Cloudflare, the kopiur repo
password, etc.) is pulled by External Secrets automatically once the cluster is up.

| Item (`op://k8s/<item>`) | Fields                                                                                                                                                                                                                                                                                                            | Used for                                                                                        |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `talos`                  | `MACHINE_TOKEN`, `MACHINE_CA_CRT`, `MACHINE_CA_KEY`, `CLUSTER_ID`, `CLUSTER_SECRET`, `CLUSTER_TOKEN`, `CLUSTER_SECRETBOXENCRYPTIONSECRET`, `CLUSTER_CA_CRT`, `CLUSTER_CA_KEY`, `CLUSTER_AGGREGATORCA_CRT`, `CLUSTER_AGGREGATORCA_KEY`, `CLUSTER_SERVICEACCOUNT_KEY`, `CLUSTER_ETCD_CA_CRT`, `CLUSTER_ETCD_CA_KEY` | The Talos cluster's root secrets and CAs, injected into every node's config                     |
| `1password`              | `OP_SESSION_JSON`, `OP_CONNECT_TOKEN`                                                                                                                                                                                                                                                                             | Credentials for the in-cluster 1Password Connect server, so External Secrets can read the vault |
| `github-deploy-key`      | `identity`, `known_hosts`                                                                                                                                                                                                                                                                                         | The SSH key Flux uses to pull this repo                                                         |

How to create each:

- **`talos`** — these 14 values are your Talos secret bundle. If you are migrating from a
  `talsecret.sops.yaml`, generate the item with
  [`.private/populate-1password-talos.sh`](../.private) (it reads the decrypted bundle and
  writes each field, no plaintext to disk). For a brand-new cluster, generate a fresh
  bundle with `talosctl gen secrets` and split its values into these fields.
- **`github-deploy-key`** — create a repo deploy key
  ([GitHub docs](https://fluxcd.io/flux/installation/bootstrap/github/#github-deploy-key-authentication)),
  add the public half to the repo's Deploy Keys, and store the private key as `identity`
  and GitHub's host key as `known_hosts`. The helper
  [`.private/populate-1password-github-deploy-key.sh`](../.private) can create the item
  from an existing in-cluster secret.
- **`1password`** — from your 1Password account, create a
  [Connect server / credentials file](https://developer.1password.com/docs/connect/get-started/)
  and an access token; store the credentials JSON as `OP_SESSION_JSON` and the token as
  `OP_CONNECT_TOKEN`.

> ⭐ The item names, fields, and vault are referenced in the `op://…` paths inside
> [`bootstrap/kustomize/apps/`](kustomize/apps) and the `talos/*.yaml.j2` templates.
> Change those references if you use a different vault or item layout.

Confirm everything resolves before bootstrapping — this renders the bootstrap secrets and
should print without error:

```sh
kustomize build bootstrap/kustomize/apps | op inject >/dev/null && echo "secrets OK"
```

---

## Stage 4 — Bootstrap the cluster

One command. It will prompt for confirmation.

```sh
just bootstrap cluster
```

> [!WARNING]
> This takes **10+ minutes** and you will see a flood of errors along the way —
> "no matching resources", pods crash-looping, nodes `NotReady`. This is **normal**:
> nothing works until Cilium installs the network, and Flux needs time to converge.
> Do not interrupt it. If it does fail partway, every stage is safe to re-run — fix the
> problem and run `just bootstrap cluster` again.

The command runs these stages in order (defined in [`bootstrap/mod.just`](mod.just)):

1. **nodes** — Renders each node's Talos config from the `talos/` templates (with
   1Password injected) and applies it with `talosctl apply-config --insecure`.
   Already-configured nodes are skipped, so this is safe to re-run.
2. **etcd** — Runs `talosctl bootstrap` against the control-plane node `10.13.17.22`,
   retrying until etcd reports it already exists.
3. **kubeconfig** — Fetches the cluster's kubeconfig to the repo root.
4. **wait-nodes** — Waits for all nodes to register with the API (they stay `NotReady`
   until the CNI is installed — expected).
5. **namespaces** — Creates the namespaces under [`kubernetes/apps/`](../kubernetes/apps)
   so the next step's secrets have somewhere to land.
6. **secrets** — Applies the three bootstrap secrets, rendering
   `bootstrap/kustomize/apps` through `op inject`. This is what lets 1Password Connect
   and Flux start.
7. **crds** — Extracts and applies CRDs out-of-band from
   [`bootstrap/helmfile/crds.yaml`](helmfile/crds.yaml) (envoy-gateway, grafana-operator,
   kube-prometheus-stack, external-dns), so any resource that references them — Gateway
   API objects, `GrafanaDashboard`s, `ServiceMonitor`s — applies cleanly instead of
   failing until its controller catches up.
8. **apps** — `helmfile sync` of the minimal chain Flux needs before it can take over:
   `cilium → coredns → spegel → cert-manager → external-secrets → onepassword-connect →
flux-operator → flux-instance`. Chart, version, and values for each come straight from
   that app's manifests under `kubernetes/apps/`, so bootstrap installs exactly what Flux
   will reconcile.

Once `flux-instance` is healthy, Flux connects to Git and reconciles everything under
`kubernetes/`. From here the cluster manages itself.

---

## Verify

Work down this list; each check should pass before you trust the next.

```sh
# Talos + etcd healthy
talosctl -n 10.13.17.22 health
talosctl -n 10.13.17.22,10.13.17.23,10.13.17.24 etcd status   # 3 members, no errors

# Nodes Ready and the network up
kubectl get nodes -o wide
cilium status

# Flux connected and reconciling
flux check
flux get kustomizations -A         # all Ready=True (may take a few minutes)

# Backups operator healthy (see the kopiur guide for restores)
kopiur doctor
```

> [!TIP]
> `flux get kustomizations -A` is the single best "is the cluster done converging?"
> check. If some show `Ready=False`, give it time, then inspect with
> `flux get hr -A` and `kubectl describe` the failing resource.

---

## How secrets work

There is no SOPS and no encrypted secret file in this repo. Two mechanisms cover
everything:

- **At bootstrap**, before any controller exists, secrets are `op://…` references in
  plain manifests and Talos templates. `op inject` (using your signed-in `op` session)
  replaces them with real values at the moment they're applied. This is how the three
  root secrets in Stage 3 get in.
- **After bootstrap**, [External Secrets](https://external-secrets.io) + the in-cluster
  1Password Connect server pull every other secret from the `k8s` vault on a schedule.
  App manifests only ever contain an `ExternalSecret` pointing at a vault item, never a
  value.

The one credential that can't come from External Secrets is External Secrets' own access
to 1Password — which is exactly the `1password` item the bootstrap applies by hand.

---

## Single source of truth

The bootstrap installs the same charts Flux will go on to manage — Cilium, cert-manager,
External Secrets, Flux itself, and the CRD-bearing operators. To stop the two from
drifting, the bootstrap helmfiles hardcode neither chart versions nor values. They read
both from each app's own Flux manifests.

`bootstrap/helmfile/` holds two helmfiles, `crds.yaml` and `apps.yaml`, and both inherit
a shared `default.yaml` that wires up two templates:

- [`templates/release.yaml.gotmpl`](helmfile/templates/release.yaml.gotmpl) reads the
  chart URL and version from `kubernetes/apps/<namespace>/<app>/app/ocirepository.yaml`.
- [`templates/values.yaml.gotmpl`](helmfile/templates/values.yaml.gotmpl) reads
  `.spec.values` from that app's `helmrelease.yaml`.

A release therefore declares only its `name` and `namespace`. The `name` maps to the
app's directory under `kubernetes/apps/`, and everything else is pulled from the manifests
Flux already reconciles. Two consequences follow: the bootstrap installs exactly what
steady-state Flux would (no "works in bootstrap, breaks under Flux" surprises), and there
is exactly one place to bump a version — the app's `ocirepository.yaml`, which Renovate
keeps current.

[`crds.yaml`](helmfile/crds.yaml) uses the same sourcing for a different job. Its releases
are never installed; the `crds` stage renders each with `--include-crds` and applies only
the `CustomResourceDefinition` objects. Pre-installing CRDs this way lets a resource that
references one — a `Gateway`, a `GrafanaDashboard`, a `ServiceMonitor` — apply on Flux's
first pass instead of failing until its controller's chart catches up. That removes the
need to thread `dependsOn` through nearly every Kustomization.

> [!TIP]
> To add a chart to the bootstrap, add a `name:`/`namespace:` entry pointing at an
> existing app directory — never a chart URL or version. If that chart's CRDs are needed
> before its consumers reconcile, add the same entry to `crds.yaml` as well.

---

## Recovery and reset

- **Bootstrap failed partway:** fix the cause and run `just bootstrap cluster` again.
  Every stage is idempotent.
- **A single node is wrong:** re-apply just that node with
  `just talos apply-node <node>` (add `--insecure` if it's back in maintenance mode).
- **Start completely over:** `just talos reset` wipes all nodes back to maintenance mode.

> [!CAUTION]
> `just talos reset` destroys the cluster and all local storage on the nodes. Application
> data on the NAS-backed backup repository survives, but anything only on node disks is
> gone. Restore from backups afterward (see the
> [kopiur guide](../kubernetes/apps/kopiur-system/README.md)).

---

## Adapting this for your own cluster

If you're building your own from this repo, the files to change are:

- [`talos/nodes/`](../talos/nodes) — one file per node: hostname, IP, install disk.
- [`talos/machineconfig.yaml.j2`](../talos/machineconfig.yaml.j2) and
  [`talos/controlplane.yaml.j2`](../talos/controlplane.yaml.j2) — cluster name, VIP,
  subnets, control-plane endpoint.
- [`talos/schematic.yaml.j2`](../talos/schematic.yaml.j2) — kernel args and system
  extensions for your hardware.
- [`bootstrap/mod.just`](mod.just) — the `controller` IP the bootstrap targets.
- [`.mise.toml`](../.mise.toml) — the `TALOSCONFIG`/`KUBECONFIG` paths if you relocate them.
- The `op://…` references throughout — repoint them at your vault and items.

---

## After bootstrap: restoring data

A fresh cluster comes up with empty volumes. Restoring application data from the kopiur
backup repository is a separate procedure — see the
[kopiur guide](../kubernetes/apps/kopiur-system/README.md). In short: because each app's
PVC is wired to restore from its latest backup on creation, bringing the apps back up
repopulates their data automatically.
