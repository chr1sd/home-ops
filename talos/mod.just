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

[doc('Print the Image Factory schematic ID')]
schematic-id:
    @curl -sX POST --data-binary @<(minijinja-cli "{{ source_directory() }}/schematic.yaml.j2") https://factory.talos.dev/schematics | jq -r '.id'

[doc("Render a node's full machine config to stdout")]
render node:
    #!/usr/bin/env bash
    set -euo pipefail
    role=$(test -f "{{ source_directory() }}/nodes/controlplane/{{ node }}.yaml.j2" && echo controlplane || echo worker)
    schematic=$(just talos schematic-id)
    talosctl machineconfig patch \
        <(just template "{{ source_directory() }}/machineconfig.yaml.j2" -D schematic="$schematic") \
        --patch @<(just template "{{ source_directory() }}/${role}.yaml.j2") \
        --patch @<(just template "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2")

[doc("Dry-run a node's rendered config against what is applied")]
diff node:
    #!/usr/bin/env bash
    set -euo pipefail
    role=$(test -f "{{ source_directory() }}/nodes/controlplane/{{ node }}.yaml.j2" && echo controlplane || echo worker)
    ip=$(minijinja-cli "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2" | yq 'select(.kind == "LinkConfig") | .addresses[0].address' | cut -d/ -f1)
    just talos render "{{ node }}" | talosctl -n "$ip" apply-config --dry-run --mode=auto -f /dev/stdin

[confirm('Apply Talos config to the node? [y/N]')]
[doc("Render and apply a node's machine config (pass --insecure or --mode=... as args)")]
apply-node node *args:
    #!/usr/bin/env bash
    set -euo pipefail
    role=$(test -f "{{ source_directory() }}/nodes/controlplane/{{ node }}.yaml.j2" && echo controlplane || echo worker)
    ip=$(minijinja-cli "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2" | yq 'select(.kind == "LinkConfig") | .addresses[0].address' | cut -d/ -f1)
    just talos render "{{ node }}" | talosctl -n "$ip" apply-config -f /dev/stdin {{ args }}

[confirm('Upgrade Talos on the node? [y/N]')]
[doc('Upgrade Talos on a single node')]
upgrade-node node:
    #!/usr/bin/env bash
    set -euo pipefail
    role=$(test -f "{{ source_directory() }}/nodes/controlplane/{{ node }}.yaml.j2" && echo controlplane || echo worker)
    ip=$(minijinja-cli "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2" | yq 'select(.kind == "LinkConfig") | .addresses[0].address' | cut -d/ -f1)
    schematic=$(just talos schematic-id)
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
