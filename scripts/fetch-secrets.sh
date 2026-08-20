#!/usr/bin/env bash
# fetch-secrets.sh -- Populate secrets.yaml interactively on a new machine.
# Run this after `chezmoi init` to set up the secrets data file.

set -euo pipefail

SECRETS_DIR="$HOME/.local/share/chezmoi/.chezmoidata"
SECRETS_FILE="$SECRETS_DIR/secrets.yaml"

if [ -f "$SECRETS_FILE" ]; then
  echo "secrets.yaml already exists at: $SECRETS_FILE"
  echo "Edit it directly if you need to update tokens."
  exit 0
fi

mkdir -p "$SECRETS_DIR"

echo "=== Cursor Dotfiles: Secret Setup ==="
echo ""
echo "You need to provide the following tokens/keys."
echo "Paste each value when prompted (input is hidden)."
echo ""

read -sp "JIRA Access Token: " jira_token; echo
read -sp "Polarion PAT: " polarion_pat; echo
read -sp "GitHub PAT: " github_pat; echo
read -sp "Google OAuth Client Secret: " google_oauth_secret; echo
read -sp "Gemini API Key: " gemini_api_key; echo
read -sp "Neo4j Password: " neo4j_password; echo

cat > "$SECRETS_FILE" << EOF
secrets:
  jira_token: "$jira_token"
  polarion_pat: "$polarion_pat"
  github_pat: "$github_pat"
  google_oauth_secret: "$google_oauth_secret"
  gemini_api_key: "$gemini_api_key"
  neo4j_password: "$neo4j_password"
EOF

chmod 600 "$SECRETS_FILE"
echo ""
echo "secrets.yaml written to: $SECRETS_FILE"
echo "Run 'chezmoi apply -v' to render mcp.json with your tokens."
