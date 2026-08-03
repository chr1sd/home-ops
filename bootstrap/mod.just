set shell := ['bash', '-euo', 'pipefail', '-c']

# End-to-end cluster bootstrap. Secrets come from 1Password (op inject) — no SOPS,
# no talhelper. Requires: op (signed in), minijinja-cli, talosctl, kubectl,
# kustomize, helmfile, yq, jq, curl, gum.

# A reachable control-plane node IP to bootstrap etcd against
controller := "10.13.17.22"

[private]
default:
    @just --list bootstrap

[confirm('Bootstrap the Talos + Kubernetes cluster? [y/N]')]
[doc('Bootstrap a Talos & Kubernetes cluster end-to-end')]
cluster: nodes etcd kubeconfig wait-nodes namespaces secrets crds apps
    @just log info "Cluster bootstrapped — Flux is now syncing the Git repository"

# Apply each node's rendered config in maintenance mode (tolerates already-configured)
[private]
nodes:
    #!/usr/bin/env bash
    set -euo pipefail
    just log info "Applying Talos node configs"
    for f in {{ justfile_directory() }}/talos/nodes/controlplane/*.yaml.j2 {{ justfile_directory() }}/talos/nodes/worker/*.yaml.j2; do
        node=$(basename "$f" .yaml.j2)
        just log info "Applying node config" "node" "$node"
        just --yes talos apply-node "$node" --insecure || true
    done

# Bootstrap etcd on the controller (retry until it reports AlreadyExists)
[private]
etcd:
    #!/usr/bin/env bash
    set -euo pipefail
    just log info "Bootstrapping etcd" "node" "{{ controller }}"
    until op=$(talosctl -n {{ controller }} bootstrap 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do
        just log info "etcd bootstrap in progress, retrying in 10s"
        sleep 10
    done

# Fetch the kubeconfig to the repo root
[private]
kubeconfig:
    @just log info "Fetching kubeconfig"
    @talosctl -n {{ controller }} kubeconfig --force --force-context-name main {{ justfile_directory() }}

# Wait for nodes to register (Ready=False is enough before CNI is installed)
[private]
wait-nodes:
    #!/usr/bin/env bash
    set -euo pipefail
    just log info "Waiting for nodes to register"
    if ! kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
            just log info "Nodes not available yet, retrying in 10s"
            sleep 10
        done
    fi

# Create app namespaces
[private]
namespaces:
    #!/usr/bin/env bash
    set -euo pipefail
    just log info "Applying namespaces"
    for dir in {{ justfile_directory() }}/kubernetes/apps/*/; do
        ns=$(basename "$dir")
        kubectl get namespace "$ns" &>/dev/null && continue
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply --server-side -f -
    done

# Apply the 1Password-connect + git deploy-key root secrets (op inject)
[private]
secrets:
    @just log info "Applying bootstrap secrets"
    @kustomize build {{ justfile_directory() }}/bootstrap/kustomize/apps | just template - | kubectl apply --server-side -f -

# Apply CRDs required before the Helm apps
[private]
crds:
    @just log info "Applying CRDs"
    @helmfile --file {{ justfile_directory() }}/bootstrap/helmfile.d/00-crds.yaml template --quiet | kubectl apply --server-side -f -

# Sync the bootstrap Helm releases (cilium, flux, etc.)
[private]
apps:
    @just log info "Syncing Helm releases"
    @helmfile --file {{ justfile_directory() }}/bootstrap/helmfile.d/01-apps.yaml sync --hide-notes
