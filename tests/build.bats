#!/usr/bin/env bats

setup() {
  export CLP_TEST_MODE=1
}

@test "build helper prefers the generated build/phalcon source directory" {
  tmpdir="${BATS_TEST_TMPDIR}/cphalcon"
  mkdir -p "${tmpdir}/build/phalcon" "${tmpdir}/ext"
  touch "${tmpdir}/build/phalcon/config.m4" "${tmpdir}/ext/config.m4"

  run bash -c 'source lib/common.sh; source lib/build.sh; clp_find_cphalcon_extension_source "$1"' _ "${tmpdir}"
  [ "$status" -eq 0 ]
  [ "$output" = "${tmpdir}/build/phalcon" ]
}

@test "build helper falls back to any config.m4 source directory" {
  tmpdir="${BATS_TEST_TMPDIR}/cphalcon"
  mkdir -p "${tmpdir}/custom/source"
  touch "${tmpdir}/custom/source/config.m4"

  run bash -c 'source lib/common.sh; source lib/build.sh; clp_find_cphalcon_extension_source "$1"' _ "${tmpdir}"
  [ "$status" -eq 0 ]
  [ "$output" = "${tmpdir}/custom/source" ]
}
