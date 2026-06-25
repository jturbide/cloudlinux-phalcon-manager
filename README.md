# cloudlinux-phalcon-manager

`cloudlinux-phalcon-manager` provides `cl-phalcon`, a conservative Bash CLI for
building and managing versioned Phalcon PHP extensions on CloudLinux cPanel
servers that use alt-php, PHP Selector, and CageFS.

It replaces the manual process of cloning `phalcon/cphalcon`, compiling with the
matching CloudLinux `phpize` and `php-config`, renaming `phalcon.so` to a
versioned module such as `phalcon514.so`, writing PHP Selector ini files, keeping
extension conflicts in sync, and rebuilding CageFS alt-php ini state.

## Status

This is an MVP. The first supported workflow covers:

- `detect`
- `install --php phpXX --phalcon VERSION`
- `update`
- metadata storage
- ini generation
- validation
- CageFS rebuild
- idempotent conflict updates

## Supported Environment

This tool is intended for CloudLinux OS on cPanel servers with CloudLinux
alt-php and PHP Selector paths such as:

```text
/opt/alt/php74
/opt/alt/php80
/opt/alt/php82
/opt/alt/php83
/opt/alt/php84
/opt/alt/php85
```

It is not intended for generic EasyApache-only PHP setups where CloudLinux
alt-php, PHP Selector, and CageFS are not in use.

## Requirements

- root shell
- Bash
- `jq`
- `git`
- `gcc`
- `make`
- `cagefsctl`
- matching CloudLinux alt-php `phpize`
- matching CloudLinux alt-php `php-config`

All mutating commands require root. Tests can use `CLP_TEST_MODE=1` with a mock
root, but production use should not.

## Install the CLI

From a checkout:

```bash
install -m 0755 bin/cl-phalcon /usr/local/sbin/cl-phalcon
install -d /usr/local/lib/cloudlinux-phalcon-manager
cp -a lib /usr/local/lib/cloudlinux-phalcon-manager/
```

If you install the script somewhere else, keep `bin/cl-phalcon` and `lib/`
together, or wrap the repo-local `bin/cl-phalcon`.

## Commands

```bash
cl-phalcon list
cl-phalcon doctor
cl-phalcon detect
cl-phalcon install
cl-phalcon reinstall
cl-phalcon remove
cl-phalcon validate
cl-phalcon update
cl-phalcon upgrade
cl-phalcon rebuild-needed
cl-phalcon rebuild-all-needed
cl-phalcon conflicts
cl-phalcon cagefs-rebuild
```

Global options:

```bash
cl-phalcon --dry-run ...
cl-phalcon --yes ...
```

## Real-world Workflows

See [docs/compatibility-grid.md](docs/compatibility-grid.md) for the usual
CloudLinux alt-php and Phalcon version grid. Individual per-PHP examples live in
[examples/](examples/). INI dependency defaults are documented in
[docs/dependencies.md](docs/dependencies.md).

First inspect what CloudLinux alt-php slots exist:

```bash
cl-phalcon doctor
cl-phalcon detect
```

Install the current Phalcon 5.16 line for PHP 8.5:

```bash
cl-phalcon install --php php85 --phalcon 5.16.0 --yes
cl-phalcon validate --php php85 --module phalcon516
```

Install the pinned Phalcon 5.9.3 compatibility module for older projects:

```bash
cl-phalcon install --php php81,php82,php83,php84 --phalcon 5.9.3 --module phalcon59 --yes
cl-phalcon validate
```

This is useful when CloudLinux's official `phalcon5` package has moved past
5.9.3 but older projects are still aligned with that framework behavior.

Install an older Phalcon 4 build for a legacy PHP 7.4 application:

```bash
cl-phalcon install \
  --php php74 \
  --phalcon 4.1.3 \
  --module phalcon4 \
  --yes
```

For Phalcon 4, the generated ini loads `psr.so` before `phalcon4.so` by
default. Use `--dependencies` only when you want a custom load order.

After CloudLinux updates alt-php packages, preview whether anything actually
needs a rebuild:

```bash
cl-phalcon rebuild-needed
```

Rebuild only the managed installs whose ABI, extension directory, module file,
or validation state requires it:

```bash
cl-phalcon update --yes
```

Limit an update to one PHP slot:

```bash
cl-phalcon update --php php85 --yes
```

Dry-run the same update first:

```bash
cl-phalcon --dry-run update --php php85
```

Upgrade one managed module to a newer Phalcon release:

```bash
cl-phalcon upgrade --php php85 --phalcon 5.16.0 --module phalcon516 --yes
cl-phalcon validate --php php85 --module phalcon516
```

`upgrade` targets already-managed PHP slots and leaves the old module installed
until you remove it. That gives you a PHP Selector rollback path.

Then let PHP Selector expose only one Phalcon option at a time:

```bash
cl-phalcon conflicts
cl-phalcon cagefs-rebuild
```

## Detection

`detect` scans:

```text
/opt/alt/php*/usr/bin/php-config
```

For each detected slot it resolves:

- PHP binary
- `phpize`
- `php-config`
- extension directory
- PHP version
- PHP API
- Zend Module API
- Zend Extension Build
- thread safety
- debug build

Example:

```bash
cl-phalcon detect
cl-phalcon detect --php php85
```

## Install Examples

Install Phalcon 5.14.2 for `php85` using the default module name
`phalcon514.so`:

```bash
cl-phalcon install --php php85 --phalcon 5.14.2 --yes
```

Install with an explicit module name:

```bash
cl-phalcon install --php php85 --phalcon 5.14.2 --module phalcon514 --yes
```

Install the pinned Phalcon 5.9.3 compatibility module for multiple alt-php
slots:

```bash
cl-phalcon install --php php82,php83,php84 --phalcon 5.9.3 --module phalcon59 --yes
```

Install for every detected alt-php slot:

```bash
cl-phalcon install --all-php --phalcon 5.16.0 --yes
```

Use full patch module naming:

```bash
cl-phalcon install --php php85 --phalcon 5.14.2 --full-patch-module --yes
```

That produces `phalcon5142.so`.

Use a branch or non-default git ref:

```bash
cl-phalcon install --php php80 --phalcon 4.2.x --git-ref 4.2.x --module phalcon4 --yes
```

Phalcon 4 ini dependencies are applied automatically:

```bash
cl-phalcon install --php php74 --phalcon 4.1.x --git-ref 4.1.x --module phalcon4 --yes
```

That writes:

```ini
extension=psr.so
extension=phalcon4.so
```

Override the generated ini dependency order when a legacy server needs it:

```bash
cl-phalcon install \
  --php php74 \
  --phalcon 4.1.3 \
  --module phalcon4 \
  --dependencies psr,pdo,json \
  --yes
```

Disable automatic dependency defaults when another server-owned ini already
loads the dependency:

```bash
cl-phalcon install \
  --php php74 \
  --phalcon 4.1.x \
  --git-ref 4.1.x \
  --module phalcon4 \
  --no-default-dependencies \
  --yes
```

The tool does not hardcode PSR/PDO/JSON for every Phalcon version. See
[docs/dependencies.md](docs/dependencies.md) for the current dependency matrix.

## Validation

Validation checks:

- module file exists
- module ownership is `root:linksafe`
- ini file exists
- ini contains `extension=<module>.so`
- ini contains any recorded dependency `extension=<dependency>.so` lines
- matching alt-php can load recorded dependencies and the module with isolated
  `php -n` checks
- matching alt-php reports Phalcon with isolated `php -n --ri phalcon`

Examples:

```bash
cl-phalcon validate
cl-phalcon validate --php php85 --module phalcon514
```

## Rebuild Logic

Each install writes metadata to:

```text
/var/lib/cloudlinux-phalcon-manager/installs.json
```

`rebuild-needed` compares stored metadata with the current alt-php slot.

A rebuild is required when:

- the module is missing
- validation fails
- the PHP version family changed
- the PHP API changed
- the Zend Module API changed
- the Zend Extension Build changed
- the extension directory changed
- the recorded Phalcon install is reinstalled with a different source version

Examples:

```bash
cl-phalcon rebuild-needed
cl-phalcon rebuild-needed --php php85 --module phalcon514
cl-phalcon rebuild-all-needed --apply --yes
cl-phalcon update --yes
cl-phalcon upgrade --php php85 --phalcon 5.16.0 --module phalcon516 --yes
```

Normal PHP patch updates usually do not require rebuilding if the PHP ABI/build
metadata is unchanged. The important compatibility boundary for native PHP
extensions is the ABI/build metadata, not just the human-readable patch number.

`update` is the practical maintenance command. It reads stored metadata,
validates each managed install, compares the current alt-php ABI/build metadata,
and only reinstalls entries that need rebuilding. It does not rebuild healthy
modules just because a PHP patch package changed.

`upgrade` is different: it is for moving an already-managed PHP slot to a newer
Phalcon source version. It installs the new module and keeps the old module
until you remove it explicitly.

## Why Each alt-php Slot Gets Its Own Build

Native PHP extensions are compiled against a specific PHP build. CloudLinux
alt-php slots can differ in PHP version, extension directory, PHP API, Zend
Module API, thread-safety settings, and debug/build flags.

Because of that, `phalcon.so` compiled for one slot must not be copied into
another slot. `cl-phalcon` always builds per selected `phpXX` slot and stores
per-slot metadata.

## Conflicts

`cl-phalcon conflicts` safely manages:

```text
/etc/cl.selector/php.extensions.conflicts
```

It creates a timestamped backup, preserves unrelated content, removes stale
managed Phalcon entries, and writes a single managed block that makes all
managed Phalcon module names conflict with each other.

Default managed names include:

```text
phalcon phalcon2 phalcon3 phalcon4 phalcon5 phalcon51 phalcon52 phalcon53
phalcon54 phalcon55 phalcon56 phalcon57 phalcon58 phalcon59 phalcon513
phalcon514 phalcon515 phalcon516
```

Any module installed by the tool is added to the managed conflict set.

CloudLinux also ships official Phalcon packages, commonly exposed through PHP
Selector as `phalcon`. Those packages are useful, but their version may be too
old or too new for a specific application target. `cl-phalcon` does not
overwrite the official `phalcon.so` by default; custom builds use versioned
module names such as `phalcon514.so` and `phalcon516.so`.

Prefer the official CloudLinux RPM when it already satisfies the application.
Use `cl-phalcon` for missing combinations, pinned compatibility versions,
newer upstream versions, or controlled migrations that need a separate
versioned selector module.

Check package availability and version before compiling:

```bash
dnf search phalcon
dnf info alt-php85-phalcon5
rpm -qa | sort | grep -E '^alt-php[0-9]+-phalcon'
```

The managed conflicts block always includes the official selector name
`phalcon`, plus the versioned names managed by this tool. That prevents an
account from enabling the CloudLinux official Phalcon extension and a custom
Phalcon extension at the same time.

This tool does not uninstall CloudLinux's official Phalcon RPMs. It coexists
with them by using versioned module names and PHP Selector conflicts.

## CageFS

After install, reinstall, remove, or conflict updates, run:

```bash
cl-phalcon cagefs-rebuild
```

Install and rebuild commands run this automatically unless `--skip-cagefs` is
used.

## Safety

The CLI uses strict Bash mode:

```bash
set -Eeuo pipefail
```

Safety behavior:

- requires root for real commands
- supports `--dry-run`
- supports `--yes`
- logs to `/var/log/cloudlinux-phalcon-manager.log`
- fails fast for missing build tools and CloudLinux tools
- backs up existing modules and ini files before replacement
- builds in an isolated workspace before final installation
- avoids `make install` so upstream cphalcon cannot overwrite CloudLinux's
  official `phalcon.so`
- only uses recursive removal inside tool-owned source/build/cache directories
- never assumes a module built for one alt-php slot can be reused elsewhere

## Test Overrides

Mock-root tests can override paths:

```bash
CLP_ROOT=/tmp/mock-root
CLP_OPT_ALT=/tmp/mock-root/opt/alt
CLP_SELECTOR_CONFLICTS=/tmp/mock-root/etc/cl.selector/php.extensions.conflicts
CLP_STATE_DIR=/tmp/mock-root/var/lib/cloudlinux-phalcon-manager
CLP_LOG_FILE=/tmp/mock-root/var/log/cloudlinux-phalcon-manager.log
CLP_TEST_MODE=1
```

## Tests

Bats specs live in `tests/`.

```bash
bats tests
```

If Bats is not installed, at minimum run:

```bash
bash -n bin/cl-phalcon lib/*.sh
```

## Production Checklist

See [docs/production-readiness.md](docs/production-readiness.md).
Rollback guidance lives in [docs/rollback.md](docs/rollback.md).
Dependency guidance lives in [docs/dependencies.md](docs/dependencies.md).
The original manual command sequence is preserved in
[docs/manual-install-reference.md](docs/manual-install-reference.md).
