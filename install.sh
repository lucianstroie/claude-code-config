#!/usr/bin/env bash
# Deploy this personal Claude Code config into ~/.claude (user-level, global).
# Idempotent. Symlinks authored config so edits flow back to the repo.
#
# Vault / knowledge skills are NOT deployed here. They live in the Knowledge Bank
# repo as a project-scoped .claude/ and load automatically when you work inside it.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"

mkdir -p "$CLAUDE_DIR" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/config"

link() {
  # link <src> <dst>: replace an existing symlink, back up a real file/dir, then symlink
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "$dst.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  ln -s "$src" "$dst"
  echo "linked $dst -> $src"
}

link "$REPO_DIR/claude-md-template.md" "$CLAUDE_DIR/CLAUDE.md"
link "$REPO_DIR/settings.json" "$CLAUDE_DIR/settings.json"
link "$REPO_DIR/scripts/statusline.sh" "$CLAUDE_DIR/statusline.sh"
chmod +x "$REPO_DIR/scripts/statusline.sh"

# Per-item links so we never clobber plugin- or project-provided entries.
for d in commands skills agents; do
  for item in "$REPO_DIR/$d"/*; do
    [ -e "$item" ] || continue
    link "$item" "$CLAUDE_DIR/$d/$(basename "$item")"
  done
done

# Machine-local paths.env: generated once, never tracked.
if [ ! -f "$CLAUDE_DIR/config/paths.env" ]; then
  sed -e "s#__CLAUDE_DIR__#$CLAUDE_DIR#" -e "s#__HOME__#$HOME#" \
    "$REPO_DIR/config/paths.env.template" >"$CLAUDE_DIR/config/paths.env"
  echo "generated $CLAUDE_DIR/config/paths.env (edit machine-local values)"
fi

cat <<'EOF'

Done. Next:
- MCP servers: merge mcp-template.json into your MCP config and set EXA_API_KEY
  (servers live in ~/.claude.json, which install.sh does not touch).
- Vault skills: clone the Knowledge Bank repo; its .claude/ loads when you cd into it.
- Pull upstream updates: git fetch upstream && git merge upstream/main (or run /trailofbits:config).
EOF
