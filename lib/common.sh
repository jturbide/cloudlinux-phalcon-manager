#!/usr/bin/env bash
set -Eeuo pipefail

CLP_TOOL_VERSION="${CLP_TOOL_VERSION:-1.0.0}"
CLP_GITHUB_REPO="${CLP_GITHUB_REPO:-https://github.com/phalcon/cphalcon.git}"
CLP_DEFAULT_CFLAGS="${CLP_DEFAULT_CFLAGS:--march=native -O2 -fomit-frame-pointer}"

CLP_DRY_RUN="${CLP_DRY_RUN:-0}"
CLP_YES="${CLP_YES:-0}"

clp_rooted_path() {
    local path="$1"

    if [[ -n "${CLP_ROOT:-}" && "${CLP_ROOT}" != "/" && "${path}" == /* ]]; then
        case "${path}" in
            "${CLP_ROOT}"|"${CLP_ROOT}"/*)
                printf '%s\n' "${path}"
                ;;
            *)
                printf '%s%s\n' "${CLP_ROOT%/}" "${path}"
                ;;
        esac
        return
    fi

    printf '%s\n' "${path}"
}

: "${CLP_OPT_ALT:=$(clp_rooted_path /opt/alt)}"
: "${CLP_SELECTOR_CONFLICTS:=$(clp_rooted_path /etc/cl.selector/php.extensions.conflicts)}"
: "${CLP_STATE_DIR:=$(clp_rooted_path /var/lib/cloudlinux-phalcon-manager)}"
: "${CLP_LOG_FILE:=$(clp_rooted_path /var/log/cloudlinux-phalcon-manager.log)}"
: "${CLP_SRC_DIR:=$(clp_rooted_path /usr/local/src/cloudlinux-phalcon-manager/src)}"
: "${CLP_BUILD_DIR:=$(clp_rooted_path /usr/local/src/cloudlinux-phalcon-manager/build)}"
: "${CLP_CACHE_DIR:=$(clp_rooted_path /usr/local/src/cloudlinux-phalcon-manager/cache)}"
: "${CLP_CPANEL_USERS_DIR:=$(clp_rooted_path /var/cpanel/users)}"
: "${CLP_USERDOMAINS_FILE:=$(clp_rooted_path /etc/userdomains)}"

CLP_METADATA_FILE="${CLP_STATE_DIR}/installs.json"

clp_now_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

clp_backup_suffix() {
    date -u '+%Y%m%d%H%M%S'
}

clp_log() {
    local level="$1"
    shift || true
    local message="$*"
    local line
    line="$(printf '%s [%s] %s\n' "$(clp_now_utc)" "${level}" "${message}")"

    if [[ "${CLP_DRY_RUN}" != "1" ]]; then
        mkdir -p "$(dirname "${CLP_LOG_FILE}")" 2>/dev/null || true
        printf '%s\n' "${line}" >> "${CLP_LOG_FILE}" 2>/dev/null || true
    fi
}

clp_info() {
    printf '%s\n' "$*"
    clp_log INFO "$*"
}

clp_warn() {
    printf 'WARNING: %s\n' "$*" >&2
    clp_log WARN "$*"
}

clp_die() {
    printf 'ERROR: %s\n' "$*" >&2
    clp_log ERROR "$*"
    exit 1
}

clp_is_test_mode() {
    [[ "${CLP_TEST_MODE:-}" == "1" ]]
}

clp_require_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        return 0
    fi

    if clp_is_test_mode; then
        return 0
    fi

    clp_die "This command must be run as root. Use CLP_TEST_MODE=1 only for mock-root tests."
}

clp_require_command() {
    local command_name="$1"
    command -v "${command_name}" >/dev/null 2>&1 || clp_die "Missing required command: ${command_name}"
}

clp_require_commands() {
    local command_name
    for command_name in "$@"; do
        clp_require_command "${command_name}"
    done
}

clp_require_executable() {
    local path="$1"
    local label="${2:-executable}"
    [[ -x "${path}" ]] || clp_die "Missing required ${label}: ${path}"
}

clp_run() {
    local printable=""
    local arg

    for arg in "$@"; do
        printable+="$(printf '%q' "${arg}") "
    done
    printable="${printable% }"

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: %s\n' "${printable}"
        clp_log INFO "dry-run: ${printable}"
        return 0
    fi

    clp_log INFO "run: ${printable}"
    "$@"
}

clp_confirm() {
    local prompt="$1"

    if [[ "${CLP_YES}" == "1" ]]; then
        return 0
    fi

    if [[ ! -t 0 ]]; then
        clp_die "${prompt} Refusing non-interactive operation without --yes."
    fi

    local answer
    read -r -p "${prompt} [y/N] " answer
    [[ "${answer}" == "y" || "${answer}" == "Y" || "${answer}" == "yes" || "${answer}" == "YES" ]]
}

clp_ensure_dir() {
    local dir="$1"

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: mkdir -p %q\n' "${dir}"
        clp_log INFO "dry-run: mkdir -p ${dir}"
        return 0
    fi

    mkdir -p "${dir}"
}

clp_backup_file() {
    local path="$1"

    [[ -e "${path}" ]] || return 0

    local backup
    backup="${path}.bak.$(clp_backup_suffix)"
    clp_info "Creating backup: ${backup}"
    clp_run cp -p "${path}" "${backup}"
}

clp_normalize_module_base() {
    local raw="$1"
    raw="${raw%.so}"

    [[ -n "${raw}" ]] || clp_die "Module name cannot be empty."
    [[ "${raw}" =~ ^[A-Za-z0-9_]+$ ]] || clp_die "Invalid module name: ${raw}"

    printf '%s\n' "${raw}"
}

clp_normalize_extension_base() {
    local raw="$1"
    raw="${raw%.so}"

    [[ -n "${raw}" ]] || clp_die "Extension dependency cannot be empty."
    [[ "${raw}" =~ ^[A-Za-z0-9_]+$ ]] || clp_die "Invalid extension dependency: ${raw}"

    printf '%s\n' "${raw}"
}

clp_phalcon_default_module_base() {
    local phalcon_version="$1"
    local full_patch="$2"
    local major minor patch

    IFS='.' read -r major minor patch <<< "${phalcon_version}"
    [[ -n "${major:-}" && -n "${minor:-}" ]] || clp_die "Phalcon version must look like MAJOR.MINOR.PATCH or MAJOR.MINOR."

    if [[ "${full_patch}" == "1" ]]; then
        [[ -n "${patch:-}" ]] || clp_die "--full-patch-module requires a patch version."
        printf 'phalcon%s%s%s\n' "${major}" "${minor}" "${patch}"
        return
    fi

    printf 'phalcon%s%s\n' "${major}" "${minor}"
}

clp_phalcon_major() {
    local version="$1"
    printf '%s\n' "${version%%.*}"
}

clp_phalcon_default_ini_dependencies() {
    local phalcon_version="$1"

    case "$(clp_phalcon_major "${phalcon_version}")" in
        5)
            printf 'pdo\n'
            ;;
        4)
            printf 'psr,pdo\n'
            ;;
        *)
            printf '\n'
            ;;
    esac
}

clp_resolve_ini_dependencies() {
    local phalcon_version="$1"
    local explicit_dependencies_csv="$2"

    if [[ -n "${explicit_dependencies_csv}" ]]; then
        printf '%s\n' "${explicit_dependencies_csv}"
        return
    fi

    clp_phalcon_default_ini_dependencies "${phalcon_version}"
}

clp_csv_append() {
    local csv="$1"
    local value="$2"

    if [[ -z "${csv}" ]]; then
        printf '%s\n' "${value}"
    else
        printf '%s,%s\n' "${csv}" "${value}"
    fi
}

clp_join_by() {
    local delimiter="$1"
    shift || true
    local first=1
    local item

    for item in "$@"; do
        if [[ "${first}" == "1" ]]; then
            printf '%s' "${item}"
            first=0
        else
            printf '%s%s' "${delimiter}" "${item}"
        fi
    done
}

clp_path_is_under() {
    local path="${1%/}"
    local base="${2%/}"

    [[ "${path}" == "${base}" || "${path}" == "${base}/"* ]]
}

clp_safe_rm_rf() {
    local path="$1"

    [[ -n "${path}" && "${path}" != "/" ]] || clp_die "Refusing unsafe removal path: ${path}"

    if ! clp_path_is_under "${path}" "${CLP_SRC_DIR}" \
        && ! clp_path_is_under "${path}" "${CLP_BUILD_DIR}" \
        && ! clp_path_is_under "${path}" "${CLP_CACHE_DIR}"; then
        clp_die "Refusing to remove path outside tool-owned directories: ${path}"
    fi

    clp_run rm -rf -- "${path}"
}

clp_sha256() {
    local path="$1"
    sha256sum "${path}" | awk '{print $1}'
}

clp_chown_root_linksafe() {
    local path="$1"

    if clp_is_test_mode && [[ "${EUID}" -ne 0 ]]; then
        clp_warn "Skipping root:linksafe ownership change in CLP_TEST_MODE: ${path}"
        return 0
    fi

    clp_run chown root:linksafe "${path}"
}

clp_parse_common_command_option() {
    case "${1:-}" in
        --dry-run)
            CLP_DRY_RUN=1
            return 0
            ;;
        --yes|-y)
            CLP_YES=1
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

clp_split_csv_to_lines() {
    local csv="$1"
    local old_ifs="${IFS}"
    local item

    IFS=','
    for item in ${csv}; do
        IFS="${old_ifs}"
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"
        [[ -n "${item}" ]] && printf '%s\n' "${item}"
        IFS=','
    done
    IFS="${old_ifs}"
}
