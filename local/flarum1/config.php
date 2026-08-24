<?php

/*
 * Flarum-In-A-Box configuration (Flarum 1.x variant).
 *
 * Same dynamic URL detection as src/box/config.php, but with the
 * `mysql` driver that Flarum 1.x expects and without the queue
 * config section introduced in Flarum 2.x.
 */
return [
    'debug' => false,
    'database' => [
        'driver' => 'mysql',
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
];
