#!/usr/bin/env bash
set -Eeuo pipefail

clp_metadata_require_jq() {
    clp_require_command jq
}

clp_metadata_init() {
    clp_metadata_require_jq

    if [[ -f "${CLP_METADATA_FILE}" ]]; then
        jq empty "${CLP_METADATA_FILE}" >/dev/null
        return 0
    fi

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: initialize metadata file %q\n' "${CLP_METADATA_FILE}"
        return 0
    fi

    mkdir -p "${CLP_STATE_DIR}"
    local tmp
    tmp="$(mktemp "${CLP_STATE_DIR}/.installs.json.XXXXXX")"
    printf '%s\n' '{"schema_version":1,"installs":[]}' > "${tmp}"
    mv -f "${tmp}" "${CLP_METADATA_FILE}"
}

clp_metadata_file_or_empty() {
    if [[ -f "${CLP_METADATA_FILE}" ]]; then
        printf '%s\n' "${CLP_METADATA_FILE}"
        return 0
    fi

    printf '%s\n' "/dev/null"
}

clp_metadata_count() {
    clp_metadata_require_jq
    if [[ ! -f "${CLP_METADATA_FILE}" ]]; then
        printf '0\n'
        return 0
    fi

    jq '.installs | length' "${CLP_METADATA_FILE}"
}

clp_metadata_get() {
    local php_slot="$1"
    local module_base="$2"
    local module_name="${module_base%.so}.so"

    clp_metadata_require_jq
    [[ -f "${CLP_METADATA_FILE}" ]] || return 1

    jq -e --arg slot "${php_slot}" --arg wanted_module "${module_name}" \
        '.installs[] | select(.php_slot == $slot and .module_name == $wanted_module)' \
        "${CLP_METADATA_FILE}"
}

clp_metadata_select() {
    local php_slot="$1"
    local module_base="$2"
    local module_name=""

    clp_metadata_require_jq
    [[ -f "${CLP_METADATA_FILE}" ]] || return 0

    if [[ -n "${module_base}" ]]; then
        module_name="${module_base%.so}.so"
    fi

    jq -c --arg slot "${php_slot}" --arg wanted_module "${module_name}" '
        .installs[]
        | select(($slot == "" or .php_slot == $slot)
          and ($wanted_module == "" or .module_name == $wanted_module))
    ' "${CLP_METADATA_FILE}"
}

clp_metadata_upsert() {
    local install_json="$1"

    clp_metadata_init

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: upsert metadata entry:\n%s\n' "${install_json}"
        return 0
    fi

    local tmp
    tmp="$(mktemp "${CLP_STATE_DIR}/.installs.json.XXXXXX")"

    jq --argjson item "${install_json}" --arg updated_at "$(clp_now_utc)" '
        .schema_version = 1
        | .updated_at = $updated_at
        | .installs = (
            [.installs[] | select(.php_slot != $item.php_slot or .module_name != $item.module_name)]
            + [$item]
            | sort_by(.php_slot, .module_name)
        )
    ' "${CLP_METADATA_FILE}" > "${tmp}"

    mv -f "${tmp}" "${CLP_METADATA_FILE}"
}

clp_metadata_remove() {
    local php_slot="$1"
    local module_base="$2"
    local module_name="${module_base%.so}.so"

    clp_metadata_init

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: remove metadata entry %s %s\n' "${php_slot}" "${module_name}"
        return 0
    fi

    local tmp
    tmp="$(mktemp "${CLP_STATE_DIR}/.installs.json.XXXXXX")"

    jq --arg slot "${php_slot}" --arg wanted_module "${module_name}" --arg updated_at "$(clp_now_utc)" '
        .updated_at = $updated_at
        | .installs = [.installs[] | select(.php_slot != $slot or .module_name != $wanted_module)]
    ' "${CLP_METADATA_FILE}" > "${tmp}"

    mv -f "${tmp}" "${CLP_METADATA_FILE}"
}

clp_metadata_field() {
    local json="$1"
    local field="$2"

    jq -r --arg field "${field}" '.[$field] // ""' <<< "${json}"
}

clp_metadata_array_csv() {
    local json="$1"
    local field="$2"

    jq -r --arg field "${field}" '.[$field] // [] | join(",")' <<< "${json}"
}

clp_metadata_installed_module_bases() {
    clp_metadata_require_jq
    [[ -f "${CLP_METADATA_FILE}" ]] || return 0

    jq -r '.installs[].module_name | sub("\\.so$"; "")' "${CLP_METADATA_FILE}" | sort
}

clp_cmd_list() {
    while (($# > 0)); do
        if clp_parse_common_command_option "$1"; then
            shift
        else
            clp_die "Unknown list option: $1"
        fi
    done

    clp_metadata_require_jq

    if [[ ! -f "${CLP_METADATA_FILE}" || "$(clp_metadata_count)" == "0" ]]; then
        clp_info "No Phalcon installs recorded in ${CLP_METADATA_FILE}."
        return 0
    fi

    printf '%-8s %-12s %-14s %-14s %-40s %-20s\n' \
        "SLOT" "PHP" "MODULE" "PHALCON" "INI" "BUILD_TIME"

    jq -r '
        .installs[]
        | [.php_slot, .php_version, .module_name, .phalcon_version, .ini_path, .build_time]
        | @tsv
    ' "${CLP_METADATA_FILE}" |
        while IFS=$'\t' read -r slot php_version module_name phalcon_version ini_path build_time; do
            printf '%-8s %-12s %-14s %-14s %-40s %-20s\n' \
                "${slot}" "${php_version}" "${module_name}" "${phalcon_version}" "${ini_path}" "${build_time}"
        done
}
