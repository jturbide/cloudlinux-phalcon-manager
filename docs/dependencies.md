# Phalcon INI Dependencies

`cl-phalcon` distinguishes between upstream build dependencies and PHP Selector
INI load-order dependencies.

Build dependencies are discovered by cphalcon during compilation. INI
dependencies are extension lines that must be loaded before the managed
`phalcon*.so` module in the generated PHP Selector ini file.

## Default INI Rules

| Phalcon line | Default INI dependencies | Reason |
| --- | --- | --- |
| Phalcon 3.x | none | Upstream build config checks JSON and PCRE, but no PSR runtime note is present in the 3.4 README. |
| Phalcon 4.1.x | `psr,pdo` | Upstream Phalcon 4 README says the PSR PHP extension must be installed and enabled; CloudLinux-built modules can also require PDO at load time. |
| Phalcon 4.2.x | `psr,pdo` | Same Phalcon 4 runtime requirement; use this branch for PHP 8.0 transition installs. |
| Phalcon 5.x | `pdo` | A production CloudLinux Phalcon 5.16 module reported `required module "pdo" is not loaded` when loaded with isolated `php -n`. |

Generated Phalcon 4 ini example:

```ini
; Managed by cloudlinux-phalcon-manager. Do not edit by hand.
extension=psr.so
extension=pdo.so
extension=phalcon4.so
```

Generated Phalcon 5 ini example:

```ini
; Managed by cloudlinux-phalcon-manager. Do not edit by hand.
extension=pdo.so
extension=phalcon516.so
```

## Why JSON Is Not A Default INI Dependency

Older manual runbooks often used:

```bash
--dependencies psr,pdo,json
```

That load order can still be requested explicitly, and it may be useful on a
legacy server where the application expects PDO and JSON to be loaded by the
same selector option.

The default now includes PDO for Phalcon 4 and 5 because production
CloudLinux-built modules can require it at extension-load time. JSON is still
not included by default because:

- JSON and PCRE are declared by cphalcon build config, but modern PHP often has
  them built in. Writing `extension=json.so` on a PHP where JSON is built in can
  create avoidable load warnings.
- The safest default is to write only dependencies observed as required at
  extension-load time or documented as required for that line.

## Override Examples

Use the default for a Phalcon 4 install:

```bash
cl-phalcon install --php php74 --phalcon 4.1.x --git-ref 4.1.x --module phalcon4 --yes
```

Force the older manual dependency order:

```bash
cl-phalcon install \
  --php php74 \
  --phalcon 4.1.x \
  --git-ref 4.1.x \
  --module phalcon4 \
  --dependencies psr,pdo,json \
  --yes
```

Disable automatic defaults when another server-owned ini already loads the
dependency:

```bash
cl-phalcon install \
  --php php74 \
  --phalcon 4.1.x \
  --git-ref 4.1.x \
  --module phalcon4 \
  --no-default-dependencies \
  --yes
```

Validation uses the stored `ini_dependencies` metadata and loads those
dependencies before the managed Phalcon module during isolated `php -n` checks.

## Upstream References Checked

- Phalcon 4.1.3 README:
  `https://raw.githubusercontent.com/phalcon/cphalcon/v4.1.3/README.md`
- Phalcon 4.2.x README:
  `https://raw.githubusercontent.com/phalcon/cphalcon/4.2.x/README.md`
- Phalcon build config samples:
  `https://raw.githubusercontent.com/phalcon/cphalcon/v3.4.5/build/_resource/config/config.m4`
  `https://raw.githubusercontent.com/phalcon/cphalcon/v4.1.3/build/_resource/config/config.m4`
  `https://raw.githubusercontent.com/phalcon/cphalcon/4.2.x/build/_resource/config/config.m4`
  `https://raw.githubusercontent.com/phalcon/cphalcon/v5.9.3/build/phalcon/config.m4`
  `https://raw.githubusercontent.com/phalcon/cphalcon/v5.16.0/build/phalcon/config.m4`
