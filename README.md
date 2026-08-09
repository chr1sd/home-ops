```bash
    __   ____          ___             __                 __                     ___   __  _
   / /__( __ )_____   / _/  ____ _____/ /   _____  ____  / /___  __________     /  /  / /_(_)___ ___  ___
  / //_/ __  / ___/  / /   / __ `/ __  / | / / _ \/ __ \/ __/ / / / ___/ _ \    / /  / __/ / __ `__ \/ _ \
 / ,< / /_/ (__  )  / /   / /_/ / /_/ /| |/ /  __/ / / / /_/ /_/ / /  /  __/   / /  / /_/ / / / / / /  __/
/_/|_|\____/____/  / /    \__,_/\__,_/ |___/\___/_/ /_/\__/\__,_/_/   \___/  _/ /   \__/_/_/ /_/ /_/\___/
                  /__/                                                      /__/
```

<div align="center">

[![Discord](https://img.shields.io/discord/673534664354430999?style=for-the-badge&label&logo=discord&logoColor=white&color=blue)](https://discord.gg/home-operations)&nbsp;&nbsp;
[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://talos.dev)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=%20)](https://fluxcd.io)&nbsp;&nbsp;

</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Power](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fcluster_power_usage&style=flat-square&label=Power)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.dovis.me%2Fcluster_alert_count&style=flat-square&label=Alerts)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;

</div>

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f44b/512.gif" alt="👋" width="30" height="30"> Welcome

Welcome to the (Kubernetes) Humble Home Lab repo. The source of truth for my bare metal cluster running on Talos Linux. The goal here is to deepen my understanding of k8s, become the GitOps mindset, and share what I learn along the way.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f916/512.gif" alt="🤖" width="30" height="30"> Hardware

| System                | Role                 | CPU             | RAM        | Graphics       | Disk (boot)                  | Disk (storage)                  |
| --------------------- | -------------------- | --------------- | ---------- | -------------- | ---------------------------- | ------------------------------- |
| Minisforum MS-01 (3x) | Control Plane/Worker | Intel i9-12900H | 96GB DDR5  | Intel Iris XE  | Samsung PM983 960GB M.2 NVME | Crucial 1TB M.2 NVME            |
| HL15 2.0              | NAS                  | AMD Epyc 7452   | 256GB DDR4 | Intel ARC A310 | 512GB NVME Mirror            | ZFS RaidZ2 Pool (12x 8TB Disks) |

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f512/512.gif" alt="🔒" width="30" height="30"> Operating System

I'm running [Talos Linux](https://www.talos.dev), which is an immutable, API driven operating system designed specifically for Kubernetes. Talos is configured declaritively and is a great choice for a GitOps driven workflow.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.gif" alt="🚀" width="30" height="30"> Kubernetes

For me, a home lab about tinkering and learning. So I set off to learn [Kubernetes](https://kubernetes.io) with a goal to grow my skillset and have an infrastructure that allows me to scale and provide useful, locally hosted applications for my family.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f30f/512.gif" alt="🌏" width="30" height="30"> Networking

My homelab network stack consists of [Ubiquiti](https://ui.com) equipment with VLANS configured for IoT, Management, DMZ, and Cameras. Networking in my cluster is handled by [Cilium](https://cilium.io/). I'm using [Envoy Gateway](https://gateway.envoyproxy.io) to manage application traffic coming into the cluster.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4c8/512.gif" alt="📈" width="30" height="30"> Observability Stack

To keep a pulse on the cluster, I'm using: [Prometheus](https://prometheus.io), [Grafana](https://grafana.com), [VictoriaLogs](https://victoriametrics.com/products/victorialogs/), [Alertmanager](https://github.com/prometheus/alertmanager), [Gatus](https://github.com/TwiN/gatus), and [Fluentbit](https://fluentbit.io).

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f48e/512.gif" alt="💎" width="30" height="30"> Storage: Rook + Ceph

Persistent storage is provided by [Rook-Ceph](https://rook.io/), utilizing the 1TB NVMe drives on each node. Volumes are replicated across each node so if an app is rescheduled to a different node it will have access to it's data.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2699_fe0f/512.gif" alt="⚙️" width="30" height="30"> GitOps with Flux

The backbone of this cluster is [Flux CD](https://fluxcd.io/) — a GitOps controller that reconciles my entire Kubernetes state from a Git repository Flux and [Renovate](https://www.mend.io/renovate/) handle most of the deployments and updates to the cluster.

### How does it work?

The core idea: **Git is the single source of truth**. Flux continuously compares what's in Git against what's running in the cluster, and corrects any difference — whether that's a new commit you pushed, or a "drift" caused by a manual change someone made directly on the cluster.

<details>
  <summary>See Flux in action</summary>

```mermaid
flowchart TD
    %% MEANING: the GitOps loop — Git is the source of truth, Flux reconciles the cluster to match it

    Dev(["You — edit YAML and git push"]) --> Git[("Git repository<br/>single source of truth")]

    subgraph FluxLoop["Flux — runs inside the cluster, never sleeps"]
        Pull("Pull the latest manifests") --> Diff{"Does the cluster<br/>match Git?"}
        Diff -->|"yes — in sync"| Wait("Wait for the next check")
        Wait -.-> Pull
        Diff -->|"no — out of sync"| Apply("Apply what changed")
    end

    Git -->|"Flux checks ~every minute"| Pull
    Apply --> K8s("Kubernetes updates<br/>pods, services and config")
    K8s -->|"cluster now matches Git"| Diff
    Drift("Manual kubectl edit") -.->|"drift! Flux puts it back"| Diff

    classDef human fill:#A7F3D0,stroke:#047857,stroke-width:2px,color:#000
    classDef git fill:#DDD6FE,stroke:#6D28D9,stroke-width:2px,color:#000
    classDef flux fill:#BFDBFE,stroke:#1D4ED8,stroke-width:2px,color:#000
    classDef k8s fill:#A5F3FC,stroke:#0E7490,stroke-width:2px,color:#000
    classDef warn fill:#FDE68A,stroke:#B45309,stroke-width:2px,color:#000

    class Dev human
    class Git git
    class Pull,Diff,Wait,Apply flux
    class K8s k8s
    class Drift warn

    style FluxLoop fill:#EFF6FF,stroke:#93C5FD,color:#1E3A8A
```

> **The magic of GitOps:** if someone manually tweaks a resource directly on the cluster, Flux detects the drift and reverts it back to what Git says it should be. The cluster always converges to Git — not the other way around.

</details>

---

I made a [Youtube video](https://youtu.be/aeUKOpeoiUs) that gives a general overview of my configuration and the core components.

<a href="https://youtube.com/watch?v=aeUKOpeoiUs">
  <img src="https://github.com/user-attachments/assets/2dab1c6f-7b27-4b94-a7ad-a6d9c5b17c78" alt="Youtube Video" width="300">
</a>

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f6a7/512.gif" alt="🚧" width="30" height="30"> Foundation: onedr0p's Cluster Template

Special thanks to the most excellent [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template). It provides a clean, modern foundation for Talos + Flux-based clusters — and taught me how to organize manifests properly, use SOPS, and implement GitOps the right way.

[![Flux Cluster Template](https://img.shields.io/badge/Cluster%20Template-1f6feb?style=for-the-badge)](https://github.com/onedr0p/cluster-template)
[![Flux Cluster Template Stars](https://img.shields.io/github/stars/onedr0p/cluster-template?style=for-the-badge&color=1f6feb)](https://github.com/onedr0p/cluster-template)

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f92f/512.gif" alt="🤯" width="30" height="30"> Start This Journey Today

If you're interested in this type of thing, I encourage you to build your own home lab. It doesn't have to be Kubernetes. Grab ANY old computer and see what you can deploy on it.

Embrace the process. It will be infuriating at times, blissful at others.

You'll build some really cool stuff along the way. And your brain waves will expand.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f31f/512.gif" alt="🌟" width="30" height="30"> Stargazers

<a href="https://www.star-history.com/?repos=chr1sd%2Fhome-ops&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=chr1sd/home-ops&type=date&theme=dark&legend=top-left&sealed_token=rt4b4YsMszpCGWPEEx0TgN1icgjWcY8w8xDTKxruvR7MF7yOd4LC9S6Cy0wVsz4bMUvYZlM_x1L8c2-A76b-oxL9HbNrOgF-zDvNUllZrCvGBvnUGMa4kg" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=chr1sd/home-ops&type=date&legend=top-left&sealed_token=rt4b4YsMszpCGWPEEx0TgN1icgjWcY8w8xDTKxruvR7MF7yOd4LC9S6Cy0wVsz4bMUvYZlM_x1L8c2-A76b-oxL9HbNrOgF-zDvNUllZrCvGBvnUGMa4kg" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=chr1sd/home-ops&type=date&legend=top-left&sealed_token=rt4b4YsMszpCGWPEEx0TgN1icgjWcY8w8xDTKxruvR7MF7yOd4LC9S6Cy0wVsz4bMUvYZlM_x1L8c2-A76b-oxL9HbNrOgF-zDvNUllZrCvGBvnUGMa4kg" />
 </picture>
</a>
