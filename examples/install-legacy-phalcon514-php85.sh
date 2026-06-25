#!/usr/bin/env bash
set -Eeuo pipefail

# Legacy/custom example only.
# The recommended PHP 8.5 target is Phalcon 5.16.0+ via install-php85.sh.

cl-phalcon install \
  --php php85 \
  --phalcon 5.14.2 \
  --module phalcon514 \
  --yes
