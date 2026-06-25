#!/usr/bin/env bats

setup() {
  export CLP_TEST_MODE=1
  export CLP_ROOT="${BATS_TEST_TMPDIR}/root"
  export CLP_OPT_ALT="${CLP_ROOT}/opt/alt"
  export CLP_SELECTOR_CONFLICTS="${CLP_ROOT}/etc/cl.selector/php.extensions.conflicts"
  export CLP_STATE_DIR="${CLP_ROOT}/var/lib/cloudlinux-phalcon-manager"
  export CLP_LOG_FILE="${CLP_ROOT}/var/log/cloudlinux-phalcon-manager.log"
  export CLP_VALIDATE_ARGS_LOG="${BATS_TEST_TMPDIR}/php-args.log"

  mkdir -p \
    "${CLP_OPT_ALT}/php85/usr/bin" \
    "${CLP_OPT_ALT}/php85/usr/lib64/php/modules" \
    "${CLP_OPT_ALT}/php85/etc/php.d.all" \
    "${CLP_STATE_DIR}"

  cat > "${CLP_OPT_ALT}/php85/usr/bin/php" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CLP_VALIDATE_ARGS_LOG}"
case "$*" in
  *"--ri phalcon"*) echo "phalcon"; exit 0 ;;
  *"-m"*) echo "phalcon"; exit 0 ;;
esac
exit 0
EOF
  chmod +x "${CLP_OPT_ALT}/php85/usr/bin/php"

  touch "${CLP_OPT_ALT}/php85/usr/lib64/php/modules/phalcon514.so"
  {
    echo "extension=psr.so"
    echo "extension=pdo.so"
    echo "extension=phalcon514.so"
  } > "${CLP_OPT_ALT}/php85/etc/php.d.all/phalcon514.ini"

  cat > "${CLP_STATE_DIR}/installs.json" <<EOF
{
  "schema_version": 1,
  "installs": [
    {
      "php_slot": "php85",
      "php_binary": "${CLP_OPT_ALT}/php85/usr/bin/php",
      "extension_dir": "${CLP_OPT_ALT}/php85/usr/lib64/php/modules",
      "module_name": "phalcon514.so",
      "ini_path": "${CLP_OPT_ALT}/php85/etc/php.d.all/phalcon514.ini",
      "ini_dependencies": ["psr", "pdo"]
    }
  ]
}
EOF
}

@test "validate accepts a matching module and ini in mock root" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" validate --php php85 --module phalcon514
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS php85/phalcon514.so"* ]]
  grep -q "extension=psr.so" "${CLP_VALIDATE_ARGS_LOG}"
  grep -q "extension=pdo.so" "${CLP_VALIDATE_ARGS_LOG}"
}
