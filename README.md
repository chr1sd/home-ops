# 🌐 --- k8s[adventure]time --- o()xxxx[{::::::::::::::::::::::::>

> This repository is a living journal of my journey to mastering **Kubernetes**, **Talos Linux**, and the **GitOps mindset** — through trial, error, and persistent volume claims.

---

## 🧠 Learning by Building
> There is no substitute for hands-on learning.

I believe the best way to learn is to *jump in the deep end* and *build* — even if that means failing over and over until something clicks.

Years ago, I wanted to learn Linux. So I wiped an old gaming PC and installed Ubuntu Server. I broke it, fixed it, rebuilt it… over 10 times. Each iteration helped me gain a little more skill and confidence.

Then came the containerize everythin phase. It was *confusing* at first — port mappings, volumes, docker-compose files — but I kept at it. Today, I’m running over 25 containers at home, including:

- 🔮 Ollama + Open WebUI (local AI)
- 🔁 n8n (workflow orchestration)
- 🧠 Qdrant (vector database)
- 🎮 Minecraft servers
- 🎙️ TeamSpeak
- 🛠️ Media stack (Radarr, Sonarr, Plex, etc.)

---

## ☸️ Enter: Kubernetes

After containers came **Kubernetes**. I figured the best way to learn it was to create my own mini production-grade data center using bare metal hardware and modern GitOps principles.

My homelab is powered by **6 HP EliteDesk 800 G3 Mini PCs**.

### 🧱 Cluster Architecture
>Node System Specs

| Role           | Nodes | CPU                | RAM   | Disk (boot) | Disk (storage) |
|----------------|-------|--------------------|-------|-------------|----------------|
| Control Plane  | 3     | Intel i5-6500T     | 16GB  | 256GB SSD   | —              |
| Worker Node    | 3     | Intel i5-6500T     | 64GB  | 512GB SSD   | 1TB NVMe       |



>🐧 Talos Linux: Immutable + Secure

All nodes run **[Talos Linux](https://www.talos.dev/)** — a modern, immutable Linux distribution built specifically for Kubernetes. There’s no shell, no package manager, and minimal surface area for attack.

Provisioning is done declaratively via **machine configurations**, and interaction is handled through `talosctl`.


>🌐 Cilium: eBPF-Powered Networking

Networking in my cluster is handled by **[Cilium](https://cilium.io/)**.


>📈 Observability Stack

To keep a pulse on the cluster, these are the obvervability apps I'm currently using:

- **Prometheus**
- **Grafana**
- **Loki**
- **Alertmanager**
- **Gatus**

>🪵 Rook + Ceph: Distributed Storage

Persistent storage is provided by **Rook-Ceph**, utilizing the 1TB NVMe drives on each worker.

>⚙️ GitOps with Flux

The backbone of this cluster is **[Flux CD](https://fluxcd.io/)** — a GitOps controller that reconciles my entire Kubernetes state from a Git repository.

My ultimate goal is to have Flux and Renovate handle most of the deployments and updates to the cluster.

---
## 📌 Foundation: onedr0p's Cluster Template

Special thanks to the most excellent [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template). It provided a clean, modern foundation for Talos + Flux-based clusters — and taught me how to organize manifests properly, use SOPS, and implement GitOps the right way.

---

## 🛠️ Coming Soon

- ✅ More observability and start deploying apps once I get my NAS re-configured.
- 🔜 Documentation for the things I learned and challenges I faced

---
### 🤯 Wow, You're Still Reading
If you're interested in this type of thing, I encourage you to build your own home lab. Embrace the process. It will be infuriating at times, blissful at others.

You'll build some really cool stuff along the way. And your brain waves will expand.