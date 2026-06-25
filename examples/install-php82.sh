#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 8.2 should use Phalcon 5.9.3 in this compatibility grid.

cl-phalcon install \
  --php php82 \
  --phalcon 5.9.3 \
  --module phalcon59 \
  --yes

cl-phalcon validate --php php82 --module phalcon59
