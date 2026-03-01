#!/usr/bin/env bash
set -euo pipefail

: "${DRY_RUN:=1}"   # set DRY_RUN=0 to actually scale + migrate
: "${SUFFIX:=-temp}"

# Format: "namespace pvcname"
PVC_LIST=$(cat <<'EOF'
default autobrr
default bazarr
default config-cross-seed-0
default jellyfin
default prowlarr
default qbittorrent-config
default qui
default radarr
default recyclarr
default seerr
default sonarr
default thelounge
default trilium
games minecraft-java
observability alertmanager-kube-prometheus-stack-db-alertmanager-kube-prometheus-stack-0
observability prometheus-kube-prometheus-stack-db-prometheus-kube-prometheus-stack-0
observability storage-loki-0
EOF
)
pv-migrate --source prowlarr-temp --dest prowlarr -n default -N default --ignore-mounted
pv-migrate --source qbittorrent-config-temp --dest qbittorrent -n default -N default --ignore-mounted
pv-migrate --source qui-temp --dest qui -n default -N default --ignore-mounted
pv-migrate --source radarr-temp --dest radarr -n default -N default --ignore-mounted
pv-migrate --source recyclarr-temp --dest recyclarr -n default -N default --ignore-mounted
pv-migrate --source seerr-temp --dest seerr -n default -N default --ignore-mounted
pv-migrate --source thelounge-temp --dest thelounge -n default -N default --ignore-mounted
pv-migrate --source trilium-temp --dest trilium -n default -N default --ignore-mounted
pv-migrate --source minecraft-java-temp --dest minecraft -n games -N games --ignore-mounted
pv-migrate --source sonarr-temp --dest sonarr -n default -N default --ignore-mounted
log() { printf "\n[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

kubectl_apply() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY_RUN apply:"
    cat
  else
    kubectl apply -f -
  fi
}

scale_to_zero() {
  local ns="$1" kind="$2" name="$3"
  case "$kind" in
    Deployment)
      log "Scaling Deployment/$name in $ns to 0"
      [[ "$DRY_RUN" == "1" ]] && echo "kubectl -n $ns scale deploy/$name --replicas=0" || kubectl -n "$ns" scale deploy/"$name" --replicas=0
      ;;
    StatefulSet)
      log "Scaling StatefulSet/$name in $ns to 0"
      [[ "$DRY_RUN" == "1" ]] && echo "kubectl -n $ns scale sts/$name --replicas=0" || kubectl -n "$ns" scale sts/"$name" --replicas=0
      ;;
    *)
      log "WARNING: owner kind '$kind' not handled automatically for $ns/$name (skipping scale)"
      ;;
  esac
}

pods_using_pvc() {
  local ns="$1" pvc="$2"
  kubectl -n "$ns" get pods -o json \
    | jq -r --arg pvc "$pvc" '
      .items[]
      | select(any(.spec.volumes[]?; .persistentVolumeClaim?.claimName == $pvc))
      | .metadata.name
    '
}

owner_of_pod() {
  local ns="$1" pod="$2"
  kubectl -n "$ns" get pod "$pod" -o json \
    | jq -r '
      if (.metadata.ownerReferences|length)>0 then
        .metadata.ownerReferences[0].kind + " " + .metadata.ownerReferences[0].name
      else
        "None None"
      end
    '
}

deployment_from_rs() {
  local ns="$1" rs="$2"
  kubectl -n "$ns" get rs "$rs" -o json \
    | jq -r '
      if (.metadata.ownerReferences|length)>0 and .metadata.ownerReferences[0].kind=="Deployment" then
        .metadata.ownerReferences[0].name
      else
        ""
      end
    '
}

create_temp_pvc() {
  local ns="$1" pvc="$2" temp="${pvc}${SUFFIX}"

  if kubectl -n "$ns" get pvc "$temp" >/dev/null 2>&1; then
    log "Temp PVC already exists: $ns/$temp"
    return
  fi

  local size sc am vm
  size=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.resources.requests.storage}')
  sc=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.storageClassName}')
  am=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.accessModes[0]}')
  vm=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.volumeMode}' 2>/dev/null || true)

  log "Creating temp PVC $ns/$temp (size=$size sc=$sc am=$am)"
  cat <<EOF | kubectl_apply
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${temp}
  namespace: ${ns}
spec:
  accessModes:
    - ${am}
  resources:
    requests:
      storage: ${size}
  storageClassName: ${sc}
$( [[ -n "$vm" ]] && echo "  volumeMode: ${vm}" )
EOF
}

wait_until_unused() {
  local ns="$1" pvc="$2"
  if [[ "${DRY_RUN:-1}" == "1" ]]; then
    log "DRY_RUN: skipping wait for pods to release $ns/$pvc"
    log "Pods currently using $ns/$pvc:"
    pods_using_pvc "$ns" "$pvc" || true
    return 0
  fi
  log "Waiting until PVC is not mounted by any pod: $ns/$pvc"
  for i in {1..120}; do
    local pods
    pods=$(pods_using_pvc "$ns" "$pvc" | wc -l | tr -d ' ')
    if [[ "$pods" == "0" ]]; then
      log "PVC is unused: $ns/$pvc"
      return
    fi
    sleep 2
  done
  log "WARNING: timed out waiting for pods to release $ns/$pvc"
}

run_pv_migrate() {
  local ns="$1" pvc="$2" temp="${pvc}${SUFFIX}"
  log "Running pv-migrate: $ns/$pvc -> $ns/$temp"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "pv-migrate --source $pvc --dest $temp -n $ns -N $ns --ignore-mounted"
  else
    pv-migrate --source "$pvc" --dest "$temp" -n "$ns" -N "$ns" --ignore-mounted
  fi
}

log "DRY_RUN=$DRY_RUN (set DRY_RUN=0 to execute)"
while read -r ns pvc; do
  [[ -z "$ns" || -z "$pvc" ]] && continue

  log "==== Processing $ns/$pvc ===="
  create_temp_pvc "$ns" "$pvc"

  # scale down owners of pods using this PVC
  mapfile -t pods < <(pods_using_pvc "$ns" "$pvc")
  if (( ${#pods[@]} == 0 )); then
    log "No pods currently mounting $ns/$pvc"
  else
    declare -A scaled=()
    for pod in "${pods[@]}"; do
      read -r kind name < <(owner_of_pod "$ns" "$pod")
      if [[ "$kind" == "ReplicaSet" ]]; then
        dep=$(deployment_from_rs "$ns" "$name")
        if [[ -n "$dep" ]]; then
          kind="Deployment"; name="$dep"
        fi
      fi

      key="${kind}/${name}"
      if [[ "${scaled[$key]+x}" != "x" && "$kind" != "None" ]]; then
        scale_to_zero "$ns" "$kind" "$name"
        scaled[$key]=1
      fi
    done
  fi

  # wait for source PVC to be unused, then migrate
  wait_until_unused "$ns" "$pvc"
  run_pv_migrate "$ns" "$pvc"

done <<< "$PVC_LIST"

log "Done."