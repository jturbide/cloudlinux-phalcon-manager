#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 8.3 uses Phalcon 5.9.3 here as a compatibility pin for older projects.

cl-phalcon install \
  --php php83 \
  --phalcon 5.9.3 \
  --module phalcon59 \
  --yes

cl-phalcon validate --php php83 --module phalcon59
