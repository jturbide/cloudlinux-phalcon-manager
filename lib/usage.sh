#!/usr/bin/env bash
set -Eeuo pipefail

declare -A CLP_USAGE_MANAGED_MODULES=()
declare -A CLP_USAGE_OFFICIAL_MODULES=()
declare -a CLP_USAGE_SUMMARY_KEYS=()
declare -A CLP_USAGE_ACCOUNT_COUNTS=()
declare -A CLP_USAGE_DOMAIN_COUNTS=()
declare -A CLP_USAGE_USERS=()
declare -A CLP_USAGE_DOMAINS=()
CLP_USAGE_CURRENT_PROBE_FAILURES=0
CLP_USAGE_EXTENSION_PROBE_FAILURES=0
CLP_USAGE_EXTENSION_EMPTY_RESULTS=0

clp_usage_load_managed_modules() {
    CLP_USAGE_MANAGED_MODULES=()

    clp_metadata_require_jq
    [[ -f "${CLP_METADATA_FILE}" ]] || return 0

    local record slot module
    while IFS= read -r record; do
        slot="$(clp_metadata_field "${record}" php_slot)"
        module="$(clp_metadata_field "${record}" module_name)"
        [[ -n "${slot}" && -n "${module}" ]] || continue
        CLP_USAGE_MANAGED_MODULES["${slot}|${module}"]=1
    done < <(jq -c '.installs[]?' "${CLP_METADATA_FILE}")
}

clp_usage_load_official_modules() {
    CLP_USAGE_OFFICIAL_MODULES=()

    command -v rpm >/dev/null 2>&1 || return 0

    local name rest slot module
    while IFS= read -r name; do
        [[ -n "${name}" ]] || continue
        slot=""
        module=""

        case "${name}" in
            alt-php[0-9][0-9]-phalcon*)
                rest="${name#alt-}"
                slot="${rest%%-*}"
                module="${rest#${slot}-}.so"
                ;;
            ea-php[0-9][0-9]-php-phalcon*)
                slot="${name%%-php-phalcon*}"
                module="${name#${slot}-php-}.so"
                ;;
        esac

        [[ -n "${slot}" && -n "${module}" ]] || continue
        CLP_USAGE_OFFICIAL_MODULES["${slot}|${module}"]=1
    done < <(rpm -qa --qf '%{NAME}\n' 2>/dev/null | awk '/^(alt|ea)-php.*phalcon/ { print }' | sort || true)
}

clp_usage_module_status() {
    local slot="$1"
    local module="$2"

    if [[ -n "${CLP_USAGE_MANAGED_MODULES["${slot}|${module}"]+set}" ]]; then
        printf 'MANAGED\n'
    elif [[ -n "${CLP_USAGE_OFFICIAL_MODULES["${slot}|${module}"]+set}" ]]; then
        printf 'OFFICIAL\n'
    else
        printf 'FOREIGN\n'
    fi
}

clp_usage_list_users() {
    local user_path

    shopt -s nullglob
    for user_path in "${CLP_CPANEL_USERS_DIR}"/*; do
        [[ -f "${user_path}" ]] || continue
        basename "${user_path}"
    done | sort
    shopt -u nullglob
}

clp_usage_domains_for_user() {
    local user="$1"
    local domain owner

    [[ -f "${CLP_USERDOMAINS_FILE}" ]] || return 0

    while IFS=: read -r domain owner; do
        domain="${domain//[[:space:]]/}"
        owner="${owner//[[:space:]]/}"
        [[ -n "${domain}" && "${owner}" == "${user}" ]] || continue
        printf '%s\n' "${domain}"
    done < "${CLP_USERDOMAINS_FILE}" | sort -u
}

clp_usage_domains_csv_for_user() {
    local user="$1"
    local domains
    domains="$(clp_usage_domains_for_user "${user}" | paste -sd, -)"
    printf '%s\n' "${domains:-"-"}"
}

clp_usage_slot_from_text() {
    local text="$1"
    local major minor digits

    if [[ "${text}" =~ (alt-)?php([0-9][0-9]) ]]; then
        printf 'php%s\n' "${BASH_REMATCH[2]}"
        return 0
    fi

    if [[ "${text}" =~ ([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        digits="${major}${minor}"
        printf 'php%s\n' "${digits}"
        return 0
    fi

    return 1
}

clp_usage_selector_version_for_slot() {
    local slot="$1"
    local major minor rest

    clp_detect_php_slot "${slot}" >/dev/null
    IFS='.' read -r major minor rest <<< "${CLP_DETECTED_PHP_VERSION}"
    [[ -n "${major}" && -n "${minor}" ]] || return 1
    printf '%s.%s\n' "${major}" "${minor}"
}

clp_usage_selector_current_slot() {
    local user="$1"
    local output

    if output="$(selectorctl --user-current "--user=${user}" 2>/dev/null)"; then
        clp_usage_slot_from_text "${output}" && return 0
    fi

    if output="$(selectorctl --user-current --user "${user}" 2>/dev/null)"; then
        clp_usage_slot_from_text "${output}" && return 0
    fi

    if output="$(selectorctl "--user-current=${user}" 2>/dev/null)"; then
        clp_usage_slot_from_text "${output}" && return 0
    fi

    if output="$(selectorctl --user-current "${user}" 2>/dev/null)"; then
        clp_usage_slot_from_text "${output}" && return 0
    fi

    CLP_USAGE_CURRENT_PROBE_FAILURES=$((CLP_USAGE_CURRENT_PROBE_FAILURES + 1))
    return 1
}

clp_usage_selector_extensions() {
    local user="$1"
    local selector_version="$2"

    selectorctl --user-extensions "--user=${user}" "--version=${selector_version}" 2>/dev/null && return 0
    selectorctl --user-extensions --user "${user}" --version "${selector_version}" 2>/dev/null && return 0
    selectorctl "--user-extensions=${user}" "--version=${selector_version}" 2>/dev/null && return 0
    selectorctl --user-extensions "${user}" --version "${selector_version}" 2>/dev/null && return 0
    CLP_USAGE_EXTENSION_PROBE_FAILURES=$((CLP_USAGE_EXTENSION_PROBE_FAILURES + 1))
    return 1
}

clp_usage_phalcon_modules_from_extensions() {
    awk '
        {
            gsub(/[,;=:"()<>]/, " ")
            for (i = 1; i <= NF; i++) {
                token = tolower($i)
                gsub(/^[^a-z0-9_+-]+|[^a-z0-9_+.-]+$/, "", token)
                if (token ~ /^phalcon[0-9a-z_-]*(\.so)?$/) {
                    sub(/\.so$/, "", token)
                    print token ".so"
                }
            }
        }
    ' | awk 'NF && !seen[$0]++'
}

clp_usage_add_summary() {
    local key="$1"
    local user="$2"
    local domains_csv="$3"
    local domain domain_count=0

    if [[ -z "${CLP_USAGE_ACCOUNT_COUNTS["${key}"]+set}" ]]; then
        CLP_USAGE_SUMMARY_KEYS+=("${key}")
        CLP_USAGE_ACCOUNT_COUNTS["${key}"]=0
        CLP_USAGE_DOMAIN_COUNTS["${key}"]=0
        CLP_USAGE_USERS["${key}"]=""
        CLP_USAGE_DOMAINS["${key}"]=""
    fi

    CLP_USAGE_ACCOUNT_COUNTS["${key}"]=$((CLP_USAGE_ACCOUNT_COUNTS["${key}"] + 1))
    CLP_USAGE_USERS["${key}"]="$(clp_csv_append "${CLP_USAGE_USERS["${key}"]}" "${user}")"

    if [[ "${domains_csv}" != "-" ]]; then
        while IFS= read -r domain; do
            [[ -n "${domain}" ]] || continue
            domain_count=$((domain_count + 1))
        done < <(clp_split_csv_to_lines "${domains_csv}")

        CLP_USAGE_DOMAIN_COUNTS["${key}"]=$((CLP_USAGE_DOMAIN_COUNTS["${key}"] + domain_count))
        CLP_USAGE_DOMAINS["${key}"]="$(clp_csv_append "${CLP_USAGE_DOMAINS["${key}"]}" "${domains_csv}")"
    fi
}

clp_usage_print_summary() {
    local key status slot module

    printf '%-14s %-8s %-8s %-14s %-9s %-8s %s\n' \
        "TYPE" "STATUS" "SLOT" "MODULE" "ACCOUNTS" "DOMAINS" "USERS"

    if ((${#CLP_USAGE_SUMMARY_KEYS[@]} == 0)); then
        printf '%-14s %-8s %-8s %-14s %-9s %-8s %s\n' \
            "USAGE_SUMMARY" "NONE" "-" "-" "0" "0" "no Phalcon selector usage detected"
        if ((CLP_USAGE_CURRENT_PROBE_FAILURES > 0 || CLP_USAGE_EXTENSION_PROBE_FAILURES > 0)); then
            printf 'WARNING: selectorctl probe failures: current=%s extensions=%s\n' \
                "${CLP_USAGE_CURRENT_PROBE_FAILURES}" \
                "${CLP_USAGE_EXTENSION_PROBE_FAILURES}" >&2
        fi
        if ((CLP_USAGE_EXTENSION_EMPTY_RESULTS > 0)); then
            printf 'NOTE: selectorctl returned no extension output for %s account/version probe(s).\n' \
                "${CLP_USAGE_EXTENSION_EMPTY_RESULTS}" >&2
        fi
        return 0
    fi

    for key in "${CLP_USAGE_SUMMARY_KEYS[@]}"; do
        IFS='|' read -r status slot module <<< "${key}"
        printf '%-14s %-8s %-8s %-14s %-9s %-8s %s\n' \
            "USAGE_SUMMARY" \
            "${status}" \
            "${slot}" \
            "${module}" \
            "${CLP_USAGE_ACCOUNT_COUNTS["${key}"]}" \
            "${CLP_USAGE_DOMAIN_COUNTS["${key}"]}" \
            "${CLP_USAGE_USERS["${key}"]}"
    done
}

clp_usage_scan_user_slot() {
    local user="$1"
    local slot="$2"
    local module_filter="$3"
    local selector_version output domains_csv module status key

    selector_version="$(clp_usage_selector_version_for_slot "${slot}")" || return 0
    output="$(clp_usage_selector_extensions "${user}" "${selector_version}" || true)"
    if [[ -z "${output}" ]]; then
        CLP_USAGE_EXTENSION_EMPTY_RESULTS=$((CLP_USAGE_EXTENSION_EMPTY_RESULTS + 1))
        return 0
    fi

    domains_csv="$(clp_usage_domains_csv_for_user "${user}")"

    while IFS= read -r module; do
        [[ -n "${module}" ]] || continue
        if [[ -n "${module_filter}" && "${module}" != "${module_filter%.so}.so" ]]; then
            continue
        fi
        status="$(clp_usage_module_status "${slot}" "${module}")"
        key="${status}|${slot}|${module}"
        clp_usage_add_summary "${key}" "${user}" "${domains_csv}"
        printf '%-14s %-8s %-8s %-14s %-16s %s\n' \
            "SELECTOR_USE" "${status}" "${slot}" "${module}" "${user}" "${domains_csv}"
    done < <(printf '%s\n' "${output}" | clp_usage_phalcon_modules_from_extensions)
}

clp_cmd_usage() {
    local php_filter=""
    local module_filter=""
    local user_filter=""
    local all_php=0
    local -a users=()
    local -a slots=()
    local user slot current_slot

    while (($# > 0)); do
        case "$1" in
            --php)
                php_filter="$2"
                shift 2
                ;;
            --php=*)
                php_filter="${1#--php=}"
                shift
                ;;
            --module)
                module_filter="$(clp_normalize_module_base "$2").so"
                shift 2
                ;;
            --module=*)
                module_filter="$(clp_normalize_module_base "${1#--module=}").so"
                shift
                ;;
            --user)
                user_filter="$2"
                shift 2
                ;;
            --user=*)
                user_filter="${1#--user=}"
                shift
                ;;
            --all-php)
                all_php=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown usage option: $1"
                fi
                ;;
        esac
    done

    command -v selectorctl >/dev/null 2>&1 || clp_die "Missing required command: selectorctl"

    if [[ -n "${user_filter}" ]]; then
        while IFS= read -r user; do
            [[ -n "${user}" ]] && users+=("${user}")
        done < <(clp_split_csv_to_lines "${user_filter}")
    else
        while IFS= read -r user; do
            [[ -n "${user}" ]] && users+=("${user}")
        done < <(clp_usage_list_users)
    fi

    if ((${#users[@]} == 0)); then
        clp_info "No cPanel users found under ${CLP_CPANEL_USERS_DIR}."
        return 0
    fi

    if [[ -n "${php_filter}" ]]; then
        while IFS= read -r slot; do
            [[ -n "${slot}" ]] && slots+=("${slot}")
        done < <(clp_split_csv_to_lines "${php_filter}")
    elif [[ "${all_php}" == "1" ]]; then
        while IFS= read -r slot; do
            [[ -n "${slot}" ]] && slots+=("${slot}")
        done < <(clp_detect_slot_names)
    fi

    clp_usage_load_managed_modules
    clp_usage_load_official_modules

    printf 'cl-phalcon selector usage\n'
    printf 'root: %s\n' "${CLP_ROOT:-/}"
    printf 'users: %s\n' "${#users[@]}"
    if [[ -n "${php_filter}" || "${all_php}" == "1" ]]; then
        printf 'slots: %s\n' "$(clp_join_by ', ' "${slots[@]}")"
    else
        printf 'slots: current PHP Selector version per user\n'
    fi
    printf '\n%-14s %-8s %-8s %-14s %-16s %s\n' \
        "TYPE" "STATUS" "SLOT" "MODULE" "USER" "DOMAINS"

    for user in "${users[@]}"; do
        if [[ -n "${php_filter}" || "${all_php}" == "1" ]]; then
            for slot in "${slots[@]}"; do
                clp_usage_scan_user_slot "${user}" "${slot}" "${module_filter}"
            done
        else
            current_slot="$(clp_usage_selector_current_slot "${user}" || true)"
            [[ -n "${current_slot}" ]] || continue
            clp_usage_scan_user_slot "${user}" "${current_slot}" "${module_filter}"
        fi
    done

    printf '\n'
    clp_usage_print_summary
}
