# 🌐 --- k8s[adventure]time --- o()xxxx[{::::::::::::::::::::::::>
Welcome to the humble home lab. This repo is the meat and potatoes of my bare metal **Kubernetes** cluster running on **Talos Linux**. The goal here is to deepen my understanding of k8s and become the **GitOps** mindset.

### 🧱 Architecture

| System                   | Role           | Nodes | CPU                | RAM   | Graphics | Disk (boot) | Disk (storage) |
|--------------------------|----------------|-------|--------------------|-------|-------------|----------|------|
| HP EliteDesk 800 G3 Mini | Control Plane  | 3     | Intel i5-6500T     | 16GB DDR4| Intel HD 530 |256GB SSD   | —              |
| HP EliteDesk 800 G3 Mini | Worker         | 3     | Intel i5-6500T     | 64GB DDR4  | Intel HD 530 |512GB SSD   | 1TB NVMe       |
| Cutom Built NZXT Server  | AI Workloads + NAS | 1 | Intel i7-6700K     | 64GB DDR4 | nVidia RTX3090 |256GB SSD | 12TB Mirrored ZFS Pool |

All of this is connected to a Ubiquiti network with VLANS configured for IoT, Management, DMZ, and Cameras.

## ☸️ Kubernetes

I want to have my own mini data center at the house. This infrastructure should be easy to redeploy if anything fails. That's why I chose to go the GitOps route. K8s allows me to scale and provide useful, locally hosted applications for my family.

>🌐 Networking: Cilium

Networking in my cluster is handled by **[Cilium](https://cilium.io/)**.

>📈 Observability Stack

To keep a pulse on the cluster, these are the obvervability apps I'm currently using:

- **Prometheus**
- **Grafana**
- **Loki**
- **Alertmanager**
- **Gatus**

>🪵 Storage: Rook + Ceph

Persistent storage is provided by **Rook-Ceph**, utilizing the 1TB NVMe drives on each worker.

>⚙️ GitOps with Flux

The backbone of this cluster is **[Flux CD](https://fluxcd.io/)** — a GitOps controller that reconciles my entire Kubernetes state from a Git repository.

My ultimate goal is to have Flux and Renovate handle most of the deployments and updates to the cluster.

---
## 📌 Foundation: onedr0p's Cluster Template

Special thanks to the most excellent [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template). It provided a clean, modern foundation for Talos + Flux-based clusters — and taught me how to organize manifests properly, use SOPS, and implement GitOps the right way.

---
## 🤯 Start This Journey Today
If you're interested in this type of thing, I encourage you to build your own home lab. Embrace the process. It will be infuriating at times, blissful at others.

You'll build some really cool stuff along the way. And your brain waves will expand.