#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 7.3 usually needs legacy Phalcon 3 and Phalcon 4 from the 4.1.x branch.

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
  --module phalcon4 \
  --yes

cl-phalcon validate --php php73
