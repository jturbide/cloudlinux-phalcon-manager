#!/usr/bin/env bash
set -Eeuo pipefail

CLP_DOCTOR_FAILURES=0
CLP_DOCTOR_WARNINGS=0

clp_doctor_ok() {
    printf 'OK     %s\n' "$*"
}

clp_doctor_warn() {
    CLP_DOCTOR_WARNINGS=$((CLP_DOCTOR_WARNINGS + 1))
    printf 'WARN   %s\n' "$*"
}

clp_doctor_fail() {
    CLP_DOCTOR_FAILURES=$((CLP_DOCTOR_FAILURES + 1))
    printf 'FAIL   %s\n' "$*"
}

clp_doctor_command() {
    local command_name="$1"
    local required="${2:-1}"

    if command -v "${command_name}" >/dev/null 2>&1; then
        clp_doctor_ok "command available: ${command_name}"
        return 0
    fi

    if [[ "${required}" == "1" ]]; then
        clp_doctor_fail "missing required command: ${command_name}"
    else
        clp_doctor_warn "optional command not found: ${command_name}"
    fi
}

clp_doctor_writable_target() {
    local path="$1"
    local label="$2"
    local target="${path}"

    while [[ ! -e "${target}" && "${target}" != "/" ]]; do
        target="$(dirname "${target}")"
    done

    if [[ -w "${target}" ]]; then
        clp_doctor_ok "${label} writable via ${target}"
    else
        clp_doctor_fail "${label} is not writable: ${path}"
    fi
}

clp_doctor_check_php_slot() {
    local slot="$1"

    if ! clp_detect_php_slot "${slot}" >/dev/null 2>&1; then
        clp_doctor_fail "${slot}: detection failed"
        return
    fi

    clp_doctor_ok "${slot}: PHP ${CLP_DETECTED_PHP_VERSION:-unknown}, extension dir ${CLP_DETECTED_EXTENSION_DIR:-unknown}"

    if [[ -x "${CLP_DETECTED_PHP_BINARY}" ]]; then
        clp_doctor_ok "${slot}: php binary executable"
    else
        clp_doctor_warn "${slot}: php binary missing or not executable: ${CLP_DETECTED_PHP_BINARY}"
    fi

    if [[ -x "${CLP_DETECTED_PHPIZE}" ]]; then
        clp_doctor_ok "${slot}: phpize executable"
    else
        clp_doctor_fail "${slot}: phpize missing or not executable: ${CLP_DETECTED_PHPIZE}"
    fi

    if [[ -x "${CLP_DETECTED_PHP_CONFIG}" ]]; then
        clp_doctor_ok "${slot}: php-config executable"
    else
        clp_doctor_fail "${slot}: php-config missing or not executable: ${CLP_DETECTED_PHP_CONFIG}"
    fi

    if [[ -d "${CLP_DETECTED_EXTENSION_DIR}" ]]; then
        clp_doctor_ok "${slot}: extension directory exists"
    else
        clp_doctor_warn "${slot}: extension directory does not exist yet: ${CLP_DETECTED_EXTENSION_DIR}"
    fi
}

clp_doctor_cloudlinux_phalcon_rpms() {
    if ! command -v rpm >/dev/null 2>&1; then
        clp_doctor_warn "rpm command not found; cannot inspect CloudLinux Phalcon packages"
        return
    fi

    local packages
    packages="$(rpm -qa 2>/dev/null | sort | grep -E '^alt-php[0-9]+.*phalcon|^alt-php.*phalcon' || true)"

    if [[ -z "${packages}" ]]; then
        clp_doctor_ok "no official CloudLinux Phalcon RPMs detected"
        return
    fi

    clp_doctor_warn "official CloudLinux Phalcon RPMs are installed; selector conflicts must include phalcon"
    printf '%s\n' "${packages}" | sed 's/^/       /'
}

clp_cmd_doctor() {
    local strict=0

    while (($# > 0)); do
        case "$1" in
            --strict)
                strict=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown doctor option: $1"
                fi
                ;;
        esac
    done

    CLP_DOCTOR_FAILURES=0
    CLP_DOCTOR_WARNINGS=0

    printf 'cl-phalcon doctor\n'
    printf 'tool version: %s\n' "${CLP_TOOL_VERSION}"
    printf 'root: %s\n' "${CLP_ROOT:-/}"

    if [[ "${EUID}" -eq 0 ]]; then
        clp_doctor_ok "running as root"
    elif clp_is_test_mode; then
        clp_doctor_warn "not running as root; allowed because CLP_TEST_MODE=1"
    else
        clp_doctor_fail "not running as root"
    fi

    clp_doctor_command jq
    clp_doctor_command git
    clp_doctor_command gcc
    clp_doctor_command make
    if clp_is_test_mode; then
        clp_doctor_command cagefsctl 0
    else
        clp_doctor_command cagefsctl
    fi

    if getent group linksafe >/dev/null 2>&1; then
        clp_doctor_ok "group exists: linksafe"
    elif clp_is_test_mode; then
        clp_doctor_warn "group missing in test mode: linksafe"
    else
        clp_doctor_fail "required group missing: linksafe"
    fi

    if [[ -d "${CLP_OPT_ALT}" ]]; then
        clp_doctor_ok "alt-php root exists: ${CLP_OPT_ALT}"
    else
        clp_doctor_fail "alt-php root missing: ${CLP_OPT_ALT}"
    fi

    clp_doctor_writable_target "${CLP_STATE_DIR}" "state directory"
    clp_doctor_writable_target "${CLP_LOG_FILE}" "log file path"
    clp_doctor_writable_target "${CLP_SRC_DIR}" "source directory"
    clp_doctor_writable_target "${CLP_BUILD_DIR}" "build directory"
    clp_doctor_writable_target "${CLP_SELECTOR_CONFLICTS}" "selector conflicts file path"

    if [[ -f "${CLP_METADATA_FILE}" ]]; then
        if jq empty "${CLP_METADATA_FILE}" >/dev/null 2>&1; then
            clp_doctor_ok "metadata JSON is valid: ${CLP_METADATA_FILE}"
        else
            clp_doctor_fail "metadata JSON is invalid: ${CLP_METADATA_FILE}"
        fi
    else
        clp_doctor_warn "metadata file does not exist yet: ${CLP_METADATA_FILE}"
    fi

    local -a slots=()
    local slot
    while IFS= read -r slot; do
        [[ -n "${slot}" ]] && slots+=("${slot}")
    done < <(clp_detect_slot_names)

    if ((${#slots[@]} == 0)); then
        clp_doctor_fail "no CloudLinux alt-php slots detected under ${CLP_OPT_ALT}"
    else
        clp_doctor_ok "detected ${#slots[@]} alt-php slot(s): $(clp_join_by ', ' "${slots[@]}")"
        for slot in "${slots[@]}"; do
            clp_doctor_check_php_slot "${slot}"
        done
    fi

    local -a internal_slots=()
    while IFS= read -r slot; do
        [[ -n "${slot}" ]] && internal_slots+=("${slot}")
    done < <(clp_detect_internal_slot_names)

    if ((${#internal_slots[@]} > 0)); then
        clp_doctor_warn "ignored non-selector/internal slot(s) by default: $(clp_join_by ', ' "${internal_slots[@]}")"
        printf '       Use detect --include-internal only for troubleshooting, not normal Phalcon installs.\n'
    fi

    clp_doctor_cloudlinux_phalcon_rpms

    printf 'summary: %s failure(s), %s warning(s)\n' "${CLP_DOCTOR_FAILURES}" "${CLP_DOCTOR_WARNINGS}"

    if ((CLP_DOCTOR_FAILURES > 0)); then
        return 1
    fi
    if [[ "${strict}" == "1" && "${CLP_DOCTOR_WARNINGS}" -gt 0 ]]; then
        return 1
    fi

    return 0
}
