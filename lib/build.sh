#!/usr/bin/env bash
set -Eeuo pipefail

clp_source_ref_for_version() {
    local phalcon_version="$1"
    local explicit_ref="$2"

    if [[ -n "${explicit_ref}" ]]; then
        printf '%s\n' "${explicit_ref}"
    else
        printf 'v%s\n' "${phalcon_version}"
    fi
}

clp_safe_ref_name() {
    local ref="$1"
    printf '%s\n' "${ref}" | sed 's/[^A-Za-z0-9._-]/_/g'
}

clp_prepare_source_checkout() {
    local git_ref="$1"
    local safe_ref
    safe_ref="$(clp_safe_ref_name "${git_ref}")"

    CLP_SOURCE_CHECKOUT_PATH="${CLP_SRC_DIR%/}/cphalcon-${safe_ref}"

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        printf 'DRY-RUN: prepare source checkout %q at %q\n' "${git_ref}" "${CLP_SOURCE_CHECKOUT_PATH}"
        return 0
    fi

    clp_ensure_dir "${CLP_SRC_DIR}"

    if [[ ! -d "${CLP_SOURCE_CHECKOUT_PATH}/.git" ]]; then
        clp_info "Cloning cphalcon ${git_ref} into ${CLP_SOURCE_CHECKOUT_PATH}"
        clp_run git clone --depth 1 --branch "${git_ref}" "${CLP_GITHUB_REPO}" "${CLP_SOURCE_CHECKOUT_PATH}"
        return 0
    fi

    clp_info "Refreshing cphalcon checkout ${git_ref} in ${CLP_SOURCE_CHECKOUT_PATH}"
    clp_run git -C "${CLP_SOURCE_CHECKOUT_PATH}" fetch --tags origin
    clp_run git -C "${CLP_SOURCE_CHECKOUT_PATH}" checkout --force "${git_ref}"
}

clp_build_jobs() {
    local jobs="1"

    if command -v getconf >/dev/null 2>&1; then
        jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
    fi

    if [[ ! "${jobs}" =~ ^[0-9]+$ || "${jobs}" -lt 1 ]]; then
        jobs="1"
    fi

    printf '%s\n' "${jobs}"
}

clp_find_cphalcon_extension_source() {
    local work_src="$1"
    local candidate

    for candidate in \
        "${work_src}/build/phalcon" \
        "${work_src}/ext"; do
        if [[ -f "${candidate}/config.m4" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    while IFS= read -r candidate; do
        dirname "${candidate}"
        return 0
    done < <(find "${work_src}" -path '*/.git' -prune -o -type f -name config.m4 -print | sort)

    clp_die "Could not find cphalcon generated extension source with config.m4 under ${work_src}."
}

clp_build_phalcon_module() {
    local source_checkout="$1"
    local php_slot="$2"
    local phpize="$3"
    local php_config="$4"
    local _extension_dir="$5"
    local module_base="$6"
    local cflags="$7"

    CLP_BUILT_MODULE_PATH=""

    if [[ "${CLP_DRY_RUN}" == "1" ]]; then
        CLP_BUILT_MODULE_PATH="${CLP_BUILD_DIR%/}/dry-run-${php_slot}-${module_base}.so"
        printf 'DRY-RUN: build %s for %s using %s and %s\n' "${module_base}.so" "${php_slot}" "${phpize}" "${php_config}"
        return 0
    fi

    clp_require_commands git gcc make
    clp_require_executable "${phpize}" "phpize for ${php_slot}"
    clp_require_executable "${php_config}" "php-config for ${php_slot}"

    clp_ensure_dir "${CLP_BUILD_DIR}"

    local stage_dir
    stage_dir="$(mktemp -d "${CLP_BUILD_DIR%/}/build-${php_slot}-${module_base}.XXXXXX")"
    clp_path_is_under "${stage_dir}" "${CLP_BUILD_DIR}" || clp_die "Unsafe build staging directory: ${stage_dir}"

    local work_src="${stage_dir}/src"

    clp_info "Creating isolated build workspace: ${stage_dir}"
    clp_run git clone "${source_checkout}" "${work_src}"

    local extension_source_dir
    extension_source_dir="$(clp_find_cphalcon_extension_source "${work_src}")"

    (
        cd "${extension_source_dir}"
        export CC="gcc"
        export CFLAGS="${cflags}"
        export CPPFLAGS="${CPPFLAGS:+${CPPFLAGS} }-DPHALCON_RELEASE"
        export echo=echo

        clp_info "Compiling Phalcon in ${PWD} for ${php_slot}"

        if [[ -f Makefile ]]; then
            clp_run make clean
            clp_run "${phpize}" --clean || true
        fi

        clp_run "${phpize}"
        clp_run ./configure --silent "--with-php-config=${php_config}" --enable-phalcon
        clp_run make -s "-j$(clp_build_jobs)"
    )

    local found_module=""
    if [[ -f "${extension_source_dir}/modules/phalcon.so" ]]; then
        found_module="${extension_source_dir}/modules/phalcon.so"
    else
        found_module="$(find "${extension_source_dir}" -type f -name phalcon.so -print -quit)"
    fi

    [[ -n "${found_module}" && -f "${found_module}" ]] || clp_die "Build completed but no phalcon.so was found under ${extension_source_dir}."

    CLP_BUILT_MODULE_PATH="${stage_dir}/${module_base}.so"
    clp_run cp -p "${found_module}" "${CLP_BUILT_MODULE_PATH}"
    clp_info "Built staged module: ${CLP_BUILT_MODULE_PATH}"
}
