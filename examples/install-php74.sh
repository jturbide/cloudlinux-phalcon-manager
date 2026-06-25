#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 7.4 usually needs Phalcon 4 from 4.1.x and Phalcon 5.9.3.

cl-phalcon install \
  --php php74 \
  --phalcon 4.1.x \
  --git-ref 4.1.x \
  --module phalcon4 \
  --yes

cl-phalcon install \
  --php php74 \
  --phalcon 5.9.3 \
  --module phalcon59 \
  --yes

cl-phalcon validate --php php74
