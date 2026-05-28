set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l talos

[confirm('Apply Talos config to ' + node + ' [y|N] ?')]
[doc('Apply Talos config to a node')]
apply-node node *args:
    just talos render-config "{{ node }}" | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[script]
[doc('Download Talos machine image')]
download-image node version:
    export SCHEMATIC="$(just talos schematic-id {{ node }})"
    curl -fL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors --progress-bar \
        -o "{{ source_directory() }}/talos-{{ version }}-${SCHEMATIC:0:8}.iso" \
        "https://factory.talos.dev/image/${SCHEMATIC}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "${SCHEMATIC}"


[confirm('Reboot node ' + node + ' [y|N] ?')]
[doc('Reboot a node')]
reboot-node node:
    talosctl -n {{ node }} reboot -m powercycle

[doc('Render Talos config for a node')]
[script]
render-config node:
    export CONTROLPLANE="$(just talos machine-controller {{ node }})"
    export SCHEMATIC="$(just talos schematic-id {{ node }})"
    talosctl machineconfig patch <(just template "{{ source_directory() }}/machineconfig.yaml.j2") \
        -p @<(just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2")


[confirm('Reset node ' + node + ' [y|N] ?')]
[doc('Reset a node')]
reset-node node *args:
    talosctl -n "{{ node }}" reset --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --system-labels-to-wipe u-local-hostpath --graceful=false {{ args }}

[confirm('Shutdown node ' + node + ' [y|N] ?')]
[doc('Shutdown a node')]
shutdown-node node *args:
    talosctl -n "{{ node }}" shutdown --force {{ args }}

[confirm('Upgrade Kubernetes to ' + version + ' [y|N] ?')]
[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl -n "$(talosctl config info -o yaml | yq -e '.endpoints[0]')" upgrade-k8s --to {{ version }}

[confirm('Upgrade node ' + node + ' [y|N] ?')]
[doc('Upgrade Talos version on a node')]
upgrade-node node *args:
    talosctl -n "{{ node }}" upgrade -i "$(just talos machine-image {{ node }})" -m powercycle --timeout=10m {{ args }}

[private]
[script]
schematic-id node:
    export NODE_TYPE="$(just talos machine-nodetype {{ node }})"
    export NODE_IP="$(just talos machine-nodeip {{ node }})"
    curl -sX POST --data-binary @<(just template "{{ source_directory() }}/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'

[private]
machine-controller node:
    yq -e 'select(.machine) | (.machine.type == "controlplane") // ""' "{{ source_directory() }}/nodes/{{ node }}.yaml.j2"

[private]
machine-nodetype node:
    grep -m1 '^# talos:node-type=' "{{ source_directory() }}/nodes/{{ node }}.yaml.j2" | cut -d= -f2 || echo 'baremetal'

[private]
machine-nodeip node:
    grep -m1 '^# talos:node-ip=' "{{ source_directory() }}/nodes/{{ node }}.yaml.j2" | cut -d= -f2 || echo ''

[private]
[script]
machine-image node:
    export SCHEMATIC="$(just talos schematic-id {{ node }})"
    just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2" | yq -e 'select(.machine.install) | .machine.install.image'

[doc('Generate kubeconfig for the cluster')]
[private]
[script]
generate-kubeconfig:
    talosctl kubeconfig -n "$(talosctl config info -o yaml | yq -e '.endpoints[0]')" -f --force-context-name main {{ justfile_dir() }}
