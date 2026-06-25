#!/usr/bin/env bash
set -Eeuo pipefail

cl-phalcon install \
  --php php82,php83,php84 \
  --phalcon 5.9.3 \
  --yes
