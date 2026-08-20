#!/usr/bin/env python3
"""fragility-score.py — Score every locator in console-e2e virt test code for fragility.

Outputs a JSON report with per-file and per-locator fragility scores (0–100).
Lower = more resilient. Higher = more likely to break on UI changes.

Scoring rubric (from pw-doctor and 2026 Playwright best practices):
  getByRole with name     →  0  (best: binds to user-visible meaning)
  getByLabel              → 10  (high: binds to form label)
  getByPlaceholder        → 15  (high: binds to placeholder text)
  getByTestId             → 20  (high if disciplined: explicit contract)
  getByText               → 30  (medium: breaks on copy changes / i18n)
  getByRole without name  → 35  (medium: too broad, fragile if DOM has multiples)
  locator([data-test=])   → 25  (high: explicit test attribute)
  locator([data-testid=]) → 25  (high: explicit test attribute)
  locator(#id)            → 40  (medium-low: IDs can be generated)
  locator(.pf-v*-c-*)     → 60  (low: coupled to PF version)
  locator(.class)         → 70  (low: breaks on CSS refactors)
  locator(tag)            → 75  (low: breaks on component refactors)
  locator(xpath/complex)  → 85  (worst: breaks on any DOM change)
  nth-child / .nth()      → 90  (worst: breaks on insertion/reorder)

Usage:
  python3 fragility-score.py [REPO_ROOT_OR_BRANCH]

If REPO_ROOT_OR_BRANCH is a directory, scan it directly.
If it's a branch name (or omitted, default: main), shallow-clone from GitHub.
"""

import re
import json
import sys
import os
import subprocess
import tempfile
import shutil


def resolve_repo_root(arg):
    """Return (repo_root, cleanup_fn). If arg is a dir, use it. Otherwise clone."""
    if arg and os.path.isdir(arg):
        return arg, lambda: None

    branch = arg if arg and not os.path.isdir(arg) else "main"
    clone_dir = tempfile.mkdtemp()
    print(f"Cloning stolostron/console-e2e@{branch} for fragility analysis...", file=sys.stderr)
    subprocess.run(
        ["git", "clone", "--depth", "1", "--branch", branch, "--single-branch",
         "--quiet", "https://github.com/stolostron/console-e2e.git", clone_dir],
        check=True, capture_output=True
    )
    return clone_dir, lambda: shutil.rmtree(clone_dir, ignore_errors=True)


arg = sys.argv[1] if len(sys.argv) > 1 else "main"
REPO_ROOT, _cleanup = resolve_repo_root(arg)

SCAN_DIRS = [
    "src/pages/fleet-virt",
    "src/pages/fg-rbac",
    "src/pages/infrastructure",
    "src/components/fleet-virt",
    "src/components/fg-rbac",
    "src/lib",
    "src/lib/fg-rbac",
]

SCORING_RULES = [
    (r"getByRole\([^)]+,\s*\{[^}]*name:", 0, "getByRole+name"),
    (r"getByLabel\(", 10, "getByLabel"),
    (r"getByPlaceholder\(", 15, "getByPlaceholder"),
    (r"getByTestId\(", 20, "getByTestId"),
    (r'getByText\(', 30, "getByText"),
    (r"getByRole\([^,)]+\)", 35, "getByRole-noName"),
    (r'locator\([\'\"]\[data-test[^i]', 25, "data-test-attr"),
    (r'locator\([\'\"]\[data-testid', 25, "data-testid-attr"),
    (r'locator\([A-Z_]+\.\w+\)', 25, "constant-ref"),      # locator(CONSTANT.key)
    (r'locator\(`#\$\{', 40, "template-id"),                 # locator(`#${VAR}`)
    (r'locator\([\'\"]\[role=', 15, "role-attr"),             # locator('[role="tab"]')
    (r"locator\(['\"]#", 40, "id-selector"),
    (r"locator\(['\"]\.pf-v\d+-c-", 60, "pf-class"),
    (r"locator\(['\"]\.(?!pf-)", 70, "css-class"),
    (r"\.nth\(|nth-child|nth-of-type", 90, "nth-positional"),
    (r"locator\(['\"][a-z]+[^.#\['\"]", 75, "tag-selector"),
    (r"locator\(['\"].*>>.*", 85, "deep-chain"),
    (r"locator\(['\"]xpath=", 85, "xpath"),                   # explicit xpath
]


def score_line(line):
    """Return (score, strategy_name) for a line containing a locator."""
    for pattern, score, name in SCORING_RULES:
        if re.search(pattern, line):
            return score, name
    return 50, "unknown"


def scan_file(filepath):
    """Scan a file and return per-locator scores."""
    locators = []
    try:
        with open(filepath) as f:
            lines = f.readlines()
    except (FileNotFoundError, PermissionError):
        return locators

    locator_pattern = re.compile(
        r"(getByRole|getByText|getByLabel|getByTestId|getByPlaceholder|\.locator)\("
    )

    for i, line in enumerate(lines, 1):
        if locator_pattern.search(line):
            score, strategy = score_line(line)
            locators.append({
                "line": i,
                "score": score,
                "strategy": strategy,
                "code": line.strip()[:120],
            })

    return locators


def main():
    all_files = {}
    total_score = 0
    total_count = 0

    for scan_dir in SCAN_DIRS:
        full_dir = os.path.join(REPO_ROOT, scan_dir)
        if not os.path.isdir(full_dir):
            continue
        for fname in os.listdir(full_dir):
            if not fname.endswith(".ts"):
                continue
            fpath = os.path.join(full_dir, fname)
            rel_path = os.path.relpath(fpath, REPO_ROOT)
            locators = scan_file(fpath)
            if locators:
                file_score = sum(l["score"] for l in locators) / len(locators)
                all_files[rel_path] = {
                    "locators": locators,
                    "count": len(locators),
                    "avgScore": round(file_score, 1),
                    "worstScore": max(l["score"] for l in locators),
                }
                total_score += sum(l["score"] for l in locators)
                total_count += len(locators)

    # Strategy distribution
    strategy_counts = {}
    for fdata in all_files.values():
        for loc in fdata["locators"]:
            s = loc["strategy"]
            strategy_counts[s] = strategy_counts.get(s, 0) + 1

    # High-risk locators (score >= 60)
    high_risk = []
    for fpath, fdata in all_files.items():
        for loc in fdata["locators"]:
            if loc["score"] >= 60:
                high_risk.append({
                    "file": fpath,
                    "line": loc["line"],
                    "score": loc["score"],
                    "strategy": loc["strategy"],
                    "code": loc["code"],
                })

    high_risk.sort(key=lambda x: x["score"], reverse=True)

    result = {
        "summary": {
            "totalLocators": total_count,
            "avgFragility": round(total_score / total_count, 1) if total_count else 0,
            "highRiskCount": len(high_risk),
            "fileCount": len(all_files),
        },
        "strategyDistribution": dict(sorted(strategy_counts.items(), key=lambda x: -x[1])),
        "highRiskLocators": high_risk[:20],
        "perFile": {k: {"count": v["count"], "avgScore": v["avgScore"], "worstScore": v["worstScore"]}
                    for k, v in sorted(all_files.items(), key=lambda x: -x[1]["avgScore"])},
    }

    json.dump(result, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    try:
        main()
    finally:
        _cleanup()
