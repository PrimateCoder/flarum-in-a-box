<?php
/*
 * Flarum-In-A-Box configuration.
 *
 * This file replaces the one written by `php flarum install`. The only
 * meaningful difference is that `url` is computed dynamically per request:
 *
 *   1. If FLARUM_FORUM_URL is set, use it (e.g. behind a reverse proxy
 *      where the request Host doesn't match the public URL).
 *   2. Otherwise build proto://host from the request, honoring
 *      X-Forwarded-Proto / X-Forwarded-Host for proxied setups.
 *   3. Fall back to http://localhost:8080 for CLI commands and any
 *      non-HTTP context.
 *
 * config.php is require()d once per request, so the closure runs fresh
 * each time and Flarum sees the right URL no matter which host:port is
 * mapped to the container.
 */
return [
    'debug' => false,
    'database' => [
        'driver' => 'mariadb',
        'host' => 'localhost',
        'port' => 3306,
        'database' => 'flarum',
        'username' => 'flarum',
        'password' => 'flarum',
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => 'flarum_',
        'prefix_indexes' => true,
        'engine' => 'InnoDB',
        'strict' => false,
    ],
    'url' => (function () {
        $env = getenv('FLARUM_FORUM_URL');
        if ($env !== false && $env !== '') {
            return $env;
        }
        if (PHP_SAPI === 'cli' || empty($_SERVER['HTTP_HOST'])) {
            return 'http://localhost:8080';
        }
        $proto = $_SERVER['HTTP_X_FORWARDED_PROTO']
              ?? ((($_SERVER['HTTPS'] ?? '') === 'on') ? 'https' : 'http');
        $host = $_SERVER['HTTP_X_FORWARDED_HOST'] ?? $_SERVER['HTTP_HOST'];
        return $proto . '://' . $host;
    })(),
    'paths' => [
        'api' => 'api',
        'admin' => 'admin',
    ],
    'headers' => [
        'poweredByHeader' => true,
        'referrerPolicy' => 'same-origin',
    ],
    'queue' => [
        'driver' => 'sync',
    ],
];
