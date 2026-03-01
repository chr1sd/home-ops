#!/usr/bin/env bash
set -euo pipefail

WORKERS=(
  10.13.17.19
  10.13.17.20
  10.13.17.21
)

CONTROLPLANE=(
  10.13.17.22
  10.13.17.23
  10.13.17.24
)

csv() { IFS=,; echo "$*"; }

W_CSV="$(csv "${WORKERS[@]}")"
C_CSV="$(csv "${CONTROLPLANE[@]}")"

echo "Shutting down WORKERS first: ${W_CSV}"
talosctl --nodes "${W_CSV}" shutdown --force --wait=false

# Give workers a head start before pulling the rug from etcd/API
sleep 120

echo "Shutting down CONTROL PLANE last: ${C_CSV}"
talosctl --nodes "${C_CSV}" shutdown --force --wait=false

echo "Shutdown commands sent."



## scale pvs down
# kubectl scale deploy -n default --all --replicas=1
# kubectl scale deploy -n games --all --replicas=1
# kubectl scale deploy -n observability --all --replicas=1
# kubectl -n observability scale sts prometheus-kube-prometheus-stack --replicas=1
# kubectl -n observability scale sts alertmanager-kube-prometheus-stack --replicas=1
# kubectl -n observability scale sts loki --replicas=1
# kubectl -n default scale sts cross-seed --replicas=1