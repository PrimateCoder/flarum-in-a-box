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
 * import-tabular.php — bulk-import build-time seed data via PDO prepared statements.
 *
 * Usage:
 *     php import-tabular.php settings <path>
 *     php import-tabular.php tags <path>
 *     php import-tabular.php group-permissions <path>
 *
 * Each TSV is read with PHP's CSV parser (tab delimiter), allowing values to
 * safely contain quotes/semicolons/etc. Lines starting with '#' and blank
 * lines are skipped. Tables that have a header row identify columns by name;
 * `\N` literal in any field becomes SQL NULL.
 */

if ($argc < 3) {
    fwrite(STDERR, "usage: php import-tabular.php <kind> <tsv-path>\n");
    fwrite(STDERR, "  kind: settings | tags | group-permissions\n");
    exit(2);
}

$kind = $argv[1];
$path = $argv[2];

if (!is_readable($path)) {
    fwrite(STDERR, "ERROR: cannot read $path\n");
    exit(1);
}

$rows = read_tsv($path);

$pdo = new PDO('mysql:unix_socket=/run/mysqld/mysqld.sock;dbname=flarum;charset=utf8mb4', 'root', '', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_EMULATE_PREPARES => false,
]);

switch ($kind) {
    case 'settings':
        import_settings($pdo, $rows);
        break;
    case 'tags':
        import_tags($pdo, $rows);
        break;
    case 'group-permissions':
        import_group_permissions($pdo, $rows);
        break;
    default:
        fwrite(STDERR, "ERROR: unknown kind '$kind'\n");
        exit(2);
}

// ─────────────────────────────────────────────────────────────────────────

/**
 * Read a TSV file into rows. Skips blank lines and lines whose first
 * non-whitespace char is '#'. Returns an array of arrays (no header
 * interpretation — caller decides if first row is a header).
 */
function read_tsv(string $path): array {
    $rows = [];
    $fh = fopen($path, 'r');
    if (!$fh) {
        throw new RuntimeException("cannot open $path");
    }
    while (($line = fgets($fh)) !== false) {
        $trim = ltrim($line);
        if ($trim === '' || $trim[0] === '#' || $trim === "\n") continue;
        // strip trailing newline only (preserve embedded tabs/etc)
        $line = rtrim($line, "\r\n");
        $rows[] = explode("\t", $line);
    }
    fclose($fh);
    return $rows;
}

function import_settings(PDO $pdo, array $rows): void {
    // Optional header row (key, value); detect and skip
    if ($rows && strtolower($rows[0][0] ?? '') === 'key') {
        array_shift($rows);
    }
    $stmt = $pdo->prepare(
        'INSERT INTO flarum_settings (`key`, value) VALUES (:k, :v)
         ON DUPLICATE KEY UPDATE value = VALUES(value)'
    );
    foreach ($rows as $i => $row) {
        if (count($row) < 2) {
            fwrite(STDERR, "ERROR: settings row " . ($i + 1) . " has fewer than 2 columns\n");
            exit(1);
        }
        [$k, $v] = $row;
        $stmt->execute([':k' => $k, ':v' => $v]);
        echo "    setting: $k = $v\n";
    }
}

function import_tags(PDO $pdo, array $rows): void {
    if (!$rows) return;
    $header = array_map('strtolower', array_shift($rows));
    $expected = ['id','name','slug','description','color','icon','is_primary','position'];
    if ($header !== $expected) {
        fwrite(STDERR, "ERROR: tags.tsv header mismatch.\n  expected: " . implode("\t", $expected) . "\n  got:      " . implode("\t", $header) . "\n");
        exit(1);
    }
    $stmt = $pdo->prepare(
        'INSERT INTO flarum_tags (id, name, slug, description, color, icon, is_primary, position)
         VALUES (:id, :name, :slug, :description, :color, :icon, :is_primary, :position)
         ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            slug = VALUES(slug),
            description = VALUES(description),
            color = VALUES(color),
            icon = VALUES(icon),
            is_primary = VALUES(is_primary),
            position = VALUES(position)'
    );
    $slugs_seen = [];
    foreach ($rows as $i => $row) {
        if (count($row) !== 8) {
            fwrite(STDERR, "ERROR: tags row " . ($i + 1) . " has " . count($row) . " columns, expected 8\n");
            exit(1);
        }
        [$id, $name, $slug, $desc, $color, $icon, $is_primary, $position] = $row;
        if (isset($slugs_seen[$slug])) {
            fwrite(STDERR, "ERROR: duplicate tag slug '$slug' in tags.tsv\n");
            exit(1);
        }
        $slugs_seen[$slug] = true;
        $stmt->execute([
            ':id' => (int) $id,
            ':name' => $name,
            ':slug' => $slug,
            ':description' => $desc,
            ':color' => $color,
            ':icon' => $icon,
            ':is_primary' => (int) $is_primary,
            ':position' => $position === '\\N' ? null : (int) $position,
        ]);
        echo "    tag: #$id $slug ($name)\n";
    }
}

function import_group_permissions(PDO $pdo, array $rows): void {
    if (!$rows) return;
    $header = array_map('strtolower', array_shift($rows));
    if ($header !== ['group_id', 'permission']) {
        fwrite(STDERR, "ERROR: group-permissions.tsv header mismatch.\n  expected: group_id\\tpermission\n  got:      " . implode("\t", $header) . "\n");
        exit(1);
    }
    $stmt = $pdo->prepare(
        'INSERT IGNORE INTO flarum_group_permission (group_id, permission, created_at)
         VALUES (:group_id, :permission, NOW())'
    );
    foreach ($rows as $i => $row) {
        if (count($row) !== 2) {
            fwrite(STDERR, "ERROR: group-permissions row " . ($i + 1) . " has " . count($row) . " columns, expected 2\n");
            exit(1);
        }
        [$gid, $perm] = $row;
        $stmt->execute([':group_id' => (int) $gid, ':permission' => $perm]);
        echo "    permission: group=$gid → $perm\n";
    }
}
