#!/bin/bash
# Unit tests for dtcw internal functions (Chicago School)
#
# Sources dtcw via BASH_SOURCE guard, then tests functions directly.
# No container runtime or docToolchain installation needed.
set -e -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source dtcw — BASH_SOURCE guard skips main()
source "${REPO_ROOT}/dtcw"

passed=0
failed=0

pass() { echo "  PASS"; passed=$((passed + 1)); }
fail() { echo "  FAIL: $1"; failed=$((failed + 1)); }

# --- find_dtc_service ---

test_find_dtc_service_valid() {
    echo "Testing: find_dtc_service with valid compose file..."
    local service
    service=$(find_dtc_service "${SCRIPT_DIR}/fixtures/compose-dtc-valid.yml")
    [[ "${service}" == "doctoolchain" ]] || { fail "expected 'doctoolchain', got '${service}'"; return; }
    pass
}

test_find_dtc_service_custom_name() {
    echo "Testing: find_dtc_service with custom service name..."
    local service
    service=$(find_dtc_service "${SCRIPT_DIR}/fixtures/compose-custom-service.yml")
    [[ "${service}" == "docs-builder" ]] || { fail "expected 'docs-builder', got '${service}'"; return; }
    pass
}

test_find_dtc_service_no_match() {
    echo "Testing: find_dtc_service with no doctoolchain service..."
    local service
    service=$(find_dtc_service "${SCRIPT_DIR}/fixtures/compose-no-dtc.yml")
    [[ -z "${service}" ]] || { fail "expected empty, got '${service}'"; return; }
    pass
}

# --- detect_compose_path ---

test_detect_compose_path_via_env() {
    echo "Testing: detect_compose_path via DTC_COMPOSE..."
    local result
    result=$(DTC_COMPOSE="${SCRIPT_DIR}/fixtures/compose-dtc-valid.yml" detect_compose_path)
    [[ "${result}" == "${SCRIPT_DIR}/fixtures/compose-dtc-valid.yml" ]] || { fail "got '${result}'"; return; }
    pass
}

test_detect_compose_path_auto_detect() {
    echo "Testing: detect_compose_path auto-detects in current directory..."
    local tmpdir
    tmpdir=$(mktemp -d)
    cp "${SCRIPT_DIR}/fixtures/compose-dtc-valid.yml" "${tmpdir}/docker-compose.yml"
    local result
    result=$(cd "${tmpdir}" && DTC_COMPOSE="" detect_compose_path)
    [[ "${result}" == "docker-compose.yml" ]] || { fail "got '${result}'"; return; }
    rm -rf "${tmpdir}"
    pass
}

test_detect_compose_path_no_match() {
    echo "Testing: detect_compose_path fails without doctoolchain service..."
    local tmpdir
    tmpdir=$(mktemp -d)
    cp "${SCRIPT_DIR}/fixtures/compose-no-dtc.yml" "${tmpdir}/docker-compose.yml"
    local rc=0
    (cd "${tmpdir}" && DTC_COMPOSE="" detect_compose_path) >/dev/null 2>&1 || rc=$?
    [[ ${rc} -ne 0 ]] || { fail "expected failure"; return; }
    rm -rf "${tmpdir}"
    pass
}

# --- detect_devcontainer ---

test_detect_devcontainer_match() {
    echo "Testing: detect_devcontainer with doctoolchain image..."
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "${tmpdir}/.devcontainer"
    cp "${SCRIPT_DIR}/fixtures/devcontainer-dtc.json" "${tmpdir}/.devcontainer/devcontainer.json"
    (cd "${tmpdir}" && detect_devcontainer)
    local rc=$?
    [[ ${rc} -eq 0 ]] || { fail "expected success"; return; }
    rm -rf "${tmpdir}"
    pass
}

test_detect_devcontainer_no_match() {
    echo "Testing: detect_devcontainer without doctoolchain image..."
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "${tmpdir}/.devcontainer"
    cp "${SCRIPT_DIR}/fixtures/devcontainer-no-dtc.json" "${tmpdir}/.devcontainer/devcontainer.json"
    local rc=0
    (cd "${tmpdir}" && detect_devcontainer) || rc=$?
    [[ ${rc} -ne 0 ]] || { fail "expected failure"; return; }
    rm -rf "${tmpdir}"
    pass
}

test_detect_devcontainer_missing() {
    echo "Testing: detect_devcontainer without devcontainer.json..."
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    (cd "${tmpdir}" && detect_devcontainer) || rc=$?
    [[ ${rc} -ne 0 ]] || { fail "expected failure"; return; }
    rm -rf "${tmpdir}"
    pass
}

# --- detect_container_runner ---

test_detect_container_runner_finds_something() {
    echo "Testing: detect_container_runner finds a runtime on this system..."
    unset DTC_CONTAINER_RUNNER 2>/dev/null || true
    local rc=0
    detect_container_runner || rc=$?
    if [[ ${rc} -eq 0 ]]; then
        [[ -n "${DTC_CONTAINER_RUNNER}" ]] || { fail "DTC_CONTAINER_RUNNER empty after success"; return; }
        echo "  PASS (found: ${DTC_CONTAINER_RUNNER})"
        ((passed++))
    else
        echo "  SKIP (no container runtime installed)"
    fi
}

test_detect_container_runner_respects_preset() {
    echo "Testing: detect_container_runner respects pre-set value..."
    DTC_CONTAINER_RUNNER="/usr/bin/fake-runner"
    detect_container_runner
    [[ "${DTC_CONTAINER_RUNNER}" == "/usr/bin/fake-runner" ]] || { fail "preset was overwritten"; return; }
    unset DTC_CONTAINER_RUNNER
    pass
}

# --- is_supported_environment ---

test_supported_environments() {
    echo "Testing: is_supported_environment for all environments..."
    for env in compose devcontainer local sdk docker; do
        is_supported_environment "${env}" || { fail "'${env}' not supported"; return; }
    done
    pass
}

test_unsupported_environment() {
    echo "Testing: is_supported_environment rejects unknown..."
    local rc=0
    is_supported_environment "generateHTML" || rc=$?
    [[ ${rc} -ne 0 ]] || { fail "'generateHTML' should not be a supported environment"; return; }
    pass
}

# --- Run all tests ---
echo "=== dtcw unit tests ==="
test_find_dtc_service_valid
test_find_dtc_service_custom_name
test_find_dtc_service_no_match
test_detect_compose_path_via_env
test_detect_compose_path_auto_detect
test_detect_compose_path_no_match
test_detect_devcontainer_match
test_detect_devcontainer_no_match
test_detect_devcontainer_missing
test_detect_container_runner_finds_something
test_detect_container_runner_respects_preset
test_supported_environments
test_unsupported_environment
echo ""
echo "=== Results: ${passed} passed, ${failed} failed ==="
[[ ${failed} -eq 0 ]] || exit 1
