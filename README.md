# 📦 Flarum-In-A-Box

All-in-one Docker container with **Flarum 2.x**, 45+ extensions, MariaDB, and Nginx.
One command to launch a fully working forum — from [🎹 Piano | Tell](https://pianotell.com).

> ⚠️ **This is a demo/playground image.** Not intended for production use.

![Flarum-In-A-Box Homepage](docs/images/homepage.png)

![Showcase Tag](docs/images/showcase.png)

## Quick Start

### Option A: Docker Desktop (no terminal needed)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Pull the image: search for `pianotell/flarum-in-a-box`
3. Click **Run**, set the host port to `8080`
4. Open [http://localhost:8080](http://localhost:8080)

### Option B: Command Line (one command)

```bash
docker run -d -p 8080:80 --name flarum-in-a-box pianotell/flarum-in-a-box
```

Then open [http://localhost:8080](http://localhost:8080).

### Option C: Docker Compose (from source)

```bash
git clone https://github.com/PrimateCoder/flarum-in-a-box.git
cd flarum-in-a-box
docker compose up -d
```

## Default Accounts

| Account | Username | Password |
|---------|----------|----------|
| Admin   | `admin`  | `password` |
| User    | `user`   | `password` |

## What's Included

### Flarum Core (bundled)

Tags, Likes, Mentions, Subscriptions, Lock, Sticky, Emoji, Flags, Suspend,
Approval, BBCode, Markdown, Statistics, Nicknames.

### 45+ Additional Extensions (enabled by default)

- **Flamoji** — Visual emoji picker
- **FoF Best Answer** — Q&A-style best answers
- **FoF Byobu** — Private discussions
- **FoF Drafts** — Save post drafts
- **FoF Formatting** — Autoimage, Autovideo, MediaEmbed
- **FoF Polls** — Polls in discussions
- **FoF Upload** — File/image attachments
- **FoF User Bio** — Profile bio field
- **FoF User Directory** — Browsable user list
- **FoF Reactions** — Post reactions (beyond likes)
- **FoF Synopsis** — Discussion excerpts in list
- **FoF Impersonate** — Admin can log in as any user
- **FoF Split / Merge** — Split and merge discussions
- **FoF BBCode Details** — Expandable sections in posts
- **FoF Discussion Views** — View counters
- **FoF Rich Text** — WYSIWYG-style editor
- **FoF Gamification** — Voting and rankings
- **FoF Categories** — Category-based navigation
- **FoF Ignore Users** — Ignore other users
- **FoF Linguist** — Customize translations
- **Profile Cover** — Cover images on profiles
- **Mobile Tab** — Bottom navigation on mobile
- **Move Posts** — Move posts between discussions
- **BBCode FA** — Font Awesome icons in posts
- **Stickiest** — Three-tier sticky system
- **Diff** — Post edit history
- **Topic Rating** — Rate discussions
- **Post Search** — Search within posts
- **Forum Widgets** — Customizable widgets
- **Markdown Tables** — Tables in posts
- **Inline Audio** — Audio player in posts
- ...and more

### Installed but Not Enabled

- **Avocado** — A beautiful green theme (try it!)
- **Colored** — Colored usernames by group
- **Modern Footer** — Responsive forum footer
- **FoF Terms** — Terms of service acceptance
- **FoF Share Social** — Social media sharing
- **FoF Pages** — Custom static pages
- **FoF Discussion Thumbnail** — Thumbnails on discussion list
- **FoF Anti Spam** — Spam prevention

Enable any of these from the Admin Panel → Extensions.

## Customization

Copy `.env.example` to `.env` and adjust values before starting:

```bash
cp .env.example .env
# Edit .env with your preferred settings
docker compose up -d
```

Available settings:

| Variable              | Default                 | Description            |
|-----------------------|-------------------------|------------------------|
| `FLARUM_FORUM_URL`    | `http://localhost:8080`  | Public URL of the forum |
| `FLARUM_FORUM_TITLE`  | `📦 Flarum-In-A-Box`    | Forum title            |
| `FLARUM_ADMIN_USER`   | `admin`                 | Admin username         |
| `FLARUM_ADMIN_PASS`   | `password`              | Admin password         |
| `FLARUM_ADMIN_EMAIL`  | `admin@example.com`     | Admin email            |

## Managing the Container

```bash
# View logs
docker logs flarum-in-a-box

# Stop
docker stop flarum-in-a-box

# Start again (data is preserved)
docker start flarum-in-a-box

# Reset everything (fresh start)
docker rm -f flarum-in-a-box
docker run -d -p 8080:80 --name flarum-in-a-box pianotell/flarum-in-a-box
```

## Troubleshooting

### Container exits immediately
Check the logs: `docker logs flarum-in-a-box`. Common causes:
- Port 8080 already in use → use a different port: `-p 9090:80`

### "Access denied" or database errors
The database initializes on first boot. If it was interrupted, reset:
```bash
docker rm -f flarum-in-a-box
docker run -d -p 8080:80 --name flarum-in-a-box pianotell/flarum-in-a-box
```

### Extensions not showing
Some extensions may not yet be compatible with Flarum 2.x. Check the
container build logs for skip messages.

## Architecture

```
┌──────────────────────────────────────────┐
│         Single Docker Container           │
│                                           │
│  supervisord manages:                     │
│  ┌──────────┐  ┌──────────┐              │
│  │ Nginx    │  │ MariaDB  │              │
│  │ + PHP    │  │ (local)  │              │
│  └──────────┘  └──────────┘              │
│                                           │
│  Flarum 2.x + 45+ extensions             │
│                                           │
│  Port 80 exposed                          │
└──────────────────────────────────────────┘
```

## License

MIT
