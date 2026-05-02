#!/bin/sh
set -e

# ── Configuration (from environment variables) ───────────────────────
FLARUM_DB_HOST="${FLARUM_DB_HOST:-localhost}"
FLARUM_DB_NAME="${FLARUM_DB_NAME:-flarum}"
FLARUM_DB_USER="${FLARUM_DB_USER:-flarum}"
FLARUM_DB_PASS="${FLARUM_DB_PASS:-flarum}"
FLARUM_DB_PREFIX="${FLARUM_DB_PREFIX:-flarum_}"
FLARUM_ADMIN_USER="${FLARUM_ADMIN_USER:-admin}"
FLARUM_ADMIN_PASS="${FLARUM_ADMIN_PASS:-password}"
FLARUM_ADMIN_EMAIL="${FLARUM_ADMIN_EMAIL:-admin@example.com}"
FLARUM_FORUM_TITLE="${FLARUM_FORUM_TITLE:-📦 Flarum-In-A-Box}"
FLARUM_FORUM_URL="${FLARUM_FORUM_URL:-http://localhost:8080}"

MARKER_FILE="/var/lib/mysql/.flarum-initialized"

# ── Initialize MariaDB data directory if needed ──────────────────────
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "==> Initializing MariaDB data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
fi

# ── Start temporary MariaDB for setup ────────────────────────────────
echo "==> Starting MariaDB for initialization..."
mysqld_safe &
MYSQLD_PID=$!

# Wait for MariaDB to be ready
echo "==> Waiting for MariaDB..."
for i in $(seq 1 30); do
    if mysqladmin ping --silent 2>/dev/null; then
        echo "    MariaDB is ready."
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "    ERROR: MariaDB failed to start within 30 seconds."
        exit 1
    fi
    sleep 1
done

# ── Create database and user if needed ───────────────────────────────
echo "==> Ensuring database and user exist..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${FLARUM_DB_NAME}\`;"
mysql -u root -e "GRANT ALL ON \`${FLARUM_DB_NAME}\`.* TO '${FLARUM_DB_USER}'@'${FLARUM_DB_HOST}' IDENTIFIED BY '${FLARUM_DB_PASS}'; FLUSH PRIVILEGES;"
mysql -u root -e "GRANT ALL ON \`${FLARUM_DB_NAME}\`.* TO '${FLARUM_DB_USER}'@'localhost' IDENTIFIED BY '${FLARUM_DB_PASS}'; FLUSH PRIVILEGES;"

# ── Install or migrate Flarum ────────────────────────────────────────
cd /var/www/html

if [ ! -f "/var/www/html/config.php" ]; then
    echo "==> First run — installing Flarum..."

    # Generate install config YAML
    cat > /tmp/flarum-install.yaml <<YAML
baseUrl: "${FLARUM_FORUM_URL}"
databaseConfiguration:
  driver: mysql
  host: "${FLARUM_DB_HOST}"
  port: 3306
  database: "${FLARUM_DB_NAME}"
  username: "${FLARUM_DB_USER}"
  password: "${FLARUM_DB_PASS}"
  prefix: "${FLARUM_DB_PREFIX}"
adminUser:
  username: "${FLARUM_ADMIN_USER}"
  password: "${FLARUM_ADMIN_PASS}"
  email: "${FLARUM_ADMIN_EMAIL}"
settings:
  forum_title: "${FLARUM_FORUM_TITLE}"
  welcome_title: "👋 Welcome to Flarum-In-A-Box!"
  welcome_message: "A ready-to-run Flarum 2.x demo from 🎹 Piano | Tell — with 45+ extensions pre-installed. Log in as admin/password or sign up to explore!"
YAML

    php flarum install --file=/tmp/flarum-install.yaml
    rm -f /tmp/flarum-install.yaml

    # Fix ownership so the web server can write to storage and assets
    chown -R www-data:www-data /var/www/html/config.php /var/www/html/storage /var/www/html/public/assets
    chmod -R 775 /var/www/html/storage /var/www/html/public/assets

    # ── Enable extensions ────────────────────────────────────────────
    # Flarum install enables bundled extensions. Now enable additional ones.
    echo "==> Enabling additional extensions..."
    ENABLE_EXTENSIONS="
        flarum-extension-manager
        pianotell-flamoji
        fof-best-answer
        fof-byobu
        fof-drafts
        fof-follow-tags
        fof-formatting
        fof-polls
        fof-upload
        fof-user-bio
        fof-user-directory
        fof-ignore-users
        fof-linguist
        fof-categories
        fof-links
        fof-sitemap
        fof-frontpage
        fof-gamification
        fof-moderator-notes
        fof-reactions
        fof-synopsis
        fof-impersonate
        fof-split
        fof-merge-discussions
        fof-bbcode-details
        fof-discussion-views
        antoinefr-bbcode-fa
        sycho-move-posts
        sycho-profile-cover
        acpl-mobile-tab
        ekumanov-post-search
        ekumanov-forum-widgets
        ekumanov-markdown-tables
        ekumanov-inline-audio
        tryhackx-topic-rating
        fof-rich-text
        huseyinfiliz-stickiest
        huseyinfiliz-diff
        linkrobins-auto-verify
    "
    for ext_id in $ENABLE_EXTENSIONS; do
        echo "    Enabling $ext_id ..."
        php flarum extension:enable "$ext_id" 2>&1 \
            || echo "    ⚠ Could not enable $ext_id"
    done

    # Fix any root-owned files created during extension enabling
    chown -R www-data:www-data /var/www/html/public/assets /var/www/html/storage
    find /var/www/html/vendor -user root -exec chown www-data:www-data {} \; 2>/dev/null
    find /var/www/html/vendor -type d ! -perm -755 -exec chmod 755 {} \; 2>/dev/null

    # Extensions installed but NOT enabled by default:
    # - ramon/avocado (theme)
    # - ramon/colored
    # - huseyinfiliz/modern-footer
    # - linkrobins/font-sizer
    # - fof/terms
    # - fof/share-social
    # - fof/pages
    # - fof/discussion-thumbnail
    # - fof/anti-spam

    # ── Configure extension settings ─────────────────────────────────
    echo "==> Configuring extension defaults..."
    mysql -u root "${FLARUM_DB_NAME}" -e "
        INSERT INTO flarum_settings (\`key\`, value) VALUES
            ('fof-formatting.plugin.autoimage', '1'),
            ('fof-formatting.plugin.autovideo', '1'),
            ('fof-formatting.plugin.mediaembed', '1'),
            ('fof-drafts.enable_scheduled_drafts', '0')
        ON DUPLICATE KEY UPDATE value=VALUES(value);
    " 2>/dev/null || true

    # ── Configure mail driver to 'log' (no sendmail in container) ────
    echo "==> Configuring mail..."
    mysql -u root "${FLARUM_DB_NAME}" -e "
        INSERT INTO flarum_settings (\`key\`, value)
        VALUES ('mail_driver', 'log')
        ON DUPLICATE KEY UPDATE value='log';
    " 2>/dev/null || true

    # ── Create sample tags ──────────────────────────────────────────────
    echo "==> Creating sample tags..."
    mysql -u root "${FLARUM_DB_NAME}" -e "
        INSERT INTO flarum_tags (id, name, slug, description, color, icon, is_primary, position)
        VALUES
            (2, 'Announcements', 'announcements', 'Official announcements and news', '#e74c3c', 'fas fa-bullhorn', 1, 1),
            (3, 'Support', 'support', 'Ask questions and get help', '#3498db', 'fas fa-life-ring', 1, 2),
            (4, 'Feedback', 'feedback', 'Share ideas, suggestions, and feature requests', '#2ecc71', 'fas fa-comment-dots', 1, 3),
            (5, 'Showcase', 'showcase', 'Show off what you have built', '#9b59b6', 'fas fa-star', 1, 4),
            (6, 'Off-Topic', 'off-topic', 'Chat about anything and everything', '#f39c12', 'fas fa-coffee', 1, 5),
            (7, 'Guides', 'guides', 'Tutorials, how-tos, and documentation', '#1abc9c', 'fas fa-book', 0, NULL),
            (8, 'Bugs', 'bugs', 'Report issues and bugs', '#e67e22', 'fas fa-bug', 0, NULL)
        ON DUPLICATE KEY UPDATE name=VALUES(name);
    " 2>&1 || echo "    ⚠ Tag seeding skipped"

    # ── Fix permissions ──────────────────────────────────────────────
    echo "==> Setting permissions..."
    mysql -u root "${FLARUM_DB_NAME}" -e "
        INSERT IGNORE INTO flarum_group_permission (group_id, permission, created_at)
        VALUES 
            (2, 'fof.gamification.viewRankingPage', NOW()),
            (2, 'searchUsers', NOW());
    " 2>/dev/null || true

    # ── Sticky the welcome and extensions posts ──────────────────────
    # (applied after seeding since discussion IDs are assigned at creation)
    STICKY_WELCOME_AND_EXTENSIONS=true

    # ── Seed demo content via API ──────────────────────────────────────
    # Flarum stores posts in internal XML format — must use the API, not raw SQL.
    if [ ! -f "$MARKER_FILE" ]; then
        echo "==> Seeding demo content..."

        # Get an API token for admin
        API_TOKEN=$(mysql -u root "${FLARUM_DB_NAME}" -sNe "
            INSERT INTO flarum_api_keys (id, \`key\`, user_id, created_at)
            VALUES (1, 'flarum-in-a-box-seed-token', 1, NOW())
            ON DUPLICATE KEY UPDATE \`key\`='flarum-in-a-box-seed-token';
            SELECT 'flarum-in-a-box-seed-token';
        " 2>/dev/null) || true

        if [ -n "$API_TOKEN" ]; then
            # Start Nginx + PHP-FPM temporarily for API calls
            php-fpm --daemonize 2>/dev/null
            nginx 2>/dev/null
            echo "    Waiting for web server..."
            for i in $(seq 1 30); do
                if curl -s -o /dev/null http://127.0.0.1:80 2>/dev/null; then
                    break
                fi
                if [ "$i" -eq 30 ]; then
                    echo "    ⚠ Web server did not start in time, skipping seed content"
                fi
                sleep 1
            done

            # Post 1: Welcome
            curl -s -X POST http://127.0.0.1:80/api/discussions \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "discussions",
                        "attributes": {
                            "title": "👋 Welcome to Flarum-In-A-Box!",
                            "content": "## 👋 Welcome to Flarum-In-A-Box!\n\n**Flarum-In-A-Box** is a ready-to-run, all-in-one Docker container from [🎹 Piano | Tell](https://pianotell.com) that gives you a fully working **Flarum 2.x** forum with 45+ extensions pre-installed. No setup, no configuration — just launch and go.\n\n### What is it good for?\n\n- 🧪 **Demo & Evaluation** — Quickly show off Flarum to stakeholders, clients, or your team without setting up a server\n- 💻 **Extension Development** — A clean, reproducible Flarum environment to build and test extensions against\n- 📚 **Learning & Experimentation** — Explore Flarum features, try out extensions, and learn how everything works\n- 🏗️ **Theme Development** — Test themes like the included **Avocado** theme in a real Flarum instance\n- 🎓 **Workshops & Training** — Spin up identical instances for every participant in minutes\n\n### Default Accounts\n\n| Account | Username | Password |\n|---------|----------|----------|\n| Admin | `admin` | `password` |\n| User | `user` | `password` |\n\nThe admin account has full access to the Admin Panel (click your avatar → Administration). New users can sign up without email confirmation.\n\n### Important Notes\n\n- ⚠️ This is a **demo/playground** — not intended for production use\n- 🔑 Change the default passwords if exposing this beyond localhost\n- 💾 Data persists across container restarts but is lost on `docker rm`\n- 🔄 To reset everything: `docker rm -f flarum-in-a-box` then run again\n\nHave fun exploring Flarum! 🚀"
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Welcome post created" || echo "    ⚠ Welcome post skipped"

            # Post 2: Extensions Guide
            curl -s -X POST http://127.0.0.1:80/api/discussions \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "discussions",
                        "attributes": {
                            "title": "Getting Started with Extensions",
                            "content": "## Extensions Guide\n\nThis instance comes with **45+ extensions** installed. Visit **Admin Panel → Extensions** to see and configure them all.\n\n### Enabled by Default\n\nCore: Tags, Likes, Mentions, Lock, Sticky, Suspend, Markdown, BBCode, Emoji, Flags, Nicknames, Subscriptions, Approval, Statistics\n\nCommunity favorites: **Flamoji** (emoji picker), **Upload**, **Polls**, **Best Answer**, **Byobu** (private discussions), **Drafts**, **Reactions**, **Rich Text**, **Gamification** (voting & rankings), **Profile Cover**, **Mobile Tab**, **Categories**, **Stickiest**, **Diff** (edit history), **Synopsis**, **Discussion Views**, **Impersonate**, **Split/Merge**, **Topic Rating**, **Post Search**, **Forum Widgets**, **Markdown Tables**, **Inline Audio**, and more.\n\n### Installed but Not Enabled\n\nSome extensions are installed but disabled by default — try them out!\n\n- 🥑 **Avocado** — A gorgeous green theme that transforms your forum (see the dedicated post about it!)\n- 🎨 **Colored** — Colorful usernames by group\n- 🦶 **Modern Footer** — Responsive footer\n- 📄 **FoF Pages** — Custom static pages\n- 🖼️ **FoF Discussion Thumbnail** — Thumbnails in discussion list\n- 🤝 **FoF Terms** — Terms of service acceptance\n- 📣 **FoF Share Social** — Social media sharing\n- 🛡️ **FoF Anti Spam** — Spam prevention\n\nEnable any of them from the Admin Panel → Extensions.\n\n### Installing More Extensions\n\nThe **Extension Manager** is enabled — search for and install additional extensions directly from the Admin Panel, no command line needed.\n\n### Feedback\n\nHave ideas or found a bug? Visit our [GitHub repository](https://github.com/PrimateCoder/flarum-in-a-box) to open an issue or contribute."
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Extensions guide post created" || echo "    ⚠ Extensions guide post skipped"

            # Create a regular 'user' account
            curl -s -X POST http://127.0.0.1:80/api/users \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "users",
                        "attributes": {
                            "username": "user",
                            "email": "user@example.com",
                            "password": "password",
                            "isEmailConfirmed": true
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Regular user account created" || echo "    ⚠ User account skipped"

            # Additional seed discussions in various tags
            curl -s -X POST http://127.0.0.1:80/api/discussions \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "discussions",
                        "attributes": {
                            "title": "Tips for Customizing Your Forum",
                            "content": "Here are some quick tips to make your Flarum forum your own:\n\n1. **Change the logo** — Admin Panel → Appearance → Logo\n2. **Pick a theme color** — Admin Panel → Appearance → Colors\n3. **Set a custom header** — Add HTML in Admin Panel → Appearance → Custom Header\n4. **Try the Avocado theme** — Enable it from Admin Panel → Extensions for a fresh look\n5. **Configure tags** — Organize your discussions with custom tags and colors\n\nFlarum is designed to be simple yet powerful. Explore the admin panel to discover all the options!"
                        },
                        "relationships": {
                            "tags": {"data": [{"type": "tags", "id": "7"}]}
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Customization tips post created" || echo "    ⚠ Customization tips post skipped"

            curl -s -X POST http://127.0.0.1:80/api/discussions \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "discussions",
                        "attributes": {
                            "title": "How to Create a Poll",
                            "content": "The **Polls** extension is enabled! Here is how to use it:\n\n1. Click **Start a Discussion**\n2. Write your question in the title and body\n3. Click the **poll icon** in the toolbar (bar chart icon)\n4. Add your poll options\n5. Set whether users can change their vote\n6. Post your discussion!\n\nPolls are a great way to gather community feedback and make decisions together. Try creating one now!"
                        },
                        "relationships": {
                            "tags": {"data": [{"type": "tags", "id": "7"}]}
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Poll guide post created" || echo "    ⚠ Poll guide post skipped"

            curl -s -X POST http://127.0.0.1:80/api/discussions \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "discussions",
                        "attributes": {
                            "title": "What features would you like to see?",
                            "content": "If you could add any feature to this demo, what would it be?\n\nSome ideas to get the conversation started:\n\n- More sample content and users?\n- A specific extension you would like to see included?\n- Better default theme or styling?\n- Integration examples?\n\nFeel free to share your thoughts! This is a great place to test the **Polls** and **Reactions** extensions too."
                        },
                        "relationships": {
                            "tags": {"data": [{"type": "tags", "id": "4"}]}
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Feedback post created" || echo "    ⚠ Feedback post skipped"

            curl -s -X POST http://127.0.0.1:80/api/discussions \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "discussions",
                        "attributes": {
                            "title": "Try the Emoji Picker! 🎉",
                            "content": "The [**Flamoji**](https://discuss.flarum.org/d/39130-new-flamoji-emoji-picker-extension-for-flarum) extension adds a visual emoji picker to your posts. Try it out:\n\n1. Start writing a reply or new discussion\n2. Click the **smiley face icon** 😊 in the text editor toolbar\n3. Browse or search for emoji\n4. Click to insert!\n\nHere are some to get you started: 🚀 🎸 🌮 🐱 💡 🎨 🔥 ✨\n\nFlamoji works alongside Flarum'\''s built-in emoji extension to give you the best emoji experience."
                        },
                        "relationships": {
                            "tags": {"data": [{"type": "tags", "id": "5"}]}
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Emoji picker post created" || echo "    ⚠ Emoji picker post skipped"

            curl -s -X POST http://127.0.0.1:80/api/discussions \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "discussions",
                        "attributes": {
                            "title": "Coffee break ☕ — What are you working on?",
                            "content": "Take a break and share what you are working on today!\n\nWhether it is a side project, learning something new, or just browsing forums — we would love to hear about it.\n\nThis is also a great place to test out **Byobu** (private discussions) — try clicking the lock icon when creating a discussion to make it private between specific users."
                        },
                        "relationships": {
                            "tags": {"data": [{"type": "tags", "id": "6"}]}
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Off-topic post created" || echo "    ⚠ Off-topic post skipped"

            # Post: Avocado Theme
            curl -s -X POST http://127.0.0.1:80/api/discussions \
                -H "Authorization: Token ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "data": {
                        "type": "discussions",
                        "attributes": {
                            "title": "🥑 Try the Avocado Theme!",
                            "content": "## 🥑 Avocado — A Beautiful Theme for Flarum\n\nOne of the most eye-catching extensions included in Flarum-In-A-Box is [**Avocado**](https://discuss.flarum.org/d/38940-avocado-theme) by [ramon](https://discuss.flarum.org/u/ramon) — a gorgeous green-themed design that completely transforms the look and feel of your forum.\n\n### How to Enable It\n\n1. Log in as **admin** (password: `password`)\n2. Go to **Admin Panel → Extensions**\n3. Find **Avocado** and click to enable it\n4. Refresh the page — enjoy the new look!\n\n### What It Changes\n\n- 🎨 Fresh green color palette throughout the forum\n- 🌿 Modern, clean design with smooth styling\n- 📱 Fully responsive — looks great on mobile too\n- 🌙 Works well with dark/light modes\n\n### Why Try It?\n\nAvocado is a great example of how Flarum themes can dramatically change the user experience with just one click. It is perfect for:\n\n- Seeing how theme extensions work in Flarum\n- Getting inspiration for your own forum styling\n- Showing stakeholders different visual options\n\nGive it a try and see the difference! You can always disable it to go back to the default look."
                        },
                        "relationships": {
                            "tags": {"data": [{"type": "tags", "id": "5"}]}
                        }
                    }
                }' > /dev/null 2>&1 && echo "    ✓ Avocado theme post created" || echo "    ⚠ Avocado theme post skipped"

            # Clean up: remove seed token and stop temporary web server
            mysql -u root "${FLARUM_DB_NAME}" -e "DELETE FROM flarum_api_keys WHERE id = 1;" 2>/dev/null || true
            nginx -s stop 2>/dev/null || true
            # Kill all php-fpm processes (master + workers)
            kill $(pidof php-fpm) 2>/dev/null || true
            # Ensure processes are stopped before supervisord takes over
            for i in $(seq 1 10); do
                if ! pidof nginx > /dev/null 2>&1 && ! pidof php-fpm > /dev/null 2>&1; then break; fi
                kill $(pidof php-fpm) 2>/dev/null || true
                sleep 1
            done

            # Sticky the Welcome and Extensions posts
            if [ "$STICKY_WELCOME_AND_EXTENSIONS" = "true" ]; then
                echo "==> Stickying welcome posts..."
                mysql -u root "${FLARUM_DB_NAME}" -e "
                    UPDATE flarum_discussions SET is_sticky = 1
                    WHERE title LIKE '%Welcome to Flarum-In-A-Box%'
                       OR title LIKE '%Getting Started with Extensions%';
                " 2>/dev/null || true
            fi
        else
            echo "    ⚠ Could not create API token, skipping seed content"
        fi

        touch "$MARKER_FILE"
    fi

    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║         Flarum-in-a-Box is ready!            ║"
    echo "╠══════════════════════════════════════════════╣"
    echo "║  URL:      ${FLARUM_FORUM_URL}"
    echo "║  Admin:    ${FLARUM_ADMIN_USER}"
    echo "║  Password: ${FLARUM_ADMIN_PASS}"
    echo "╚══════════════════════════════════════════════╝"
    echo ""

else
    echo "==> Existing installation found — running migrations..."
    php flarum migrate 2>&1 || true

    echo "==> Flarum-in-a-Box is ready at ${FLARUM_FORUM_URL}"
fi

# ── Stop temporary MariaDB ───────────────────────────────────────────
echo "==> Stopping temporary MariaDB..."
mysqladmin shutdown 2>/dev/null || true
wait $MYSQLD_PID 2>/dev/null || true

# ── Hand off to supervisord ──────────────────────────────────────────
echo "==> Starting services via supervisord..."
exec "$@"
