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
| `php74` | PHP 7.4 | `phalcon4`, `phalcon59` | Phalcon 4 from `4.1.x`; Phalcon 5.9.3 for apps ready for Phalcon 5. |
| `php80` | PHP 8.0 | `phalcon4`, `phalcon59` | Transition slot. Phalcon 4 must come from `4.2.x`; earlier PHP slots use `4.1.x`. |
| `php81` | PHP 8.1 | `phalcon59` | Do not recommend Phalcon below 5 after PHP 8.0. |
| `php82` | PHP 8.2 | `phalcon59` | Recommended Phalcon 5 baseline. |
| `php83` | PHP 8.3 | `phalcon59` | Recommended Phalcon 5 baseline. |
| `php84` | PHP 8.4 | `phalcon59` | Recommended Phalcon 5 baseline. |
| `php85` | PHP 8.5 | `phalcon516` or newer | Jump straight to Phalcon 5.16.0 or a newer vetted 5.16+ release. |

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
cl-phalcon install --php php72,php73 --phalcon 3.4.5 --git-ref v3.4.5 --module phalcon3 --yes
cl-phalcon install --php php72,php73 --phalcon 4.1.x --git-ref 4.1.x --module phalcon4 --yes
```

PHP 7.4:

```bash
cl-phalcon install --php php74 --phalcon 4.1.x --git-ref 4.1.x --module phalcon4 --yes
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
