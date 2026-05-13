set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

volsync_resources_dir := source_directory() + '/templates/volsync'

[private]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f -

[doc('Browse a PVC')]
browse-pvc ns claim:
    kubectl browse-pvc -n {{ ns }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f -

[script]
[doc('Open a shell on a node')]
node-shell node:
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Force Flux to reconcile')]
reconcile:
    flux reconcile kustomization flux-system --with-source

[script]
[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded; do
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true
    done

[script]
[doc('Snapshot VolSync PVCs')]
snapshot:
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch replicationsources "$name" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'
    done

[arg('state', pattern='suspend|resume')]
[doc('Suspend or resume VolSync')]
[script]
volsync state:
    flux -n volsync-system {{ state }} kustomization volsync
    flux -n volsync-system {{ state }} helmrelease volsync
    kubectl -n volsync-system scale deployment volsync --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[script]
[doc('Show VolSync backup schedules')]
volsync-schedule:
    kubectl get replicationsources -A \
        -o custom-columns='NAMESPACE:.metadata.namespace,APP:.metadata.name,SCHEDULE:.spec.trigger.schedule,LAST_DURATION:.status.lastSyncDuration' \
        | (read -r header; echo "$header"; sort -k3)

[script]
[doc('Sync ExternalSecrets')]
sync-es:
    kubectl get es --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite es "$name" force-sync="$(date +%s)"
    done

[doc('Sync a specific ExternalSecret')]
sync-externalsecret ns name:
    kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite externalsecret "{{ name }}" force-sync="$(date +%s)"

[script]
[doc('Sync GitRepositories')]
sync-git:
    kubectl get gitrepo --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"
    done

[script]
[doc('Sync HelmReleases')]
sync-hr:
    kubectl get hr --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite hr "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)" reconcile.fluxcd.io/forceAt="$(date +%s)"
    done

[script]
[doc('Sync Kustomizations')]
sync-ks:
    kubectl get ks --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ks "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"
    done

[script]
[doc('Sync OCIRepositories')]
sync-oci:
    kubectl get ocirepo --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ocirepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"
    done

[doc('View a secret')]
view-secret ns secret:
    kubectl-view-secret -n "{{ ns }}" "{{ secret }}"

[script]
[doc('Unlock all VolSync restic repos')]
volsync-unlock:
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch --field-manager=flux-client-side-apply replicationsources "$name" --type merge --patch '{"spec":{"restic":{"unlock":"$(date +%s)"}}}'
    done

[script]
[doc('Unlock a VolSync restic repo from local machine')]
volsync-unlock-local ns app:
    export NS="{{ ns }}" APP="{{ app }}"
    just template "{{ volsync_resources_dir }}/unlock.yaml.j2" | kubectl apply --server-side -f -
    until kubectl -n "{{ ns }}" get job/volsync-unlock-"{{ app }}" &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-unlock-"{{ app }}" --for=condition=complete --timeout=5m
    stern -n "{{ ns }}" job/volsync-unlock-"{{ app }}" --no-follow
    kubectl -n "{{ ns }}" delete job volsync-unlock-"{{ app }}"

[script]
[doc('Snapshot a specific VolSync app')]
snapshot-app ns app:
    kubectl -n "{{ ns }}" patch replicationsources "{{ app }}" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'
    until kubectl -n "{{ ns }}" get job/volsync-src-"{{ app }}" &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-src-"{{ app }}" --for=condition=complete --timeout=120m

[script]
[doc('Restore a PVC from VolSync')]
restore ns app previous='0':
    flux -n {{ ns }} suspend kustomization {{ app }}
    flux -n {{ ns }} suspend helmrelease {{ app }}
    kubectl -n {{ ns }} get deploy,sts -l app.kubernetes.io/name={{ app }} -o name \
        | xargs -r -I{} kubectl -n {{ ns }} scale {} --replicas=0
    kubectl -n {{ ns }} wait pod --for=delete --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
    kubectl -n {{ ns }} get replicationdestination {{ app }}-dst -o json \
        | jq 'del(.status)
            | .metadata = {name: "{{ app }}-manual", namespace: .metadata.namespace}
            | .spec.kopia.copyMethod = "Direct"
            | .spec.kopia.destinationPVC = "{{ app }}"
            | .spec.kopia.previous = {{ previous }}' \
        | kubectl apply --server-side -f -
    kubectl -n {{ ns }} wait job/volsync-dst-{{ app }}-manual --for=create --timeout=120s
    kubectl -n {{ ns }} wait job/volsync-dst-{{ app }}-manual --for=condition=complete --timeout=120m
    kubectl -n {{ ns }} delete replicationdestination {{ app }}-manual
    flux -n {{ ns }} resume kustomization {{ app }}
    flux -n {{ ns }} resume helmrelease {{ app }}
    flux -n {{ ns }} reconcile helmrelease {{ app }} --force
    kubectl -n {{ ns }} wait pod --for=condition=ready --selector="app.kubernetes.io/name={{ app }}" --timeout=5m

[private]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --path "{{ source_directory() }}/flux/cluster" "{{ ks }}"
