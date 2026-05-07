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
 * seed-discussions.php — create build-time seed discussions, sample user, and
 * apply sticky flags via Flarum's local HTTP API.
 *
 * Reads:
 *     <data-dir>/discussions/manifest.json    [{file, title, tag?, sticky?}, ...]
 *     <data-dir>/discussions/<file>           Markdown body for each entry
 *     flarum_tags table                       to resolve tag slug → id
 *
 * Usage:
 *     php seed-discussions.php <data-dir> <api-url> <api-token>
 *
 * Pre-flight validation (fails build with clear error):
 *   - manifest is a JSON array of objects with required keys
 *   - each referenced .md file exists
 *   - each referenced tag slug exists in flarum_tags
 *
 * Post-creation:
 *   - captures returned discussion IDs
 *   - applies sticky=1 directly on those IDs (no fuzzy WHERE LIKE on title)
 *   - creates the sample 'user' account
 */

if ($argc < 4) {
    fwrite(STDERR, "usage: php seed-discussions.php <data-dir> <api-url> <api-token>\n");
    exit(2);
}

[$_, $dataDir, $apiUrl, $token] = $argv;

$manifestPath = "$dataDir/discussions/manifest.json";
$manifest = load_manifest($manifestPath);
validate_manifest($manifest, "$dataDir/discussions");

$pdo = pdo_connect();
$tagSlugToId = load_tag_index($pdo);
validate_tag_refs($manifest, $tagSlugToId);

echo "==> Validation passed: " . count($manifest) . " discussions, "
    . count($tagSlugToId) . " tags available\n";

$createdIds = [];
foreach ($manifest as $entry) {
    $body = file_get_contents("$dataDir/discussions/" . $entry['file']);
    if ($body === false) {
        fwrite(STDERR, "ERROR: could not read " . $entry['file'] . "\n");
        exit(1);
    }
    $tagId = isset($entry['tag']) ? $tagSlugToId[$entry['tag']] : null;
    $id = post_discussion($apiUrl, $token, $entry['title'], $body, $tagId);
    if ($id !== null) {
        echo "    ✓ #$id  {$entry['title']}\n";
        $createdIds[$id] = $entry;
    } else {
        echo "    ✗ failed: {$entry['title']}\n";
    }
}

apply_sticky($pdo, $createdIds);
create_sample_user($apiUrl, $token);

echo "==> Discussion seeding complete.\n";

// ─────────────────────────────────────────────────────────────────────────

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

function validate_manifest(array $manifest, string $discussionsDir): void {
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
        $file = "$discussionsDir/" . $entry['file'];
        if (!is_readable($file)) {
            fwrite(STDERR, "ERROR: $where references missing/unreadable file: $file\n");
            exit(1);
        }
    }
}

function pdo_connect(): PDO {
    return new PDO('mysql:unix_socket=/run/mysqld/mysqld.sock;dbname=flarum;charset=utf8mb4', 'root', '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
}

function load_tag_index(PDO $pdo): array {
    $map = [];
    foreach ($pdo->query('SELECT id, slug FROM flarum_tags') as $row) {
        $map[$row['slug']] = (int) $row['id'];
    }
    return $map;
}

function validate_tag_refs(array $manifest, array $tagSlugToId): void {
    foreach ($manifest as $i => $entry) {
        if (isset($entry['tag']) && !isset($tagSlugToId[$entry['tag']])) {
            fwrite(STDERR, "ERROR: manifest entry #$i references unknown tag slug '{$entry['tag']}'\n");
            fwrite(STDERR, "       known slugs: " . implode(', ', array_keys($tagSlugToId)) . "\n");
            exit(1);
        }
    }
}

function post_discussion(string $apiUrl, string $token, string $title, string $body, ?int $tagId): ?int {
    $payload = [
        'data' => [
            'type' => 'discussions',
            'attributes' => [
                'title' => $title,
                'content' => $body,
            ],
        ],
    ];
    if ($tagId !== null) {
        $payload['data']['relationships']['tags']['data'][] = ['type' => 'tags', 'id' => (string) $tagId];
    }

    $ch = curl_init("$apiUrl/discussions");
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Authorization: Token $token",
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode($payload),
    ]);
    $resp = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    if ($code !== 200 && $code !== 201) {
        fwrite(STDERR, "    HTTP $code — " . substr((string) $resp, 0, 300) . "\n");
        return null;
    }
    $decoded = json_decode((string) $resp, true);
    return isset($decoded['data']['id']) ? (int) $decoded['data']['id'] : null;
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

function create_sample_user(string $apiUrl, string $token): void {
    $payload = [
        'data' => [
            'type' => 'users',
            'attributes' => [
                'username' => 'user',
                'email' => 'user@example.com',
                'password' => 'password',
                'isEmailConfirmed' => true,
            ],
        ],
    ];
    $ch = curl_init("$apiUrl/users");
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Authorization: Token $token",
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode($payload),
    ]);
    $resp = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    if ($code === 200 || $code === 201) {
        echo "    ✓ user account 'user' created\n";
    } else {
        fwrite(STDERR, "    ✗ user creation failed: HTTP $code — " . substr((string) $resp, 0, 200) . "\n");
    }
}
