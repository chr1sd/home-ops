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

</div>

---
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f44b/512.gif" alt="👋" width="30" height="30"> Welcome

Welcome to the (Kubernetes) Humble Home Lab repo. The source of truth for my bare metal cluster running on Talos Linux.

The goal here is to deepen my understanding of k8s, become the GitOps mindset, and share what I learn along the way.

---
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f916/512.gif" alt="🤖" width="30" height="30"> Hardware

| System                   | Role           | CPU   | RAM   | Graphics | Disk (boot) | Disk (storage) |
|--------------------------|----------------|-------|-------|----------|-------------|----------------|
| (3x) HP EliteDesk 800 G3 Mini | Control Plane  | Intel i5-6500T     | 16GB DDR4| Intel HD 530 |256GB SSD   | —              |
| (3x) HP EliteDesk 800 G3 Mini | Worker         | Intel i5-6500T     | 64GB DDR4  | Intel HD 530 |512GB SSD   | 1TB NVMe       |
| Custom Server  | AI Workloads + NAS | Intel i7-6700K     | 64GB DDR4 |  RTX3090 |256GB SSD | 50TB RaidZ2 Pool (4x 28TB Disks) |

All of this is connected to a [Ubiquiti](https://ui.com) network with VLANS configured for IoT, Management, DMZ, and Cameras.

---
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f512/512.gif" alt="🔒" width="30" height="30"> Talos Linux

[Talos](https://www.talos.dev) is an immutable, API driven operating system designed specifically for Kubernetes. Talos is configured declaritively and is a great choice for a GitOps driven workflow.

---
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.gif" alt="🚀" width="30" height="30"> Kubernetes

For me, a home lab about tinkering and learning. So I set off to learn [Kubernetes](https://kubernetes.io) with a goal to grow my skillset and have an infrastructure that allows me to scale and provide useful, locally hosted applications for my family.

---
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f30f/512.gif" alt="🌏" width="30" height="30"> Networking: Cilium

Networking in my cluster is handled by [Cilium](https://cilium.io/).

I'm using [Envoy Gateway](https://gateway.envoyproxy.io) to manage application traffic coming into the cluster.

---
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4c8/512.gif" alt="📈" width="30" height="30"> Observability Stack

To keep a pulse on the cluster, I'm using: [Prometheus](https://prometheus.io), [Grafana](https://grafana.com), [VictoriaLogs](https://victoriametrics.com/products/victorialogs/), [Alertmanager](https://github.com/prometheus/alertmanager), [Gatus](https://github.com/TwiN/gatus), and [Fluentbit](https://fluentbit.io).

---
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f48e/512.gif" alt="💎" width="30" height="30"> Storage: Rook + Ceph

Persistent storage is provided by [Rook-Ceph](https://rook.io/), utilizing the 1TB NVMe drives on each worker.

---
## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2699_fe0f/512.gif" alt="⚙️" width="30" height="30"> GitOps with Flux

The backbone of this cluster is [Flux CD](https://fluxcd.io/) — a GitOps controller that reconciles my entire Kubernetes state from a Git repository.

My ultimate goal is to have Flux and [Renovate](https://www.mend.io/renovate/) handle most of the deployments and updates to the cluster.

### How does it work?

The core idea: **Git is the single source of truth**. Flux continuously compares what's in Git against what's running in the cluster, and corrects any difference — whether that's a new commit you pushed, or a "drift" caused by a manual change someone made directly on the cluster.

<details>
  <summary>See Flux in action</summary>

```mermaid
flowchart TD
    Dev["👩‍💻 You push YAML to Git"] --> Git[("📂 Git Repo
    Source of Truth")]
    Git -->|"Flux polls ~every 1 min"| Fetch["Flux fetches
    latest manifests"]
    Fetch --> Diff{"Cluster state = Git state?"}
    Diff -->|"✅ Already in sync"| Idle["Flux idles"]
    Idle -.->|"next poll"| Fetch
    Diff -->|"❌ Out of sync"| Apply["Flux applies manifests to Kubernetes"]
    Apply --> Cluster["☸️ Kubernetes creates / updates resources"]
    Cluster -->|"sync complete"| Diff
    Drift["⚠️ Someone manually changes the cluster"] -.->|"causes drift"| Diff

    classDef gitNode fill:#6e40c9,stroke:#4a2d8c,color:#fff
    classDef fluxNode fill:#326ce5,stroke:#1e4db3,color:#fff
    classDef k8sNode fill:#81D4FA,stroke:#0277BD,color:#000
    classDef devNode fill:#2ea44f,stroke:#1a7036,color:#fff
    classDef driftNode fill:#FFE082,stroke:#F57C00,color:#000

    class Git gitNode
    class Fetch,Diff,Idle fluxNode
    class Apply,Cluster k8sNode
    class Dev devNode
    class Drift driftNode
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

<a href="https://star-history.com/#gavinmcfall/home-ops&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=chr1sd/home-ops&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=chr1sd/home-ops&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=chr1sd/home-ops&type=Date" />
  </picture>
</a>