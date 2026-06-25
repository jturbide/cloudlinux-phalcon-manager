#!/usr/bin/env bats

setup() {
  export CLP_TEST_MODE=1
  export CLP_ROOT="${BATS_TEST_TMPDIR}/root"
  export CLP_OPT_ALT="${CLP_ROOT}/opt/alt"
  export CLP_SELECTOR_CONFLICTS="${CLP_ROOT}/etc/cl.selector/php.extensions.conflicts"
  export CLP_STATE_DIR="${CLP_ROOT}/var/lib/cloudlinux-phalcon-manager"
  export CLP_LOG_FILE="${CLP_ROOT}/var/log/cloudlinux-phalcon-manager.log"

  mkdir -p \
    "${CLP_OPT_ALT}/php85/usr/bin" \
    "${CLP_OPT_ALT}/php85/usr/lib64/php/modules" \
    "${CLP_OPT_ALT}/php85/etc/php.d.all" \
    "${CLP_STATE_DIR}" \
    "${BATS_TEST_TMPDIR}/bin"

  cat > "${BATS_TEST_TMPDIR}/bin/rpm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-qa" && "$2" == "--qf" ]]; then
  printf '%s\t%s\n' \
    "alt-php85-phalcon5" "5.14.0-1.el8.x86_64" \
    "bash" "5.2.0-1.x86_64"
elif [[ "$1" == "-qa" ]]; then
  printf '%s\n' \
    "alt-php85-phalcon5-5.14.0-1.el8.x86_64" \
    "bash-5.2.0-1.x86_64"
fi
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/rpm"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"

  cat > "${CLP_OPT_ALT}/php85/usr/bin/php-config" <<EOF
#!/usr/bin/env bash
case "\$1" in
  --version) echo "8.5.7" ;;
  --extension-dir) echo "${CLP_OPT_ALT}/php85/usr/lib64/php/modules" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "${CLP_OPT_ALT}/php85/usr/bin/php-config"
  touch "${CLP_OPT_ALT}/php85/usr/bin/phpize"
  chmod +x "${CLP_OPT_ALT}/php85/usr/bin/phpize"

  touch \
    "${CLP_OPT_ALT}/php85/usr/lib64/php/modules/phalcon516.so" \
    "${CLP_OPT_ALT}/php85/usr/lib64/php/modules/phalcon5.so"

  cat > "${CLP_OPT_ALT}/php85/etc/php.d.all/phalcon516.ini" <<'EOF'
extension=pdo.so
extension=phalcon516.so
EOF

  cat > "${CLP_OPT_ALT}/php85/etc/php.d.all/phalcon5.ini" <<'EOF'
extension=phalcon5.so
EOF

  cat > "${CLP_STATE_DIR}/installs.json" <<EOF
{
  "schema_version": 1,
  "installs": [
    {
      "php_slot": "php85",
      "module_name": "phalcon516.so",
      "ini_path": "${CLP_OPT_ALT}/php85/etc/php.d.all/phalcon516.ini"
    }
  ]
}
EOF
}

@test "foreign inventory separates managed and unmanaged Phalcon artifacts" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" foreign --php php85
  [ "$status" -eq 0 ]

  [[ "$output" =~ RPM_PACKAGE[[:space:]]+OFFICIAL[[:space:]]+php85[[:space:]]+phalcon5[[:space:]]+5\.14\.0-1\.el8\.x86_64[[:space:]]+alt-php85-phalcon5-5\.14\.0-1\.el8\.x86_64 ]]
  [[ "$output" == *"MODULE_FILE  MANAGED  php85    phalcon516.so"* ]]
  [[ "$output" == *"MODULE_FILE  OFFICIAL php85    phalcon5.so"* ]]
  [[ "$output" == *"INI_FILE     MANAGED  php85    phalcon516.ini"* ]]
  [[ "$output" == *"INI_FILE     OFFICIAL php85    phalcon5.ini"* ]]
}
