# Changelog

All notable changes to Flarum-In-A-Box are documented here.

## 0.2.5

### Fixed
- Extension Manager now has the write access it needs on `composer.json`, `composer.lock`, `vendor/`, `storage/`, and `storage/.composer`.

## 0.2.4

### Fixed
- Sporadic 500 errors on the front page caused by PHP-FPM running out of memory when compiling LESS (Avocado + ~40 extensions). Bumped `memory_limit` from 128M to 512M.

## 0.2.3

### Added
- `forumaker/profile-cover` (replaces `sycho/flarum-profile-cover`) — adds GIF/WebP support and improved thumbnails
- `forumaker/magicslider`, `forumaker/magicbb` — enabled by default
- `forumaker/magicread`, `forumaker/yandex-oauth`, `forumaker/yandex-smartcaptcha`, `fof/oauth` — installed but not enabled
- `justoverclock/flarum-ext-welcomebox` — installed but not enabled
- `ralkage/flarum-ext-profile-messages` — enabled by default

## 0.2.2

### Added
- `linkrobins/auto-verify` — enabled by default; replaces the MariaDB trigger we used to skip email confirmation
- `linkrobins/font-sizer` — installed but not enabled

## 0.2.1

### Changed
- **Major rewrite: setup moved from runtime entrypoint to build time.**
- **First boot is now ~8 seconds** (previously ~45+ seconds)

## 0.2.0

### Added
- Initial release: all-in-one Docker container with Flarum 2.x, ~50 extensions, MariaDB, and Nginx