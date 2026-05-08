<?php

/*
 * This file is part of pianotell/flarum-in-a-box.
 *
 * Copyright (c) 2026 Navindra Umanee
 *
 * LICENSE: For the full copyright and license information,
 * please view the LICENSE file that was distributed
 * with this source code.
 */

/**
 * seed-discussions.php — create build-time sample users, seed discussions
 * with replies, and apply sticky flags via Flarum's local HTTP API.
 *
 * Reads:
 *     <data-dir>/users.tsv                    [username, email, password, groups]
 *     <data-dir>/discussions/manifest.json    [{file, title, tag?, sticky?, replies?}, ...]
 *     <data-dir>/discussions/<file>           Markdown body for each entry
 *     flarum_tags table                       to resolve tag slug → id
 *     flarum_users table                      to resolve username → id (for authors)
 *
 * Usage:
 *     php seed-discussions.php <data-dir> <api-url> <admin-token>
 *
 * The <admin-token> is a build-time API key bound to user_id=1 (admin).
 * For non-admin authors (replies in the moderation playground, etc.) we
 * insert per-user build tokens into flarum_api_keys, then post as those
 * users. All build tokens are deleted at the end.
 *
 * Pre-flight validation (fails build with clear error):
 *   - manifest is a JSON array of objects with required keys
 *   - each referenced .md file exists
 *   - each referenced tag slug exists in flarum_tags
 *   - each referenced author username exists in users.tsv (or is 'admin')
 */

if ($argc < 4) {
    fwrite(STDERR, "usage: php seed-discussions.php <data-dir> <api-url> <admin-token>\n");
    exit(2);
}

[$_, $dataDir, $apiUrl, $adminToken] = $argv;

$pdo = pdo_connect();

$users = load_users("$dataDir/users.tsv");
create_users($pdo, $apiUrl, $adminToken, $users);

$manifest = load_manifest("$dataDir/discussions/manifest.json");
$tagSlugToId = load_tag_index($pdo);
$userTokens = load_user_tokens($pdo, $users); // username → build token

validate_manifest($manifest, "$dataDir/discussions", $tagSlugToId, array_keys($userTokens));

echo "==> Validation passed: " . count($manifest) . " discussions, "
    . count($tagSlugToId) . " tags, " . count($userTokens) . " posting identities\n";

$createdIds = [];
foreach ($manifest as $entry) {
    $authorToken = $userTokens[$entry['author'] ?? 'admin'];
    $body = read_post_body("$dataDir/discussions/" . $entry['file']);
    $tagId = isset($entry['tag']) ? $tagSlugToId[$entry['tag']] : null;
    $id = post_discussion($apiUrl, $authorToken, $entry['title'], $body, $tagId);
    if ($id === null) {
        echo "    ✗ failed: {$entry['title']}\n";
        continue;
    }
    echo "    ✓ #$id  " . ($entry['author'] ?? 'admin') . ": {$entry['title']}\n";
    $createdIds[$id] = $entry;

    foreach (($entry['replies'] ?? []) as $reply) {
        $replyToken = $userTokens[$reply['author']];
        $replyBody = read_post_body("$dataDir/discussions/" . $reply['file']);
        if (post_reply($apiUrl, $replyToken, $id, $replyBody)) {
            echo "        ↳ {$reply['author']}: {$reply['file']}\n";
        } else {
            echo "        ✗ reply failed: {$reply['file']}\n";
        }
    }
}

apply_sticky($pdo, $createdIds);
delete_build_tokens($pdo, $users);

echo "==> Discussion seeding complete.\n";

// ─────────────────────────────────────────────────────────────────────────

function pdo_connect(): PDO {
    return new PDO('mysql:unix_socket=/run/mysqld/mysqld.sock;dbname=flarum;charset=utf8mb4', 'root', '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
}

function load_users(string $path): array {
    if (!is_readable($path)) {
        fwrite(STDERR, "ERROR: cannot read users.tsv at $path\n");
        exit(1);
    }
    $rows = [];
    $fh = fopen($path, 'r');
    while (($line = fgets($fh)) !== false) {
        $trim = ltrim($line);
        if ($trim === '' || $trim[0] === '#' || $trim === "\n") continue;
        $rows[] = explode("\t", rtrim($line, "\r\n"));
    }
    fclose($fh);
    if (!$rows) return [];
    $header = array_map('strtolower', array_shift($rows));
    if ($header !== ['username', 'email', 'password', 'groups']) {
        fwrite(STDERR, "ERROR: users.tsv header mismatch.\n  expected: username\\temail\\tpassword\\tgroups\n  got:      " . implode("\t", $header) . "\n");
        exit(1);
    }
    $users = [];
    foreach ($rows as $i => $row) {
        if (count($row) !== 4) {
            fwrite(STDERR, "ERROR: users.tsv row " . ($i + 1) . " has " . count($row) . " columns, expected 4\n");
            exit(1);
        }
        [$username, $email, $password, $groups] = $row;
        $extraGroups = $groups === '' ? [] : array_map('intval', explode(',', $groups));
        $users[] = compact('username', 'email', 'password', 'extraGroups');
    }
    return $users;
}

function create_users(PDO $pdo, string $apiUrl, string $adminToken, array $users): void {
    echo "==> Creating " . count($users) . " sample user(s)...\n";
    foreach ($users as $u) {
        $payload = [
            'data' => [
                'type' => 'users',
                'attributes' => [
                    'username' => $u['username'],
                    'email' => $u['email'],
                    'password' => $u['password'],
                    'isEmailConfirmed' => true,
                ],
            ],
        ];
        $resp = api_post($apiUrl, $adminToken, '/users', $payload);
        if ($resp['code'] !== 201 && $resp['code'] !== 200) {
            // user may already exist (rebuilds) — tolerate, look up id below
            fwrite(STDERR, "    ! user creation HTTP {$resp['code']} for {$u['username']} — assuming existing\n");
        } else {
            echo "    ✓ created {$u['username']}\n";
        }
        $userId = (int) $pdo->query("SELECT id FROM flarum_users WHERE username = " . $pdo->quote($u['username']))->fetchColumn();
        if (!$userId) {
            fwrite(STDERR, "ERROR: could not find user '{$u['username']}' after create attempt\n");
            exit(1);
        }
        // Add to extra groups (e.g. 4=Mod). flarum_group_user is (user_id, group_id).
        foreach ($u['extraGroups'] as $gid) {
            $stmt = $pdo->prepare('INSERT IGNORE INTO flarum_group_user (user_id, group_id) VALUES (:u, :g)');
            $stmt->execute([':u' => $userId, ':g' => $gid]);
            echo "        + group $gid\n";
        }
    }
}

function load_user_tokens(PDO $pdo, array $users): array {
    // Map username → API token for posting. Admin is user_id=1 with the build-seed token
    // already in flarum_api_keys (id=1, key='build-seed-token'). For each non-admin user
    // we insert another row with key='build-seed-<username>' bound to that user.
    $tokens = ['admin' => 'build-seed-token'];
    $stmt = $pdo->prepare('INSERT INTO flarum_api_keys (`key`, user_id, created_at) VALUES (:k, :u, NOW())');
    foreach ($users as $u) {
        $userId = (int) $pdo->query("SELECT id FROM flarum_users WHERE username = " . $pdo->quote($u['username']))->fetchColumn();
        $key = 'build-seed-' . $u['username'];
        $pdo->exec("DELETE FROM flarum_api_keys WHERE `key` = " . $pdo->quote($key));
        $stmt->execute([':k' => $key, ':u' => $userId]);
        $tokens[$u['username']] = $key;
    }
    return $tokens;
}

function delete_build_tokens(PDO $pdo, array $users): void {
    $keys = ['build-seed-token'];
    foreach ($users as $u) $keys[] = 'build-seed-' . $u['username'];
    $placeholders = implode(',', array_fill(0, count($keys), '?'));
    $stmt = $pdo->prepare("DELETE FROM flarum_api_keys WHERE `key` IN ($placeholders)");
    $stmt->execute($keys);
}

function load_manifest(string $path): array {
    if (!is_readable($path)) {
        fwrite(STDERR, "ERROR: cannot read manifest at $path\n");
        exit(1);
    }
    $data = json_decode(file_get_contents($path), true);
    if (!is_array($data)) {
        fwrite(STDERR, "ERROR: manifest is not a JSON array\n");
        exit(1);
    }
    return $data;
}

function validate_manifest(array $manifest, string $discussionsDir, array $tagSlugToId, array $knownAuthors): void {
    foreach ($manifest as $i => $entry) {
        $where = "manifest entry #$i";
        if (!is_array($entry)) {
            fwrite(STDERR, "ERROR: $where is not an object\n");
            exit(1);
        }
        foreach (['file', 'title'] as $required) {
            if (!isset($entry[$required]) || !is_string($entry[$required]) || $entry[$required] === '') {
                fwrite(STDERR, "ERROR: $where missing required string '$required'\n");
                exit(1);
            }
        }
        if (isset($entry['tag']) && !is_string($entry['tag'])) {
            fwrite(STDERR, "ERROR: $where 'tag' must be a string slug\n");
            exit(1);
        }
        if (isset($entry['sticky']) && !is_bool($entry['sticky'])) {
            fwrite(STDERR, "ERROR: $where 'sticky' must be a boolean\n");
            exit(1);
        }
        if (isset($entry['author']) && !in_array($entry['author'], $knownAuthors, true)) {
            fwrite(STDERR, "ERROR: $where references unknown author '{$entry['author']}'\n");
            exit(1);
        }
        $file = "$discussionsDir/" . $entry['file'];
        if (!is_readable($file)) {
            fwrite(STDERR, "ERROR: $where references missing/unreadable file: $file\n");
            exit(1);
        }
        if (isset($entry['tag']) && !isset($tagSlugToId[$entry['tag']])) {
            fwrite(STDERR, "ERROR: $where references unknown tag slug '{$entry['tag']}'\n");
            fwrite(STDERR, "       known slugs: " . implode(', ', array_keys($tagSlugToId)) . "\n");
            exit(1);
        }
        foreach (($entry['replies'] ?? []) as $j => $reply) {
            $rwhere = "$where reply #$j";
            foreach (['author', 'file'] as $required) {
                if (!isset($reply[$required]) || !is_string($reply[$required])) {
                    fwrite(STDERR, "ERROR: $rwhere missing required string '$required'\n");
                    exit(1);
                }
            }
            if (!in_array($reply['author'], $knownAuthors, true)) {
                fwrite(STDERR, "ERROR: $rwhere references unknown author '{$reply['author']}'\n");
                exit(1);
            }
            $rfile = "$discussionsDir/" . $reply['file'];
            if (!is_readable($rfile)) {
                fwrite(STDERR, "ERROR: $rwhere references missing/unreadable file: $rfile\n");
                exit(1);
            }
        }
    }
}

function load_tag_index(PDO $pdo): array {
    $map = [];
    foreach ($pdo->query('SELECT id, slug FROM flarum_tags') as $row) {
        $map[$row['slug']] = (int) $row['id'];
    }
    return $map;
}

function read_post_body(string $path): string {
    $body = file_get_contents($path);
    if ($body === false) {
        fwrite(STDERR, "ERROR: could not read $path\n");
        exit(1);
    }
    return $body;
}

function post_discussion(string $apiUrl, string $token, string $title, string $body, ?int $tagId): ?int {
    $payload = [
        'data' => [
            'type' => 'discussions',
            'attributes' => ['title' => $title, 'content' => $body],
        ],
    ];
    if ($tagId !== null) {
        $payload['data']['relationships']['tags']['data'][] = ['type' => 'tags', 'id' => (string) $tagId];
    }
    $resp = api_post($apiUrl, $token, '/discussions', $payload);
    if ($resp['code'] !== 200 && $resp['code'] !== 201) {
        fwrite(STDERR, "    HTTP {$resp['code']} — " . substr($resp['body'], 0, 300) . "\n");
        return null;
    }
    $decoded = json_decode($resp['body'], true);
    return isset($decoded['data']['id']) ? (int) $decoded['data']['id'] : null;
}

function post_reply(string $apiUrl, string $token, int $discussionId, string $body): bool {
    $payload = [
        'data' => [
            'type' => 'posts',
            'attributes' => ['content' => $body],
            'relationships' => [
                'discussion' => ['data' => ['type' => 'discussions', 'id' => (string) $discussionId]],
            ],
        ],
    ];
    $resp = api_post($apiUrl, $token, '/posts', $payload);
    if ($resp['code'] === 200 || $resp['code'] === 201) return true;
    fwrite(STDERR, "        HTTP {$resp['code']} — " . substr($resp['body'], 0, 300) . "\n");
    return false;
}

function apply_sticky(PDO $pdo, array $createdIds): void {
    $stickyIds = [];
    foreach ($createdIds as $id => $entry) {
        if (!empty($entry['sticky'])) $stickyIds[] = $id;
    }
    if (!$stickyIds) return;
    $placeholders = implode(',', array_fill(0, count($stickyIds), '?'));
    $stmt = $pdo->prepare("UPDATE flarum_discussions SET is_sticky = 1 WHERE id IN ($placeholders)");
    $stmt->execute($stickyIds);
    echo "    stickied: " . implode(', ', $stickyIds) . "\n";
}

function api_post(string $apiUrl, string $token, string $path, array $payload): array {
    $ch = curl_init($apiUrl . $path);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Authorization: Token $token",
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode($payload),
    ]);
    $body = (string) curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    return ['code' => $code, 'body' => $body];
}
