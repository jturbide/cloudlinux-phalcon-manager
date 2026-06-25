#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 7.3 usually needs legacy Phalcon 3 and Phalcon 4 from the 4.1.x branch.
# CloudLinux provides official alt-php73 Phalcon 3/4 RPMs. Run this custom
# build example only when the official package is not acceptable for the host.

cl-phalcon install \
  --php php73 \
  --phalcon 3.4.5 \
  --git-ref v3.4.5 \
  --module phalcon3 \
  --yes

cl-phalcon install \
  --php php73 \
  --phalcon 4.1.x \
  --git-ref 4.1.x \
  --module phalcon41 \
  --yes

cl-phalcon validate --php php73
