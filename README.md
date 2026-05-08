# 📦 Flarum-In-A-Box

All-in-one Docker container with **Flarum 2.x**, ~60 extensions, MariaDB, and nginx.
One command to launch a fully working forum — from [🎹 Piano | Tell](https://pianotell.com).

> ⚠️ **Demo/playground image** — fantastic for testing and development, but not for production. Data is ephemeral for the lifetime of the container.

![Flarum-In-A-Box Homepage](https://raw.githubusercontent.com/PrimateCoder/flarum-in-a-box/main/docs/images/homepage.png)

![Showcase Tag](https://raw.githubusercontent.com/PrimateCoder/flarum-in-a-box/main/docs/images/showcase.png)

## Quick Start

### Option A: Docker Desktop (no terminal needed)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Search for `pianotell/flarum-in-a-box`
3. Click **Run** — in Optional Settings be sure to set the host port to `8080`
4. Open [http://localhost:8080](http://localhost:8080)

### Option B: Command Line (one command)

```bash
docker run -d -p 8080:80 --name flarum-in-a-box pianotell/flarum-in-a-box
```

Then open [http://localhost:8080](http://localhost:8080).

### Updating to the Latest Version

Docker caches images locally, so to get the latest release you need
to explicitly pull, remove the old container, and start a fresh one:

```bash
docker pull pianotell/flarum-in-a-box
docker rm -f flarum-in-a-box
docker run -d -p 8080:80 --name flarum-in-a-box pianotell/flarum-in-a-box
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
docker exec flarum-in-a-box php flarum info
```

Get a shell inside the container (to run Composer, edit files, etc.):

```bash
docker exec -it flarum-in-a-box /bin/sh
```

Copy files to and from the container:

```bash
# Host → container
docker cp my-logo.png flarum-in-a-box:/var/www/html/public/assets/

# Container → host
docker cp flarum-in-a-box:/var/www/html/config.php ./config.php
```

View container logs (nginx, PHP-FPM, MariaDB, s6-overlay):

```bash
# All logs
docker logs flarum-in-a-box

# Follow live
docker logs -f flarum-in-a-box

# Last 100 lines
docker logs --tail 100 flarum-in-a-box
```

## What's Included

### Flarum Core (bundled)

[Tags](https://packagist.org/packages/flarum/tags), [Likes](https://packagist.org/packages/flarum/likes), [Mentions](https://packagist.org/packages/flarum/mentions), [Subscriptions](https://packagist.org/packages/flarum/subscriptions), [Lock](https://packagist.org/packages/flarum/lock), [Sticky](https://packagist.org/packages/flarum/sticky), [Emoji](https://packagist.org/packages/flarum/emoji), [Flags](https://packagist.org/packages/flarum/flags), [Suspend](https://packagist.org/packages/flarum/suspend), [Approval](https://packagist.org/packages/flarum/approval), [BBCode](https://packagist.org/packages/flarum/bbcode), [Markdown](https://packagist.org/packages/flarum/markdown), [Statistics](https://packagist.org/packages/flarum/statistics), [Nicknames](https://packagist.org/packages/flarum/nicknames), [Extension Manager](https://packagist.org/packages/flarum/extension-manager).

### Sample Content

The image is pre-seeded so the forum looks lived-in from the first second:

- **8 sample tags** (Announcements, Support, Feedback, Showcase, Off-Topic, Guides, Bugs, plus the bundled General)
- **9 seed discussions** including a **🛠️ Moderation Playground** — a deliberately-heated thread where `user1`–`user5` argue about moderation policy so you can practice mod actions on real-looking content
- **Default accounts**: `admin` (Admin), `moderator` (Mod group), `user`, `user1`–`user5` — all with password `password`

### Additional Extensions — Enabled by Default

**Composer & posting**
- [**Flamoji**](https://discuss.flarum.org/d/39130-new-flamoji-emoji-picker-extension-for-flarum) — Visual emoji picker
- [**Drafts**](https://packagist.org/packages/fof/drafts) — Save post drafts
- [**Formatting**](https://packagist.org/packages/fof/formatting) — Autoimage, Autovideo, MediaEmbed
- [**Polls**](https://packagist.org/packages/fof/polls) — Polls in discussions
- [**Upload**](https://packagist.org/packages/fof/upload) — File and image attachments
- [**Rich Text**](https://packagist.org/packages/fof/rich-text) — WYSIWYG-style editor
- [**BBCode Details**](https://packagist.org/packages/fof/bbcode-details) — Expandable sections in posts
- [**BBCode FA**](https://packagist.org/packages/antoinefr/flarum-ext-bbcode-fa) — Font Awesome icons in posts
- [**Markdown Tables**](https://packagist.org/packages/ekumanov/flarum-ext-markdown-tables) — Tables in posts
- [**Inline Audio**](https://packagist.org/packages/ekumanov/flarum-ext-inline-audio) — Audio player in posts

**Discussions & navigation**
- [**Best Answer**](https://packagist.org/packages/fof/best-answer) — Q&A-style best answers
- [**Byobu**](https://packagist.org/packages/fof/byobu) — Private discussions
- [**Categories**](https://packagist.org/packages/fof/categories) — Category-based navigation
- [**Follow Tags**](https://packagist.org/packages/fof/follow-tags) — Per-tag subscriptions
- [**Frontpage**](https://packagist.org/packages/fof/frontpage) — Pin a discussion as the homepage
- [**Sitemap**](https://packagist.org/packages/fof/sitemap) — XML sitemap for SEO
- [**Synopsis**](https://packagist.org/packages/fof/synopsis) — Discussion excerpts in the list
- [**Discussion Views**](https://packagist.org/packages/fof/discussion-views) — View counters
- [**Stickiest**](https://packagist.org/packages/huseyinfiliz/stickiest) — Three-tier sticky system
- [**External Links in New Tab**](https://packagist.org/packages/walsgit/external-links-in-new-tab) — Outbound links open in a new tab
- [**Last Post Avatar**](https://packagist.org/packages/rob006/flarum-ext-last-post-avatar) — Show the last poster's avatar in the discussion list
- [**Menu Control**](https://packagist.org/packages/resofire/menu-control) — Customize the navigation menu
- [**Mobile Search**](https://packagist.org/packages/resofire/mobile-search) — Better mobile search experience
- [**Mobile Tab**](https://packagist.org/packages/acpl/mobile-tab) — Bottom navigation on mobile

**User experience**
- [**Reactions**](https://packagist.org/packages/fof/reactions) — Post reactions beyond likes
- [**Gamification**](https://packagist.org/packages/fof/gamification) — Voting and rankings
- [**User Bio**](https://packagist.org/packages/fof/user-bio) — Profile bio field
- [**User Directory**](https://packagist.org/packages/fof/user-directory) — Browsable user list
- [**Ignore Users**](https://packagist.org/packages/fof/ignore-users) — Ignore other users
- [**Profile Cover**](https://packagist.org/packages/forumaker/profile-cover) — Cover images on profiles (with GIF/WebP support)
- [**MagicSlider**](https://packagist.org/packages/forumaker/magicslider) — Image slider in posts
- [**MagicRead**](https://packagist.org/packages/forumaker/magicread) — Reading progress / scroll tracking
- [**Profile Messages**](https://packagist.org/packages/ralkage/flarum-ext-profile-messages) — Public profile messages (XenForo-style)
- [**Profile Views**](https://packagist.org/packages/michaelbelgium/flarum-profile-views) — Track and display profile view counts
- [**Topic Rating**](https://packagist.org/packages/tryhackx/flarum-topic-rating) — Rate discussions
- [**Forum Widgets**](https://packagist.org/packages/ekumanov/flarum-ext-forum-widgets) — Customizable widgets

**Moderation & admin**
- [**Moderator Notes**](https://packagist.org/packages/fof/moderator-notes) — Per-user mod notes
- [**Impersonate**](https://packagist.org/packages/fof/impersonate) — Admin can log in as any user
- [**Split**](https://packagist.org/packages/fof/split) — Split discussions
- [**Merge Discussions**](https://packagist.org/packages/fof/merge-discussions) — Merge discussions
- [**Move Posts**](https://discuss.flarum.org/d/38941-friendsofflarum-move-posts) — Move posts between discussions
- [**Diff**](https://packagist.org/packages/huseyinfiliz/flarum-diff) — Post edit history
- [**Recycle Bin**](https://packagist.org/packages/walsgit/recycle-bin) — Restore deleted discussions/posts
- [**Log Viewer**](https://packagist.org/packages/ianm/log-viewer) — View Flarum log files in the admin panel

**Other**
- [**Linguist**](https://packagist.org/packages/fof/linguist) — Customize translations
- [**Links**](https://packagist.org/packages/fof/links) — Custom navigation links
- [**Post Search**](https://packagist.org/packages/ekumanov/flarum-ext-post-search) — Search within posts
- [**AutoVerify**](https://packagist.org/packages/linkrobins/auto-verify) — Auto-confirms email on signup (no mail server needed)

### Installed but Not Enabled

- 🥑 [**Avocado**](https://discuss.flarum.org/d/38940-avocado-theme) — Modern, polished theme with hero banner, tag styling, and rich customization (try it!)
- 🎨 [**Colored**](https://packagist.org/packages/ramon/colored) — Colored usernames by group
- 🦶 [**Modern Footer**](https://packagist.org/packages/huseyinfiliz/modern-footer) — Responsive forum footer
- 🔤 [**Font Sizer**](https://packagist.org/packages/linkrobins/font-sizer) — Adjustable font sizes
- 🧰 [**MagicBB**](https://packagist.org/packages/forumaker/magicbb) — Extended BBCode toolkit
- 👋 [**WelcomeBox**](https://packagist.org/packages/justoverclock/flarum-ext-welcomebox) — Customizable welcome banner
- 🃏 [**Discussion Cards**](https://packagist.org/packages/walsgit/flarum-discussion-cards) — Card-style discussion list
- 🔐 [**OAuth**](https://packagist.org/packages/fof/oauth) — Social login framework (Google, Discord, GitHub, etc.)
- 🟡 [**Yandex OAuth**](https://packagist.org/packages/forumaker/yandex-oauth) — Yandex ID login (requires OAuth + setup)
- 🛡️ [**Yandex SmartCaptcha**](https://packagist.org/packages/forumaker/yandex-smartcaptcha) — Yandex CAPTCHA for signup
- 📄 [**Pages**](https://packagist.org/packages/fof/pages) — Custom static pages
- 🖼️ [**Discussion Thumbnail**](https://packagist.org/packages/fof/discussion-thumbnail) — Thumbnails on discussion list
- 🤝 [**Terms**](https://packagist.org/packages/fof/terms) — Terms of service acceptance
- 📣 [**Share Social**](https://packagist.org/packages/fof/share-social) — Social media sharing
- 🛡️ [**Anti Spam**](https://packagist.org/packages/fof/anti-spam) — Spam prevention

Enable any of these from the Admin Panel → Extensions.

## Customization


If you map to a non-default port, set `FLARUM_FORUM_URL` to match:

```bash
docker run -d -p 9090:80 -e FLARUM_FORUM_URL=http://localhost:9090 \
    --name flarum-in-a-box pianotell/flarum-in-a-box
```

## Links

- [Source code on GitHub](https://github.com/PrimateCoder/flarum-in-a-box)
- [Docker Hub](https://hub.docker.com/r/pianotell/flarum-in-a-box)
- [Changelog](https://github.com/PrimateCoder/flarum-in-a-box/blob/main/CHANGELOG.md)
- [Discuss on Flarum Community](https://discuss.flarum.org/d/39191-flarum-in-a-box-try-flarum-2x-in-one-command-with-docker)
- [Report an issue](https://github.com/PrimateCoder/flarum-in-a-box/issues)

## License

MIT
