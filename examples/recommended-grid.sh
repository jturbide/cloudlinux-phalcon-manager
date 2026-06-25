#!/usr/bin/env bash
set -Eeuo pipefail

# Recommended CloudLinux alt-php / Phalcon grid.
# Review before running on a production server.

# PHP 7.2 / 7.3: legacy Phalcon 3 plus Phalcon 4 from 4.1.x.
cl-phalcon install --php php72,php73 --phalcon 3.4.5 --git-ref v3.4.5 --module phalcon3 --yes
cl-phalcon install --php php72,php73 --phalcon 4.1.x --git-ref 4.1.x --module phalcon4 --yes

# PHP 7.4: Phalcon 4 from 4.1.x plus Phalcon 5.9.3.
cl-phalcon install --php php74 --phalcon 4.1.x --git-ref 4.1.x --module phalcon4 --yes
cl-phalcon install --php php74 --phalcon 5.9.3 --module phalcon59 --yes

# PHP 8.0 transition: Phalcon 4 must use 4.2.x; Phalcon 5.9.3 is recommended.
cl-phalcon install --php php80 --phalcon 4.2.x --git-ref 4.2.x --module phalcon4 --yes
cl-phalcon install --php php80 --phalcon 5.9.3 --module phalcon59 --yes

# PHP 8.1 through 8.4: Phalcon 5.9.3.
cl-phalcon install --php php81,php82,php83,php84 --phalcon 5.9.3 --module phalcon59 --yes

# PHP 8.5: Phalcon 5.16.0 or a newer vetted 5.16+ release.
cl-phalcon install --php php85 --phalcon 5.16.0 --module phalcon516 --yes

cl-phalcon conflicts
cl-phalcon cagefs-rebuild
cl-phalcon validate
