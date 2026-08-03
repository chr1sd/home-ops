#!/usr/bin/env -S just --justfile
set shell := ['bash', '-euo', 'pipefail', '-c']

[group('Bootstrap')]
mod bootstrap

[group('Talos')]
mod talos

[group('Kube')]
mod kube "kubernetes"

[private]
default:
    @just --list

# Structured logging via gum
[private]
log level message *args:
    @gum log --time rfc3339 --structured --level "{{ level }}" "{{ message }}" {{ args }}

# Render a Jinja template and inject 1Password secrets (op://... references).
# Reads a file path, or "-" for stdin. MINIJINJA_CONFIG_FILE (mise env) applies.
[private]
template file *args:
    @minijinja-cli "{{ file }}" {{ args }} | op inject
