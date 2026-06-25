# Architecture

`cl-phalcon` is intentionally a Bash tool with small source files rather than a
framework. CloudLinux/cPanel servers already provide the important PHP build
tools, and the risky operations are filesystem operations that are easier to
audit when they are explicit shell commands.

## Paths

Production defaults:

```text
/opt/alt
/var/lib/cloudlinux-phalcon-manager/installs.json
/var/log/cloudlinux-phalcon-manager.log
/usr/local/src/cloudlinux-phalcon-manager/src
/usr/local/src/cloudlinux-phalcon-manager/build
/usr/local/src/cloudlinux-phalcon-manager/cache
/etc/cl.selector/php.extensions.conflicts
```

Tests and dry runs can override those paths with:

```text
CLP_ROOT
CLP_OPT_ALT
CLP_SELECTOR_CONFLICTS
CLP_STATE_DIR
CLP_LOG_FILE
```

## Install Flow

1. Detect the target `phpXX` slot from `php-config`.
2. Read ABI/build metadata from the matching alt-php binary.
3. Prepare a cphalcon source checkout for the requested tag or branch.
4. Build inside a tool-owned staging directory with `phpize`, `configure`, and
   `make`.
5. Copy the staged `modules/phalcon.so` from the build workspace.
6. Back up an existing module or ini file if present.
7. Atomically install the versioned module name.
8. Write the PHP Selector ini file.
9. Persist metadata.
10. Rewrite the managed conflicts block.
11. Run `cagefsctl --rebuild-alt-php-ini`.

The tool never treats a compiled module for one `phpXX` slot as reusable for
another slot.

## Build Safety

The manual baseline for this project uses cphalcon's `build/install` script.
That script is useful because it selects the generated `build/phalcon` extension
source and builds it with the requested `phpize` and `php-config`.

For production safety, `cl-phalcon` intentionally avoids the final `make
install` step from that script. It performs the equivalent build steps inside an
isolated workspace:

```bash
phpize
./configure --with-php-config=/opt/alt/phpXX/usr/bin/php-config --enable-phalcon
make
```

Then it copies `modules/phalcon.so` into the requested versioned module name.
This avoids overwriting CloudLinux's official `phalcon.so` or another unmanaged
module during compilation.
