# Title: 📦 Flarum-In-A-Box — Try Flarum 2.x in One Command (Docker)

---

## 📦 Flarum-In-A-Box

**One command. \~60 extensions. A fully working Flarum 2.x forum.**

Inspired by the [discussion about demo sites](https://discuss.flarum.org/d/39142-flarum-official-demo-sites-usage-update) + the fact that [PianoTell](https://forum.pianotell.com) itself is [already on Docker](https://forum.pianotell.com/d/785-piano-tell-hosting-updates), I built [**Flarum-In-A-Box**](https://github.com/PrimateCoder/flarum-in-a-box) — an all-in-one Docker container that gives you a complete Flarum 2.x forum with \~60 popular extensions pre-installed. No server setup, no configuration, no database provisioning.

Now everyone can have admin access and customize Flarum 2.x at will in the comfort and safety of Flarum-In-A-Box.

### Quick Start

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Search for `pianotell/flarum-in-a-box`
3. Click **Run** — in Optional Settings be sure to set the host port to `8080`

Open [http://localhost:8080](http://localhost:8080) and you're in. 🚀

This is the One Command:

```
docker run -d -p 8080:80 --name flarum-in-a-box pianotell/flarum-in-a-box
```

To **update** to the latest release, run these three commands:

```
docker pull pianotell/flarum-in-a-box
docker rm -f flarum-in-a-box
docker run -d -p 8080:80 --name flarum-in-a-box pianotell/flarum-in-a-box
```

### Screenshots

![Homepage](https://raw.githubusercontent.com/PrimateCoder/flarum-in-a-box/main/docs/images/homepage.png)

![Showcase](https://raw.githubusercontent.com/PrimateCoder/flarum-in-a-box/main/docs/images/showcase.png)

### Why?

This makes it effortless for anyone to:

- 🧪 **Demo Flarum** for fun and profit
- 💻 **Develop extensions** against a real, fully loaded Flarum instance
- 📚 **Learn and experiment** with features and extensions
- 🏗️ **Test themes** like the included [Avocado](https://discuss.flarum.org/d/38940-avocado-theme) theme

> ⚠️ This is a **demo/playground** image — not intended for production use but perfect for testing and development. Data is ephemeral for the lifetime of the container.

### What's Inside?

**PHP 8.5** on Alpine Linux, with **nginx**, **MariaDB**, and **s6-overlay** — all in a single container. Multi-arch (amd64 + arm64), so it runs on Intel PCs, Apple Silicon Macs, and ARM cloud instances.

#### \~60 Extensions Pre-Installed

**Enabled by default** — [Tags](https://packagist.org/packages/flarum/tags), [Likes](https://packagist.org/packages/flarum/likes), [Mentions](https://packagist.org/packages/flarum/mentions), [Lock](https://packagist.org/packages/flarum/lock), [Sticky](https://packagist.org/packages/flarum/sticky), [Suspend](https://packagist.org/packages/flarum/suspend), [Markdown](https://packagist.org/packages/flarum/markdown), [BBCode](https://packagist.org/packages/flarum/bbcode), [Emoji](https://packagist.org/packages/flarum/emoji), [Flags](https://packagist.org/packages/flarum/flags), [Nicknames](https://packagist.org/packages/flarum/nicknames), [Subscriptions](https://packagist.org/packages/flarum/subscriptions), [Approval](https://packagist.org/packages/flarum/approval), [Statistics](https://packagist.org/packages/flarum/statistics), [Extension Manager](https://packagist.org/packages/flarum/extension-manager), plus:

**Composer & posting**
- [**Flamoji**](https://discuss.flarum.org/d/39130-new-flamoji-emoji-picker-extension-for-flarum) — Intuitive emoji picker 😉
- [**Drafts**](https://packagist.org/packages/fof/drafts), [**Formatting**](https://packagist.org/packages/fof/formatting), [**Polls**](https://packagist.org/packages/fof/polls), [**Upload**](https://packagist.org/packages/fof/upload), [**Rich Text**](https://packagist.org/packages/fof/rich-text), [**BBCode Details**](https://packagist.org/packages/fof/bbcode-details)
- [**BBCode FA**](https://packagist.org/packages/antoinefr/flarum-ext-bbcode-fa), [**Markdown Tables**](https://packagist.org/packages/ekumanov/flarum-ext-markdown-tables), [**Inline Audio**](https://packagist.org/packages/ekumanov/flarum-ext-inline-audio)

**Discussions & navigation**
- [**Best Answer**](https://packagist.org/packages/fof/best-answer), [**Byobu**](https://packagist.org/packages/fof/byobu) (private discussions), [**Categories**](https://packagist.org/packages/fof/categories), [**Follow Tags**](https://packagist.org/packages/fof/follow-tags), [**Frontpage**](https://packagist.org/packages/fof/frontpage), [**Sitemap**](https://packagist.org/packages/fof/sitemap), [**Synopsis**](https://packagist.org/packages/fof/synopsis), [**Discussion Views**](https://packagist.org/packages/fof/discussion-views)
- [**Stickiest**](https://packagist.org/packages/huseyinfiliz/stickiest), [**Last Post Avatar**](https://packagist.org/packages/rob006/flarum-ext-last-post-avatar), [**External Links in New Tab**](https://packagist.org/packages/walsgit/external-links-in-new-tab)
- [**Menu Control**](https://packagist.org/packages/resofire/menu-control), [**Mobile Search**](https://packagist.org/packages/resofire/mobile-search), [**Mobile Tab**](https://packagist.org/packages/acpl/mobile-tab)

**User experience**
- [**Reactions**](https://packagist.org/packages/fof/reactions), [**Gamification**](https://packagist.org/packages/fof/gamification) (voting + rankings), [**User Bio**](https://packagist.org/packages/fof/user-bio), [**User Directory**](https://packagist.org/packages/fof/user-directory), [**Ignore Users**](https://packagist.org/packages/fof/ignore-users)
- [**Profile Cover**](https://packagist.org/packages/forumaker/profile-cover) (GIF/WebP), [**MagicSlider**](https://packagist.org/packages/forumaker/magicslider), [**MagicRead**](https://packagist.org/packages/forumaker/magicread)
- [**Profile Messages**](https://packagist.org/packages/ralkage/flarum-ext-profile-messages) (XenForo-style), [**Profile Views**](https://packagist.org/packages/michaelbelgium/flarum-profile-views) (view counts), [**Topic Rating**](https://packagist.org/packages/tryhackx/flarum-topic-rating), [**Forum Widgets**](https://packagist.org/packages/ekumanov/flarum-ext-forum-widgets)

**Moderation & admin**
- [**Moderator Notes**](https://packagist.org/packages/fof/moderator-notes), [**Impersonate**](https://packagist.org/packages/fof/impersonate) (log in as any user), [**Split**](https://packagist.org/packages/fof/split), [**Merge Discussions**](https://packagist.org/packages/fof/merge-discussions), [**Move Posts**](https://discuss.flarum.org/d/38941-friendsofflarum-move-posts)
- [**Diff**](https://packagist.org/packages/huseyinfiliz/flarum-diff) (post edit history), [**Recycle Bin**](https://packagist.org/packages/walsgit/recycle-bin), [**Log Viewer**](https://packagist.org/packages/ianm/log-viewer) (browse Flarum logs from the admin panel)

**Other**
- [**Linguist**](https://packagist.org/packages/fof/linguist), [**Links**](https://packagist.org/packages/fof/links), [**Post Search**](https://packagist.org/packages/ekumanov/flarum-ext-post-search), [**AutoVerify**](https://packagist.org/packages/linkrobins/auto-verify) (skip email verification on signup)

**Installed but not enabled** (try them from Admin Panel → Extensions):

- 🥑 [**Avocado**](https://discuss.flarum.org/d/38940-avocado-theme) — Modern, polished theme with hero banner and rich customization
- 🎨 [**Colored**](https://packagist.org/packages/ramon/colored) — Colorful usernames by group
- 🦶 [**Modern Footer**](https://packagist.org/packages/huseyinfiliz/modern-footer) — Responsive footer
- 🔤 [**Font Sizer**](https://packagist.org/packages/linkrobins/font-sizer) — Adjustable font sizes
- 🧰 [**MagicBB**](https://packagist.org/packages/forumaker/magicbb) — Extended BBCode toolkit (extra composer icons)
- 👋 [**WelcomeBox**](https://packagist.org/packages/justoverclock/flarum-ext-welcomebox) — Customizable welcome banner
- 🃏 [**Discussion Cards**](https://packagist.org/packages/walsgit/flarum-discussion-cards) — Card-style discussion list
- 🔐 [**OAuth**](https://packagist.org/packages/fof/oauth) — Social login framework (Google, Discord, GitHub, etc.)
- 🟡 [**Yandex OAuth**](https://packagist.org/packages/forumaker/yandex-oauth) / [**SmartCaptcha**](https://packagist.org/packages/forumaker/yandex-smartcaptcha)
- And several utilities ([Terms](https://packagist.org/packages/fof/terms), [Pages](https://packagist.org/packages/fof/pages), [Share Social](https://packagist.org/packages/fof/share-social), [Discussion Thumbnail](https://packagist.org/packages/fof/discussion-thumbnail), [Anti Spam](https://packagist.org/packages/fof/anti-spam))

### Ready Out of the Box

The container comes pre-configured with:

- **Default accounts:** `admin` (Admin), `moderator` (Mod group — try the moderation tools), `user`, plus `user1`–`user5` — all with password `password`
- **8 sample tags** with icons and colors (General, Announcements, Support, Feedback, Showcase, Off-Topic, Guides, Bugs)
- **9 seed discussions** including a 🛠️ **Moderation Playground** — a deliberately-heated thread where `user1`–`user5` argue about moderation policy so you can practice locking, hiding, suspending, and reviewing logs (via [Log Viewer](https://packagist.org/packages/ianm/log-viewer)) on real-looking content
- **Email auto-verified** on signup — no mail server needed
- **Rankings page** accessible to everyone

### Tips & Tricks

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

### Technical Details

- **Base:** PHP 8.5-FPM on Alpine Linux (multi-stage build)
- **Web server:** nginx
- **Database:** MariaDB (bundled, internal)
- **Process manager:** s6-overlay (nginx + PHP-FPM + MariaDB)
- **Architectures:** amd64, arm64

### Links

- [Changelog](https://github.com/PrimateCoder/flarum-in-a-box/blob/main/CHANGELOG.md)
- [Source code on GitHub](https://github.com/PrimateCoder/flarum-in-a-box)
- [Docker Hub](https://hub.docker.com/r/pianotell/flarum-in-a-box)
- [Report an issue](https://github.com/PrimateCoder/flarum-in-a-box/issues)

### Feedback Welcome!

Is this useful to anyone at all?
