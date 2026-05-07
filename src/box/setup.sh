#!/bin/sh
#
# This file is part of pianotell/flarum-in-a-box.
#
# Copyright (c) 2026 Navindra Umanee
#
# LICENSE: For the full copyright and license information,
# please view the LICENSE file that was distributed
# with this source code.

# Build-time setup orchestrator. Pre-populates MariaDB and configures Flarum
# so the container starts instantly at runtime.
#
# Content lives in /tmp/data/ — extension list, install YAML, settings/tags/
# group-permissions TSVs, and sample discussions. PHP helpers in /tmp/scripts/
# do the actual data import via PDO prepared statements + Flarum's HTTP API.
# This script is just the orchestrator: ~80 lines of glue, not data.
set -e

DATA=/tmp/data
SCRIPTS=/tmp/scripts

# ── Bring up a temporary MariaDB ──────────────────────────────────────
echo "==> Initializing MariaDB data directory..."
mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld

echo "==> Starting MariaDB..."
mariadbd-safe &
for i in $(seq 1 30); do
    if mariadb-admin ping --silent 2>/dev/null; then break; fi
    if [ "$i" -eq 30 ]; then echo "ERROR: MariaDB failed to start"; exit 1; fi
    sleep 1
done
echo "    MariaDB is ready."

mariadb -u root -e "CREATE DATABASE flarum;"
mariadb -u root -e "GRANT ALL ON flarum.* TO 'flarum'@'localhost' IDENTIFIED BY 'flarum'; FLUSH PRIVILEGES;"

# ── Install Flarum ───────────────────────────────────────────────────
cd /var/www/html
php flarum install --file="$DATA/install.yaml"
# (config.php is overwritten by the Dockerfile after this script finishes —
# our shipped src/box/config.php has dynamic URL detection.)

# ── Enable extensions ────────────────────────────────────────────────
echo "==> Enabling extensions..."
while IFS= read -r line; do
    # strip comments and trim
    ext=$(echo "$line" | sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//')
    [ -z "$ext" ] && continue
    echo "    enabling $ext ..."
    php flarum extension:enable "$ext" 2>&1 \
        || echo "    ⚠ could not enable $ext"
done < "$DATA/extensions.txt"

# ── Bulk-import settings, tags, group permissions ────────────────────
echo "==> Importing settings..."
php "$SCRIPTS/import-tabular.php" settings           "$DATA/settings.tsv"
echo "==> Importing tags..."
php "$SCRIPTS/import-tabular.php" tags               "$DATA/tags.tsv"
echo "==> Importing group permissions..."
php "$SCRIPTS/import-tabular.php" group-permissions  "$DATA/group-permissions.tsv"

# ── Fix file permissions BEFORE starting web server ──────────────────
# Some extensions (fof/rich-text) install files with restrictive perms
# that prevent www-data from reading them. Must fix before starting nginx.
# Extension Manager also needs write access on composer.json, composer.lock,
# vendor/, storage/, and storage/.composer.
echo "==> Fixing file permissions (recursive on vendor — may take ~30s)..."
mkdir -p /var/www/html/storage/.composer
chown -R www-data:www-data \
    /var/www/html/config.php \
    /var/www/html/composer.json \
    /var/www/html/composer.lock \
    /var/www/html/vendor \
    /var/www/html/storage \
    /var/www/html/public/assets
chmod -R 775 /var/www/html/storage /var/www/html/public/assets
find /var/www/html/vendor -type d ! -perm -755 -exec chmod 755 {} \; 2>/dev/null

# ── Seed sample discussions + user via local HTTP API ────────────────
# Phase 1 keeps the start-nginx-during-build dance; Phase 2 will replace
# this with in-process JSON:API dispatch and remove all of these lines.
echo "==> Seeding demo content..."
mariadb -u root flarum -e "
    INSERT INTO flarum_api_keys (id, \`key\`, user_id, created_at)
    VALUES (1, 'build-seed-token', 1, NOW());
"

echo "    starting PHP-FPM and nginx..."
php-fpm --daemonize
nginx
echo "    waiting for HTTP..."
for i in $(seq 1 30); do
    code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80 2>&1)
    if [ "$code" = "200" ]; then break; fi
    if [ "$i" -eq 30 ]; then echo "    ERROR: HTTP not ready after 30s. Last code: $code"; exit 1; fi
    sleep 1
done
echo "    HTTP ready."

php "$SCRIPTS/seed-discussions.php" "$DATA" "http://127.0.0.1:80/api" "build-seed-token"

# ── Tear down nginx + PHP-FPM, drop the build-time API token ─────────
mariadb -u root flarum -e "DELETE FROM flarum_api_keys WHERE id = 1;"
nginx -s stop 2>/dev/null || true
kill $(pidof php-fpm) 2>/dev/null || true
for i in $(seq 1 10); do
    if ! pidof nginx > /dev/null 2>&1 && ! pidof php-fpm > /dev/null 2>&1; then break; fi
    sleep 1
done

# ── Re-fix permissions (API may have created root-owned files) ───────
echo "==> Final permission sweep on vendor (recursive — may take ~30s)..."
chown -R www-data:www-data \
    /var/www/html/config.php \
    /var/www/html/composer.json \
    /var/www/html/composer.lock \
    /var/www/html/vendor \
    /var/www/html/storage \
    /var/www/html/public/assets
chmod -R 775 /var/www/html/storage /var/www/html/public/assets
find /var/www/html/vendor -type d ! -perm -755 -exec chmod 755 {} \; 2>/dev/null

# ── Shut down MariaDB cleanly (flush all InnoDB data to disk) ────────
echo "==> Flushing and shutting down MariaDB..."
mariadb -u root -e "SET GLOBAL innodb_fast_shutdown = 0;"
mariadb -u root -e "FLUSH TABLES;"
mariadb-admin shutdown 2>/dev/null || true
for i in $(seq 1 30); do
    if ! pidof mariadbd > /dev/null 2>&1; then break; fi
    sleep 1
done

echo "==> Build-time setup complete!"
