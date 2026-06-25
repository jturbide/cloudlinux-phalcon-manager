# Recommended Compatibility Grid

This grid documents the practical CloudLinux alt-php and Phalcon combinations
this tool is meant to make easy to maintain.

The goal is not to force one global Phalcon version for every PHP version. Most
servers need several versioned selector modules because old applications may
need Phalcon 3 or 4 while newer applications should use Phalcon 5.

## Usual Targets

| CloudLinux slot | PHP family | Usually wanted Phalcon modules | Notes |
| --- | --- | --- | --- |
| `php72` | PHP 7.2 | `phalcon3`, `phalcon4` | Use Phalcon `v3.4.5` for legacy apps. Use Phalcon 4 from `4.1.x`. |
| `php73` | PHP 7.3 | `phalcon3`, `phalcon4` | Same as PHP 7.2. |
| `php74` | PHP 7.4 | `phalcon4`, `phalcon59` | Phalcon 4 from `4.1.x`; Phalcon 5.9.3 for older Phalcon 5 apps pinned before later framework changes. |
| `php80` | PHP 8.0 | `phalcon4`, `phalcon59` | Transition slot. Phalcon 4 must come from `4.2.x`; earlier PHP slots use `4.1.x`. |
| `php81` | PHP 8.1 | `phalcon59` | Compatibility pin for older Phalcon 5 projects. |
| `php82` | PHP 8.2 | `phalcon59` | Compatibility pin for older Phalcon 5 projects. |
| `php83` | PHP 8.3 | `phalcon59` | Compatibility pin for older Phalcon 5 projects. |
| `php84` | PHP 8.4 | `phalcon59` | Compatibility pin for older Phalcon 5 projects. |
| `php85` | PHP 8.5 | `phalcon516` or newer | Jump straight to Phalcon 5.16.0 or a newer vetted 5.16+ release. |

## Official CloudLinux Packages First

CloudLinux ships official Phalcon packages for many older combinations, for
example `alt-php72-phalcon3`, `alt-php72-phalcon4`, `alt-php73-phalcon3`,
`alt-php73-phalcon4`, `alt-php74-phalcon4`, and `alt-php74` through
`alt-php85` Phalcon 5 packages.

Use the official RPM when it satisfies the application. Use `cl-phalcon` when:

- CloudLinux does not package the needed combination, such as Phalcon 4 for
  PHP 8.0 transition installs.
- CloudLinux packages Phalcon 5 but the packaged version is not the application
  target. It may lag behind a newer target such as 5.16.0+, or it may have
  moved past the older 5.9.3 compatibility target.
- You need versioned selector modules beside the official selector option for a
  controlled migration.

Check the official package version before compiling a custom module:

```bash
dnf info alt-php85-phalcon5
rpm -qa | sort | grep -E '^alt-php[0-9]+-phalcon'
```

The custom modules still conflict with the official selector name `phalcon`, so
users cannot enable the official package and a custom Phalcon build at the same
time.

## Why Phalcon 5.9.3 Is Pinned

Phalcon 5.9.3 is intentional for many older projects. After that line, Phalcon
started changing framework behavior more aggressively, and applications aligned
with 5.9.3 may not be ready for a newer `phalcon5` RPM.

CloudLinux can provide an official `alt-phpXX-phalcon5` package and still not
be the right choice for those applications if the packaged version has moved
above 5.9.3. In that case, install `phalcon59` as a separate versioned selector
module, keep the official package available, and let PHP Selector conflicts
prevent both from being enabled at once.

## Why PHP 8.0 Is Special

PHP 8.0 is the transition slot:

- If an application still needs Phalcon 4 on PHP 8.0, use the `4.2.x` cphalcon
  branch.
- For PHP 7.2, 7.3, and 7.4 Phalcon 4 installs, use the `4.1.x` branch.
- After PHP 8.0, do not recommend Phalcon below 5.
- Phalcon 4 installs automatically write `extension=psr.so` before
  `extension=phalcon4.so`. See `docs/dependencies.md` for the dependency
  matrix and override examples.

## Example Commands

Individual scripts for each PHP slot are available in `examples/`:

```text
examples/install-php72.sh
examples/install-php73.sh
examples/install-php74.sh
examples/install-php80.sh
examples/install-php81.sh
examples/install-php82.sh
examples/install-php83.sh
examples/install-php84.sh
examples/install-php85.sh
```

Legacy PHP 7.2 and 7.3 apps:

```bash
# Prefer official alt-php72/73 Phalcon 3 and 4 packages when acceptable.
# Uncomment only when a custom upstream build is required.
# cl-phalcon install --php php72,php73 --phalcon 3.4.5 --git-ref v3.4.5 --module phalcon3 --yes
# cl-phalcon install --php php72,php73 --phalcon 4.1.x --git-ref 4.1.x --module phalcon4 --yes
```

PHP 7.4:

```bash
# Prefer official alt-php74-phalcon4 when acceptable.
# cl-phalcon install --php php74 --phalcon 4.1.x --git-ref 4.1.x --module phalcon4 --yes
cl-phalcon install --php php74 --phalcon 5.9.3 --module phalcon59 --yes
```

PHP 8.0 transition slot:

```bash
cl-phalcon install --php php80 --phalcon 4.2.x --git-ref 4.2.x --module phalcon4 --yes
cl-phalcon install --php php80 --phalcon 5.9.3 --module phalcon59 --yes
```

PHP 8.1 through 8.4:

```bash
cl-phalcon install --php php81,php82,php83,php84 --phalcon 5.9.3 --module phalcon59 --yes
```

PHP 8.5:

```bash
cl-phalcon install --php php85 --phalcon 5.16.0 --module phalcon516 --yes
```

Refresh selector conflicts and CageFS after installing the grid:

```bash
cl-phalcon conflicts
cl-phalcon cagefs-rebuild
cl-phalcon validate
```

## Maintenance Commands

After CloudLinux updates alt-php packages:

```bash
cl-phalcon rebuild-needed
cl-phalcon update --yes
```

When moving a managed slot to a newer Phalcon source version, use `upgrade`.
This installs the new versioned module and leaves the old module in place until
you explicitly remove it:

```bash
cl-phalcon upgrade --php php85 --phalcon 5.16.1 --module phalcon516 --yes
cl-phalcon validate --php php85 --module phalcon516
```

If a PHP slot has several managed modules and you want to upgrade only one
source module family, filter by the old module:

```bash
cl-phalcon upgrade \
  --php php85 \
  --from-module phalcon514 \
  --phalcon 5.16.1 \
  --module phalcon516 \
  --yes
```

Leaving the old module in place is intentional. It gives you a rollback path
through PHP Selector. Remove old modules only after applications have been
validated.
