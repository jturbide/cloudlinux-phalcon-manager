# Contributing

This project manages native PHP extensions on root-owned CloudLinux systems.
Changes should be small, auditable, and covered by mock-root tests where
possible.

## Local Checks

Run:

```bash
bash -n bin/cl-phalcon lib/*.sh
shellcheck bin/cl-phalcon lib/*.sh tests/*.bats examples/*.sh
bats tests
git diff --check
```

If Bats or ShellCheck are not installed locally, the GitHub Actions workflow
runs them on every push and pull request.

## Safety Rules

- Keep strict Bash mode.
- Quote variables.
- Do not add broad `rm -rf` behavior.
- Do not write outside tool-owned source/build/cache paths except for explicit
  module, ini, metadata, log, and conflicts operations.
- Back up existing modules, ini files, and conflicts files before replacing
  them.
- Keep operations testable through `CLP_ROOT` and the other `CLP_*` path
  overrides.
- Treat CloudLinux's official `phalcon` selector module as something to coexist
  with, not overwrite.

## Compatibility Docs

When adding or changing supported Phalcon/PHP combinations, update:

- `docs/compatibility-grid.md`
- `docs/real-world-examples.md`
- `examples/recommended-grid.sh`
- `README.md` if the main workflow changes
