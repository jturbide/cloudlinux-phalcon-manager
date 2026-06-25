#!/usr/bin/env bats

setup() {
  export CLP_TEST_MODE=1
  export CLP_ROOT="${BATS_TEST_TMPDIR}/root"
  export CLP_OPT_ALT="${CLP_ROOT}/opt/alt"
  export CLP_SELECTOR_CONFLICTS="${CLP_ROOT}/etc/cl.selector/php.extensions.conflicts"
  export CLP_STATE_DIR="${CLP_ROOT}/var/lib/cloudlinux-phalcon-manager"
  export CLP_LOG_FILE="${CLP_ROOT}/var/log/cloudlinux-phalcon-manager.log"

  mkdir -p "${CLP_OPT_ALT}/php85/usr/bin" "${CLP_STATE_DIR}"
  cat > "${CLP_OPT_ALT}/php85/usr/bin/php-config" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --version) echo "8.5.7" ;;
  --extension-dir) echo "/opt/alt/php85/usr/lib64/php/modules" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "${CLP_OPT_ALT}/php85/usr/bin/php-config"

  cat > "${CLP_OPT_ALT}/php85/usr/bin/php" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"-i"* ]]; then
  printf "%s\n" \
    "PHP API => 20240924" \
    "Zend Module Api No => 20240924" \
    "Zend Extension Build => API420240924,NTS" \
    "Thread Safety => disabled" \
    "Debug Build => no"
fi
EOF
  chmod +x "${CLP_OPT_ALT}/php85/usr/bin/php"
  touch "${CLP_OPT_ALT}/php85/usr/bin/phpize"
  chmod +x "${CLP_OPT_ALT}/php85/usr/bin/phpize"

  cat > "${CLP_STATE_DIR}/installs.json" <<EOF
{
  "schema_version": 1,
  "installs": [
    {
      "php_slot": "php85",
      "php_version": "8.5.7",
      "php_prefix": "${CLP_OPT_ALT}/php85",
      "php_binary": "${CLP_OPT_ALT}/php85/usr/bin/php",
      "phpize": "${CLP_OPT_ALT}/php85/usr/bin/phpize",
      "php_config": "${CLP_OPT_ALT}/php85/usr/bin/php-config",
      "extension_dir": "${CLP_OPT_ALT}/php85/usr/lib64/php/modules",
      "phalcon_version": "5.14.2",
      "phalcon_git_ref": "v5.14.2",
      "module_name": "phalcon514.so",
      "ini_path": "${CLP_OPT_ALT}/php85/etc/php.d.all/phalcon514.ini",
      "cflags": "-O2",
      "ini_dependencies": []
    }
  ]
}
EOF
}

@test "upgrade dry-run installs newer module for managed slot" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" --dry-run upgrade --php php85 --phalcon 5.16.0 --skip-cagefs
  [ "$status" -eq 0 ]
  [[ "$output" == *"Upgrading managed php85 install to Phalcon 5.16.0 as phalcon516.so"* ]]
  [[ "$output" == *"DRY-RUN: build phalcon516.so for php85"* ]]
}
