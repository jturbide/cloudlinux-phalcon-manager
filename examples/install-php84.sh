#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 8.4 uses Phalcon 5.9.3 here as a compatibility pin for older projects.

cl-phalcon install \
  --php php84 \
  --phalcon 5.9.3 \
  --module phalcon59 \
  --yes

cl-phalcon validate --php php84 --module phalcon59
