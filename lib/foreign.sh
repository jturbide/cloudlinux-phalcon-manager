#!/usr/bin/env bash
set -Eeuo pipefail

declare -A CLP_FOREIGN_MANAGED_MODULES=()
declare -A CLP_FOREIGN_MANAGED_INIS=()

clp_foreign_load_managed_maps() {
    CLP_FOREIGN_MANAGED_MODULES=()
    CLP_FOREIGN_MANAGED_INIS=()

    clp_metadata_require_jq
    [[ -f "${CLP_METADATA_FILE}" ]] || return 0

    local record slot module ini_path
    while IFS= read -r record; do
        slot="$(clp_metadata_field "${record}" php_slot)"
        module="$(clp_metadata_field "${record}" module_name)"
        ini_path="$(clp_metadata_field "${record}" ini_path)"

        if [[ -n "${slot}" && -n "${module}" ]]; then
            CLP_FOREIGN_MANAGED_MODULES["${slot}|${module}"]=1
        fi
        if [[ -n "${ini_path}" ]]; then
            CLP_FOREIGN_MANAGED_INIS["${ini_path}"]=1
        fi
    done < <(jq -c '.installs[]?' "${CLP_METADATA_FILE}")
}

clp_foreign_module_status() {
    local slot="$1"
    local module="$2"

    if [[ -n "${CLP_FOREIGN_MANAGED_MODULES["${slot}|${module}"]+set}" ]]; then
        printf 'MANAGED\n'
    else
        printf 'FOREIGN\n'
    fi
}

clp_foreign_ini_phalcon_modules() {
    local ini_path="$1"
    local line_value module

    while IFS= read -r line_value; do
        module="$(basename "${line_value}")"
        module="${module%\"}"
        [[ "${module}" == phalcon* ]] || continue
        [[ "${module}" == *.so ]] || module="${module}.so"
        printf '%s\n' "${module}"
    done < <(sed -nE 's/^[[:space:]]*(zend_)?extension[[:space:]]*=[[:space:]]*"?([^"[:space:];#]+).*/\2/p' "${ini_path}")

    module="$(basename "${ini_path}")"
    module="${module%.ini}.so"
    if [[ "${module}" == phalcon*.so ]]; then
        printf '%s\n' "${module}"
    fi
}

clp_foreign_ini_status() {
    local slot="$1"
    local ini_path="$2"
    local module

    if [[ -n "${CLP_FOREIGN_MANAGED_INIS["${ini_path}"]+set}" ]]; then
        printf 'MANAGED\n'
        return 0
    fi

    while IFS= read -r module; do
        [[ -n "${module}" ]] || continue
        if [[ -n "${CLP_FOREIGN_MANAGED_MODULES["${slot}|${module}"]+set}" ]]; then
            printf 'MANAGED\n'
            return 0
        fi
    done < <(clp_foreign_ini_phalcon_modules "${ini_path}" | awk 'NF && !seen[$0]++')

    printf 'FOREIGN\n'
}

clp_foreign_print_rpms() {
    printf '%-12s %-10s %-10s %-16s %-24s %s\n' "TYPE" "STATUS" "SLOT" "MODULE" "VERSION" "PACKAGE"

    if ! command -v rpm >/dev/null 2>&1; then
        printf '%-12s %-10s %-10s %-16s %-24s %s\n' "RPM_PACKAGE" "UNKNOWN" "-" "-" "-" "rpm command not found"
        return 0
    fi

    local found=0
    local inventory=""
    inventory="$(rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null |
        awk -F '\t' '$1 ~ /^(alt|ea)-php.*phalcon/ { print }' |
        sort || true)"

    if [[ -z "${inventory}" ]]; then
        inventory="$(rpm -qa 2>/dev/null |
            awk '/^(alt|ea)-php.*phalcon/ { print $0 "\tunknown" }' |
            sort || true)"
    fi

    local name version rest slot module package
    while IFS=$'\t' read -r name version; do
        [[ -n "${name}" ]] || continue
        found=1
        slot="-"
        module="${name}"

        case "${name}" in
            alt-php[0-9][0-9]-phalcon*)
                rest="${name#alt-}"
                slot="${rest%%-*}"
                module="${rest#${slot}-}"
                ;;
            ea-php[0-9][0-9]-php-phalcon*)
                slot="${name%%-php-phalcon*}"
                module="${name#${slot}-php-}"
                ;;
        esac

        package="${name}"
        if [[ -n "${version}" && "${version}" != "unknown" ]]; then
            package="${name}-${version}"
        fi

        printf '%-12s %-10s %-10s %-16s %-24s %s\n' "RPM_PACKAGE" "OFFICIAL" "${slot}" "${module}" "${version:-unknown}" "${package}"
    done <<< "${inventory}"

    if [[ "${found}" == "0" ]]; then
        printf '%-12s %-10s %-10s %-16s %-24s %s\n' "RPM_PACKAGE" "NONE" "-" "-" "-" "no alt-php/ea-php Phalcon RPM packages detected"
    fi
}

clp_foreign_print_modules_for_slots() {
    local -a slots=("$@")
    local slot module_path module status

    printf '\n%-12s %-8s %-8s %-14s %s\n' "TYPE" "STATUS" "SLOT" "MODULE" "PATH"
    shopt -s nullglob
    for slot in "${slots[@]}"; do
        clp_detect_php_slot "${slot}"
        for module_path in "${CLP_DETECTED_EXTENSION_DIR%/}"/phalcon*.so; do
            module="$(basename "${module_path}")"
            status="$(clp_foreign_module_status "${slot}" "${module}")"
            printf '%-12s %-8s %-8s %-14s %s\n' "MODULE_FILE" "${status}" "${slot}" "${module}" "${module_path}"
        done
    done
    shopt -u nullglob
}

clp_foreign_print_inis_for_slots() {
    local -a slots=("$@")
    local slot ini_dir ini_path ini_name status modules_csv

    printf '\n%-12s %-8s %-8s %-18s %-24s %s\n' "TYPE" "STATUS" "SLOT" "INI" "MODULES" "PATH"
    shopt -s nullglob
    for slot in "${slots[@]}"; do
        clp_detect_php_slot "${slot}"
        ini_dir="${CLP_DETECTED_PHP_PREFIX%/}/etc/php.d.all"
        [[ -d "${ini_dir}" ]] || continue

        for ini_path in "${ini_dir}"/*.ini; do
            ini_name="$(basename "${ini_path}")"
            modules_csv="$(clp_foreign_ini_phalcon_modules "${ini_path}" | awk 'NF && !seen[$0]++' | paste -sd, -)"
            [[ "${ini_name}" == phalcon*.ini || -n "${modules_csv}" ]] || continue
            [[ -n "${modules_csv}" ]] || modules_csv="-"
            status="$(clp_foreign_ini_status "${slot}" "${ini_path}")"
            printf '%-12s %-8s %-8s %-18s %-24s %s\n' "INI_FILE" "${status}" "${slot}" "${ini_name}" "${modules_csv}" "${ini_path}"
        done
    done
    shopt -u nullglob
}

clp_cmd_foreign() {
    local php_filter=""
    local include_internal=0
    local -a slots=()
    local slot

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
            --include-internal)
                include_internal=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown foreign option: $1"
                fi
                ;;
        esac
    done

    if [[ -n "${php_filter}" ]]; then
        while IFS= read -r slot; do
            [[ -n "${slot}" ]] && slots+=("${slot}")
        done < <(clp_split_csv_to_lines "${php_filter}")
    else
        while IFS= read -r slot; do
            [[ -n "${slot}" ]] && slots+=("${slot}")
        done < <(clp_detect_slot_names "${include_internal}")
    fi

    if ((${#slots[@]} == 0)); then
        clp_info "No CloudLinux alt-php slots detected under ${CLP_OPT_ALT}."
        return 0
    fi

    clp_foreign_load_managed_maps

    printf 'cl-phalcon foreign inventory\n'
    printf 'root: %s\n' "${CLP_ROOT:-/}"
    printf 'slots: %s\n\n' "$(clp_join_by ', ' "${slots[@]}")"

    clp_foreign_print_rpms
    clp_foreign_print_modules_for_slots "${slots[@]}"
    clp_foreign_print_inis_for_slots "${slots[@]}"
}
