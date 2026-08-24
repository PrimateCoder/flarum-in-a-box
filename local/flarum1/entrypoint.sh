#!/bin/sh

set -e

mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Flarum-in-a-Box (Flarum 1.x) is ready!"
echo "╠══════════════════════════════════════════════╣"
echo "║  URL:      ${FLARUM_FORUM_URL:-http://localhost:8080}"
echo "║  Admin:    admin / password"
echo "╚══════════════════════════════════════════════╝"
echo ""

exec "$@"
