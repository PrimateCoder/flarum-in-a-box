#!/usr/bin/env bash
# Create a versioned Flarum-in-a-Box release and optionally publish it.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  scripts/release.sh [options]

Options:
  --version VERSION          Release version without the v prefix; defaults to the next build version
  --editor COMMAND           Editor command (default: $VISUAL, then $EDITOR, then vi)
  --message TEXT             Commit message (default: [no-build] Release vVERSION)
  --local-smoke-test         Build, run, and smoke-test a temporary local Docker image
  --expect-flarum VERSION    With --local-smoke-test, require this `php flarum info` version
  --push                     Push main and the vVERSION tag to origin
  --watch                    With --push, wait for the GitHub Actions image workflow to finish
  -h, --help                 Show this help

Examples:
  scripts/release.sh --local-smoke-test --expect-flarum 2.0.0-rc.5 --push --watch

  scripts/release.sh --version 0.2.14 --editor 'code --wait' --push
EOF
}

fail() { echo "error: $*" >&2; exit 1; }

version=''
editor_command="${VISUAL:-${EDITOR:-vi}}"
commit_message=''
local_smoke_test=false
expect_flarum=''
push=false
watch=false

while (( $# )); do
    case "$1" in
        --version) version="${2:-}"; shift 2 ;;
        --editor) editor_command="${2:-}"; shift 2 ;;
        --message) commit_message="${2:-}"; shift 2 ;;
        --local-smoke-test) local_smoke_test=true; shift ;;
        --expect-flarum) expect_flarum="${2:-}"; shift 2 ;;
        --push) push=true; shift ;;
        --watch) watch=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
done

[[ -z $expect_flarum || $local_smoke_test == true ]] || fail '--expect-flarum requires --local-smoke-test'
[[ $watch == false || $push == true ]] || fail '--watch requires --push'

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || fail 'run from inside the repository'
cd "$repo_root"
[[ $(git branch --show-current) == main ]] || fail 'releases must be created from main'
[[ -z $(git status --porcelain) ]] || fail 'working tree must be clean before starting a release'
if [[ -z $version ]]; then
    latest_tag="$(git tag --list 'v[0-9]*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)"
    [[ -n $latest_tag ]] || fail 'could not find a stable version tag to increment'
    IFS=. read -r major minor build <<<"${latest_tag#v}"
    version="$major.$minor.$((build + 1))"
fi
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] || fail '--version must be a semantic version without v'
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && fail "tag v$version already exists locally"
git ls-remote --exit-code --tags origin "refs/tags/v$version" >/dev/null 2>&1 && fail "tag v$version already exists on origin" || true
[[ -n $commit_message ]] || commit_message="[no-build] Release v$version"

read -r -a editor_parts <<<"$editor_command"
(( ${#editor_parts[@]} > 0 )) || fail 'editor command must not be empty'
echo "Opening CHANGELOG.md for v$version..."
"${editor_parts[@]}" CHANGELOG.md
grep -qE "^## ${version//./\\.} — [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md \
    || fail "CHANGELOG.md must contain a heading for $version with an ISO date"

echo 'Running repository checks...'
git diff --check
if grep -rnE '~?\\?~?[1-7][0-9]+\+?\s*(popular |demo )?extensions?' \
    --include='*.md' --include='*.json' --include='*.yml' \
    --include='*.yaml' --include='Dockerfile' --include='*.TEMPLATE' \
    | grep -v 'Initial release: all-in-one'; then
    fail 'stale extension-count references found'
fi
python3 - <<'PY'
import json
d = json.load(open('src/box/composer.json.TEMPLATE'))
installed = {package for package in d['require'] if package != 'flarum/core'}
with open('src/box/data/extensions.txt') as f:
    enabled = {line.strip() for line in f if line.strip() and not line.startswith('#')}
def to_id(package):
    vendor, name = package.split('/')
    return f"{vendor}-{name.replace('flarum-ext-', '').replace('flarum-', '')}"
orphans = enabled - {to_id(package) for package in installed} - {'flarum-extension-manager'}
if orphans:
    raise SystemExit(f'ENABLED IDs with no installed package: {sorted(orphans)}')
PY
python3 - <<'PY'
import json
import os
manifest = json.load(open('src/box/data/discussions/manifest.json'))
directory = 'src/box/data/discussions'
for entry in manifest:
    assert os.path.exists(os.path.join(directory, entry['file'])), entry['file']
    for reply in entry.get('replies', []):
        assert os.path.exists(os.path.join(directory, reply['file'])), reply['file']
print(f'{len(manifest)} discussions, all files exist')
PY

if [[ $local_smoke_test == true ]]; then
    image="flarum-in-a-box:${version}-release-test"
    container="flarum-release-test-$$"
    cleanup_container() { docker rm -f "$container" >/dev/null 2>&1 || true; }
    trap cleanup_container EXIT
    echo "Building $image..."
    docker build -f src/box/Dockerfile -t "$image" .
    docker run -d --rm --name "$container" -p 127.0.0.1::80 "$image" >/dev/null
    port="$(docker port "$container" 80/tcp | sed 's/.*://')"
    for _ in {1..30}; do
        curl --fail --silent --show-error "http://127.0.0.1:$port" >/dev/null && break
        sleep 2
    done
    curl --fail --silent --show-error "http://127.0.0.1:$port" >/dev/null
    info="$(docker exec "$container" php flarum info)"
    echo "$info"
    [[ -z $expect_flarum || $info == *"$expect_flarum"* ]] || fail "expected Flarum $expect_flarum"
    [[ $(docker exec "$container" mariadb -u root flarum -N -e 'SELECT COUNT(*) FROM flarum_discussions') == 10 ]] || fail 'expected 10 seed discussions'
    [[ $(docker exec "$container" mariadb -u root flarum -N -e 'SELECT COUNT(*) FROM flarum_discussions WHERE is_sticky = 1') -gt 0 ]] || fail 'expected sticky discussions'
    ! docker exec "$container" sh -c 'grep -R ERROR /var/www/html/storage/logs 2>/dev/null' >/dev/null
    cleanup_container
fi

git add CHANGELOG.md
git commit -m "$commit_message"
git tag "v$version"
if [[ $push == true ]]; then git push origin main "v$version"; fi

echo "Created v$version."
if [[ $watch == true ]]; then
    run_id="$(gh run list --workflow build.yml --branch "v$version" --limit 1 --json databaseId --jq '.[0].databaseId')"
    [[ -n $run_id ]] || fail 'could not find the GitHub Actions release run'
    gh run watch "$run_id" --exit-status
fi
