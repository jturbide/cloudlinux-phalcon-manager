# Changelog

## 1.0.1 - 2026-06-25

### Fixed

- Mark CloudLinux RPM-owned Phalcon module and INI files as `OFFICIAL` in the
  foreign inventory instead of reporting them as unmanaged foreign files.
- Make `usage` default to each account's current PHP Selector version, using
  `selectorctl --user-current` with a selected-row summary fallback.
- Keep `usage --all-php` available for slower exhaustive audits across every
  detected selector PHP slot.
- Add parallel selector probes via `--jobs` for broad usage scans.

## 1.0.0 - 2026-06-25

First stable release of `cloudlinux-phalcon-manager`.

### Added

- Add `cl-phalcon` Bash CLI for CloudLinux alt-php Phalcon management.
- Add CloudLinux alt-php detection with PHP ABI/build metadata capture.
- Add install, reinstall, remove, validate, update, upgrade, conflicts,
  CageFS rebuild, doctor, foreign inventory, and selector usage commands.
- Add persistent metadata storage in `installs.json`.
- Add rebuild detection for PHP ABI/build changes, extension directory changes,
  Phalcon source changes, missing modules, and validation failures.
- Add version-aware module naming for `phalcon41`, `phalcon42`, `phalcon59`,
  `phalcon516`, and full-patch module names.
- Add configurable INI dependency handling with safe defaults for Phalcon 4 and
  Phalcon 5.
- Add PHP Selector conflict management for custom modules and official
  CloudLinux Phalcon selector names.
- Add foreign inventory reporting for official RPMs, unmanaged module files,
  unmanaged INI files, and managed installs.
- Add selector usage reporting across all detected PHP Selector slots, with a
  `--current-only` mode for the legacy current-version-only report.
- Add production docs, rollback docs, metadata docs, dependency docs,
  real-world examples, compatibility grid, and manual install reference.
- Add Bats tests, ShellCheck coverage, and GitHub Actions CI.

### Safety

- Require root for mutating and server-inspection commands.
- Support `--dry-run` and `--yes`.
- Log actions to `/var/log/cloudlinux-phalcon-manager.log`.
- Build in isolated staging directories before installing modules.
- Back up modules, INI files, and selector conflict files before replacing them.
- Avoid deleting paths outside the tool-owned source/build/cache directories.
- Preserve unrelated selector conflict-file content.

### Notes

- This release is intended for CloudLinux alt-php, PHP Selector, and CageFS on
  cPanel servers. It is not a generic EasyApache-only PHP extension manager.
- Compiled Phalcon modules are intentionally treated as PHP-slot-specific and
  are never reused across different alt-php slots.
