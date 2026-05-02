#!/bin/sh
# Build-time setup: runs during docker build to pre-populate the database
# and configure Flarum so the container starts instantly at runtime.
set -e

echo "==> Initializing MariaDB data directory..."
mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld

echo "==> Starting MariaDB..."
mysqld_safe &
for i in $(seq 1 30); do
    if mysqladmin ping --silent 2>/dev/null; then break; fi
    if [ "$i" -eq 30 ]; then echo "ERROR: MariaDB failed to start"; exit 1; fi
    sleep 1
done
echo "    MariaDB is ready."

# ── Create database and user ─────────────────────────────────────────
mysql -u root -e "CREATE DATABASE flarum;"
mysql -u root -e "GRANT ALL ON flarum.* TO 'flarum'@'localhost' IDENTIFIED BY 'flarum'; FLUSH PRIVILEGES;"

# ── Install Flarum ───────────────────────────────────────────────────
cd /var/www/html
cat > /tmp/flarum-install.yaml <<'YAML'
baseUrl: "http://localhost:8080"
databaseConfiguration:
  driver: mysql
  host: "localhost"
  port: 3306
  database: "flarum"
  username: "flarum"
  password: "flarum"
  prefix: "flarum_"
adminUser:
  username: "admin"
  password: "password"
  email: "admin@example.com"
settings:
  forum_title: "📦 Flarum-In-A-Box"
  welcome_title: "👋 Welcome to Flarum-In-A-Box!"
  welcome_message: "A ready-to-run Flarum 2.x demo from 🎹 Piano | Tell — with ~50 extensions pre-installed. Log in as admin/password or sign up to explore!"
YAML

php flarum install --file=/tmp/flarum-install.yaml
rm -f /tmp/flarum-install.yaml

# ── Enable extensions ────────────────────────────────────────────────
echo "==> Enabling extensions..."
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

# ── Configure extension settings ─────────────────────────────────────
echo "==> Configuring settings..."
mysql -u root flarum -e "
    INSERT INTO flarum_settings (\`key\`, value) VALUES
        ('fof-formatting.plugin.autoimage', '1'),
        ('fof-formatting.plugin.autovideo', '1'),
        ('fof-formatting.plugin.mediaembed', '1'),
        ('fof-drafts.enable_scheduled_drafts', '0'),
        ('mail_driver', 'log')
    ON DUPLICATE KEY UPDATE value=VALUES(value);
"

# ── Create sample tags ───────────────────────────────────────────────
echo "==> Creating tags..."
mysql -u root flarum -e "
    INSERT INTO flarum_tags (id, name, slug, description, color, icon, is_primary, position) VALUES
        (2, 'Announcements', 'announcements', 'Official announcements and news', '#e74c3c', 'fas fa-bullhorn', 1, 1),
        (3, 'Support', 'support', 'Ask questions and get help', '#3498db', 'fas fa-life-ring', 1, 2),
        (4, 'Feedback', 'feedback', 'Share ideas, suggestions, and feature requests', '#2ecc71', 'fas fa-comment-dots', 1, 3),
        (5, 'Showcase', 'showcase', 'Show off what you have built', '#9b59b6', 'fas fa-star', 1, 4),
        (6, 'Off-Topic', 'off-topic', 'Chat about anything and everything', '#f39c12', 'fas fa-coffee', 1, 5),
        (7, 'Guides', 'guides', 'Tutorials, how-tos, and documentation', '#1abc9c', 'fas fa-book', 0, NULL),
        (8, 'Bugs', 'bugs', 'Report issues and bugs', '#e67e22', 'fas fa-bug', 0, NULL)
    ON DUPLICATE KEY UPDATE name=VALUES(name);
"

# ── Set permissions for guests ───────────────────────────────────────
mysql -u root flarum -e "
    INSERT IGNORE INTO flarum_group_permission (group_id, permission, created_at) VALUES
        (2, 'fof.gamification.viewRankingPage', NOW()),
        (2, 'searchUsers', NOW());
"

# ── Fix file permissions BEFORE starting web server ──────────────────
# Some extensions (fof/rich-text) install files with restrictive perms
# that prevent www-data from reading them. Must fix before starting nginx.
chown -R www-data:www-data /var/www/html/config.php /var/www/html/storage /var/www/html/public/assets
chmod -R 775 /var/www/html/storage /var/www/html/public/assets
find /var/www/html/vendor -user root -exec chown www-data:www-data {} \; 2>/dev/null
find /var/www/html/vendor -type d ! -perm -755 -exec chmod 755 {} \; 2>/dev/null

# ── Seed demo content via API ────────────────────────────────────────
echo "==> Seeding demo content..."
mysql -u root flarum -e "
    INSERT INTO flarum_api_keys (id, \`key\`, user_id, created_at)
    VALUES (1, 'build-seed-token', 1, NOW());
"

echo "    Starting PHP-FPM and Nginx..."
php-fpm --daemonize
nginx
echo "    Waiting for HTTP..."
for i in $(seq 1 30); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80 2>&1)
    if [ "$HTTP_CODE" = "200" ]; then break; fi
    if [ "$i" -eq 30 ]; then
        echo "    ERROR: HTTP not ready after 30s. Last code: $HTTP_CODE"
        exit 1
    fi
    sleep 1
done
echo "    HTTP ready."

API="http://127.0.0.1:80/api"
AUTH="Authorization: Token build-seed-token"
CT="Content-Type: application/json"

# Helper: post a discussion via API
post_discussion() {
    local title="$1"
    local content="$2"
    local tag_id="$3"
    local rels=""
    if [ -n "$tag_id" ]; then
        rels=', "relationships": {"tags": {"data": [{"type": "tags", "id": "'"$tag_id"'"}]}}'
    fi
    HTTP=$(curl -s -o /tmp/api_resp -w "%{http_code}" -X POST "$API/discussions" \
        -H "$AUTH" -H "$CT" \
        -d "{\"data\": {\"type\": \"discussions\", \"attributes\": {\"title\": $title, \"content\": $content}$rels}}")
    if [ "$HTTP" = "201" ] || [ "$HTTP" = "200" ]; then
        echo "    ✓ $1"
    else
        echo "    ✗ HTTP $HTTP — $(head -c 200 /tmp/api_resp)"
    fi
}

# Welcome post
post_discussion \
    '"👋 Welcome to Flarum-In-A-Box!"' \
    '"## 👋 Welcome to Flarum-In-A-Box!\n\n**Flarum-In-A-Box** is a ready-to-run, all-in-one Docker container from [🎹 Piano | Tell](https://pianotell.com) that gives you a fully working **Flarum 2.x** forum with ~50 extensions pre-installed. No setup, no configuration — just launch and go.\n\n### What is it good for?\n\n- 🧪 **Demo & Evaluation** — Quickly show off Flarum to stakeholders, clients, or your team without setting up a server\n- 💻 **Extension Development** — A clean, reproducible Flarum environment to build and test extensions against\n- 📚 **Learning & Experimentation** — Explore Flarum features, try out extensions, and learn how everything works\n- 🏗️ **Theme Development** — Test themes like the included **Avocado** theme in a real Flarum instance\n- 🎓 **Workshops & Training** — Spin up identical instances for every participant in minutes\n\n### Default Accounts\n\n| Account | Username | Password |\n|---------|----------|----------|\n| Admin | `admin` | `password` |\n| User | `user` | `password` |\n\nThe admin account has full access to the Admin Panel (click your avatar → Administration). New users can sign up without email confirmation.\n\n### Important Notes\n\n- ⚠️ This is a **demo/playground** — not intended for production use\n- 🔑 Change the default passwords if exposing this beyond localhost\n- 💾 Data persists across container restarts but is lost on `docker rm`\n- 🔄 To reset everything: `docker rm -f flarum-in-a-box` then run again\n\nHave fun exploring Flarum! 🚀"' \
    ""

# Extensions guide
post_discussion \
    '"Getting Started with Extensions"' \
    '"## Extensions Guide\n\nThis instance comes with **~50 extensions** installed. Visit **Admin Panel → Extensions** to see and configure them all.\n\n### Enabled by Default\n\nCore: Tags, Likes, Mentions, Lock, Sticky, Suspend, Markdown, BBCode, Emoji, Flags, Nicknames, Subscriptions, Approval, Statistics\n\nCommunity favorites: **Flamoji** (emoji picker), **Upload**, **Polls**, **Best Answer**, **Byobu** (private discussions), **Drafts**, **Reactions**, **Rich Text**, **Gamification** (voting & rankings), **Profile Cover**, **Mobile Tab**, **Categories**, **Stickiest**, **Diff** (edit history), **Synopsis**, **Discussion Views**, **Impersonate**, **Split/Merge**, **Topic Rating**, **Post Search**, **Forum Widgets**, **Markdown Tables**, **Inline Audio**, and more.\n\n### Installed but Not Enabled\n\nSome extensions are installed but disabled by default — try them out!\n\n- 🥑 **Avocado** — A gorgeous green theme that transforms your forum (see the dedicated post about it!)\n- 🎨 **Colored** — Colorful usernames by group\n- 🦶 **Modern Footer** — Responsive footer\n- 🔤 **Font Sizer** — Adjustable font sizes\n- 📄 **FoF Pages** — Custom static pages\n- 🖼️ **FoF Discussion Thumbnail** — Thumbnails in discussion list\n- 🤝 **FoF Terms** — Terms of service acceptance\n- 📣 **FoF Share Social** — Social media sharing\n- 🛡️ **FoF Anti Spam** — Spam prevention\n\nEnable any of them from the Admin Panel → Extensions.\n\n### Installing More Extensions\n\nThe **Extension Manager** is enabled — search for and install additional extensions directly from the Admin Panel, no command line needed.\n\n### Feedback\n\nHave ideas or found a bug? Visit our [GitHub repository](https://github.com/PrimateCoder/flarum-in-a-box) to open an issue or contribute."' \
    ""

# Customization tips
post_discussion \
    '"Tips for Customizing Your Forum"' \
    '"Here are some quick tips to make your Flarum forum your own:\n\n1. **Change the logo** — Admin Panel → Appearance → Logo\n2. **Pick a theme color** — Admin Panel → Appearance → Colors\n3. **Set a custom header** — Add HTML in Admin Panel → Appearance → Custom Header\n4. **Try the Avocado theme** — Enable it from Admin Panel → Extensions for a fresh look\n5. **Configure tags** — Organize your discussions with custom tags and colors\n\nFlarum is designed to be simple yet powerful. Explore the admin panel to discover all the options!"' \
    "7"

# Poll guide
post_discussion \
    '"How to Create a Poll"' \
    '"The **Polls** extension is enabled! Here is how to use it:\n\n1. Click **Start a Discussion**\n2. Write your question in the title and body\n3. Click the **poll icon** in the toolbar (bar chart icon)\n4. Add your poll options\n5. Set whether users can change their vote\n6. Post your discussion!\n\nPolls are a great way to gather community feedback and make decisions together. Try creating one now!"' \
    "7"

# Feedback
post_discussion \
    '"What features would you like to see?"' \
    '"If you could add any feature to this demo, what would it be?\n\nSome ideas to get the conversation started:\n\n- More sample content and users?\n- A specific extension you would like to see included?\n- Better default theme or styling?\n- Integration examples?\n\nFeel free to share your thoughts! This is a great place to test the **Polls** and **Reactions** extensions too."' \
    "4"

# Emoji picker
post_discussion \
    '"Try the Emoji Picker! 🎉"' \
    '"The [**Flamoji**](https://discuss.flarum.org/d/39130-new-flamoji-emoji-picker-extension-for-flarum) extension adds a visual emoji picker to your posts. Try it out:\n\n1. Start writing a reply or new discussion\n2. Click the **smiley face icon** 😊 in the text editor toolbar\n3. Browse or search for emoji\n4. Click to insert!\n\nHere are some to get you started: 🚀 🎸 🌮 🐱 💡 🎨 🔥 ✨\n\nFlamoji works alongside Flarum'\''s built-in emoji extension to give you the best emoji experience."' \
    "5"

# Off-topic
post_discussion \
    '"Coffee break ☕ — What are you working on?"' \
    '"Take a break and share what you are working on today!\n\nWhether it is a side project, learning something new, or just browsing forums — we would love to hear about it.\n\nThis is also a great place to test out **Byobu** (private discussions) — try clicking the lock icon when creating a discussion to make it private between specific users."' \
    "6"

# Avocado theme
post_discussion \
    '"🥑 Try the Avocado Theme!"' \
    '"## 🥑 Avocado — A Beautiful Theme for Flarum\n\nOne of the most eye-catching extensions included in Flarum-In-A-Box is [**Avocado**](https://discuss.flarum.org/d/38940-avocado-theme) by [ramon](https://discuss.flarum.org/u/ramon) — a gorgeous green-themed design that completely transforms the look and feel of your forum.\n\n### How to Enable It\n\n1. Log in as **admin** (password: `password`)\n2. Go to **Admin Panel → Extensions**\n3. Find **Avocado** and click to enable it\n4. Refresh the page — enjoy the new look!\n\n### What It Changes\n\n- 🎨 Fresh green color palette throughout the forum\n- 🌿 Modern, clean design with smooth styling\n- 📱 Fully responsive — looks great on mobile too\n- 🌙 Works well with dark/light modes\n\n### Why Try It?\n\nAvocado is a great example of how Flarum themes can dramatically change the user experience with just one click. It is perfect for:\n\n- Seeing how theme extensions work in Flarum\n- Getting inspiration for your own forum styling\n- Showing stakeholders different visual options\n\nGive it a try and see the difference! You can always disable it to go back to the default look."' \
    "5"

# Create regular user account
HTTP=$(curl -s -o /tmp/api_resp -w "%{http_code}" -X POST "$API/users" \
    -H "$AUTH" -H "$CT" \
    -d '{"data": {"type": "users", "attributes": {"username": "user", "email": "user@example.com", "password": "password", "isEmailConfirmed": true}}}')
if [ "$HTTP" = "201" ] || [ "$HTTP" = "200" ]; then
    echo "    ✓ User account 'user' created"
else
    echo "    ✗ User account creation failed: HTTP $HTTP"
fi

# Sticky welcome posts
mysql -u root flarum -e "
    UPDATE flarum_discussions SET is_sticky = 1
    WHERE title LIKE '%Welcome to Flarum-In-A-Box%'
       OR title LIKE '%Getting Started with Extensions%';
"

# ── Clean up: stop temp services and remove seed token ───────────────
mysql -u root flarum -e "DELETE FROM flarum_api_keys WHERE id = 1;"
nginx -s stop 2>/dev/null || true
kill $(pidof php-fpm) 2>/dev/null || true
for i in $(seq 1 10); do
    if ! pidof nginx > /dev/null 2>&1 && ! pidof php-fpm > /dev/null 2>&1; then break; fi
    sleep 1
done

# ── Re-fix permissions (API may have created root-owned files) ───────
chown -R www-data:www-data /var/www/html/config.php /var/www/html/storage /var/www/html/public/assets
chmod -R 775 /var/www/html/storage /var/www/html/public/assets
find /var/www/html/vendor -user root -exec chown www-data:www-data {} \; 2>/dev/null
find /var/www/html/vendor -type d ! -perm -755 -exec chmod 755 {} \; 2>/dev/null

# ── Shut down MariaDB cleanly (flush all InnoDB data to disk) ────────
echo "==> Flushing and shutting down MariaDB..."
mysql -u root -e "SET GLOBAL innodb_fast_shutdown = 0;"
mysql -u root -e "FLUSH TABLES;"
mysqladmin shutdown 2>/dev/null || true
for i in $(seq 1 30); do
    if ! pidof mariadbd > /dev/null 2>&1; then break; fi
    sleep 1
done

echo "==> Build-time setup complete!"
