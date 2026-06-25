#!/usr/bin/env bash
set -Eeuo pipefail

clp_install_module_file() {
    local built_module="$1"
    local extension_dir="$2"
    local module_name="$3"
    local destination="${extension_dir%/}/${module_name}"

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: install module %q to %q\n' "${built_module}" "${destination}"
        return 0
    fi

    clp_ensure_dir "${extension_dir}"

    if [[ -e "${destination}" ]]; then
        clp_confirm "Replace existing module ${destination}?"
        clp_backup_file "${destination}"
    fi

    local tmp
    tmp="$(mktemp "${extension_dir}/.${module_name}.XXXXXX")"
    install -m 0755 "${built_module}" "${tmp}"
    clp_chown_root_linksafe "${tmp}"
    mv -f "${tmp}" "${destination}"
    clp_info "Installed module: ${destination}"
}

clp_write_ini_file() {
    local ini_path="$1"
    local module_name="$2"
    local dependencies_csv="$3"
    local ini_dir
    ini_dir="$(dirname "${ini_path}")"

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: write ini %q\n' "${ini_path}"
        return 0
    fi

    clp_ensure_dir "${ini_dir}"

    if [[ -e "${ini_path}" ]]; then
        clp_confirm "Replace existing ini ${ini_path}?"
        clp_backup_file "${ini_path}"
    fi

    local tmp
    tmp="$(mktemp "${ini_dir}/.$(basename "${ini_path}").XXXXXX")"
    {
        printf '; Managed by cloudlinux-phalcon-manager. Do not edit by hand.\n'
        printf '; Generated at %s\n' "$(clp_now_utc)"
        local dependency
        while IFS= read -r dependency; do
            [[ -n "${dependency}" ]] || continue
            printf 'extension=%s.so\n' "${dependency}"
        done < <(clp_split_csv_to_lines "${dependencies_csv}")
        printf 'extension=%s\n' "${module_name}"
    } > "${tmp}"
    chmod 0644 "${tmp}"
    clp_chown_root_linksafe "${tmp}"
    mv -f "${tmp}" "${ini_path}"
    clp_info "Wrote ini: ${ini_path}"
}

clp_install_one() {
    local php_slot="$1"
    local phalcon_version="$2"
    local git_ref="$3"
    local requested_module_base="$4"
    local full_patch_module="$5"
    local cflags="$6"
    local dependencies_csv="$7"
    local source_checkout="$8"

    clp_detect_php_slot "${php_slot}"

    clp_require_executable "${CLP_DETECTED_PHPIZE}" "phpize for ${php_slot}"
    clp_require_executable "${CLP_DETECTED_PHP_CONFIG}" "php-config for ${php_slot}"

    local module_base
    if [[ -n "${requested_module_base}" ]]; then
        module_base="$(clp_normalize_module_base "${requested_module_base}")"
    else
        module_base="$(clp_phalcon_default_module_base "${phalcon_version}" "${full_patch_module}")"
    fi

    local module_name="${module_base}.so"
    local ini_path="${CLP_DETECTED_PHP_PREFIX}/etc/php.d.all/${module_base}.ini"

    clp_info "Installing Phalcon ${phalcon_version} (${git_ref}) for ${php_slot} as ${module_name}"
    if [[ -n "${dependencies_csv}" ]]; then
        clp_info "Using ini dependencies for ${module_name}: ${dependencies_csv}"
    fi

    clp_build_phalcon_module \
        "${source_checkout}" \
        "${php_slot}" \
        "${CLP_DETECTED_PHPIZE}" \
        "${CLP_DETECTED_PHP_CONFIG}" \
        "${CLP_DETECTED_EXTENSION_DIR}" \
        "${module_base}" \
        "${cflags}"

    clp_install_module_file "${CLP_BUILT_MODULE_PATH}" "${CLP_DETECTED_EXTENSION_DIR}" "${module_name}"
    clp_write_ini_file "${ini_path}" "${module_name}" "${dependencies_csv}"

    local module_path="${CLP_DETECTED_EXTENSION_DIR%/}/${module_name}"
    local sha256=""
    if [[ -f "${module_path}" ]]; then
        sha256="$(clp_sha256 "${module_path}")"
    fi

    local install_json
    install_json="$(jq -n \
        --arg php_slot "${php_slot}" \
        --arg php_version "${CLP_DETECTED_PHP_VERSION}" \
        --arg php_prefix "${CLP_DETECTED_PHP_PREFIX}" \
        --arg php_binary "${CLP_DETECTED_PHP_BINARY}" \
        --arg phpize "${CLP_DETECTED_PHPIZE}" \
        --arg php_config "${CLP_DETECTED_PHP_CONFIG}" \
        --arg extension_dir "${CLP_DETECTED_EXTENSION_DIR}" \
        --arg phalcon_version "${phalcon_version}" \
        --arg phalcon_git_ref "${git_ref}" \
        --arg module_name "${module_name}" \
        --arg ini_path "${ini_path}" \
        --arg cflags "${cflags}" \
        --arg php_api "${CLP_DETECTED_PHP_API}" \
        --arg zend_module_api "${CLP_DETECTED_ZEND_MODULE_API}" \
        --arg zend_extension_build "${CLP_DETECTED_ZEND_EXTENSION_BUILD}" \
        --arg thread_safety "${CLP_DETECTED_THREAD_SAFETY}" \
        --arg debug_build "${CLP_DETECTED_DEBUG_BUILD}" \
        --arg source_checkout_path "${source_checkout}" \
        --arg build_time "$(clp_now_utc)" \
        --arg installed_by_tool_version "${CLP_TOOL_VERSION}" \
        --arg sha256 "${sha256}" \
        --arg dependencies_csv "${dependencies_csv}" \
        '{
            php_slot: $php_slot,
            php_version: $php_version,
            php_prefix: $php_prefix,
            php_binary: $php_binary,
            phpize: $phpize,
            php_config: $php_config,
            extension_dir: $extension_dir,
            phalcon_version: $phalcon_version,
            phalcon_git_ref: $phalcon_git_ref,
            module_name: $module_name,
            ini_path: $ini_path,
            cflags: $cflags,
            php_api: $php_api,
            zend_module_api: $zend_module_api,
            zend_extension_build: $zend_extension_build,
            thread_safety: $thread_safety,
            debug_build: $debug_build,
            source_checkout_path: $source_checkout_path,
            build_time: $build_time,
            installed_by_tool_version: $installed_by_tool_version,
            sha256: $sha256,
            ini_dependencies: ($dependencies_csv | split(",") | map(select(length > 0)))
        }')"

    clp_metadata_upsert "${install_json}"
}

clp_slots_from_install_args() {
    local php_arg="$1"
    local all_php="$2"
    local slot

    if [[ "${all_php}" == "1" ]]; then
        clp_detect_slot_names
        return 0
    fi

    [[ -n "${php_arg}" ]] || clp_die "Specify --php phpXX or --all-php."
    while IFS= read -r slot; do
        printf '%s\n' "${slot}"
    done < <(clp_split_csv_to_lines "${php_arg}")
}

clp_install_records() {
    local php_arg="$1"
    local all_php="$2"
    local phalcon_version="$3"
    local explicit_git_ref="$4"
    local module_base="$5"
    local full_patch_module="$6"
    local cflags="$7"
    local dependencies_csv="$8"
    local skip_conflicts="$9"
    local skip_cagefs="${10}"

    clp_metadata_require_jq
    if [[ "${CLP_DRY_RUN}" != "1" ]]; then
        clp_require_commands git gcc make
    fi
    if [[ "${skip_cagefs}" != "1" && "${CLP_DRY_RUN}" != "1" ]]; then
        clp_require_command cagefsctl
    fi

    [[ -n "${phalcon_version}" ]] || clp_die "Specify --phalcon VERSION."

    local git_ref
    git_ref="$(clp_source_ref_for_version "${phalcon_version}" "${explicit_git_ref}")"

    local -a slots=()
    local slot
    while IFS= read -r slot; do
        [[ -n "${slot}" ]] && slots+=("${slot}")
    done < <(clp_slots_from_install_args "${php_arg}" "${all_php}")

    ((${#slots[@]} > 0)) || clp_die "No PHP slots selected."

    clp_prepare_source_checkout "${git_ref}"

    for slot in "${slots[@]}"; do
        clp_install_one \
            "${slot}" \
            "${phalcon_version}" \
            "${git_ref}" \
            "${module_base}" \
            "${full_patch_module}" \
            "${cflags}" \
            "${dependencies_csv}" \
            "${CLP_SOURCE_CHECKOUT_PATH}"
    done

    if [[ "${skip_conflicts}" != "1" ]]; then
        clp_rewrite_conflicts_file
    fi

    if [[ "${skip_cagefs}" != "1" ]]; then
        clp_cmd_cagefs_rebuild
    fi
}

clp_cmd_install() {
    local php_arg=""
    local all_php=0
    local phalcon_version=""
    local git_ref=""
    local module_base=""
    local full_patch_module=0
    local cflags="${CLP_DEFAULT_CFLAGS}"
    local dependencies_csv=""
    local use_default_dependencies=1
    local skip_conflicts=0
    local skip_cagefs=0

    while (($# > 0)); do
        case "$1" in
            --php)
                php_arg="$2"
                shift 2
                ;;
            --php=*)
                php_arg="${1#--php=}"
                shift
                ;;
            --all-php)
                all_php=1
                shift
                ;;
            --phalcon)
                phalcon_version="$2"
                shift 2
                ;;
            --phalcon=*)
                phalcon_version="${1#--phalcon=}"
                shift
                ;;
            --git-ref)
                git_ref="$2"
                shift 2
                ;;
            --git-ref=*)
                git_ref="${1#--git-ref=}"
                shift
                ;;
            --module)
                module_base="$(clp_normalize_module_base "$2")"
                shift 2
                ;;
            --module=*)
                module_base="$(clp_normalize_module_base "${1#--module=}")"
                shift
                ;;
            --full-patch-module)
                full_patch_module=1
                shift
                ;;
            --cflags)
                cflags="$2"
                shift 2
                ;;
            --cflags=*)
                cflags="${1#--cflags=}"
                shift
                ;;
            --dependency|--ini-dependency)
                dependencies_csv="$(clp_csv_append "${dependencies_csv}" "$(clp_normalize_extension_base "$2")")"
                shift 2
                ;;
            --dependency=*|--ini-dependency=*)
                dependencies_csv="$(clp_csv_append "${dependencies_csv}" "$(clp_normalize_extension_base "${1#*=}")")"
                shift
                ;;
            --dependencies|--ini-dependencies)
                local dependency
                while IFS= read -r dependency; do
                    dependencies_csv="$(clp_csv_append "${dependencies_csv}" "$(clp_normalize_extension_base "${dependency}")")"
                done < <(clp_split_csv_to_lines "$2")
                shift 2
                ;;
            --dependencies=*|--ini-dependencies=*)
                local dependency
                while IFS= read -r dependency; do
                    dependencies_csv="$(clp_csv_append "${dependencies_csv}" "$(clp_normalize_extension_base "${dependency}")")"
                done < <(clp_split_csv_to_lines "${1#*=}")
                shift
                ;;
            --no-default-dependencies)
                use_default_dependencies=0
                shift
                ;;
            --skip-conflicts)
                skip_conflicts=1
                shift
                ;;
            --skip-cagefs)
                skip_cagefs=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown install option: $1"
                fi
                ;;
        esac
    done

    local resolved_dependencies_csv="${dependencies_csv}"
    if [[ "${use_default_dependencies}" == "1" && -n "${phalcon_version}" ]]; then
        resolved_dependencies_csv="$(clp_resolve_ini_dependencies "${phalcon_version}" "${dependencies_csv}")"
    fi

    clp_install_records \
        "${php_arg}" \
        "${all_php}" \
        "${phalcon_version}" \
        "${git_ref}" \
        "${module_base}" \
        "${full_patch_module}" \
        "${cflags}" \
        "${resolved_dependencies_csv}" \
        "${skip_conflicts}" \
        "${skip_cagefs}"
}

clp_single_metadata_record_or_die() {
    local php_slot="$1"
    local module_base="$2"
    local -a records=()
    local record

    while IFS= read -r record; do
        records+=("${record}")
    done < <(clp_metadata_select "${php_slot}" "${module_base}")

    ((${#records[@]} > 0)) || clp_die "No metadata record found for php=${php_slot:-*} module=${module_base:-*}."
    ((${#records[@]} == 1)) || clp_die "Multiple records match. Specify both --php and --module."

    printf '%s\n' "${records[0]}"
}

clp_cmd_reinstall() {
    local php_slot=""
    local module_base=""
    local skip_conflicts=0
    local skip_cagefs=0

    while (($# > 0)); do
        case "$1" in
            --php)
                php_slot="$2"
                shift 2
                ;;
            --php=*)
                php_slot="${1#--php=}"
                shift
                ;;
            --module)
                module_base="$(clp_normalize_module_base "$2")"
                shift 2
                ;;
            --module=*)
                module_base="$(clp_normalize_module_base "${1#--module=}")"
                shift
                ;;
            --skip-conflicts)
                skip_conflicts=1
                shift
                ;;
            --skip-cagefs)
                skip_cagefs=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown reinstall option: $1"
                fi
                ;;
        esac
    done

    [[ -n "${php_slot}" ]] || clp_die "reinstall requires --php."

    local record
    record="$(clp_single_metadata_record_or_die "${php_slot}" "${module_base}")"

    local phalcon_version git_ref cflags dependencies_csv record_module_base
    phalcon_version="$(clp_metadata_field "${record}" phalcon_version)"
    git_ref="$(clp_metadata_field "${record}" phalcon_git_ref)"
    cflags="$(clp_metadata_field "${record}" cflags)"
    dependencies_csv="$(clp_metadata_array_csv "${record}" ini_dependencies)"
    record_module_base="$(clp_metadata_field "${record}" module_name)"
    record_module_base="${record_module_base%.so}"

    clp_install_records \
        "${php_slot}" \
        "0" \
        "${phalcon_version}" \
        "${git_ref}" \
        "${record_module_base}" \
        "0" \
        "${cflags}" \
        "${dependencies_csv}" \
        "${skip_conflicts}" \
        "${skip_cagefs}"
}

clp_cmd_remove() {
    local php_slot=""
    local module_base=""
    local skip_conflicts=0
    local skip_cagefs=0

    while (($# > 0)); do
        case "$1" in
            --php)
                php_slot="$2"
                shift 2
                ;;
            --php=*)
                php_slot="${1#--php=}"
                shift
                ;;
            --module)
                module_base="$(clp_normalize_module_base "$2")"
                shift 2
                ;;
            --module=*)
                module_base="$(clp_normalize_module_base "${1#--module=}")"
                shift
                ;;
            --skip-conflicts)
                skip_conflicts=1
                shift
                ;;
            --skip-cagefs)
                skip_cagefs=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown remove option: $1"
                fi
                ;;
        esac
    done

    [[ -n "${php_slot}" && -n "${module_base}" ]] || clp_die "remove requires --php and --module."

    local record
    record="$(clp_single_metadata_record_or_die "${php_slot}" "${module_base}")"

    local module_name extension_dir ini_path module_path
    module_name="$(clp_metadata_field "${record}" module_name)"
    extension_dir="$(clp_metadata_field "${record}" extension_dir)"
    ini_path="$(clp_metadata_field "${record}" ini_path)"
    module_path="${extension_dir%/}/${module_name}"

    clp_confirm "Remove ${php_slot}/${module_name}?"

    if [[ -f "${module_path}" ]]; then
        clp_backup_file "${module_path}"
        clp_run rm -f -- "${module_path}"
    fi
    if [[ -f "${ini_path}" ]]; then
        clp_backup_file "${ini_path}"
        clp_run rm -f -- "${ini_path}"
    fi

    clp_metadata_remove "${php_slot}" "${module_base}"

    if [[ "${skip_conflicts}" != "1" ]]; then
        clp_rewrite_conflicts_file
    fi
    if [[ "${skip_cagefs}" != "1" ]]; then
        clp_cmd_cagefs_rebuild
    fi
}

clp_cmd_update() {
    clp_info "Updating managed Phalcon installs that need a rebuild."
    clp_cmd_rebuild_needed --apply "$@"
}

clp_upgrade_selected_records() {
    local php_arg="$1"
    local all_managed="$2"
    local from_module_base="$3"
    local -A seen_slots=()
    local record slot

    if [[ "${all_managed}" == "1" ]]; then
        while IFS= read -r record; do
            slot="$(clp_metadata_field "${record}" php_slot)"
            [[ -n "${slot}" ]] || continue
            if [[ -n "${seen_slots[${slot}]:-}" ]]; then
                continue
            fi
            seen_slots["${slot}"]=1
            printf '%s\n' "${record}"
        done < <(clp_metadata_select "" "${from_module_base}")
        return 0
    fi

    [[ -n "${php_arg}" ]] || clp_die "upgrade requires --php phpXX or --all-managed."

    local requested_slot
    while IFS= read -r requested_slot; do
        while IFS= read -r record; do
            slot="$(clp_metadata_field "${record}" php_slot)"
            [[ -n "${slot}" ]] || continue
            if [[ -n "${seen_slots[${slot}]:-}" ]]; then
                continue
            fi
            seen_slots["${slot}"]=1
            printf '%s\n' "${record}"
        done < <(clp_metadata_select "${requested_slot}" "${from_module_base}")
    done < <(clp_split_csv_to_lines "${php_arg}")
}

clp_cmd_upgrade() {
    local php_arg=""
    local all_managed=0
    local phalcon_version=""
    local git_ref=""
    local new_module_base=""
    local from_module_base=""
    local full_patch_module=0
    local cflags_override=""
    local dependencies_csv=""
    local dependencies_set=0
    local use_default_dependencies=1
    local skip_conflicts=0
    local skip_cagefs=0

    while (($# > 0)); do
        case "$1" in
            --php)
                php_arg="$2"
                shift 2
                ;;
            --php=*)
                php_arg="${1#--php=}"
                shift
                ;;
            --all-managed)
                all_managed=1
                shift
                ;;
            --phalcon)
                phalcon_version="$2"
                shift 2
                ;;
            --phalcon=*)
                phalcon_version="${1#--phalcon=}"
                shift
                ;;
            --git-ref)
                git_ref="$2"
                shift 2
                ;;
            --git-ref=*)
                git_ref="${1#--git-ref=}"
                shift
                ;;
            --module)
                new_module_base="$(clp_normalize_module_base "$2")"
                shift 2
                ;;
            --module=*)
                new_module_base="$(clp_normalize_module_base "${1#--module=}")"
                shift
                ;;
            --from-module)
                from_module_base="$(clp_normalize_module_base "$2")"
                shift 2
                ;;
            --from-module=*)
                from_module_base="$(clp_normalize_module_base "${1#--from-module=}")"
                shift
                ;;
            --full-patch-module)
                full_patch_module=1
                shift
                ;;
            --cflags)
                cflags_override="$2"
                shift 2
                ;;
            --cflags=*)
                cflags_override="${1#--cflags=}"
                shift
                ;;
            --dependency|--ini-dependency)
                dependencies_csv="$(clp_csv_append "${dependencies_csv}" "$(clp_normalize_extension_base "$2")")"
                dependencies_set=1
                shift 2
                ;;
            --dependency=*|--ini-dependency=*)
                dependencies_csv="$(clp_csv_append "${dependencies_csv}" "$(clp_normalize_extension_base "${1#*=}")")"
                dependencies_set=1
                shift
                ;;
            --dependencies|--ini-dependencies)
                local dependency
                while IFS= read -r dependency; do
                    dependencies_csv="$(clp_csv_append "${dependencies_csv}" "$(clp_normalize_extension_base "${dependency}")")"
                done < <(clp_split_csv_to_lines "$2")
                dependencies_set=1
                shift 2
                ;;
            --dependencies=*|--ini-dependencies=*)
                local dependency
                while IFS= read -r dependency; do
                    dependencies_csv="$(clp_csv_append "${dependencies_csv}" "$(clp_normalize_extension_base "${dependency}")")"
                done < <(clp_split_csv_to_lines "${1#*=}")
                dependencies_set=1
                shift
                ;;
            --no-default-dependencies)
                use_default_dependencies=0
                dependencies_set=1
                shift
                ;;
            --skip-conflicts)
                skip_conflicts=1
                shift
                ;;
            --skip-cagefs)
                skip_cagefs=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown upgrade option: $1"
                fi
                ;;
        esac
    done

    [[ -n "${phalcon_version}" ]] || clp_die "upgrade requires --phalcon VERSION."

    clp_metadata_require_jq
    if [[ "${CLP_DRY_RUN}" != "1" ]]; then
        clp_require_commands git gcc make
    fi
    if [[ "${skip_cagefs}" != "1" && "${CLP_DRY_RUN}" != "1" ]]; then
        clp_require_command cagefsctl
    fi

    local -a records=()
    local record
    while IFS= read -r record; do
        records+=("${record}")
    done < <(clp_upgrade_selected_records "${php_arg}" "${all_managed}" "${from_module_base}")

    ((${#records[@]} > 0)) || clp_die "No managed install records matched the upgrade selection."

    local resolved_git_ref
    resolved_git_ref="$(clp_source_ref_for_version "${phalcon_version}" "${git_ref}")"
    clp_prepare_source_checkout "${resolved_git_ref}"

    for record in "${records[@]}"; do
        local slot cflags selected_dependencies selected_module_base
        slot="$(clp_metadata_field "${record}" php_slot)"
        cflags="${cflags_override:-$(clp_metadata_field "${record}" cflags)}"
        [[ -n "${cflags}" ]] || cflags="${CLP_DEFAULT_CFLAGS}"

        if [[ "${dependencies_set}" == "1" ]]; then
            if [[ "${use_default_dependencies}" == "1" ]]; then
                selected_dependencies="$(clp_resolve_ini_dependencies "${phalcon_version}" "${dependencies_csv}")"
            else
                selected_dependencies="${dependencies_csv}"
            fi
        elif [[ "$(clp_phalcon_major "${phalcon_version}")" == "4" ]]; then
            selected_dependencies="$(clp_metadata_array_csv "${record}" ini_dependencies)"
            if [[ -z "${selected_dependencies}" ]]; then
                selected_dependencies="$(clp_resolve_ini_dependencies "${phalcon_version}" "")"
            fi
        else
            selected_dependencies="$(clp_resolve_ini_dependencies "${phalcon_version}" "")"
        fi

        if [[ -n "${new_module_base}" ]]; then
            selected_module_base="${new_module_base}"
        else
            selected_module_base="$(clp_phalcon_default_module_base "${phalcon_version}" "${full_patch_module}")"
        fi

        clp_info "Upgrading managed ${slot} install to Phalcon ${phalcon_version} as ${selected_module_base}.so"
        clp_install_one \
            "${slot}" \
            "${phalcon_version}" \
            "${resolved_git_ref}" \
            "${selected_module_base}" \
            "0" \
            "${cflags}" \
            "${selected_dependencies}" \
            "${CLP_SOURCE_CHECKOUT_PATH}"
    done

    if [[ "${skip_conflicts}" != "1" ]]; then
        clp_rewrite_conflicts_file
    fi
    if [[ "${skip_cagefs}" != "1" ]]; then
        clp_cmd_cagefs_rebuild
    fi
}

clp_cmd_rebuild_needed() {
    local php_slot=""
    local module_base=""
    local apply=0
    local all=0
    local skip_conflicts=0
    local skip_cagefs=0

    while (($# > 0)); do
        case "$1" in
            --php)
                php_slot="$2"
                shift 2
                ;;
            --php=*)
                php_slot="${1#--php=}"
                shift
                ;;
            --module)
                module_base="$(clp_normalize_module_base "$2")"
                shift 2
                ;;
            --module=*)
                module_base="$(clp_normalize_module_base "${1#--module=}")"
                shift
                ;;
            --apply)
                apply=1
                shift
                ;;
            --all)
                all=1
                shift
                ;;
            --skip-conflicts)
                skip_conflicts=1
                shift
                ;;
            --skip-cagefs)
                skip_cagefs=1
                shift
                ;;
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown rebuild-needed option: $1"
                fi
                ;;
        esac
    done

    if [[ "${all}" == "1" ]]; then
        php_slot=""
        module_base=""
    fi

    clp_metadata_require_jq

    local -a needed_records=()
    local record found=0

    while IFS= read -r record; do
        found=1
        local slot module
        slot="$(clp_metadata_field "${record}" php_slot)"
        module="$(clp_metadata_field "${record}" module_name)"
        if clp_rebuild_check_record "${record}"; then
            printf 'OK       %s/%s does not need rebuild\n' "${slot}" "${module}"
        else
            printf 'NEEDED   %s/%s: %s\n' "${slot}" "${module}" "${CLP_REBUILD_NEEDED_REASON}"
            needed_records+=("${record}")
        fi
    done < <(clp_metadata_select "${php_slot}" "${module_base}")

    if [[ "${found}" == "0" ]]; then
        clp_info "No matching metadata records found."
        return 0
    fi

    if ((${#needed_records[@]} == 0)); then
        return 0
    fi

    if [[ "${apply}" != "1" ]]; then
        return 2
    fi

    if [[ "${skip_cagefs}" != "1" && "${CLP_DRY_RUN}" != "1" ]]; then
        clp_require_command cagefsctl
    fi

    for record in "${needed_records[@]}"; do
        local slot phalcon_version git_ref cflags dependencies_csv record_module_base
        slot="$(clp_metadata_field "${record}" php_slot)"
        phalcon_version="$(clp_metadata_field "${record}" phalcon_version)"
        git_ref="$(clp_metadata_field "${record}" phalcon_git_ref)"
        cflags="$(clp_metadata_field "${record}" cflags)"
        dependencies_csv="$(clp_metadata_array_csv "${record}" ini_dependencies)"
        record_module_base="$(clp_metadata_field "${record}" module_name)"
        record_module_base="${record_module_base%.so}"

        clp_install_records \
            "${slot}" \
            "0" \
            "${phalcon_version}" \
            "${git_ref}" \
            "${record_module_base}" \
            "0" \
            "${cflags}" \
            "${dependencies_csv}" \
            "1" \
            "1"
    done

    if [[ "${skip_conflicts}" != "1" ]]; then
        clp_rewrite_conflicts_file
    fi
    if [[ "${skip_cagefs}" != "1" ]]; then
        clp_cmd_cagefs_rebuild
    fi
}
