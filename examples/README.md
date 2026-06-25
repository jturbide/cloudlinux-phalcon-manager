# Examples

These scripts are copy-paste friendly examples for common CloudLinux alt-php
slots. Review them before running on a production server.

Recommended individual-slot examples:

```text
install-php72.sh  PHP 7.2: Phalcon 3 and custom phalcon41 from 4.1.x
install-php73.sh  PHP 7.3: Phalcon 3 and custom phalcon41 from 4.1.x
install-php74.sh  PHP 7.4: custom phalcon41 from 4.1.x and pinned phalcon59
install-php80.sh  PHP 8.0: custom phalcon42 from 4.2.x and pinned phalcon59
install-php81.sh  PHP 8.1: pinned Phalcon 5.9.3
install-php82.sh  PHP 8.2: pinned Phalcon 5.9.3
install-php83.sh  PHP 8.3: pinned Phalcon 5.9.3
install-php84.sh  PHP 8.4: pinned Phalcon 5.9.3
install-php85.sh  PHP 8.5: Phalcon 5.16.0+
```

Full-grid example:

```text
recommended-grid.sh
```

The full-grid script intentionally leaves some legacy custom builds commented
out because CloudLinux already provides official RPMs for common Phalcon 3/4
combinations. Prefer the official package when it satisfies the application;
uncomment custom builds only when you need a specific upstream build.

The `phalcon59` examples are intentionally active even when CloudLinux provides
an official `phalcon5` package. They are for older projects pinned to Phalcon
5.9.3 before later Phalcon 5 framework behavior changes.

Phalcon 4 examples rely on the tool's default `psr,pdo` INI dependencies.
Phalcon 5 examples rely on the default `pdo` dependency. See
`../docs/dependencies.md` before adding legacy `psr,pdo,json` load-order
overrides.

Custom Phalcon 4 examples use minor-specific module names: `phalcon41` for the
4.1.x branch and `phalcon42` for the 4.2.x branch. The official CloudLinux RPM
name `phalcon4` remains reserved for CloudLinux's own selector package unless
you explicitly choose to adopt an existing manual install with that name.

Legacy or custom examples:

```text
install-legacy-phalcon514-php85.sh
```

Run a preflight first:

```bash
cl-phalcon doctor
cl-phalcon detect
```

Then run the matching script, or copy the relevant commands into your own
maintenance runbook.
