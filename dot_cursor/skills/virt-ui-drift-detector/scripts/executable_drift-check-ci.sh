#!/usr/bin/env bash
# drift-check-ci.sh — Standalone CI-runnable drift check.
#
# Compares console-e2e selectors (from GitHub remote) against a committed baseline.
# Performs a shallow clone to a temp directory — never touches any local checkout.
# Runs in ~10-15 seconds (clone + parse). No MCP, no AI, no browser.
#
# Exit codes:
#   0 = no drift detected (or first run — baseline created)
#   1 = BREAKING drift detected
#   2 = WARNING drift detected (no breaking)
#   3 = script error
#
# Usage:
#   ./drift-check-ci.sh [BASELINE_PATH] [BRANCH]
#
# Default BASELINE_PATH: ~/.cursor/skills/virt-ui-drift-detector/assets/.drift-baseline.json
# Default BRANCH: main

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASELINE_PATH="${1:-$SCRIPT_DIR/../assets/.drift-baseline.json}"
BRANCH="${2:-main}"
REPO_URL="https://github.com/stolostron/console-e2e.git"

CLONE_DIR=$(mktemp -d)
trap 'rm -rf "$CLONE_DIR"' EXIT

echo "Fetching stolostron/console-e2e@${BRANCH}..."
git clone --depth 1 --branch "$BRANCH" --single-branch --quiet "$REPO_URL" "$CLONE_DIR" 2>&2

if [ ! -d "$CLONE_DIR/src/constants" ]; then
  echo "ERROR: src/constants not found in cloned repo" >&2
  exit 3
fi

cd "$CLONE_DIR"

# Extract current selectors from constants files
CURRENT=$(python3 -c "
import re, json, sys

files = [
    'src/constants/fleet-virt.ts',
    'src/constants/fg-rbac.ts',
    'src/constants/selectors.ts',
    'src/constants/app.ts',
]

selectors = {}
routes = {}
pf_version = ''

for fpath in files:
    try:
        with open(fpath) as f:
            content = f.read()
    except FileNotFoundError:
        continue

    for m in re.finditer(r\"(\w+):\s*['\\\"]([^'\\\"]+)['\\\"]\", content):
        key, val = m.group(1), m.group(2)
        selectors[f'{fpath}:{key}'] = val

    for m in re.finditer(r\"(\w+):\s*['\\\"](/[^'\\\"]+)['\\\"]\", content):
        key, path = m.group(1), m.group(2)
        routes[key] = path

    pf = re.search(r\"const PF = '(pf-v\\d+-c)'\", content)
    if pf:
        pf_version = pf.group(1)

json.dump({
    'source': 'github:stolostron/console-e2e@${BRANCH}',
    'selectors': selectors,
    'routes': routes,
    'pfVersion': pf_version,
    'selectorCount': len(selectors),
}, sys.stdout)
")

# First run: no baseline exists — create it
if [ ! -f "$BASELINE_PATH" ]; then
  mkdir -p "$(dirname "$BASELINE_PATH")"
  echo "$CURRENT" > "$BASELINE_PATH"
  COUNT=$(echo "$CURRENT" | python3 -c "import json,sys; print(json.load(sys.stdin)['selectorCount'])")
  echo "FIRST RUN: Baseline created with $COUNT selectors at $BASELINE_PATH"
  exit 0
fi

# Compare current vs baseline
python3 - "$CURRENT" "$BASELINE_PATH" <<'PYEOF'
import json, sys

current = json.loads(sys.argv[1])
with open(sys.argv[2]) as f:
    baseline = json.load(f)

breaking = []
warning = []
info = []

# Check for removed selectors (BREAKING)
for key, val in baseline['selectors'].items():
    if key not in current['selectors']:
        breaking.append(f'REMOVED: {key} (was: {val})')
    elif current['selectors'][key] != val:
        breaking.append(f'CHANGED: {key}: {val!r} -> {current["selectors"][key]!r}')

# Check for new selectors (INFO)
for key, val in current['selectors'].items():
    if key not in baseline['selectors']:
        info.append(f'ADDED: {key} = {val}')

# Check route changes (BREAKING)
for key, val in baseline['routes'].items():
    if key in current['routes'] and current['routes'][key] != val:
        breaking.append(f'ROUTE CHANGED: {key}: {val!r} -> {current["routes"][key]!r}')
    elif key not in current['routes']:
        breaking.append(f'ROUTE REMOVED: {key} (was: {val})')

# Check PF version (WARNING)
if baseline['pfVersion'] != current['pfVersion'] and current['pfVersion']:
    warning.append(f'PF VERSION: {baseline["pfVersion"]} -> {current["pfVersion"]}')

# Report
total = len(breaking) + len(warning) + len(info)

if total == 0:
    print('No selector drift detected.')
    sys.exit(0)

print(f'Selector drift detected: {len(breaking)} BREAKING, {len(warning)} WARNING, {len(info)} INFO')
print()

if breaking:
    print('BREAKING:')
    for item in breaking:
        print(f'  {item}')
    print()

if warning:
    print('WARNING:')
    for item in warning:
        print(f'  {item}')
    print()

if info:
    print('INFO:')
    for item in info[:10]:
        print(f'  {item}')
    if len(info) > 10:
        print(f'  ... and {len(info) - 10} more')
    print()

if breaking:
    print('EXIT: BREAKING drift — tests will likely fail.')
    sys.exit(1)
elif warning:
    print('EXIT: WARNING drift — tests may become fragile.')
    sys.exit(2)
else:
    print('EXIT: INFO only — no immediate risk.')
    sys.exit(0)
PYEOF
