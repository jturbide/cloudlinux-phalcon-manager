# Examples

These scripts are copy-paste friendly examples for common CloudLinux alt-php
slots. Review them before running on a production server.

Recommended individual-slot examples:

```text
install-php72.sh  PHP 7.2: Phalcon 3 and Phalcon 4 from 4.1.x
install-php73.sh  PHP 7.3: Phalcon 3 and Phalcon 4 from 4.1.x
install-php74.sh  PHP 7.4: Phalcon 4 from 4.1.x and Phalcon 5.9.3
install-php80.sh  PHP 8.0: Phalcon 4 from 4.2.x and Phalcon 5.9.3
install-php81.sh  PHP 8.1: Phalcon 5.9.3
install-php82.sh  PHP 8.2: Phalcon 5.9.3
install-php83.sh  PHP 8.3: Phalcon 5.9.3
install-php84.sh  PHP 8.4: Phalcon 5.9.3
install-php85.sh  PHP 8.5: Phalcon 5.16.0+
```

Full-grid example:

```text
recommended-grid.sh
```

Phalcon 4 examples rely on the tool's default `psr` INI dependency. See
`../docs/dependencies.md` before adding legacy `psr,pdo,json` load-order
overrides.

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
