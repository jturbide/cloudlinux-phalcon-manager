# Security Policy

`cl-phalcon` is a root-level server administration tool. Security issues should
be handled privately until a fix is available.

## Report a Vulnerability

Open a private security advisory on GitHub, or contact the project maintainer
privately with:

- affected command
- exact arguments used
- expected behavior
- observed behavior
- relevant filesystem paths
- whether `--dry-run` reproduces the issue

Do not include production secrets, customer data, or full server backups.

## Security Expectations

Security-sensitive areas include:

- path handling
- backup and replacement behavior
- conflict-file rewriting
- build directory cleanup
- root execution checks
- module ownership
- shell quoting
- environment overrides used by tests

Reports about arbitrary path deletion, command injection, unsafe ownership
changes, or overwriting CloudLinux official modules should be treated as high
priority.
