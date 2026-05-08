# Changelog

All notable changes to Flarum-In-A-Box are documented here.

## 0.2.9 — 2026-05-07

### Added
- 7 new extensions enabled by default:
  - [**Menu Control**](https://packagist.org/packages/resofire/menu-control) (`resofire/menu-control`)
  - [**Mobile Search**](https://packagist.org/packages/resofire/mobile-search) (`resofire/mobile-search`)
  - [**External Links in New Tab**](https://packagist.org/packages/walsgit/external-links-in-new-tab) (`walsgit/external-links-in-new-tab`)
  - [**Recycle Bin**](https://packagist.org/packages/walsgit/recycle-bin) (`walsgit/recycle-bin`)
  - [**Last Post Avatar**](https://packagist.org/packages/rob006/flarum-ext-last-post-avatar) (`rob006/flarum-ext-last-post-avatar`)
  - [**Profile Views**](https://packagist.org/packages/michaelbelgium/flarum-profile-views) (`michaelbelgium/flarum-profile-views`)
  - [**Log Viewer**](https://packagist.org/packages/ianm/log-viewer) (`ianm/log-viewer`)
- [**Discussion Cards**](https://packagist.org/packages/walsgit/flarum-discussion-cards) (`walsgit/flarum-discussion-cards`) installed but not enabled
- Moderator account (`moderator` / `password`) in the Mod group with standard permissions
- Sample members `user1`–`user5`
- 🛠️ Moderation Playground seed discussion — a heated debate among `user1`–`user5` so you can practice locking, hiding, suspending, etc. on real-looking content

## 0.2.8 — 2026-05-04

### Changed
- Auto-detect forum URL from request host (`FLARUM_FORUM_URL` still wins; honors `X-Forwarded-Proto`/`Host`)
- Switched database driver from `mysql` to `mariadb`
- Replaced `sycho/move-posts` with `fof/move-posts`

## 0.2.7 — 2026-05-02

### Changed
- Disabled `forumaker/magicbb` by default
- Enabled `forumaker/magicread` by default

## 0.2.6 — 2026-05-02

### Changed
- Switched from supervisord to s6-overlay (drops Python from the image)

## 0.2.5 — 2026-05-02

### Fixed
- Extension Manager write permissions

## 0.2.4 — 2026-05-02

### Fixed
- Sporadic 500 errors on the front page (raised PHP memory limit)

## 0.2.3 — 2026-05-02

### Added
- `forumaker/profile-cover` (replaces `sycho/flarum-profile-cover`) — adds GIF/WebP support and improved thumbnails
- `forumaker/magicslider`, `forumaker/magicbb` — enabled by default
- `forumaker/magicread`, `forumaker/yandex-oauth`, `forumaker/yandex-smartcaptcha`, `fof/oauth` — installed but not enabled
- `justoverclock/flarum-ext-welcomebox` — installed but not enabled
- `ralkage/flarum-ext-profile-messages` — enabled by default

## 0.2.2 — 2026-05-01

### Added
- `linkrobins/auto-verify` — enabled by default; replaces the MariaDB trigger we used to skip email confirmation
- `linkrobins/font-sizer` — installed but not enabled

## 0.2.1 — 2026-05-01

### Changed
- **Major rewrite: setup moved from runtime entrypoint to build time.**
- **First boot is now ~8 seconds** (previously ~45+ seconds)

## 0.2.0 — 2026-05-01

### Added
- Initial release: all-in-one Docker container with Flarum 2.x, ~50 extensions, MariaDB, and nginx