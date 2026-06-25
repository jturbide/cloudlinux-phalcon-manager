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
    "${CLP_OPT_ALT}/php-internal/usr/bin" \
    "${CLP_OPT_ALT}/php74-imunify/usr/bin"

  cat > "${CLP_OPT_ALT}/php85/usr/bin/php-config" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --version) echo "8.5.7" ;;
  --extension-dir) echo "/opt/alt/php85/usr/lib64/php/modules" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "${CLP_OPT_ALT}/php85/usr/bin/php-config"
  cp "${CLP_OPT_ALT}/php85/usr/bin/php-config" "${CLP_OPT_ALT}/php-internal/usr/bin/php-config"
  cp "${CLP_OPT_ALT}/php85/usr/bin/php-config" "${CLP_OPT_ALT}/php74-imunify/usr/bin/php-config"
  chmod +x \
    "${CLP_OPT_ALT}/php-internal/usr/bin/php-config" \
    "${CLP_OPT_ALT}/php74-imunify/usr/bin/php-config"

  cat > "${CLP_OPT_ALT}/php85/usr/bin/php" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"-i"* ]]; then
  cat <<'INFO'
PHP API => 20240924
Zend Module Api No => 20240924
Zend Extension Build => API420240924,NTS
Thread Safety => disabled
Debug Build => no
INFO
  exit 0
fi
exit 0
EOF
  chmod +x "${CLP_OPT_ALT}/php85/usr/bin/php"
  cp "${CLP_OPT_ALT}/php85/usr/bin/php" "${CLP_OPT_ALT}/php-internal/usr/bin/php"
  cp "${CLP_OPT_ALT}/php85/usr/bin/php" "${CLP_OPT_ALT}/php74-imunify/usr/bin/php"
  chmod +x \
    "${CLP_OPT_ALT}/php-internal/usr/bin/php" \
    "${CLP_OPT_ALT}/php74-imunify/usr/bin/php"

  touch "${CLP_OPT_ALT}/php85/usr/bin/phpize"
  touch "${CLP_OPT_ALT}/php-internal/usr/bin/phpize"
  touch "${CLP_OPT_ALT}/php74-imunify/usr/bin/phpize"
  chmod +x \
    "${CLP_OPT_ALT}/php85/usr/bin/phpize" \
    "${CLP_OPT_ALT}/php-internal/usr/bin/phpize" \
    "${CLP_OPT_ALT}/php74-imunify/usr/bin/phpize"
}

@test "detect lists mocked alt-php slot metadata" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" detect
  [ "$status" -eq 0 ]
  [[ "$output" == *"php85"* ]]
  [[ "$output" == *"8.5.7"* ]]
  [[ "$output" == *"20240924"* ]]
  [[ "$output" != *"php-internal"* ]]
  [[ "$output" != *"php74-imunify"* ]]
}

@test "detect can include internal slots explicitly" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" detect --include-internal
  [ "$status" -eq 0 ]
  [[ "$output" == *"php85"* ]]
  [[ "$output" == *"php-internal"* ]]
  [[ "$output" == *"php74-imunify"* ]]
}
