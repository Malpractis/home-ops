set lazy
set positional-arguments
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'
volsync_resources_dir := justfile_dir() + '/kubernetes/templates/volsync'

[private]
[script]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
[script]
apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f -

[doc('Browse a PVC')]
[script]
browse-pvc ns claim:
    kubectl browse-pvc -n {{ ns }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Delete local Flux Kustomization')]
[script]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f -

[doc('Open a shell on a node')]
[script]
node-shell node:
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Force Flux to reconcile')]
[script]
reconcile:
    flux reconcile kustomization flux-system --with-source

[doc('Prune pods in Failed, Pending, or Succeeded state')]
[script]
prune-pods:
    for phase in Failed Pending Succeeded; do
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true
    done

[doc('Snapshot VolSync PVCs')]
[script]
snapshot:
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch replicationsources "$name" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'
    done

[doc('Suspend or resume VolSync')]
[script]
volsync state:
    flux -n volsync-system {{ state }} kustomization volsync
    flux -n volsync-system {{ state }} helmrelease volsync
    kubectl -n volsync-system scale deployment volsync --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[doc('Sync ExternalSecrets')]
[script]
sync-es:
    kubectl get es --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite es "$name" force-sync="$(date +%s)"
    done

[doc('Sync a specific ExternalSecret')]
[script]
sync-externalsecret ns name:
    kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite externalsecret "{{ name }}" force-sync="$(date +%s)"

[doc('Sync GitRepositories')]
[script]
sync-git:
    kubectl get gitrepo --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"
    done

[doc('Sync HelmReleases')]
[script]
sync-hr:
    kubectl get hr --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite hr "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)" reconcile.fluxcd.io/forceAt="$(date +%s)"
    done

[doc('Sync Kustomizations')]
[script]
sync-ks:
    kubectl get ks --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ks "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"
    done

[doc('Sync OCIRepositories')]
[script]
sync-oci:
    kubectl get ocirepo --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ocirepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"
    done

[doc('View a secret')]
[script]
view-secret ns secret:
    kubectl-view-secret -n "{{ ns }}" "{{ secret }}"

[doc('Unlock all VolSync restic repos')]
[script]
volsync-unlock:
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch --field-manager=flux-client-side-apply replicationsources "$name" --type merge --patch '{"spec":{"restic":{"unlock":"$(date +%s)"}}}'
    done

[doc('Unlock a VolSync restic repo from local machine')]
[script]
volsync-unlock-local ns app:
    export NS="{{ ns }}" APP="{{ app }}"
    just template "{{ volsync_resources_dir }}/unlock.yaml.j2" | kubectl apply --server-side -f -
    until kubectl -n "{{ ns }}" get job/volsync-unlock-"{{ app }}" &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-unlock-"{{ app }}" --for=condition=complete --timeout=5m
    stern -n "{{ ns }}" job/volsync-unlock-"{{ app }}" --no-follow
    kubectl -n "{{ ns }}" delete job volsync-unlock-"{{ app }}"

[doc('Snapshot a specific VolSync app')]
[script]
snapshot-app ns app:
    kubectl -n "{{ ns }}" patch replicationsources "{{ app }}" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'
    until kubectl -n "{{ ns }}" get job/volsync-src-"{{ app }}" &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-src-"{{ app }}" --for=condition=complete --timeout=120m

[doc('Restore a VolSync app')]
[script]
restore ns app previous:
    export NS="{{ ns }}" APP="{{ app }}" PREVIOUS="{{ previous }}"
    export CLAIM=$(kubectl -n "{{ ns }}" get replicationsources/"{{ app }}" -o jsonpath='{.spec.sourcePVC}')
    export ACCESS_MODES=$(kubectl -n "{{ ns }}" get replicationsources/"{{ app }}" -o jsonpath='{.spec.restic.accessModes}')
    export STORAGE_CLASS_NAME=$(kubectl -n "{{ ns }}" get replicationsources/"{{ app }}" -o jsonpath='{.spec.restic.storageClassName}')
    export PUID=$(kubectl -n "{{ ns }}" get replicationsources/"{{ app }}" -o jsonpath='{.spec.restic.moverSecurityContext.runAsUser}')
    export PGID=$(kubectl -n "{{ ns }}" get replicationsources/"{{ app }}" -o jsonpath='{.spec.restic.moverSecurityContext.runAsGroup}')
    controller=$(kubectl -n "{{ ns }}" get deployment "{{ app }}" &>/dev/null && echo deployment || echo statefulset)
    # Suspend
    flux -n "{{ ns }}" suspend kustomization "{{ app }}"
    flux -n "{{ ns }}" suspend helmrelease "{{ app }}"
    kubectl -n "{{ ns }}" scale "$controller"/"{{ app }}" --replicas 0
    kubectl -n "{{ ns }}" wait pod --for=delete --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
    # Restore
    just template "{{ volsync_resources_dir }}/replicationdestination.yaml.j2" | kubectl apply --server-side -f -
    until kubectl -n "{{ ns }}" get job/volsync-dst-"{{ app }}"-manual &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-dst-"{{ app }}"-manual --for=condition=complete --timeout=120m
    kubectl -n "{{ ns }}" delete replicationdestination "{{ app }}"-manual
    # Resume
    flux -n "{{ ns }}" resume kustomization "{{ app }}"
    flux -n "{{ ns }}" resume helmrelease "{{ app }}"
    flux -n "{{ ns }}" reconcile helmrelease "{{ app }}" --force
    kubectl -n "{{ ns }}" wait pod --for=condition=ready --selector="app.kubernetes.io/name={{ app }}" --timeout=5m

[private]
[script]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"
