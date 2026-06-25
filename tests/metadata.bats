#!/usr/bin/env bats

setup() {
  export CLP_TEST_MODE=1
  export CLP_ROOT="${BATS_TEST_TMPDIR}/root"
  export CLP_OPT_ALT="${CLP_ROOT}/opt/alt"
  export CLP_SELECTOR_CONFLICTS="${CLP_ROOT}/etc/cl.selector/php.extensions.conflicts"
  export CLP_STATE_DIR="${CLP_ROOT}/var/lib/cloudlinux-phalcon-manager"
  export CLP_LOG_FILE="${CLP_ROOT}/var/log/cloudlinux-phalcon-manager.log"
  mkdir -p "${CLP_STATE_DIR}"
}

@test "list reports no installs when metadata is absent" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Phalcon installs recorded"* ]]
}

@test "versioned module defaults are conservative" {
  run bash -c 'source lib/common.sh; clp_phalcon_default_module_base 5.14.2 0'
  [ "$status" -eq 0 ]
  [ "$output" = "phalcon514" ]

  run bash -c 'source lib/common.sh; clp_phalcon_default_module_base 5.14.2 1'
  [ "$status" -eq 0 ]
  [ "$output" = "phalcon5142" ]

  run bash -c 'source lib/common.sh; clp_phalcon_default_module_base 4.1.3 0'
  [ "$status" -eq 0 ]
  [ "$output" = "phalcon4" ]
}

@test "ini dependency defaults are version-aware" {
  run bash -c 'source lib/common.sh; clp_resolve_ini_dependencies 4.1.3 ""'
  [ "$status" -eq 0 ]
  [ "$output" = "psr" ]

  run bash -c 'source lib/common.sh; clp_resolve_ini_dependencies 4.2.x ""'
  [ "$status" -eq 0 ]
  [ "$output" = "psr" ]

  run bash -c 'source lib/common.sh; clp_resolve_ini_dependencies 5.16.0 ""'
  [ "$status" -eq 0 ]
  [ "$output" = "" ]

  run bash -c 'source lib/common.sh; clp_resolve_ini_dependencies 4.1.3 "psr,pdo,json"'
  [ "$status" -eq 0 ]
  [ "$output" = "psr,pdo,json" ]
}
