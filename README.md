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

Run these commands as `root` on the CloudLinux/cPanel server.

Install required operating-system tools first:

```bash
dnf install -y git gcc make jq
```

Make sure CageFS is installed and that each PHP slot you plan to build has its
matching CloudLinux development package installed. Package names vary by
CloudLinux release, but they are commonly shaped like:

```bash
dnf install -y alt-php85-devel
```

Install only the development packages for PHP slots you plan to compile. Avoid
broad globs such as `alt-php8*-devel` unless you intentionally want development
headers for every PHP 8 alt-php slot on that server.

Examples:

```bash
dnf install -y alt-php85-devel
dnf install -y alt-php74-devel alt-php80-devel alt-php81-devel alt-php82-devel alt-php83-devel alt-php84-devel alt-php85-devel
```

If you installed extra `alt-phpXX-devel` packages by accident, it is usually
safe to leave them installed; they provide build headers and tools such as
`phpize` and `php-config`. They do not enable Phalcon by themselves. If you want
to remove extras, review the transaction before confirming and remove only
development packages for slots you will not build:

```bash
rpm -qa 'alt-php*-devel' | sort
dnf remove alt-php80-devel
```

Clone the project:

```bash
cd /usr/local/src
git clone https://github.com/jturbide/cloudlinux-phalcon-manager.git
cd cloudlinux-phalcon-manager
```

Install the command and its libraries:

```bash
install -m 0755 bin/cl-phalcon /usr/local/sbin/cl-phalcon
install -d -m 0755 /usr/local/lib/cloudlinux-phalcon-manager/lib
install -m 0644 lib/*.sh /usr/local/lib/cloudlinux-phalcon-manager/lib/
```

Verify the installed command:

```bash
cl-phalcon --version
cl-phalcon doctor
cl-phalcon detect
```

If you install the script somewhere else, keep `bin/cl-phalcon` and `lib/`
together, or wrap the repo-local `bin/cl-phalcon`.

For quick testing from a checkout without installing system-wide:

```bash
chmod +x bin/cl-phalcon
./bin/cl-phalcon doctor
./bin/cl-phalcon detect
```

## Update the CLI

If you run `./bin/cl-phalcon` directly from the checkout, `git pull` is enough
to update the working copy:

```bash
cd /usr/local/src/cloudlinux-phalcon-manager
git pull --ff-only
./bin/cl-phalcon --version
./bin/cl-phalcon doctor
./bin/cl-phalcon detect
```

If you installed `cl-phalcon` into `/usr/local/sbin`, `git pull` updates only
the checkout. Reinstall the command and library files after pulling:

```bash
cd /usr/local/src/cloudlinux-phalcon-manager
git pull --ff-only
install -m 0755 bin/cl-phalcon /usr/local/sbin/cl-phalcon
install -d -m 0755 /usr/local/lib/cloudlinux-phalcon-manager/lib
install -m 0644 lib/*.sh /usr/local/lib/cloudlinux-phalcon-manager/lib/
cl-phalcon --version
cl-phalcon doctor
cl-phalcon detect
```

This updates the `cl-phalcon` tool itself. It does not rebuild installed
Phalcon modules. To check whether managed modules need rebuilding after
CloudLinux PHP package updates, use `cl-phalcon rebuild-needed` or
`cl-phalcon update --yes`.

## Commands

```bash
# Show Phalcon modules already managed by this tool from metadata.
cl-phalcon list

# Run environment checks before installing or troubleshooting modules.
cl-phalcon doctor

# Inventory official RPMs, unmanaged Phalcon files, and managed modules.
cl-phalcon foreign

# Count Phalcon modules enabled by PHP Selector accounts and list domains.
cl-phalcon usage

# Detect CloudLinux alt-php slots and their PHP ABI/build metadata.
cl-phalcon detect

# Compile and install a Phalcon version for one or more alt-php slots.
cl-phalcon install

# Rebuild and replace an existing managed module using its stored metadata.
cl-phalcon reinstall

# Remove a managed module, its selector ini, and its metadata entry.
cl-phalcon remove

# Verify module files, ownership, ini load order, and PHP runtime loading.
cl-phalcon validate

# Rebuild only managed modules that currently need rebuilding.
cl-phalcon update

# Install a newer Phalcon version while keeping the old module available.
cl-phalcon upgrade

# Report whether one managed module needs a rebuild and why.
cl-phalcon rebuild-needed

# Report whether any managed modules need rebuilds, optionally applying them.
cl-phalcon rebuild-all-needed

# Update PHP Selector conflicts so only one Phalcon module can be enabled.
cl-phalcon conflicts

# Rebuild CloudLinux CageFS/PHP Selector alt-php ini state.
cl-phalcon cagefs-rebuild
```

Global options:

```bash
cl-phalcon --dry-run ...
cl-phalcon --yes ...
```

## Foreign Inventory

Use `foreign` when you want to see which Phalcon artifacts are managed by
`cl-phalcon` and which ones came from CloudLinux packages or previous manual
installs.

```bash
cl-phalcon foreign
cl-phalcon foreign --php php85
```

The command is read-only. It reports:

- `RPM_PACKAGE OFFICIAL` for installed `alt-php*phalcon*` or
  `ea-php*phalcon*` RPM packages, including parsed slot, module line, and RPM
  version. These are CloudLinux/cPanel packages, not modules managed by this
  tool.
- `MODULE_FILE MANAGED` for `.so` files recorded in metadata.
- `MODULE_FILE FOREIGN` for Phalcon `.so` files found in alt-php extension
  directories but not recorded in metadata.
- `INI_FILE MANAGED` for selector ini files recorded in metadata or loading a
  managed module.
- `INI_FILE FOREIGN` for Phalcon selector ini files not tracked by metadata.

## Selector Usage

Use `usage` when you want to see which Phalcon modules are enabled by PHP
Selector accounts, how many accounts selected each module, and which domains
belong to those accounts.

```bash
cl-phalcon usage
cl-phalcon usage --php php85
cl-phalcon usage --php php85 --module phalcon516
cl-phalcon usage --user accountname
```

By default, `usage` reads CloudLinux's bulk selector report with
`selectorctl --list-user-extensions` and uses `selectorctl --list-users` for the
account list when available. Use `--php php85` to audit a specific alt-php slot,
or `--module phalcon516` to narrow the report to one selector module.

If the bulk selector report is unavailable on a host, `usage` will say so
instead of silently running slow per-account probes. Add `--probe-users` only
when you intentionally want that slower fallback.

This command reports PHP Selector enablement. It does not prove whether an
application's PHP code actively imports or executes Phalcon classes.

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
  --module phalcon41 \
  --yes
```

For Phalcon 4, the generated ini loads `psr.so` and `pdo.so` before
the selected Phalcon module by default. Custom Phalcon 4 examples use
minor-specific module names such as `phalcon41.so` and `phalcon42.so` so they
are clearly distinct from CloudLinux's official `phalcon4` package. For Phalcon
5, it loads `pdo.so` before the versioned Phalcon module. Use `--dependencies`
only when you want a custom load order.

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

## Migrating Existing Manual Installs

If a versioned module such as `phalcon516.so` was installed manually before
using `cl-phalcon`, install the same PHP slot, Phalcon version, and module name
with the tool. The tool will back up the existing module and ini file, replace
them atomically, write metadata, update conflicts, and rebuild CageFS ini state.

Example:

```bash
cl-phalcon --dry-run install --php php85 --phalcon 5.16.0 --module phalcon516 --yes
cl-phalcon install --php php85 --phalcon 5.16.0 --module phalcon516 --yes
cl-phalcon validate --php php85 --module phalcon516
```

Backups are written beside the replaced files with a `.bak.YYYYMMDDHHMMSS`
suffix. Keep the old manual files only as backups; once metadata exists, use
`cl-phalcon update`, `reinstall`, `remove`, and `validate` for that module.

## Detection

`detect` scans:

```text
/opt/alt/php*/usr/bin/php-config
```

By default, `detect` reports selector-style slots named `phpNN`, such as
`php74` or `php85`. Internal slots such as `php-internal` or vendor-specific
slots such as `php74-imunify` are ignored for normal output because they should
not be used for regular PHP Selector Phalcon installs.

For each detected selector slot it resolves:

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
cl-phalcon detect --include-internal
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

Avoid broad `--all-php` installs on production servers with many legacy
CloudLinux slots. `--all-php` targets every detected selector-style `phpNN`
slot, which can include old PHP versions that are not compatible with the
requested Phalcon release. Prefer an explicit `--php` list.

Use `--all-php` only when you have reviewed the detected slots and the selected
Phalcon release is compatible with all of them:

```bash
cl-phalcon install --all-php --phalcon 5.16.0 --yes
```

Use full patch module naming:

```bash
cl-phalcon install --php php85 --phalcon 5.14.2 --full-patch-module --yes
```

That produces `phalcon5142.so`.

Default module names use major/minor version digits. For example, Phalcon
`4.1.x` defaults to `phalcon41`, Phalcon `4.2.x` defaults to `phalcon42`,
Phalcon `5.9.3` defaults to `phalcon59`, and Phalcon `5.16.0` defaults to
`phalcon516`. Use `--module` only when you want a specific selector name or
when adopting an existing manual install.

Use a branch or non-default git ref:

```bash
cl-phalcon install --php php80 --phalcon 4.2.x --git-ref 4.2.x --module phalcon42 --yes
```

Phalcon 4 ini dependencies are applied automatically:

```bash
cl-phalcon install --php php74 --phalcon 4.1.x --git-ref 4.1.x --module phalcon41 --yes
```

That writes:

```ini
extension=psr.so
extension=pdo.so
extension=phalcon41.so
```

Override the generated ini dependency order when a legacy server needs it:

```bash
cl-phalcon install \
  --php php74 \
  --phalcon 4.1.3 \
  --module phalcon41 \
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
  --module phalcon41 \
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
phalcon phalcon2 phalcon3 phalcon4 phalcon41 phalcon42 phalcon5 phalcon51 phalcon52 phalcon53
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

The block uses CloudLinux's native comma-separated conflict-group syntax, for
example:

```text
phalcon, phalcon2, phalcon3, phalcon4, phalcon41, phalcon42, phalcon5, phalcon59, phalcon516
```

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
