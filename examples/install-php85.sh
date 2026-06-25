#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 8.5 should jump straight to Phalcon 5.16.0 or a newer vetted 5.16+ release.

cl-phalcon install \
  --php php85 \
  --phalcon 5.16.0 \
  --module phalcon516 \
  --yes

cl-phalcon validate --php php85 --module phalcon516
