# Title: 📦 Flarum-In-A-Box — Try Flarum 2.x in One Command (Docker)

---

## 📦 Flarum-In-A-Box

**One command. ~50 extensions. A fully working Flarum 2.x forum.**

Inspired by the [discussion about demo sites](https://discuss.flarum.org/d/39142-flarum-official-demo-sites-usage-update) + the fact that [PianoTell](https://forum.pianotell.com) itself is [already on Docker](https://forum.pianotell.com/d/785-piano-tell-hosting-updates), I built [**Flarum-In-A-Box**](https://github.com/PrimateCoder/flarum-in-a-box) — an all-in-one Docker container that gives you a complete Flarum 2.x forum with ~50 popular extensions pre-installed. No server setup, no configuration, no database provisioning.

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

#### ~50 Extensions Pre-Installed

**Enabled by default:**
Tags, Likes, Mentions, Lock, Sticky, Suspend, Markdown, BBCode, Emoji, Flags, Nicknames, Subscriptions, Approval, Extension Manager, and...

- [**Flamoji**](https://discuss.flarum.org/d/39130-new-flamoji-emoji-picker-extension-for-flarum) — Intuitive emoji picker 😉
- **FoF Best Answer** — Q&A-style discussions
- **FoF Byobu** — Private discussions
- **FoF Drafts** — Save posts as drafts
- **FoF Formatting** — Autoimage, Autovideo, MediaEmbed
- **FoF Polls** — Create polls
- **FoF Upload** — File and image attachments
- **FoF Reactions** — Post reactions beyond likes
- **FoF Rich Text** — Enhanced text editor
- **FoF Synopsis** — Discussion excerpts in the list
- **FoF Gamification** — Voting and rankings
- **FoF Categories** — Category-based navigation
- **FoF Impersonate** — Log in as any user (great for demos!)
- **FoF Split / Merge** — Discussion management
- **Forumaker Profile Cover** — Cover images on profiles (with GIF/WebP support)
- **Forumaker MagicSlider** — Image slider in posts
- **Forumaker MagicRead** — Reading progress / scroll tracking
- **Profile Messages** — Public messages on user profiles (XenForo-style)
- **Mobile Tab** — Bottom navigation on mobile
- **Stickiest** — Three-tier sticky system
- **Diff** — Post edit history
- **Topic Rating** — Rate discussions
- **AutoVerify** — Skip email verification on signup
- ...and many more (BBCode FA, Inline Audio, Forum Widgets, Markdown Tables, Post Search, Move Posts, etc.)

**Installed but not enabled** (try them from Admin Panel → Extensions):

- 🥑 [**Avocado**](https://discuss.flarum.org/d/38940-avocado-theme) — A modern, polished theme with hero banner and rich customization
- 🎨 **Colored** — Colorful usernames by group
- 🦶 **Modern Footer** — Responsive footer
- 🔤 **Font Sizer** — Adjustable font sizes
- 🧰 **Forumaker MagicBB** — Extended BBCode toolkit (extra composer icons)
- 👋 **WelcomeBox** — Customizable welcome banner
- And several FoF utilities (Terms, Pages, Share Social, Discussion Thumbnail, Anti Spam)

### Ready Out of the Box

The container comes pre-configured with:

- **Two accounts:** `admin` / `password` and `user` / `password`
- **8 sample tags** with icons and colors (General, Announcements, Support, Feedback, Showcase, Off-Topic, Guides, Bugs)
- **9 seed discussions** covering features, extensions, and the Avocado theme
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
