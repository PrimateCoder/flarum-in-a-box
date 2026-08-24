# Flarum-in-a-Box: basic Flarum 1.x variant (local experiment, not built by CI).
#
# Minimal install: flarum/flarum ^1.8 scaffold with its bundled extensions,
# no community extensions, no seed content. PHP 8.3 because Flarum 1.x's
# dependencies (illuminate 8.x) are not clean on newer PHP — they emit
# deprecation notices into HTTP output ("headers already sent").
#
# Reuses nginx.conf + s6 service definitions from src/box/.

# ═══════════════════════════════════════════════════════════════════════
# Stage 1: Builder — compile PHP extensions, install Flarum 1.x
# ═══════════════════════════════════════════════════════════════════════
FROM php:8.3-fpm-alpine AS builder

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

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        gd \
        zip \
        intl \
        exif

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
RUN composer create-project flarum/flarum:^1.8 . \
        --stability=stable \
        --prefer-dist \
        --no-interaction \
        --no-dev \
    && composer clear-cache

# ═══════════════════════════════════════════════════════════════════════
# Stage 2: Runtime
# ═══════════════════════════════════════════════════════════════════════
FROM php:8.3-fpm-alpine

LABEL org.opencontainers.image.title="Flarum-in-a-Box (Flarum 1.x)"
LABEL org.opencontainers.image.description="Basic Flarum 1.8 demo container with MariaDB and nginx"

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions pdo_mysql gd zip intl exif

RUN apk add --no-cache \
        nginx \
        mariadb \
        mariadb-client \
        curl \
        s6-overlay

COPY --from=builder /var/www/html /var/www/html

RUN mkdir -p /run/nginx
COPY src/box/nginx.conf /etc/nginx/http.d/default.conf

COPY src/box/s6-rc.d/ /etc/s6-overlay/s6-rc.d/

COPY local/flarum1/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld \
    && echo "pdo_mysql.default_socket = /run/mysqld/mysqld.sock" > /usr/local/etc/php/conf.d/mariadb-socket.ini \
    && echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/flarum-memory.ini \
    && echo "display_errors = Off" > /usr/local/etc/php/conf.d/flarum-display-errors.ini \
    && echo "log_errors = On" > /usr/local/etc/php/conf.d/flarum-log-errors.ini

COPY local/flarum1/install.yaml /tmp/install.yaml
COPY local/flarum1/config.php /tmp/config.php

# ── Build-time setup: fresh DB, bare Flarum install ───────────────────
RUN set -e \
    && mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1 \
    && mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld \
    && mariadbd-safe & \
    for i in $(seq 1 30); do mariadb-admin ping --silent 2>/dev/null && break; sleep 1; done \
    && mariadb -u root -e "CREATE DATABASE flarum;" \
    && mariadb -u root -e "GRANT ALL ON flarum.* TO 'flarum'@'localhost' IDENTIFIED BY 'flarum'; FLUSH PRIVILEGES;" \
    && cd /var/www/html \
    && php flarum install --file=/tmp/install.yaml \
    && mkdir -p storage/.composer public/assets \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage public/assets \
    && mariadb -u root -e "SET GLOBAL innodb_fast_shutdown = 0;" \
    && mariadb-admin shutdown 2>/dev/null || true \
    && for i in $(seq 1 30); do pidof mariadbd >/dev/null 2>&1 || break; sleep 1; done \
    && rm -f /tmp/install.yaml /tmp/config.php

COPY --chown=www-data:www-data --chmod=644 local/flarum1/config.php /var/www/html/config.php

EXPOSE 80

ENV FLARUM_FORUM_URL=""

ENTRYPOINT ["entrypoint.sh"]
CMD ["/init"]
