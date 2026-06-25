#!/usr/bin/env bash
set -Eeuo pipefail

CLP_CONFLICTS_BEGIN="# BEGIN cloudlinux-phalcon-manager"
CLP_CONFLICTS_END="# END cloudlinux-phalcon-manager"

clp_cloudlinux_official_conflict_modules() {
    cat <<'MODULES'
phalcon
MODULES
}

clp_default_conflict_modules() {
    cat <<'MODULES'
phalcon
phalcon2
phalcon3
phalcon4
phalcon5
phalcon51
phalcon52
phalcon53
phalcon54
phalcon55
phalcon56
phalcon57
phalcon58
phalcon59
phalcon513
phalcon514
phalcon515
phalcon516
MODULES
}

clp_conflict_modules() {
    {
        clp_cloudlinux_official_conflict_modules
        clp_default_conflict_modules
        clp_metadata_installed_module_bases || true
    } | awk 'NF && !seen[$0]++'
}

clp_generate_conflicts_block() {
    local -a modules=()
    local module

    while IFS= read -r module; do
        modules+=("${module}")
    done < <(clp_conflict_modules)

    printf '%s\n' "${CLP_CONFLICTS_BEGIN}"
    printf '# Managed by cl-phalcon. CloudLinux expects comma-separated mutual conflict groups.\n'
    printf '# Includes CloudLinux official selector names such as phalcon so custom modules cannot be enabled beside them.\n'
    printf '%s\n' "$(clp_join_by ', ' "${modules[@]}")"
    printf '%s\n' "${CLP_CONFLICTS_END}"
}

clp_rewrite_conflicts_file() {
    clp_metadata_require_jq

    local conflicts_file="${CLP_SELECTOR_CONFLICTS}"
    local conflicts_dir
    conflicts_dir="$(dirname "${conflicts_file}")"

    local modules_csv
    modules_csv="$(clp_conflict_modules | paste -sd, -)"

    local tmp
    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: update conflicts file %q with managed block:\n' "${conflicts_file}"
        clp_generate_conflicts_block
        return 0
    fi

    clp_ensure_dir "${conflicts_dir}"
    [[ -f "${conflicts_file}" ]] || : > "${conflicts_file}"
    clp_backup_file "${conflicts_file}"

    tmp="$(mktemp "${conflicts_dir}/.php.extensions.conflicts.XXXXXX")"

    awk -v begin="${CLP_CONFLICTS_BEGIN}" -v end="${CLP_CONFLICTS_END}" -v modules_csv="${modules_csv}" '
        BEGIN {
            split(modules_csv, modules, ",")
            for (i in modules) {
                managed[modules[i]] = 1
            }
            in_block = 0
        }
        $0 == begin { in_block = 1; next }
        $0 == end { in_block = 0; next }
        in_block { next }
        {
            line = $0
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (line ~ /^#/ || line == "") {
                print
                next
            }
            normalized = line
            gsub(/[:,]/, " ", normalized)
            delete tokens
            split(normalized, tokens, /[[:space:]]+/)
            for (i in tokens) {
                if (tokens[i] in managed) {
                    next
                }
            }
            print
        }
    ' "${conflicts_file}" > "${tmp}"

    if [[ -s "${tmp}" ]]; then
        printf '\n' >> "${tmp}"
    fi
    clp_generate_conflicts_block >> "${tmp}"

    mv -f "${tmp}" "${conflicts_file}"
    clp_info "Updated conflicts file: ${conflicts_file}"
}

clp_cmd_conflicts() {
    while (($# > 0)); do
        if clp_parse_common_command_option "$1"; then
            shift
        else
            clp_die "Unknown conflicts option: $1"
        fi
    done

    clp_rewrite_conflicts_file
}

clp_cmd_cagefs_rebuild() {
    while (($# > 0)); do
        if clp_parse_common_command_option "$1"; then
            shift
        else
            clp_die "Unknown cagefs-rebuild option: $1"
        fi
    done

    if [[ "${CLP_DRY_RUN}" != "1" ]]; then
        clp_require_command cagefsctl
    fi
    clp_info "Rebuilding CloudLinux alt-php CageFS ini files."
    clp_run cagefsctl --rebuild-alt-php-ini
}
