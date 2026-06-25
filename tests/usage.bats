#!/usr/bin/env bats

setup() {
  export CLP_TEST_MODE=1
  export CLP_ROOT="${BATS_TEST_TMPDIR}/root"
  export CLP_OPT_ALT="${CLP_ROOT}/opt/alt"
  export CLP_SELECTOR_CONFLICTS="${CLP_ROOT}/etc/cl.selector/php.extensions.conflicts"
  export CLP_STATE_DIR="${CLP_ROOT}/var/lib/cloudlinux-phalcon-manager"
  export CLP_LOG_FILE="${CLP_ROOT}/var/log/cloudlinux-phalcon-manager.log"
  export CLP_CPANEL_USERS_DIR="${CLP_ROOT}/var/cpanel/users"
  export CLP_USERDOMAINS_FILE="${CLP_ROOT}/etc/userdomains"

  mkdir -p \
    "${CLP_OPT_ALT}/php85/usr/bin" \
    "${CLP_STATE_DIR}" \
    "${CLP_CPANEL_USERS_DIR}" \
    "$(dirname "${CLP_USERDOMAINS_FILE}")" \
    "${BATS_TEST_TMPDIR}/bin"

  touch \
    "${CLP_CPANEL_USERS_DIR}/alice" \
    "${CLP_CPANEL_USERS_DIR}/bob" \
    "${CLP_CPANEL_USERS_DIR}/carol"

  cat > "${CLP_USERDOMAINS_FILE}" <<'EOF'
alice.example: alice
shop.alice.example: alice
bob.example: bob
carol.example: carol
EOF

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

  cat > "${BATS_TEST_TMPDIR}/bin/rpm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-qa" && "$2" == "--qf" ]]; then
  printf '%s\n' "alt-php85-phalcon5"
elif [[ "$1" == "-qa" ]]; then
  printf '%s\n' "alt-php85-phalcon5-5.14.0-1.el8.x86_64"
fi
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/rpm"

  cat > "${BATS_TEST_TMPDIR}/bin/selectorctl" <<'EOF'
#!/usr/bin/env bash
user=""
version=""

previous=""
for arg in "$@"; do
  case "${arg}" in
    --user=*)
      user="${arg#--user=}"
      ;;
    --version=*)
      version="${arg#--version=}"
      ;;
    *)
      if [[ "${previous}" == "--user" ]]; then
        user="${arg}"
      elif [[ "${previous}" == "--version" ]]; then
        version="${arg}"
      fi
      ;;
  esac
  previous="${arg}"
done

if [[ "$1" == "--list-users" ]]; then
  printf '%s\n' "alice" "bob" "carol"
  exit 0
fi

if [[ "$1" == "--list-user-extensions" ]]; then
  [[ -n "${user}" ]] || exit 0
  if [[ -n "${version}" && "${CLP_TEST_SELECTOR_NO_VERSION_ONLY:-0}" == "1" ]]; then
    exit 0
  fi
  if [[ "${version}" == "8.5" || -z "${version}" ]]; then
    case "${user}" in
      alice) printf '%s\n' "pdo" "phalcon516" ;;
      bob) printf '%s\n' "pdo" "phalcon5" ;;
      carol) printf '%s\n' "pdo" ;;
    esac
  fi
  exit 0
fi

if [[ "$1" == "--user-current" ]]; then
  case "${user}" in
    alice|bob|carol) echo "Current PHP version: 8.5" ;;
  esac
  exit 0
fi

if [[ "$1" != "--user-extensions" ]]; then
  exit 1
fi

if [[ "${version}" != "8.5" ]]; then
  exit 0
fi

case "${user}" in
  alice) printf '%s\n' "pdo" "phalcon516" ;;
  bob) printf '%s\n' "pdo" "phalcon5" ;;
  carol) printf '%s\n' "pdo" ;;
esac
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/selectorctl"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"

  cat > "${CLP_STATE_DIR}/installs.json" <<EOF
{
  "schema_version": 1,
  "installs": [
    {
      "php_slot": "php85",
      "module_name": "phalcon516.so"
    }
  ]
}
EOF
}

@test "usage reports selector accounts and domains by Phalcon module" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" usage
  [ "$status" -eq 0 ]

  [[ "$output" =~ SELECTOR_USE[[:space:]]+MANAGED[[:space:]]+php85[[:space:]]+phalcon516\.so[[:space:]]+alice[[:space:]]+alice\.example,shop\.alice\.example ]]
  [[ "$output" =~ SELECTOR_USE[[:space:]]+OFFICIAL[[:space:]]+php85[[:space:]]+phalcon5\.so[[:space:]]+bob[[:space:]]+bob\.example ]]
  [[ "$output" =~ USAGE_SUMMARY[[:space:]]+MANAGED[[:space:]]+php85[[:space:]]+phalcon516\.so[[:space:]]+1[[:space:]]+2[[:space:]]+alice ]]
  [[ "$output" =~ USAGE_SUMMARY[[:space:]]+OFFICIAL[[:space:]]+php85[[:space:]]+phalcon5\.so[[:space:]]+1[[:space:]]+1[[:space:]]+bob ]]
  [[ "$output" != *"carol.example"* ]]
}

@test "usage can filter the bulk selector report by php slot and module" {
  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" usage --php php85 --module phalcon516
  [ "$status" -eq 0 ]

  [[ "$output" =~ SELECTOR_USE[[:space:]]+MANAGED[[:space:]]+php85[[:space:]]+phalcon516\.so[[:space:]]+alice ]]
  [[ "$output" != *"phalcon5.so"* ]]
  [[ "$output" =~ USAGE_SUMMARY[[:space:]]+MANAGED[[:space:]]+php85[[:space:]]+phalcon516\.so[[:space:]]+1[[:space:]]+2[[:space:]]+alice ]]
}

@test "usage falls back to unversioned per-user selector extension output" {
  export CLP_TEST_SELECTOR_NO_VERSION_ONLY=1

  run "${BATS_TEST_DIRNAME}/../bin/cl-phalcon" usage
  [ "$status" -eq 0 ]

  [[ "$output" =~ SELECTOR_USE[[:space:]]+MANAGED[[:space:]]+php85[[:space:]]+phalcon516\.so[[:space:]]+alice ]]
  [[ "$output" =~ SELECTOR_USE[[:space:]]+OFFICIAL[[:space:]]+php85[[:space:]]+phalcon5\.so[[:space:]]+bob ]]
}
