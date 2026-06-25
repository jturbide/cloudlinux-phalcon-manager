#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 8.0 is the transition slot: Phalcon 4 must come from 4.2.x.
# CloudLinux provides official alt-php80 Phalcon 5, but not the Phalcon 4
# transition build. Keep custom Phalcon 5.9.3 when the app is pinned to that
# framework behavior and the RPM has moved past it.

cl-phalcon install \
  --php php80 \
  --phalcon 4.2.x \
  --git-ref 4.2.x \
  --module phalcon42 \
  --yes

cl-phalcon install \
  --php php80 \
  --phalcon 5.9.3 \
  --module phalcon59 \
  --yes

cl-phalcon validate --php php80
