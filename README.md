# 📦 Flarum-In-A-Box (Flarum 1.x Edition)

[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/PrimateCoder/flarum-in-a-box/blob/main/LICENSE) [![Docker Image Version](https://img.shields.io/docker/v/pianotell/flarum-in-a-box?sort=semver)](https://hub.docker.com/r/pianotell/flarum-in-a-box) [![Docker Pulls](https://img.shields.io/docker/pulls/pianotell/flarum-in-a-box)](https://hub.docker.com/r/pianotell/flarum-in-a-box)

All-in-one Docker container with **Flarum 1.8**, 40+ extensions, PHP 8.3, MariaDB, and nginx.
One command to launch a fully working forum — from [🎹 Piano | Tell](https://pianotell.com).

> ℹ️ **Two editions, one repository.** This is the **Flarum 1.x edition** — published as image tag `flarum1` (rolling; each release is also pinned as `0.1.y`). The **Flarum 2.x edition** is the `latest` tag of the same image, built from the `main` branch. Pick whichever Flarum generation you need — or run both side by side (see below).

> ⚠️ **Demo/playground image** — fantastic for testing and development, but not for production. Data is ephemeral for the lifetime of the container.
>
> Also note: Flarum 1.8 is in maintenance mode upstream — it receives critical and security fixes only, winding down toward end of life around the end of 2026. For anything beyond a demo or a legacy extension compatibility check, prefer the Flarum 2.x edition.

![Flarum-In-A-Box Homepage](https://raw.githubusercontent.com/PrimateCoder/flarum-in-a-box/main/docs/images/homepage.png)

![Showcase Tag](https://raw.githubusercontent.com/PrimateCoder/flarum-in-a-box/main/docs/images/showcase.png)

## Quick Start

### Option A: Docker Desktop (no terminal needed)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Search for `pianotell/flarum-in-a-box`
3. In the image's **Tags** tab pick `flarum1`, then click **Run** — in Optional Settings be sure to set the host port to `8081`
4. Open [http://localhost:8081](http://localhost:8081)

### Option B: Command Line (one command)

```bash
docker run -d -p 8081:80 --name flarum1-in-a-box pianotell/flarum-in-a-box:flarum1
```

Then open [http://localhost:8081](http://localhost:8081).

### Running Both Editions Side by Side

The Flarum 1.x edition defaults to port `8081` so it coexists cleanly with the Flarum 2.x edition on `8080`:

```bash
# Flarum 2.x (latest)
docker run -d -p 8080:80 --name flarum-in-a-box pianotell/flarum-in-a-box

# Flarum 1.x (this edition)
docker run -d -p 8081:80 --name flarum1-in-a-box pianotell/flarum-in-a-box:flarum1
```

Each container is fully self-contained (own database, own seeded data) — no conflicts.

### Updating to the Latest Version

Docker caches images locally, so to get the latest release you need
to explicitly pull, remove the old container, and start a fresh one:

```bash
docker pull pianotell/flarum-in-a-box:flarum1
docker rm -f flarum1-in-a-box
docker run -d -p 8081:80 --name flarum1-in-a-box pianotell/flarum-in-a-box:flarum1
```

## Default Accounts

| Account | Username | Password | Role |
|---------|----------|----------|------|
| Admin     | `admin`     | `password` | Full Admin Panel access |
| Moderator | `moderator` | `password` | Mod group — lock, hide, suspend, etc. |
| Member    | `user`      | `password` | Regular forum member |
| Members   | `user1`–`user5` | `password` | Sample members (used in the Moderation Playground discussion) |

## Tips & Tricks

Run Flarum CLI commands directly from the host:

```bash
docker exec flarum1-in-a-box php flarum info
```

Get a shell inside the container (to run Composer, edit files, etc.):

```bash
docker exec -it flarum1-in-a-box /bin/sh
```

Copy files to and from the container:

```bash
# Host → container
docker cp my-logo.png flarum1-in-a-box:/var/www/html/public/assets/

# Container → host
docker cp flarum1-in-a-box:/var/www/html/config.php ./config.php
```

View container logs (nginx, PHP-FPM, MariaDB, s6-overlay):

```bash
# All logs
docker logs flarum1-in-a-box

# Follow live
docker logs -f flarum1-in-a-box

# Last 100 lines
docker logs --tail 100 flarum1-in-a-box
```

## What's Included

### Flarum Core (bundled)

[Tags](https://packagist.org/packages/flarum/tags), [Likes](https://packagist.org/packages/flarum/likes), [Mentions](https://packagist.org/packages/flarum/mentions), [Subscriptions](https://packagist.org/packages/flarum/subscriptions), [Lock](https://packagist.org/packages/flarum/lock), [Sticky](https://packagist.org/packages/flarum/sticky), [Emoji](https://packagist.org/packages/flarum/emoji), [Flags](https://packagist.org/packages/flarum/flags), [Suspend](https://packagist.org/packages/flarum/suspend), [Approval](https://packagist.org/packages/flarum/approval), [BBCode](https://packagist.org/packages/flarum/bbcode), [Markdown](https://packagist.org/packages/flarum/markdown), [Statistics](https://packagist.org/packages/flarum/statistics), [Nicknames](https://packagist.org/packages/flarum/nicknames), [Extension Manager](https://packagist.org/packages/flarum/extension-manager).

### Sample Content

The image is pre-seeded so the forum looks lived-in from the first second:

- **8 sample tags** (Announcements, Support, Feedback, Showcase, Off-Topic, Guides, Bugs, plus the bundled General)
- **7 seed discussions** including a **🛠️ Moderation Playground** — a deliberately-heated thread where `user1`–`user5` argue about moderation policy so you can practice mod actions on real-looking content
- **Default accounts**: `admin` (Admin), `moderator` (Mod group), `user`, `user1`–`user5` — all with password `password`

### Additional Extensions — Enabled by Default

**Composer & posting**
- [**PhotoSwipe**](https://discuss.flarum.org/d/39120-friendsofflarum-photoswipe-image-lightbox) — 📸 Full-screen tap-to-zoom image lightbox (try the **Photo Gallery** seed discussion)
- [**Flamoji**](https://discuss.flarum.org/d/39130-new-flamoji-emoji-picker-extension-for-flarum) — Visual emoji picker (try the **Emoji Picker** seed discussion)
- [**Drafts**](https://packagist.org/packages/fof/drafts) — Save post drafts
- [**Formatting**](https://packagist.org/packages/fof/formatting) — Autoimage, Autovideo, MediaEmbed
- [**Polls**](https://packagist.org/packages/fof/polls) — Polls in discussions (try the **How to Create a Poll** seed discussion)
- [**Upload**](https://packagist.org/packages/fof/upload) — File and image attachments
- [**BBCode FA**](https://packagist.org/packages/antoinefr/flarum-ext-bbcode-fa) — Font Awesome icons in posts

**Discussions & navigation**
- [**Best Answer**](https://packagist.org/packages/fof/best-answer) — Q&A-style best answers
- [**Byobu**](https://packagist.org/packages/fof/byobu) — Private discussions
- [**Discussion Views**](https://packagist.org/packages/fof/discussion-views) — View counters
- [**Follow Tags**](https://packagist.org/packages/fof/follow-tags) — Per-tag subscriptions
- [**Last Post Avatar**](https://packagist.org/packages/rob006/flarum-ext-last-post-avatar) — Show the last poster's avatar in the discussion list
- [**Sitemap**](https://packagist.org/packages/fof/sitemap) — XML sitemap for SEO

**User experience**
- [**Reactions**](https://packagist.org/packages/fof/reactions) — Post reactions beyond likes
- [**Gamification**](https://packagist.org/packages/fof/gamification) — Voting and rankings
- [**User Bio**](https://packagist.org/packages/fof/user-bio) — Profile bio field
- [**User Directory**](https://packagist.org/packages/fof/user-directory) — Browsable user list
- [**Ignore Users**](https://packagist.org/packages/fof/ignore-users) — Ignore other users
- [**Profile Views**](https://packagist.org/packages/michaelbelgium/flarum-profile-views) — Track and display profile view counts

**Moderation & admin**
- [**Moderator Notes**](https://packagist.org/packages/fof/moderator-notes) — Per-user mod notes
- [**Impersonate**](https://packagist.org/packages/fof/impersonate) — Admin can log in as any user
- [**Split**](https://packagist.org/packages/fof/split) — Split discussions
- [**Merge Discussions**](https://packagist.org/packages/fof/merge-discussions) — Merge discussions
- [**Move Posts**](https://discuss.flarum.org/d/38941-friendsofflarum-move-posts) — Move posts between discussions
- [**Log Viewer**](https://packagist.org/packages/ianm/log-viewer) — View Flarum log files in the admin panel

**Other**
- [**Links**](https://packagist.org/packages/fof/links) — Custom navigation links
- [**Demo Auto-Confirm**](https://github.com/PrimateCoder/flarum-in-a-box/blob/1.x/src/box/extensions/demo-auto-confirm/extend.php) — Bundled demo helper that auto-confirms new signups so the forum works without a mail server (the 1.x stand-in for AutoVerify, which is 2.x-only)

### Installed but Not Enabled

- 🔐 [**OAuth**](https://packagist.org/packages/fof/oauth) — Social login framework (Google, Discord, GitHub, etc.)
- 🛡️ [**Anti Spam**](https://packagist.org/packages/fof/anti-spam) — Spam prevention
- 👋 [**WelcomeBox**](https://packagist.org/packages/justoverclock/flarum-ext-welcomebox) — Customizable welcome banner (enable 🧩 **Forum Widgets** first — it's the widget framework WelcomeBox requires)
- 📄 [**Pages**](https://packagist.org/packages/fof/pages) — Custom static pages
- 📣 [**Share Social**](https://packagist.org/packages/fof/share-social) — Social media sharing
- 🤝 [**Terms**](https://packagist.org/packages/fof/terms) — Terms of service acceptance

Enable any of these from the Admin Panel → Extensions. The default-enabled set here mirrors the Flarum 2.x edition on `main`; the 2.x edition additionally ships the full 80+ catalog.

## Customization


If you map to a non-default port, set `FLARUM_FORUM_URL` to match:

```bash
docker run -d -p 9090:80 -e FLARUM_FORUM_URL=http://localhost:9090 \
    --name flarum1-in-a-box pianotell/flarum-in-a-box:flarum1
```

## Links

- [Source code on GitHub](https://github.com/PrimateCoder/flarum-in-a-box)
- [Docker Hub](https://hub.docker.com/r/pianotell/flarum-in-a-box)
- [Changelog](https://github.com/PrimateCoder/flarum-in-a-box/blob/main/CHANGELOG.md)
- [Discuss on Flarum Community](https://discuss.flarum.org/d/39191-flarum-in-a-box-try-flarum-2x-in-one-command-with-docker)
- [Report an issue](https://github.com/PrimateCoder/flarum-in-a-box/issues)

## License

MIT
