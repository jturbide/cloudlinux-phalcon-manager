#!/usr/bin/env bash
set -Eeuo pipefail

clp_php_info_value() {
    local info="$1"
    local key="$2"

    awk -F'=> ' -v wanted="${key}" '
        {
            left=$1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", left)
            if (left == wanted) {
                value=$2
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                print value
                exit
            }
        }
    ' <<< "${info}"
}

clp_detect_slot_names() {
    local include_internal="${1:-${CLP_INCLUDE_INTERNAL_SLOTS:-0}}"
    local php_config
    local prefix
    local slot

    shopt -s nullglob
    for php_config in "${CLP_OPT_ALT}"/php*/usr/bin/php-config; do
        [[ -x "${php_config}" ]] || continue
        prefix="${php_config%/usr/bin/php-config}"
        slot="$(basename "${prefix}")"
        if [[ "${include_internal}" == "1" || "${slot}" =~ ^php[0-9][0-9]$ ]]; then
            printf '%s\n' "${slot}"
        fi
    done | sort
    shopt -u nullglob
}

clp_detect_internal_slot_names() {
    local slot

    while IFS= read -r slot; do
        [[ -n "${slot}" ]] || continue
        if [[ ! "${slot}" =~ ^php[0-9][0-9]$ ]]; then
            printf '%s\n' "${slot}"
        fi
    done < <(clp_detect_slot_names 1)
}

clp_detect_php_slot() {
    local php_slot="$1"
    local php_prefix="${CLP_OPT_ALT%/}/${php_slot}"
    local php_config="${php_prefix}/usr/bin/php-config"
    local php_binary="${php_prefix}/usr/bin/php"
    local phpize="${php_prefix}/usr/bin/phpize"

    clp_require_executable "${php_config}" "php-config for ${php_slot}"

    local extension_dir
    extension_dir="$("${php_config}" --extension-dir 2>/dev/null || true)"
    [[ -n "${extension_dir}" ]] || extension_dir="${php_prefix}/usr/lib64/php/modules"
    extension_dir="$(clp_rooted_path "${extension_dir}")"

    local php_version
    php_version="$("${php_config}" --version 2>/dev/null || true)"

    local info=""
    if [[ -x "${php_binary}" ]]; then
        info="$("${php_binary}" -n -i 2>/dev/null || true)"
    fi

    CLP_DETECTED_PHP_SLOT="${php_slot}"
    CLP_DETECTED_PHP_PREFIX="${php_prefix}"
    CLP_DETECTED_PHP_BINARY="${php_binary}"
    CLP_DETECTED_PHPIZE="${phpize}"
    CLP_DETECTED_PHP_CONFIG="${php_config}"
    CLP_DETECTED_EXTENSION_DIR="${extension_dir}"
    CLP_DETECTED_PHP_VERSION="${php_version}"
    CLP_DETECTED_PHP_API="$(clp_php_info_value "${info}" "PHP API")"
    CLP_DETECTED_ZEND_MODULE_API="$(clp_php_info_value "${info}" "Zend Module Api No")"
    if [[ -z "${CLP_DETECTED_ZEND_MODULE_API}" ]]; then
        CLP_DETECTED_ZEND_MODULE_API="$(clp_php_info_value "${info}" "PHP Extension")"
    fi
    CLP_DETECTED_ZEND_EXTENSION_BUILD="$(clp_php_info_value "${info}" "Zend Extension Build")"
    CLP_DETECTED_THREAD_SAFETY="$(clp_php_info_value "${info}" "Thread Safety")"
    CLP_DETECTED_DEBUG_BUILD="$(clp_php_info_value "${info}" "Debug Build")"
}

clp_print_detect_header() {
    printf '%-8s %-12s %-38s %-12s %-12s %-18s %-10s %-8s\n' \
        "SLOT" "PHP" "EXTENSION_DIR" "PHP_API" "ZEND_API" "ZEND_BUILD" "THREAD" "DEBUG"
}

clp_print_detected_slot() {
    printf '%-8s %-12s %-38s %-12s %-12s %-18s %-10s %-8s\n' \
        "${CLP_DETECTED_PHP_SLOT}" \
        "${CLP_DETECTED_PHP_VERSION:-unknown}" \
        "${CLP_DETECTED_EXTENSION_DIR:-unknown}" \
        "${CLP_DETECTED_PHP_API:-unknown}" \
        "${CLP_DETECTED_ZEND_MODULE_API:-unknown}" \
        "${CLP_DETECTED_ZEND_EXTENSION_BUILD:-unknown}" \
        "${CLP_DETECTED_THREAD_SAFETY:-unknown}" \
        "${CLP_DETECTED_DEBUG_BUILD:-unknown}"
}

clp_cmd_detect() {
    local slot_filter=""
    local include_internal=0

    while (($# > 0)); do
        case "$1" in
            --php)
                slot_filter="$2"
                shift 2
                ;;
            --php=*)
                slot_filter="${1#--php=}"
                shift
                ;;
            --include-internal)
                include_internal=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown detect option: $1"
                fi
                ;;
        esac
    done

    local -a slots=()
    local slot

    if [[ -n "${slot_filter}" ]]; then
        while IFS= read -r slot; do
            slots+=("${slot}")
        done < <(clp_split_csv_to_lines "${slot_filter}")
    else
        while IFS= read -r slot; do
            slots+=("${slot}")
        done < <(clp_detect_slot_names "${include_internal}")
    fi

    if ((${#slots[@]} == 0)); then
        clp_info "No CloudLinux alt-php php-config binaries found under ${CLP_OPT_ALT}."
        return 0
    fi

    clp_print_detect_header
    for slot in "${slots[@]}"; do
        clp_detect_php_slot "${slot}"
        clp_print_detected_slot
    done
}
