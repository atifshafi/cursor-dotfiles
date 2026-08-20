#!/usr/bin/env bash
# afterFileEdit hook: auto-format .ts files with Prettier when edited in a repo that has it
input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')

if [ -z "$file_path" ]; then
  exit 0
fi

case "$file_path" in
  *.ts|*.tsx)
    ;;
  *)
    exit 0
    ;;
esac

dir=$(dirname "$file_path")
while [ "$dir" != "/" ]; do
  if [ -f "$dir/node_modules/.bin/prettier" ]; then
    "$dir/node_modules/.bin/prettier" --write "$file_path" > /dev/null 2>&1
    exit 0
  fi
  dir=$(dirname "$dir")
done

exit 0
