#!/usr/bin/env bash
# extract-selectors.sh — Deterministic extraction of all UI selectors
# from console-e2e virt test code. Outputs structured JSON to stdout.
#
# Fetches from GitHub remote (stolostron/console-e2e, branch main) by default.
# Uses a shallow clone to a temp directory — never touches the local checkout.
#
# Usage: ./extract-selectors.sh [BRANCH]
# Default BRANCH: main

set -euo pipefail

BRANCH="${1:-main}"
REPO_URL="https://github.com/stolostron/console-e2e.git"
CLONE_DIR=$(mktemp -d)

trap 'rm -rf "$CLONE_DIR"' EXIT

echo "Cloning stolostron/console-e2e@${BRANCH} (shallow)..." >&2
git clone --depth 1 --branch "$BRANCH" --single-branch --quiet "$REPO_URL" "$CLONE_DIR" 2>&2

if [ ! -d "$CLONE_DIR/src/constants" ]; then
  echo '{"error":"src/constants not found in cloned repo"}' >&2
  exit 1
fi

cd "$CLONE_DIR"

# Phase 1: Extract constants (data-test, data-testid, IDs, CSS classes)
CONSTANTS_JSON=$(python3 -c "
import re, json, sys

files = {
    'fleet-virt': 'src/constants/fleet-virt.ts',
    'fg-rbac': 'src/constants/fg-rbac.ts',
    'selectors': 'src/constants/selectors.ts',
    'app': 'src/constants/app.ts',
}

result = {'constants': {}, 'locators': {}, 'routes': {}, 'pfVersion': ''}

for domain, fpath in files.items():
    try:
        with open(fpath) as f:
            content = f.read()
    except FileNotFoundError:
        continue

    # Extract string literal values from constant objects
    selectors = {}
    for m in re.finditer(r\"(\w+):\s*['\\\"]([^'\\\"]+)['\\\"]\", content):
        key, val = m.group(1), m.group(2)
        selectors[key] = val

    result['constants'][domain] = selectors

    # Extract routes (paths starting with /)
    for m in re.finditer(r\"(\w+):\s*['\\\"](/[^'\\\"]+)['\\\"]\", content):
        key, path = m.group(1), m.group(2)
        result['routes'][f'{domain}.{key}'] = path

    # Extract PF version
    pf = re.search(r\"const PF = '(pf-v\\d+-c)'\", content)
    if pf:
        result['pfVersion'] = pf.group(1)

json.dump(result, sys.stdout, indent=2)
")

# Phase 2: Count locators by type in page objects and components
LOCATOR_JSON=$(python3 -c "
import subprocess, json, sys

dirs = [
    'src/pages/fleet-virt', 'src/pages/fg-rbac', 'src/pages/infrastructure',
    'src/components/fleet-virt', 'src/components/fg-rbac',
]

strategies = {
    'getByRole': 0, 'getByText': 0, 'getByLabel': 0,
    'getByTestId': 0, 'getByPlaceholder': 0, 'locator_css': 0,
}

per_file = {}

for d in dirs:
    try:
        out = subprocess.run(
            ['rg', '-c', r'getByRole|getByText|getByLabel|getByTestId|getByPlaceholder|\.locator\(', d],
            capture_output=True, text=True
        )
        for line in out.stdout.strip().split('\n'):
            if ':' in line:
                fpath, count = line.rsplit(':', 1)
                per_file[fpath] = int(count)
    except Exception:
        pass

    for strategy in ['getByRole', 'getByText', 'getByLabel', 'getByTestId', 'getByPlaceholder']:
        try:
            out = subprocess.run(['rg', '-c', strategy, d], capture_output=True, text=True)
            for line in out.stdout.strip().split('\n'):
                if ':' in line:
                    strategies[strategy] += int(line.rsplit(':', 1)[1])
        except Exception:
            pass

    try:
        out = subprocess.run(['rg', '-c', r'\.locator\(', d], capture_output=True, text=True)
        for line in out.stdout.strip().split('\n'):
            if ':' in line:
                strategies['locator_css'] += int(line.rsplit(':', 1)[1])
    except Exception:
        pass

result = {'strategies': strategies, 'perFile': per_file, 'total': sum(per_file.values())}
json.dump(result, sys.stdout, indent=2)
")

# Phase 3: Check for inline locators in spec files (anti-pattern)
INLINE_JSON=$(python3 -c "
import subprocess, json, sys

dirs = ['src/tests/fleet-virt', 'src/tests/fg-rbac']
inlines = []

for d in dirs:
    try:
        out = subprocess.run(
            ['rg', '-n', r'page\.(getByRole|getByText|getByLabel|getByTestId|locator)\(', d],
            capture_output=True, text=True
        )
        for line in out.stdout.strip().split('\n'):
            if line.strip():
                inlines.append(line.strip())
    except Exception:
        pass

json.dump({'inlineLocators': inlines, 'count': len(inlines)}, sys.stdout, indent=2)
")

# Phase 4: Check for absence assertions on selectors
ABSENCE_JSON=$(python3 -c "
import subprocess, json, sys, re

dirs = ['src/tests/fleet-virt', 'src/tests/fg-rbac']
assertions = []

patterns = [
    r'not\.toBeVisible',
    r'not\.toBeAttached',
    r'toHaveCount\s*\(\s*0\s*\)',
    r'not\.toBeEnabled',
]

for d in dirs:
    for pat in patterns:
        try:
            out = subprocess.run(['rg', '-n', pat, d], capture_output=True, text=True)
            for line in out.stdout.strip().split('\n'):
                if line.strip():
                    assertions.append({'pattern': pat, 'match': line.strip()})
        except Exception:
            pass

json.dump({'absenceAssertions': assertions, 'count': len(assertions)}, sys.stdout, indent=2)
")

# Combine all outputs using temp files to avoid shell quoting issues
TMPDIR_COMBINE=$(mktemp -d)
echo "$CONSTANTS_JSON" > "$TMPDIR_COMBINE/constants.json"
echo "$LOCATOR_JSON" > "$TMPDIR_COMBINE/locators.json"
echo "$INLINE_JSON" > "$TMPDIR_COMBINE/inlines.json"
echo "$ABSENCE_JSON" > "$TMPDIR_COMBINE/absences.json"

python3 - "$TMPDIR_COMBINE" "$BRANCH" <<'COMBINE_EOF'
import json, sys, os

tmpdir = sys.argv[1]
branch = sys.argv[2]

with open(os.path.join(tmpdir, 'constants.json')) as f:
    constants = json.load(f)
with open(os.path.join(tmpdir, 'locators.json')) as f:
    locators = json.load(f)
with open(os.path.join(tmpdir, 'inlines.json')) as f:
    inlines = json.load(f)
with open(os.path.join(tmpdir, 'absences.json')) as f:
    absences = json.load(f)

combined = {
    'source': f'github:stolostron/console-e2e@{branch}',
    **constants,
    'locatorHealth': locators,
    'inlineLocators': inlines,
    'absenceAssertions': absences,
}

json.dump(combined, sys.stdout, indent=2)
print()
COMBINE_EOF

rm -rf "$TMPDIR_COMBINE"
