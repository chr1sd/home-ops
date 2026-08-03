set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    @just --list kube

[doc('Force Flux to reconcile from the Git repository')]
reconcile:
    @flux --namespace flux-system reconcile kustomization flux-system --with-source
