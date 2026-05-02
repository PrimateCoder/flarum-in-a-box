#!/bin/sh
set -e

# ── Override forum URL if specified via environment variable ─────────
FLARUM_FORUM_URL="${FLARUM_FORUM_URL:-http://localhost:8080}"

if [ -f /var/www/html/config.php ]; then
    CURRENT_URL=$(php -r "\$c = require('/var/www/html/config.php'); echo \$c['url'] ?? '';")
    if [ "$CURRENT_URL" != "$FLARUM_FORUM_URL" ]; then
        echo "==> Updating forum URL to ${FLARUM_FORUM_URL}"
        # Escape sed-special chars (&, \, |) to safely embed URL in replacement
        ESCAPED_URL=$(echo "$FLARUM_FORUM_URL" | sed 's/[&\\|]/\\&/g')
        sed -i "s|'url' => '.*'|'url' => '${ESCAPED_URL}'|" /var/www/html/config.php
    fi
fi

# ── Ensure MariaDB runtime directory exists ──────────────────────────
mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         Flarum-in-a-Box is ready!            ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  URL:      ${FLARUM_FORUM_URL}"
echo "║  Admin:    admin / password"
echo "║  User:     user / password"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Hand off to supervisord ──────────────────────────────────────────
exec "$@"
