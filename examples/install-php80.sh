#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 8.0 is the transition slot: Phalcon 4 must come from 4.2.x.

cl-phalcon install \
  --php php80 \
  --phalcon 4.2.x \
  --git-ref 4.2.x \
  --module phalcon4 \
  --yes

cl-phalcon install \
  --php php80 \
  --phalcon 5.9.3 \
  --module phalcon59 \
  --yes

cl-phalcon validate --php php80
