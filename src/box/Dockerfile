# This file is part of pianotell/flarum-in-a-box.
#
# Copyright (c) 2026 Navindra Umanee
#
# LICENSE: For the full copyright and license information,
# please view the LICENSE file that was distributed
# with this source code.

# Flarum-in-a-Box: All-in-one Docker container
# Bundles Flarum 2.x + MariaDB + nginx + PHP-FPM in a minimal Alpine image.
#
# Multi-stage build: builder stage compiles PHP extensions and installs
# Flarum + extensions via Composer; final stage has only runtime deps.

# ═══════════════════════════════════════════════════════════════════════
# Stage 1: Builder — compile PHP extensions, install Flarum + extensions
# ═══════════════════════════════════════════════════════════════════════
FROM php:8.5-fpm-alpine AS builder

# Build dependencies (only in builder stage, discarded in final image)
RUN apk add --no-cache \
        $PHPIZE_DEPS \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libzip-dev \
        icu-dev \
        unzip \
        git \
        curl

# Compile PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        gd \
        zip \
        intl \
        exif

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install Flarum + extensions in one shot.
#
#   1. `composer create-project flarum/flarum --no-install` scaffolds the
#      project structure (config files, public/index.php, etc.) without
#      pulling any deps.
#   2. We replace the generated composer.json with our hand-managed
#      template (src/box/composer.json.TEMPLATE) listing every package we
#      want — both core flarum/* extensions and the community ones.
#   3. A single `composer install` resolves all deps at once. This gives
#      composer the full picture for conflict resolution and is much
#      faster than ~50 sequential `composer require` calls.
#
# Trade-off: a single broken extension fails the whole build (vs the old
# loop that skipped failures). When that happens, move the offender into
# the composer.json.TEMPLATE "_disabled-require" parking lot and rebuild.
WORKDIR /var/www/html
RUN composer create-project flarum/flarum:^2.0 . \
        --stability=beta \
        --prefer-dist \
        --no-interaction \
        --no-dev \
        --no-install
COPY src/box/composer.json.TEMPLATE composer.json
RUN composer install --prefer-dist --no-dev --optimize-autoloader \
    && composer clear-cache

# ═══════════════════════════════════════════════════════════════════════
# Stage 2: Runtime — minimal image with only what's needed to run
# ═══════════════════════════════════════════════════════════════════════
FROM php:8.5-fpm-alpine

LABEL org.opencontainers.image.title="Flarum-in-a-Box"
LABEL org.opencontainers.image.description="All-in-one Flarum 2.x demo container with 80+ extensions"
LABEL org.opencontainers.image.source="https://github.com/PrimateCoder/flarum-in-a-box"

# Install PHP extensions using pre-built binaries (auto-cleans build deps)
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions pdo_mysql gd zip intl exif

# Runtime dependencies (no python — using s6-overlay instead of supervisord)
RUN apk add --no-cache \
        nginx \
        mariadb \
        mariadb-client \
        curl \
        s6-overlay

# Copy Flarum application from builder
COPY --from=builder /var/www/html /var/www/html

# Copy Composer (needed for Extension Manager at runtime)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# ── nginx configuration ──────────────────────────────────────────────
RUN mkdir -p /run/nginx
COPY src/box/nginx.conf /etc/nginx/http.d/default.conf

# ── s6-overlay service definitions ───────────────────────────────────
COPY src/box/s6-rc.d/ /etc/s6-overlay/s6-rc.d/

# ── Entrypoint script (URL override, then chains to s6-overlay /init) ─
COPY src/box/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── MariaDB socket + PHP memory config ────────────────────────────────
RUN mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld \
    && echo "pdo_mysql.default_socket = /run/mysqld/mysqld.sock" > /usr/local/etc/php/conf.d/mariadb-socket.ini \
    && echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/flarum-memory.ini

# ── Build-time setup: install Flarum, enable extensions, seed content ─
# This runs MariaDB temporarily during build to pre-populate everything.
# Content (extension list, settings, tags, sample discussions) lives under
# src/box/data/. PHP helpers under src/box/scripts/ import the data via
# prepared statements / Flarum's HTTP API. setup.sh is the orchestrator.
# Everything in /tmp/data and /tmp/scripts is removed at the end of setup.sh.
COPY src/box/data /tmp/data
COPY src/box/scripts /tmp/scripts
COPY src/box/setup.sh /tmp/setup.sh
RUN chmod +x /tmp/setup.sh && /tmp/setup.sh && rm -rf /tmp/setup.sh /tmp/data /tmp/scripts

# Overwrite install's static config.php with our version — same DB credentials
# but with a dynamic url closure (see src/box/config.php for details).
COPY --chown=www-data:www-data --chmod=644 src/box/config.php /var/www/html/config.php

# ── Ports ─────────────────────────────────────────────────────────────
EXPOSE 80

# ── Configurable env vars (advertised via image metadata) ────────────
# Forum URL is auto-detected per-request from $_SERVER. Override here to pin
# a specific URL (useful behind reverse proxies, when serving from a path,
# or to harden against spoofed Host headers).
ENV FLARUM_FORUM_URL=""

# ── Entrypoint & command ─────────────────────────────────────────────
# entrypoint.sh prints a banner, then exec's /init (s6-overlay).
ENTRYPOINT ["entrypoint.sh"]
CMD ["/init"]
