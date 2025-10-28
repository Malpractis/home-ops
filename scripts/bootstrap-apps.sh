#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "${0}")/lib/common.sh"

export LOG_LEVEL="debug"
export ROOT_DIR="$(git rev-parse --show-toplevel)"
export BOOTSTRAP_DIR="${ROOT_DIR}/bootstrap"

# CRDs to be applied before the helmfile charts are installed
function apply_crds() {
    log debug "Applying CRDs"

    local -r helmfile_file="${BOOTSTRAP_DIR}/helmfile.d/00-crds.yaml"

    if [[ ! -f "${helmfile_file}" ]]; then
        log fatal "File does not exist" "file" "${helmfile_file}"
    fi

    if ! crds=$(helmfile --file "${helmfile_file}" template --quiet) || [[ -z "${crds}" ]]; then
        log fatal "Failed to render CRDs from Helmfile" "file" "${helmfile_file}"
    fi

    if echo "${crds}" | kubectl diff --filename - &>/dev/null; then
        log info "CRDs are up-to-date"
        return
    fi

    if ! echo "${crds}" | kubectl apply --server-side --filename - &>/dev/null; then
        log fatal "Failed to apply crds from Helmfile" "file" "${helmfile_file}"
    fi

    log info "CRDs applied successfully"
}

# Resources to be applied before the helmfile charts are installed
function apply_resources() {
	log debug "Applying resources"

	local -r resources_file="${BOOTSTRAP_DIR}/resources.yaml.j2"

	if ! output=$(render_template "${resources_file}") || [[ -z "${output}" ]]; then
		exit 1
	fi

	if echo "${output}" | kubectl diff --filename - &>/dev/null; then
		log info "Resources are up-to-date"
		return
	fi

	if response=$(echo "${output}" | kubectl apply --server-side --filename - 2>&1); then
		log info "Resources applied"
	else
		log error "Failed to apply resources" "response=${response}"
	fi
}

# Sync Helm releases
function sync_helm_releases() {
    log debug "Syncing Helm releases"

    local -r helmfile_file="${ROOT_DIR}/bootstrap/helmfile.d/01-apps.yaml"

    if [[ ! -f "${helmfile_file}" ]]; then
        log error "File does not exist" "file=${helmfile_file}"
    fi

    if ! helmfile --file "${helmfile_file}" sync --hide-notes; then
        log error "Failed to sync Helm releases"
    fi

    log info "Helm releases synced successfully"
}

function main() {
    check_env KUBECONFIG TALOSCONFIG
    check_cli helmfile jq kubectl kustomize minijinja-cli bws talosctl yq

	if ! bws project list &>/dev/null; then
		log error "Failed to authenticate with Bitwarden Seccret Manager CLI"
	fi

    log info "Starting cluster bootstrap process..."

    # Apply CRDs, resources, and sync Helm releases
    apply_crds
    apply_resources
    sync_helm_releases

    log info "Congrats! The cluster is bootstrapped and Flux is syncing the Git repository"
}

main "$@"
