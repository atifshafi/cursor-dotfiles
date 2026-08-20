#!/usr/bin/env bash
# Parse JUnit XML test results and output a summary.
# Usage: parse-test-results.sh <file-or-directory>
#
# Accepts a single JUnit XML file or a directory containing multiple XML files.
# Outputs: total, passed, failed, skipped counts and lists failed test names.
# POSIX-compatible (works on macOS and Linux).

set -euo pipefail

usage() {
  echo "Usage: $0 <junit-xml-file-or-directory>"
  echo "  Parses JUnit XML and outputs test result summary."
  exit 1
}

[[ $# -lt 1 ]] && usage

INPUT="$1"
XML_FILES=()

if [[ -d "$INPUT" ]]; then
  while IFS= read -r -d '' f; do
    XML_FILES+=("$f")
  done < <(find "$INPUT" -name '*.xml' -print0 2>/dev/null)
elif [[ -f "$INPUT" ]]; then
  XML_FILES=("$INPUT")
else
  echo "Error: '$INPUT' is not a valid file or directory."
  exit 1
fi

if [[ ${#XML_FILES[@]} -eq 0 ]]; then
  echo "No XML files found in '$INPUT'."
  exit 1
fi

TOTAL=0
FAILURES=0
ERRORS=0
SKIPPED=0
FAILED_NAMES=()

extract_attr() {
  local attr="$1" file="$2"
  # Extract numeric value of an attribute from the first testsuite element
  sed -n 's/.*'"$attr"'="\([0-9]*\)".*/\1/p' "$file" | head -1
}

for xml in "${XML_FILES[@]}"; do
  if ! head -5 "$xml" | grep -q '<testsuite\|<testsuites'; then
    continue
  fi

  file_tests=$(extract_attr 'tests' "$xml")
  file_failures=$(extract_attr 'failures' "$xml")
  file_errors=$(extract_attr 'errors' "$xml")
  file_skipped=$(extract_attr 'skipped' "$xml")

  TOTAL=$((TOTAL + ${file_tests:-0}))
  FAILURES=$((FAILURES + ${file_failures:-0}))
  ERRORS=$((ERRORS + ${file_errors:-0}))
  SKIPPED=$((SKIPPED + ${file_skipped:-0}))

  # Extract failed test names: find testcase lines preceding <failure> or <error>
  # Use ' name=' (with leading space) to avoid matching classname=
  while IFS= read -r name; do
    [[ -n "$name" ]] && FAILED_NAMES+=("$name")
  done < <(grep -B1 '<failure\|<error' "$xml" 2>/dev/null \
    | grep '<testcase' \
    | sed 's/.* name="\([^"]*\)".*/\1/' \
    || true)
done

PASSED=$((TOTAL - FAILURES - ERRORS - SKIPPED))

echo "Total: $TOTAL, Passed: $PASSED, Failed: $((FAILURES + ERRORS)), Skipped: $SKIPPED"

if [[ ${#FAILED_NAMES[@]} -gt 0 ]]; then
  echo "Failed:"
  for name in "${FAILED_NAMES[@]}"; do
    echo "  - $name"
  done
fi
