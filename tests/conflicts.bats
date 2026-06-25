#!/usr/bin/env bats

setup() {
  export CLP_TEST_MODE=1
  export CLP_ROOT="${BATS_TEST_TMPDIR}/root"
  export CLP_OPT_ALT="${CLP_ROOT}/opt/alt"
  export CLP_SELECTOR_CONFLICTS="${CLP_ROOT}/etc/cl.selector/php.extensions.conflicts"
  export CLP_STATE_DIR="${CLP_ROOT}/var/lib/cloudlinux-phalcon-manager"
  export CLP_LOG_FILE="${CLP_ROOT}/var/log/cloudlinux-phalcon-manager.log"

  mkdir -p "$(dirname "${CLP_SELECTOR_CONFLICTS}")" "${CLP_STATE_DIR}"
  cat > "${CLP_SELECTOR_CONFLICTS}" <<'EOF'
unrelated: other
phalcon, phalcon2, phalcon514
phalcon514: oldduplicate
EOF
  cat > "${CLP_STATE_DIR}/installs.json" <<'EOF'
{
  "schema_version": 1,
  "installs": [
    {
      "php_slot": "php85",
      "module_name": "phalcon599.so"
    }
  ]
}
EOF
}

@test "conflicts rewrites a single managed block and preserves unrelated content" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" conflicts --yes
  [ "$status" -eq 0 ]

  run grep -c "BEGIN cloudlinux-phalcon-manager" "${CLP_SELECTOR_CONFLICTS}"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]

  run grep -F "unrelated: other" "${CLP_SELECTOR_CONFLICTS}"
  [ "$status" -eq 0 ]

  run grep -F "phalcon, phalcon2, phalcon3, phalcon4" "${CLP_SELECTOR_CONFLICTS}"
  [ "$status" -eq 0 ]

  run grep -F "phalcon599" "${CLP_SELECTOR_CONFLICTS}"
  [ "$status" -eq 0 ]

  run grep -F "phalcon514: oldduplicate" "${CLP_SELECTOR_CONFLICTS}"
  [ "$status" -ne 0 ]

  run grep -F "phalcon, phalcon2, phalcon514" "${CLP_SELECTOR_CONFLICTS}"
  [ "$status" -ne 0 ]

  run grep -F "phalcon599:" "${CLP_SELECTOR_CONFLICTS}"
  [ "$status" -ne 0 ]
}
