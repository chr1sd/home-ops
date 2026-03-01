```bash
    __   ____          ___             __                 __                     ___   __  _
   / /__( __ )_____   / _/  ____ _____/ /   _____  ____  / /___  __________     /  /  / /_(_)___ ___  ___
  / //_/ __  / ___/  / /   / __ `/ __  / | / / _ \/ __ \/ __/ / / / ___/ _ \    / /  / __/ / __ `__ \/ _ \
 / ,< / /_/ (__  )  / /   / /_/ / /_/ /| |/ /  __/ / / / /_/ /_/ / /  /  __/   / /  / /_/ / / / / / /  __/
/_/|_|\____/____/  / /    \__,_/\__,_/ |___/\___/_/ /_/\__/\__,_/_/   \___/  _/ /   \__/_/_/ /_/ /_/\___/
                  /__/                                                      /__/
```

Welcome to the (Kubernetes) Humble Home Lab repo. The source of truth for my bare metal cluster running on Talos Linux.

The goal here is to deepen my understanding of k8s, become the GitOps mindset, and share what I learn along the way.

## 🖥️ Hardware

| System                   | Role           | CPU   | RAM   | Graphics | Disk (boot) | Disk (storage) |
|--------------------------|----------------|-------|-------|----------|-------------|----------------|
| (3x) HP EliteDesk 800 G3 Mini | Control Plane  | Intel i5-6500T     | 16GB DDR4| Intel HD 530 |256GB SSD   | —              |
| (3x) HP EliteDesk 800 G3 Mini | Worker         | Intel i5-6500T     | 64GB DDR4  | Intel HD 530 |512GB SSD   | 1TB NVMe       |
| Custom Server  | AI Workloads + NAS | Intel i7-6700K     | 64GB DDR4 |  RTX3090 |256GB SSD | 50TB RaidZ2 Pool (4x 28TB Disks) |

All of this is connected to a [Ubiquiti](https://ui.com) network with VLANS configured for IoT, Management, DMZ, and Cameras.

## 🛡️ Talos Linux

[Talos](https://www.talos.dev) is an immutable, API driven operating system designed specifically for Kubernetes. Talos is configured declaritively and is a great choice for a GitOps driven workflow.

## ☸️ Kubernetes

For me, a home lab about tinkering and learning. So I set off to learn [Kubernetes](https://kubernetes.io) with a goal to grow my skillset and have an infrastructure that allows me to scale and provide useful, locally hosted applications for my family.

### 🌐 Networking: Cilium

Networking in my cluster is handled by [Cilium](https://cilium.io/).

I'm using [Envoy Gateway](https://gateway.envoyproxy.io) to manage application traffic coming into the cluster.

### 📈 Observability Stack

To keep a pulse on the cluster, I'm using: [Prometheus](https://prometheus.io), [Grafana](https://grafana.com), [VictoriaLogs](https://victoriametrics.com/products/victorialogs/), [Alertmanager](https://github.com/prometheus/alertmanager), [Gatus](https://github.com/TwiN/gatus), and [Fluentbit](https://fluentbit.io).

### 🪵 Storage: Rook + Ceph

Persistent storage is provided by [Rook-Ceph](https://rook.io/), utilizing the 1TB NVMe drives on each worker.

### ⚙️ GitOps with Flux

The backbone of this cluster is [Flux CD](https://fluxcd.io/) — a GitOps controller that reconciles my entire Kubernetes state from a Git repository.

My ultimate goal is to have Flux and [Renovate](https://www.mend.io/renovate/) handle most of the deployments and updates to the cluster.

I made a [Youtube video](https://youtu.be/aeUKOpeoiUs) that gives a general overview of my configuration and the core components.

---
## 📌 Foundation: onedr0p's Cluster Template

Special thanks to the most excellent [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template). It provides a clean, modern foundation for Talos + Flux-based clusters — and taught me how to organize manifests properly, use SOPS, and implement GitOps the right way.

---
## 🤯 Start This Journey Today
If you're interested in this type of thing, I encourage you to build your own home lab. It doesn't have to be Kubernetes. Grab ANY old computer and see what you can deploy on it.

Embrace the process. It will be infuriating at times, blissful at others.

You'll build some really cool stuff along the way. And your brain waves will expand.