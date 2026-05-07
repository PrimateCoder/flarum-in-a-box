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

# Install Flarum
WORKDIR /var/www/html
RUN composer create-project flarum/flarum:^2.0 /var/www/html \
        --stability=beta \
        --prefer-dist \
        --no-interaction \
        --no-dev

# Allow dev/beta extensions
RUN composer config minimum-stability dev \
    && composer config prefer-stable true

# Install extensions one-by-one (failures skipped gracefully)
RUN set -e; \
    EXTENSIONS=" \
        flarum/extension-manager \
        flarum/nicknames \
        pianotell/flarum-ext-flamoji \
        fof/best-answer \
        fof/byobu \
        fof/drafts \
        fof/follow-tags \
        fof/formatting \
        fof/polls \
        fof/upload \
        fof/user-bio \
        fof/user-directory \
        fof/ignore-users \
        fof/linguist \
        fof/categories \
        fof/links \
        fof/pages \
        fof/sitemap \
        fof/frontpage \
        fof/gamification \
        fof/moderator-notes \
        fof/terms \
        fof/anti-spam \
        fof/reactions \
        fof/share-social \
        fof/synopsis \
        fof/discussion-thumbnail \
        fof/impersonate \
        fof/split \
        fof/merge-discussions \
        fof/bbcode-details \
        fof/discussion-views \
        antoinefr/flarum-ext-bbcode-fa \
        fof/move-posts \
        forumaker/profile-cover \
        forumaker/magicslider \
        forumaker/magicbb \
        forumaker/magicread \
        forumaker/yandex-oauth \
        forumaker/yandex-smartcaptcha \
        fof/oauth \
        acpl/mobile-tab \
        justoverclock/flarum-ext-welcomebox \
        ralkage/flarum-ext-profile-messages \
        ramon/avocado \
        ramon/colored \
        ekumanov/flarum-ext-post-search \
        ekumanov/flarum-ext-forum-widgets \
        ekumanov/flarum-ext-markdown-tables \
        ekumanov/flarum-ext-inline-audio \
        tryhackx/flarum-topic-rating \
        fof/rich-text \
        huseyinfiliz/modern-footer \
        huseyinfiliz/stickiest \
        huseyinfiliz/flarum-diff \
        linkrobins/auto-verify \
        linkrobins/font-sizer \
    "; \
    for ext in $EXTENSIONS; do \
        echo "==> Installing $ext ..."; \
        composer require "$ext" --no-interaction --prefer-dist --update-no-dev 2>&1 \
            && echo "    ✓ $ext installed" \
            || echo "    ✗ $ext skipped (not compatible)"; \
    done

# Clean up Composer cache in builder
RUN rm -rf /root/.composer/cache

# ═══════════════════════════════════════════════════════════════════════
# Stage 2: Runtime — minimal image with only what's needed to run
# ═══════════════════════════════════════════════════════════════════════
FROM php:8.5-fpm-alpine

LABEL org.opencontainers.image.title="Flarum-in-a-Box"
LABEL org.opencontainers.image.description="All-in-one Flarum 2.x demo container with ~50 extensions"
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
