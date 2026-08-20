# cursor-dotfiles

Cursor IDE configuration backup managed by [chezmoi](https://chezmoi.io).

## What's Included

- **19 custom skills** (`~/.cursor/skills/`)
- **34 workspace rules** (`~/Documents/work/automation/.cursor/rules/`)
- **Global rules** (`~/.cursorrules`)
- **Hook scripts** (`~/.cursor/hooks/` + `hooks.json`)
- **MCP server config** (`~/.cursor/mcp.json` -- secrets templated out)
- **2 symlink templates** for `acm-cluster-health` and `acm-cluster-remediation`

## Restore on a New Machine

```bash
# 1. Install chezmoi
brew install chezmoi

# 2. Clone this repo (do NOT use --apply; secrets don't exist yet)
chezmoi init git@github.com:atifshafi/cursor-dotfiles.git

# 3. Populate secrets before first apply
mkdir -p ~/.local/share/chezmoi/.chezmoidata
cp /path/from/secure-storage/secrets.yaml ~/.local/share/chezmoi/.chezmoidata/secrets.yaml
# Or run: bash ~/.local/share/chezmoi/scripts/fetch-secrets.sh

# 4. Verify templates render correctly
chezmoi apply --dry-run -v

# 5. Apply everything
chezmoi apply -v
```

> **WARNING**: Do NOT use `chezmoi init --apply` on a fresh machine.
> The `--apply` flag renders templates immediately, and `mcp.json.tmpl`
> will fail or produce empty values because `secrets.yaml` does not exist yet.

## secrets.yaml Format

Create `~/.local/share/chezmoi/.chezmoidata/secrets.yaml` with:

```yaml
secrets:
  jira_token: "your-jira-pat"
  polarion_pat: "your-polarion-jwt"
  github_pat: "ghp_your-token"
  google_oauth_secret: "GOCSPX-your-secret"
  gemini_api_key: "AIza-your-key"
  neo4j_password: "your-neo4j-password"
```

This file is gitignored and never pushed.

## Ongoing Sync

```bash
# After editing skills/rules locally:
chezmoi re-add
chezmoi git -- add -A && chezmoi git -- commit -m "sync" && chezmoi git -- push

# To pull on another machine:
chezmoi update
```

## Token Rotation

When a token expires, edit `secrets.yaml` and re-apply:

```bash
${EDITOR:-vi} ~/.local/share/chezmoi/.chezmoidata/secrets.yaml
chezmoi apply ~/.cursor/mcp.json
```

Tokens and where to rotate them:
- **JIRA PAT**: Atlassian Account > Security > API tokens
- **Polarion PAT**: Polarion > My Account > Personal Access Tokens
- **GitHub PAT**: GitHub > Settings > Developer settings > Tokens
- **Google OAuth**: Google Cloud Console (does not expire, can be revoked)
- **Gemini API key**: Google AI Studio (does not expire)
- **Neo4j password**: Local instance

## Post-Restore Steps

1. Clone `ai_systems_v2` to restore the symlink targets:
   ```bash
   # The symlinks for acm-cluster-health and acm-cluster-remediation
   # point to ~/Documents/work/ai/ai_systems_v2/.claude/skills/
   # They will be dead symlinks until that repo is cloned.
   ```

2. Install Cursor IDE and verify `~/.cursor/mcp.json` is picked up.

## Security

- This repo is **private**
- `secrets.yaml` is in `.gitignore` -- never committed
- `gitleaks` pre-commit hook blocks token patterns from being staged
- `mcp.json.tmpl` shows structure only, not secret values
