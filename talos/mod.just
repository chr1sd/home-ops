set shell := ['bash', '-euo', 'pipefail', '-c']

# Talos machine configs are rendered from Jinja templates in this dir, with
# secrets resolved from 1Password at render time (see the root `template` helper):
#   just template <tmpl> | ... -> talosctl machineconfig patch
# No talhelper, no SOPS. Requires: minijinja-cli, op (signed in), talosctl, yq, jq, curl.

# renovate: datasource=docker depName=ghcr.io/siderolabs/installer
talos_version := "v1.13.7"
# renovate: datasource=docker depName=ghcr.io/siderolabs/kubelet
kubernetes_version := "v1.36.3"

[private]
default:
    @just --list talos

[doc('Print the Image Factory schematic ID (role: controlplane|worker)')]
schematic-id role='controlplane':
    #!/usr/bin/env bash
    set -euo pipefail
    file=schematic.yaml.j2
    [[ "{{ role }}" == "worker" ]] && file=worker-schematic.yaml.j2
    curl -sX POST --data-binary @<(minijinja-cli "{{ source_directory() }}/${file}") https://factory.talos.dev/schematics | jq -r '.id'

[doc('Download the Talos ISO matching the current schematic (role: controlplane|worker)')]
download-image role='controlplane':
    #!/usr/bin/env bash
    set -euo pipefail
    id=$(just talos schematic-id {{ role }})
    curl -fL --remove-on-error --progress-bar \
        -o "{{ source_directory() }}/talos-{{ talos_version }}-${id:0:8}.iso" \
        "https://factory.talos.dev/image/${id}/{{ talos_version }}/metal-amd64.iso"
    just log info "Downloaded ISO" "schematic" "${id:0:8}" "version" "{{ talos_version }}"

[doc('Generate talosconfig at the repo root from the 1Password talos secrets')]
talosconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    # Reconstruct the secrets bundle from 1Password, then mint a fresh admin
    # talosconfig signed by the existing cluster CA (no cluster access needed).
    just template "{{ source_directory() }}/talossecret.yaml.j2" > "$tmp/secrets.yaml"
    talosctl gen config kubernetes https://10.13.17.17:6443 \
        --with-secrets "$tmp/secrets.yaml" \
        --output-types talosconfig \
        --output "{{ justfile_directory() }}/talosconfig" --force
    talosctl --talosconfig "{{ justfile_directory() }}/talosconfig" \
        config endpoint 10.13.17.22 10.13.17.23 10.13.17.24
    # Default nodes (all three) so `talosctl` without -n and the reset recipe work
    talosctl --talosconfig "{{ justfile_directory() }}/talosconfig" \
        config node 10.13.17.22 10.13.17.23 10.13.17.24
    just log info "Wrote talosconfig" "path" "{{ justfile_directory() }}/talosconfig"

[doc("Render a node's full machine config to stdout")]
render node:
    #!/usr/bin/env bash
    set -euo pipefail
    role=controlplane # kvrnts-1/2/3 are combined control-plane + worker
    [[ -f "{{ source_directory() }}/nodes/worker/{{ node }}.yaml.j2" ]] && role=worker
    schematic=$(just talos schematic-id "$role")
    talosctl machineconfig patch \
        <(just template "{{ source_directory() }}/machineconfig.yaml.j2" -D schematic="$schematic") \
        --patch @<(just template "{{ source_directory() }}/${role}.yaml.j2") \
        --patch @<(just template "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2")

[doc("Dry-run a node's rendered config against what is applied")]
diff node:
    #!/usr/bin/env bash
    set -euo pipefail
    role=controlplane # kvrnts-1/2/3 are combined control-plane + worker
    [[ -f "{{ source_directory() }}/nodes/worker/{{ node }}.yaml.j2" ]] && role=worker
    ip=$(minijinja-cli "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2" | yq 'select(.kind == "BondConfig") | .addresses[0].address' | cut -d/ -f1)
    just talos render "{{ node }}" | talosctl -n "$ip" apply-config --dry-run --mode=auto -f /dev/stdin

[confirm('Apply Talos config to the node? [y/N]')]
[doc("Render and apply a node's machine config (pass --insecure or --mode=... as args)")]
apply-node node *args:
    #!/usr/bin/env bash
    set -euo pipefail
    role=controlplane # kvrnts-1/2/3 are combined control-plane + worker
    [[ -f "{{ source_directory() }}/nodes/worker/{{ node }}.yaml.j2" ]] && role=worker
    ip=$(minijinja-cli "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2" | yq 'select(.kind == "BondConfig") | .addresses[0].address' | cut -d/ -f1)
    just talos render "{{ node }}" | talosctl -n "$ip" apply-config -f /dev/stdin {{ args }}

[confirm('Upgrade Talos on the node? [y/N]')]
[doc('Upgrade Talos on a single node')]
upgrade-node node:
    #!/usr/bin/env bash
    set -euo pipefail
    role=controlplane # kvrnts-1/2/3 are combined control-plane + worker
    [[ -f "{{ source_directory() }}/nodes/worker/{{ node }}.yaml.j2" ]] && role=worker
    ip=$(minijinja-cli "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2" | yq 'select(.kind == "BondConfig") | .addresses[0].address' | cut -d/ -f1)
    schematic=$(just talos schematic-id "$role")
    talosctl -n "$ip" upgrade --image="factory.talos.dev/metal-installer/${schematic}:{{ talos_version }}" --timeout=10m

[confirm('Upgrade Kubernetes across the cluster? [y/N]')]
[doc('Upgrade Kubernetes cluster-wide')]
upgrade-k8s:
    #!/usr/bin/env bash
    set -euo pipefail
    controller=$(talosctl config info -o yaml | yq -r '.endpoints[0]')
    talosctl -n "$controller" upgrade-k8s --to {{ kubernetes_version }}

[confirm('DESTRUCTIVE: reset all nodes to maintenance mode? [y/N]')]
[doc('Reset nodes back to maintenance mode (DESTROYS the cluster)')]
reset:
    #!/usr/bin/env bash
    set -euo pipefail
    nodes=$(talosctl config info -o yaml | yq -r '.nodes | join(" ")')
    talosctl -n "$nodes" reset --reboot --graceful=false --wait=false
