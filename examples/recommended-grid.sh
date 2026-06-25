#!/usr/bin/env bash
set -Eeuo pipefail

# Recommended CloudLinux alt-php / Phalcon grid.
# Review before running on a production server.
#
# Prefer official CloudLinux RPMs when they already satisfy the application.
# Use this script for upstream versions that are missing, newer than the RPM, or
# intentionally pinned below the RPM for application compatibility.

# PHP 7.2 / 7.3: legacy Phalcon 3 plus Phalcon 4 from 4.1.x.
# CloudLinux provides alt-php72/73 phalcon3 and phalcon4 packages, so these
# custom builds are disabled by default.
# Uncomment only when you need a specific upstream build instead of the official
# package.
# cl-phalcon install --php php72,php73 --phalcon 3.4.5 --git-ref v3.4.5 --module phalcon3 --yes
# cl-phalcon install --php php72,php73 --phalcon 4.1.x --git-ref 4.1.x --module phalcon41 --yes

# PHP 7.4: Phalcon 4 from 4.1.x plus the pinned Phalcon 5.9.3 compatibility module.
# CloudLinux provides alt-php74-phalcon4, so only build custom Phalcon 4 when
# the official package is not acceptable for that host.
# cl-phalcon install --php php74 --phalcon 4.1.x --git-ref 4.1.x --module phalcon41 --yes
cl-phalcon install --php php74 --phalcon 5.9.3 --module phalcon59 --yes

# PHP 8.0 transition: Phalcon 4 must use 4.2.x; Phalcon 5.9.3 is pinned for older projects.
cl-phalcon install --php php80 --phalcon 4.2.x --git-ref 4.2.x --module phalcon42 --yes
cl-phalcon install --php php80 --phalcon 5.9.3 --module phalcon59 --yes

# PHP 8.1 through 8.4: Phalcon 5.9.3 compatibility pin.
cl-phalcon install --php php81,php82,php83,php84 --phalcon 5.9.3 --module phalcon59 --yes

# PHP 8.5: Phalcon 5.16.0 or a newer vetted 5.16+ release.
cl-phalcon install --php php85 --phalcon 5.16.0 --module phalcon516 --yes

cl-phalcon conflicts
cl-phalcon cagefs-rebuild
cl-phalcon validate
