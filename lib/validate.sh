#!/usr/bin/env bash
set -Eeuo pipefail

clp_validate_record() {
    local record_json="$1"
    local quiet="${2:-0}"
    local failures=0

    local php_slot php_binary extension_dir module_name ini_path
    php_slot="$(clp_metadata_field "${record_json}" php_slot)"
    php_binary="$(clp_metadata_field "${record_json}" php_binary)"
    extension_dir="$(clp_metadata_field "${record_json}" extension_dir)"
    module_name="$(clp_metadata_field "${record_json}" module_name)"
    ini_path="$(clp_metadata_field "${record_json}" ini_path)"
    local dependencies_csv
    dependencies_csv="$(clp_metadata_array_csv "${record_json}" ini_dependencies)"

    local module_path="${extension_dir%/}/${module_name}"

    if [[ "${quiet}" != "1" ]]; then
        printf '%s %s\n' "Validating" "${php_slot}/${module_name}"
    fi

    if [[ ! -f "${module_path}" ]]; then
        [[ "${quiet}" == "1" ]] || printf '  FAIL module missing: %s\n' "${module_path}"
        failures=$((failures + 1))
    else
        [[ "${quiet}" == "1" ]] || printf '  OK   module exists: %s\n' "${module_path}"
        local owner
        owner="$(stat -c '%U:%G' "${module_path}" 2>/dev/null || true)"
        if [[ "${owner}" == "root:linksafe" ]]; then
            [[ "${quiet}" == "1" ]] || printf '  OK   owner root:linksafe\n'
        elif clp_is_test_mode; then
            [[ "${quiet}" == "1" ]] || printf '  SKIP owner is %s in CLP_TEST_MODE\n' "${owner:-unknown}"
        else
            [[ "${quiet}" == "1" ]] || printf '  FAIL owner is %s, expected root:linksafe\n' "${owner:-unknown}"
            failures=$((failures + 1))
        fi
    fi

    if [[ ! -f "${ini_path}" ]]; then
        [[ "${quiet}" == "1" ]] || printf '  FAIL ini missing: %s\n' "${ini_path}"
        failures=$((failures + 1))
    elif grep -Fxq "extension=${module_name}" "${ini_path}"; then
        [[ "${quiet}" == "1" ]] || printf '  OK   ini loads extension=%s\n' "${module_name}"
    else
        [[ "${quiet}" == "1" ]] || printf '  FAIL ini does not contain extension=%s\n' "${module_name}"
        failures=$((failures + 1))
    fi

    if [[ -f "${ini_path}" ]]; then
        local dependency
        while IFS= read -r dependency; do
            [[ -n "${dependency}" ]] || continue
            if grep -Fxq "extension=${dependency}.so" "${ini_path}"; then
                [[ "${quiet}" == "1" ]] || printf '  OK   ini loads dependency extension=%s.so\n' "${dependency}"
            else
                [[ "${quiet}" == "1" ]] || printf '  FAIL ini does not contain dependency extension=%s.so\n' "${dependency}"
                failures=$((failures + 1))
            fi
        done < <(clp_split_csv_to_lines "${dependencies_csv}")
    fi

    if [[ ! -x "${php_binary}" ]]; then
        [[ "${quiet}" == "1" ]] || printf '  FAIL php binary missing: %s\n' "${php_binary}"
        failures=$((failures + 1))
    elif [[ -f "${module_path}" ]]; then
        local -a load_args=()
        local runtime_dependency runtime_dependency_path
        while IFS= read -r runtime_dependency; do
            [[ -n "${runtime_dependency}" ]] || continue
            runtime_dependency_path="${extension_dir%/}/${runtime_dependency}.so"
            if [[ -f "${runtime_dependency_path}" ]]; then
                load_args+=("-d" "extension=${runtime_dependency_path}")
            else
                load_args+=("-d" "extension=${runtime_dependency}.so")
            fi
        done < <(clp_split_csv_to_lines "${dependencies_csv}")
        load_args+=("-d" "extension=${module_path}")

        if "${php_binary}" -n "${load_args[@]}" -m >/dev/null 2>&1; then
            [[ "${quiet}" == "1" ]] || printf '  OK   php -m loads module\n'
        else
            [[ "${quiet}" == "1" ]] || printf '  FAIL php -m could not load %s\n' "${module_path}"
            failures=$((failures + 1))
        fi

        if "${php_binary}" -n "${load_args[@]}" --ri phalcon >/dev/null 2>&1; then
            [[ "${quiet}" == "1" ]] || printf '  OK   php --ri phalcon works\n'
        else
            [[ "${quiet}" == "1" ]] || printf '  FAIL php --ri phalcon failed\n'
            failures=$((failures + 1))
        fi
    fi

    if ((failures == 0)); then
        [[ "${quiet}" == "1" ]] || printf '  PASS %s/%s\n' "${php_slot}" "${module_name}"
        return 0
    fi

    return 1
}

clp_cmd_validate() {
    local php_slot=""
    local module_base=""

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
            *)
                if clp_parse_common_command_option "$1"; then
                    shift
                else
                    clp_die "Unknown validate option: $1"
                fi
                ;;
        esac
    done

    clp_metadata_require_jq

    local found=0
    local failures=0
    local record

    while IFS= read -r record; do
        found=1
        if ! clp_validate_record "${record}" 0; then
            failures=$((failures + 1))
        fi
    done < <(clp_metadata_select "${php_slot}" "${module_base}")

    if [[ "${found}" == "0" ]]; then
        clp_info "No matching metadata records found."
        return 0
    fi

    if ((failures > 0)); then
        clp_die "${failures} validation record(s) failed."
    fi
}

clp_php_family() {
    local version="$1"
    local major minor rest
    IFS='.' read -r major minor rest <<< "${version}"
    printf '%s.%s\n' "${major:-unknown}" "${minor:-unknown}"
}

clp_rebuild_check_record() {
    local record_json="$1"
    local -a reasons=()

    local php_slot module_name recorded_php_version recorded_extension_dir recorded_php_api
    local recorded_zend_module_api recorded_zend_extension_build

    php_slot="$(clp_metadata_field "${record_json}" php_slot)"
    module_name="$(clp_metadata_field "${record_json}" module_name)"
    recorded_php_version="$(clp_metadata_field "${record_json}" php_version)"
    recorded_extension_dir="$(clp_metadata_field "${record_json}" extension_dir)"
    recorded_php_api="$(clp_metadata_field "${record_json}" php_api)"
    recorded_zend_module_api="$(clp_metadata_field "${record_json}" zend_module_api)"
    recorded_zend_extension_build="$(clp_metadata_field "${record_json}" zend_extension_build)"

    if ! clp_detect_php_slot "${php_slot}" >/dev/null 2>&1; then
        reasons+=("php slot no longer detected")
    else
        if [[ "$(clp_php_family "${recorded_php_version}")" != "$(clp_php_family "${CLP_DETECTED_PHP_VERSION}")" ]]; then
            reasons+=("PHP version family changed ${recorded_php_version} -> ${CLP_DETECTED_PHP_VERSION}")
        fi
        if [[ "${recorded_extension_dir}" != "${CLP_DETECTED_EXTENSION_DIR}" ]]; then
            reasons+=("extension directory changed")
        fi
        if [[ "${recorded_php_api}" != "${CLP_DETECTED_PHP_API}" ]]; then
            reasons+=("PHP API changed")
        fi
        if [[ "${recorded_zend_module_api}" != "${CLP_DETECTED_ZEND_MODULE_API}" ]]; then
            reasons+=("Zend Module API changed")
        fi
        if [[ "${recorded_zend_extension_build}" != "${CLP_DETECTED_ZEND_EXTENSION_BUILD}" ]]; then
            reasons+=("Zend Extension Build changed")
        fi
    fi

    local module_path
    module_path="$(clp_metadata_field "${record_json}" extension_dir)/${module_name}"
    if [[ ! -f "${module_path}" ]]; then
        reasons+=("module missing")
    elif ! clp_validate_record "${record_json}" 1; then
        reasons+=("validation failed")
    fi

    if ((${#reasons[@]} > 0)); then
        CLP_REBUILD_NEEDED_REASON="$(clp_join_by '; ' "${reasons[@]}")"
        return 1
    fi

    CLP_REBUILD_NEEDED_REASON=""
    return 0
}
