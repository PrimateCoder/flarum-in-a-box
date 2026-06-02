# AGENTS.md — Flarum-In-A-Box

> Single source of truth for contributors and AI coding assistants
> (Copilot, Claude Code, Cursor, etc.) working in this repo. Learnings,
> conventions, and constraints accumulated across releases. **Keep this
> file up to date** as new lessons are learned.

---

## Critical Rules

### Secrets

- **Never commit secrets, tokens, passwords, or keys.** Use GitHub repo secrets for CI (e.g. `DOCKERHUB_TOKEN`).
- The default credentials baked into the image (`admin/password`, `user/password`, `moderator/password`, `user1`–`user5`/`password`, internal MariaDB `flarum/flarum`) are **not real secrets** — they are deliberately public for the demo. Document them clearly so users know to change them if exposing the container.
- The `build-seed-token` API key is created and **deleted within the same build step** — it never persists in the published image.

### Git

- **Never squash commits unless explicitly asked.** Only squash specific commits the user names. Never collapse entire history.
- Don't force-push without confirming first.
- Don't include placeholder/synthesized values where real ones are needed (image names, URLs, etc.).
- Commits to `main` without a `v*` tag do not trigger CI builds — safe to use for doc/workflow tweaks. Prefix such commits with `[no-build]` for clarity.

---

## Architecture

- All-in-one container: PHP 8.5-FPM + nginx + MariaDB + s6-overlay on Alpine
- **Setup runs at build time** via `src/box/setup.sh` — installs Flarum, enables extensions, seeds tags + demo posts, all baked into the image layer
- Runtime entrypoint (`src/box/entrypoint.sh`) is minimal: only sed-replaces the forum URL in `config.php` if `FLARUM_FORUM_URL` env var is set, then exec's `/init` (s6-overlay's PID 1)
- Image: `pianotell/flarum-in-a-box` on Docker Hub
- Multi-arch build (amd64 + arm64) via GitHub Actions, native runner per arch (no QEMU)

### Process supervisor

- We use **s6-overlay** (Alpine package, ~3MB). It's a packaging layer over `s6` + `s6-rc` + `execline` — properly init-aware (zombie reaping, signal forwarding) and supervises 3 long-running services (mariadb, php-fpm, nginx).
- Service definitions live in `src/box/s6-rc.d/` and are copied to `/etc/s6-overlay/s6-rc.d/` in the image. Three `longrun` services + one `user` bundle that lists them.
- Service run scripts use **execline** (the s6-native shell-replacement). Looks unfamiliar but it's just a chain of binaries.

---

## Workflow / Releases

- **CI builds only on tag push** (`v*`) and manual dispatch — pushes to `main` no longer trigger builds. To release: `git tag v0.x.y && git push --tags`
- The CI workflow uses native amd64 (`ubuntu-latest`) and native arm64 (`ubuntu-24.04-arm`) runners in parallel; no QEMU emulation. Total build time is ~5–8 minutes. Force-pushing a tag cancels in-flight builds (concurrency group `build-${{ github.ref }}`).
- Tags published to Docker Hub: `0.x.y`, `0.x`, `latest`, `sha-...`
- The Docker Hub long description is auto-synced from `README.md` by `.github/workflows/dockerhub-description.yml` on every push to `main` that touches the README.

---

## Docker / Build

- The `php:8.5-fpm-alpine` base does NOT have prebuilt extensions for our PHP version — `docker-php-ext-install` compiles from source. This is unavoidable; GHA layer cache (`type=gha`) handles it for subsequent builds.
- **Don't use `--no-cache`** during local iteration unless you're debugging cache poisoning. Normal `docker build` reuses cached layers and is much faster.
- Recursive `chown -R` and `find ... -exec chmod` on `/var/www/html/vendor` take ~30s each on native, much longer under emulation. Add a progress message before them so build logs aren't confusing.
- Composer dependencies are pinned via the hand-maintained `src/box/composer.json.TEMPLATE` (replacing the auto-generated one). Single `composer install` resolves everything at once.

---

## Flarum Quirks

- Flarum stores post content in an internal XML format (TextFormatter), **not raw HTML**. Direct SQL inserts of HTML into `flarum_posts.content` cause render errors. Always seed posts via the **REST API** so Flarum's formatter processes them correctly.
- The `php flarum install --file=...` command requires a YAML/JSON config file. Quote all values in the YAML to prevent injection.
- The `install.yaml` `driver` field MUST match the runtime database (`mariadb`, not `mysql`). Mismatch breaks Flarum 2.x's driver-specific code paths (e.g. `whenMySql()` in `NotificationSyncer`).
- Group IDs: `1`=Admin, `2`=Guest, `3`=Member, `4`=Mod. The Guest group ID is **2**, not 3 (easy to get wrong).
- The `url` in `config.php` is used by Flarum for asset URLs, API base, email links, CSRF, cookies, OG tags, sitemaps, and more. It's not derivable from the request, especially for CLI/cron contexts. That's why we accept `FLARUM_FORUM_URL` as a runtime override.
- Markdown `~text~` renders as `<sub>text</sub>`. Escape with `\~` in markdown source. In setup.sh JSON-in-shell, that means `\\~` to produce a single backslash in the JSON.
- `php flarum extension:enable` runs as root by default and can create root-owned files in `vendor/`. Re-fix permissions with `chown -R www-data:www-data` and `find ... -type d ! -perm -755 -exec chmod 755` afterwards.
- Some extensions (like `fof/rich-text`) install JS dist files with restrictive perms (700). The web server (running as `www-data`) can't read them. **Always fix permissions BEFORE starting nginx**, not after.

---

## MariaDB

- Use modern command names: `mariadb`, `mariadb-admin`, `mariadbd-safe`, `mariadb-install-db`. The `mysql*` aliases are deprecated.
- The Unix user/group `mysql:mysql`, paths `/var/lib/mysql`, `/run/mysqld`, and the PHP driver `pdo_mysql` are NOT deprecated — leave those alone.
- Alpine MariaDB defaults to `skip-networking=ON` — only the Unix socket works. Use `host: localhost` (not `127.0.0.1`) and configure PHP with `pdo_mysql.default_socket = /run/mysqld/mysqld.sock`.
- For build-time setup: do `SET GLOBAL innodb_fast_shutdown = 0; FLUSH TABLES; mariadb-admin shutdown` to ensure InnoDB data is fully flushed to disk before the layer is captured. Wait for `pidof mariadbd` to be empty.

---

## Sed in Shell Scripts

- Sed replacements with user-controlled strings must escape `&`, `\`, and the delimiter: `ESCAPED=$(echo "$VAR" | sed 's/[&\\|]/\\&/g')`. The `&` is special in sed replacement (means "matched text"), causing nasty bugs in URLs with query strings.
- macOS BSD sed and GNU sed differ — `\b` word boundaries don't work on BSD. Stick to portable patterns or test on Linux (the build target).

---

## Style

- Warnings: keep them short and one-line. Format: `> ⚠️ **Demo/playground image** — fantastic for testing and development, but not for production. Data is ephemeral for the lifetime of the container.`
- Avocado theme is **not green** despite the name. Describe it as: "modern, polished theme with hero banner, tag styling, and rich customization."
- **`nginx`** is always lowercase (official spelling).
- **`PhotoSwipe`** has a capital S in the middle (the library's canonical spelling).
- **`MariaDB`** — not `MariaDb` or `Mariadb`.
- Em-dash separators in titles, not parens: `## Section — qualifier` not `## Section (qualifier)`.
- Tildes near digits in markdown render as subscript — always escape as `\~80` in seed-discussion markdown.

### Extension display names

- **Drop the vendor prefix** in user-facing docs: `Drafts`, not `FoF Drafts`. Keep the `vendor/name` form only when it's the composer-package reference in code voice (backticks) or CHANGELOG.
- In the **announcement post** (`docs/announce-discuss-flarum.md`), link text is NOT bolded: `[Name](url)`, not `[**Name**](url)` (user preference).
- In **README** and **seed discussions**, link text IS bolded: `[**Name**](url)`.
- The **disabled-extensions section** keeps emoji prefixes for visual scanning (🥑, 🎨, 🦶, etc.).

### Link choices

- **Mermaid** the library → always link to `https://mermaid.ai/open-source/`.
- **Mermaid** the Flarum extension → link to its Packagist page (`datlechin/flarum-mermaid`).
- **Move Posts**, **Avocado**, **PhotoSwipe**, **Flamoji** — link to their Discuss threads (canonical home), not Packagist.
- All other extensions — link to Packagist by default.

### Commit messages

- Match the brevity of CHANGELOG entries. One-line subject + a few short bullets. Don't include implementation details, internal reasoning, or step-by-step descriptions of what changed line-by-line. The CHANGELOG is the user-facing summary; the commit message should be similar in tone.

### CHANGELOG

- **Extreme brevity.** One short line per change is ideal.
- Don't list affected files, paths, byte counts, root causes, or implementation details.
- **Use Keep-a-Changelog subsections** (`### Added`, `### Changed`, `### Fixed`, `### Removed`) under each version heading.
- **No parenthetical justifications** ("(was cluttering X)", "(official spelling)").
- **Only user-facing changes belong in the CHANGELOG.** Skip internal cleanups (dead code, redundant build steps), README/docs tweaks, anything that doesn't change behavior or appearance for someone running the image.
- **Version heading format**: `## X.Y.Z — YYYY-MM-DD` (em dash + ISO date).

### Announcement post

- `docs/announce-discuss-flarum.md` is a mirror of [the discuss.flarum.org post](https://discuss.flarum.org/d/39191-flarum-in-a-box-try-flarum-2x-in-one-command-with-docker). The discuss version is **canonical** — when changes are made to one, sync the other.

---

## Extension management — canonical sources

| File | What it controls | Format |
|------|------------------|--------|
| `src/box/composer.json.TEMPLATE` | **What gets installed** in `vendor/` (every extension we ship) | composer JSON `"require"` block, alphabetical |
| `src/box/data/extensions.txt` | **What gets enabled** on first boot (subset of installed) | one extension ID per line, alphabetical, `#` comments allowed |

The composer package name (`vendor/name`) differs from the Flarum extension ID
(`vendor-name` with hyphens, possibly with prefixes stripped). When adding an
extension, both must be added in the right form to the right file.

---

## When ADDING or REMOVING an extension

Run this checklist for **every** extension change. Skipping any step results
in a partial/inconsistent ship.

### Step 1 — Source of truth

- [ ] Add/remove the composer package in **`src/box/composer.json.TEMPLATE`**
  - Keep alphabetical order (composer requires it via `"sort-packages": true`)
  - Use the exact Packagist name (e.g. `fof/photoswipe`, `datlechin/flarum-mermaid`)

- [ ] If enabling by default, add/remove the extension ID in **`src/box/data/extensions.txt`**
  - Use the Flarum extension ID format (hyphens, `flarum-ext-` / `flarum-` prefixes stripped):
    - `fof/photoswipe` → `fof-photoswipe`
    - `datlechin/flarum-mermaid` → `datlechin-mermaid`
    - `antoinefr/flarum-ext-bbcode-fa` → `antoinefr-bbcode-fa`
  - Keep alphabetical order

### Step 2 — User-facing docs

- [ ] Add/remove entry in **`README.md`** "What's Included" section:
  - Pick the appropriate subsection (Composer & posting / Discussions & navigation / User experience / Moderation & admin / Other)
  - For disabled extensions, the "Installed but Not Enabled" section
  - Format: `- [**Name**](link) — One-line description`
  - `link` = Discuss thread URL if known, else Packagist URL

- [ ] Add/remove entry in **`docs/announce-discuss-flarum.md`** "Extensions Pre-Installed" section:
  - Same subsections as README
  - **No bolding inside link text** (`[Name]` not `[**Name**]`)
  - Disabled section keeps emoji prefix + bolding for visual scanning

- [ ] Add/remove entry in **`src/box/data/discussions/02-extensions-guide.md`**:
  - Same subsections as README
  - Bolding inside link text IS used here (matches README style)

### Step 3 — Verify counts match reality

```bash
python3 << 'PY'
import json, re
d = json.load(open('src/box/composer.json.TEMPLATE'))
non_flarum = sorted(k for k in d['require'] if not k.startswith('flarum/'))
with open('src/box/data/extensions.txt') as f:
    enabled = sorted(l.strip() for l in f if l.strip() and not l.strip().startswith('#'))
print(f"composer non-flarum/* count:    {len(non_flarum)}")
print(f"flarum/* bundled count:         {len([k for k in d['require'] if k.startswith('flarum/') and k != 'flarum/core'])}")
print(f"extensions.txt enabled count:   {len(enabled)}")
PY
```

- [ ] Count guidance string (currently `80+`) must remain accurate. If total composer-installed extensions crosses a tens-boundary, update **all 8 places** (see "Extension count consistency" below).

### Step 4 — CHANGELOG entry

- [ ] Add a bullet under the current `### Added` (or `### Removed`) of the new version heading:
  - Composer package name in code voice + linked friendly name
  - Format: `- [Friendly Name](https://packagist.org/packages/vendor/name) (\`vendor/name\`)`
  - For headline-worthy additions (PhotoSwipe-style): lead with emoji + Discuss link

### Step 5 — Seed discussion (only for showcase extensions)

If the extension is a *visual* feature users would want to try immediately
(PhotoSwipe lightbox, Mermaid diagrams, Avocado theme, etc.):

- [ ] Add a seed discussion under `src/box/data/discussions/NN-name.md`
  - Use the next available `NN` prefix
  - Tag with appropriate slug (usually `showcase`)
  - Mention the extension by name and link to its Discuss thread

- [ ] Add entry to `src/box/data/discussions/manifest.json`:
  - JSON object with `file`, `title`, optional `tag` (slug), optional `sticky: true`, optional `replies: [...]`

---

## Extension count consistency

The count phrase (`80+ extensions`) appears in **8 distinct files**. When
the count needs to change, update **all of them** in one PR — partial
updates produce visible inconsistency between README and the welcome banner.

### Find all occurrences

```bash
grep -rnE '~?\\?~?[0-9]+\+?\s*(popular |demo )?extensions?' \
    --include='*.md' --include='*.json' --include='*.yml' \
    --include='*.yaml' --include='Dockerfile' --include='*.TEMPLATE' \
    | grep -v 'Initial release: all-in-one'
```

The `grep -v` excludes the v0.2.0 CHANGELOG entry, which is a historical
record and must NOT be edited retroactively.

### Files to update (current count phrase: `80+`)

| File | Where |
|------|-------|
| `README.md` | Tagline (line ~5): `Flarum 2.x, 80+ extensions, PHP 8.5, MariaDB, and nginx` |
| `docs/announce-discuss-flarum.md` | 3 places: subhead `One command. 80+ extensions.`, intro paragraph `with 80+ popular extensions pre-installed`, section heading `#### 80+ Extensions Pre-Installed` |
| `src/box/data/install.yaml` | `welcome_message:` — the banner on every container's homepage |
| `src/box/data/discussions/01-welcome.md` | Intro line |
| `src/box/data/discussions/02-extensions-guide.md` | Intro line AND the Mermaid mindmap `root((80+ extensions))` |
| `src/box/Dockerfile` | `LABEL org.opencontainers.image.description` |
| `src/box/composer.json.TEMPLATE` | `"description"` field |
| `.github/workflows/dockerhub-description.yml` | `short-description` (Docker Hub listing) |

### Rules for the count phrase

- Use a round friendly number (`80+`, not `84` or `~80`)
- Round UP from the actual count, never down (under-promise the headline, over-deliver in the listings)
- Verify against actual composer total before bumping; ratchet to the next +10 boundary
- Never use `~50` / `~60` / `~70` historical tilde phrasings — replace any stale tilde-form references found

---

## When BUMPING the Flarum core version

- [ ] Update `composer.json.TEMPLATE` `flarum/core` constraint if pinned (otherwise leave `^2.0`)
- [ ] Rebuild locally; verify `php flarum info` reports the expected version
- [ ] Smoke-test seed discussions (Flarum's `NotificationSyncer` has historically been version-sensitive — see CHANGELOG v0.2.10 fix)
- [ ] Lead the next CHANGELOG entry with `### Changed` "Flarum core upgraded to X.Y.Z-rcN"

---

## When ADDING a Mermaid diagram

Mermaid samples are sprinkled across seed discussions (currently 02, 03, 09).
If adding a new one:

- [ ] Use the bundled extension framing: ``rendered with the bundled [**Mermaid**](https://mermaid.ai/open-source/) extension``
- [ ] Link "Mermaid" to `https://mermaid.ai/open-source/` (the library, not the Flarum wrapper)
- [ ] Wrap in `` ```mermaid `` fenced block
- [ ] Mention in the CHANGELOG bullet for `datlechin/flarum-mermaid` if you've added meaningful samples
- [ ] Keep diagrams genuinely instructive — not decorative. Each should teach something the surrounding prose doesn't.

---

## Testing

- After build, verify: HTTP 200 at the mapped port, all 10 seed discussions present, sticky posts pinned, no `ERROR` entries in `/var/www/html/storage/logs/*.log`.
- First boot should be ~8s (DB init step is gone — just `s6-overlay` starting nginx/php-fpm/mariadb).
- Common smoke-test queries inside the container:
  - `php flarum info` — version + DB driver + enabled extensions
  - `mariadb -u root flarum -e "SELECT id,title FROM flarum_discussions"` — verify seed
  - `mariadb -u root flarum -e "SELECT value FROM flarum_settings WHERE \`key\` = 'extensions_enabled'"` — verify enable list

---

## Self-check before commit

Run these three commands. ALL should return zero output (other than the
historical v0.2.0 CHANGELOG line):

```bash
# 1. No stale count references
grep -rnE '~?\\?~?[1-7][0-9]+\+?\s*(popular |demo )?extensions?' \
    --include='*.md' --include='*.json' --include='*.yml' \
    --include='*.yaml' --include='Dockerfile' --include='*.TEMPLATE' \
    | grep -v 'Initial release: all-in-one'

# 2. composer.json.TEMPLATE and extensions.txt are in sync
python3 -c "
import json
d = json.load(open('src/box/composer.json.TEMPLATE'))
installed = set(k for k in d['require'] if k != 'flarum/core' and not k.startswith('flarum/'))
with open('src/box/data/extensions.txt') as f:
    enabled = set(l.strip() for l in f if l.strip() and not l.strip().startswith('#'))
def to_id(pkg):
    vendor, name = pkg.split('/')
    name = name.replace('flarum-ext-', '').replace('flarum-', '')
    return f'{vendor}-{name}'
# every enabled ID must correspond to an installed package
orphans = enabled - {to_id(p) for p in installed} - {'flarum-extension-manager'}
if orphans: print('ENABLED IDs with no installed package:', orphans)
"

# 3. manifest.json validates as JSON and references real files
python3 -c "
import json, os
m = json.load(open('src/box/data/discussions/manifest.json'))
d = 'src/box/data/discussions'
for entry in m:
    assert os.path.exists(os.path.join(d, entry['file'])), f\"missing {entry['file']}\"
    for r in entry.get('replies', []):
        assert os.path.exists(os.path.join(d, r['file'])), f\"missing {r['file']}\"
print(f'{len(m)} discussions, all files exist')
"
```

If any check fails, fix before committing.
