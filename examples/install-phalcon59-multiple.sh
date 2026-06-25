#!/usr/bin/env bash
set -Eeuo pipefail

# Install Phalcon 5.9.3 as a compatibility pin for older projects that are not
# ready for newer Phalcon 5 framework changes.

cl-phalcon install \
  --php php82,php83,php84 \
  --phalcon 5.9.3 \
  --yes
