#!/bin/sh
#
# This file is part of pianotell/flarum-in-a-box.
#
# Copyright (c) 2026 Navindra Umanee
#
# LICENSE: For the full copyright and license information,
# please view the LICENSE file that was distributed
# with this source code.

set -e

# ── Ensure MariaDB runtime directory exists ──────────────────────────
mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld

# Forum URL is auto-detected per request from $_SERVER (see config.php).
# Set FLARUM_FORUM_URL to pin a specific URL (useful behind reverse proxies
# or when you want absolute links to point somewhere other than the request host).
DISPLAY_URL="${FLARUM_FORUM_URL:-http://localhost:8080  (auto-detects from request)}"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         Flarum-in-a-Box is ready!"
echo "╠══════════════════════════════════════════════╣"
echo "║  URL:      ${DISPLAY_URL}"
echo "║  Admin:    admin / password"
echo "║  User:     user / password"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Hand off to s6-overlay /init ─────────────────────────────────────
exec "$@"
