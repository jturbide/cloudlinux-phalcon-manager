#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 7.4 usually needs Phalcon 4 from 4.1.x and the pinned Phalcon 5.9.3
# compatibility module.
# CloudLinux provides official alt-php74 Phalcon 4/5 RPMs. Use this custom
# example when the official package version is missing, too old, or newer than
# the app's 5.9.3 compatibility target.

cl-phalcon install \
  --php php74 \
  --phalcon 4.1.x \
  --git-ref 4.1.x \
  --module phalcon41 \
  --yes

cl-phalcon install \
  --php php74 \
  --phalcon 5.9.3 \
  --module phalcon59 \
  --yes

cl-phalcon validate --php php74
