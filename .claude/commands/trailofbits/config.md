You are installing or updating Trail of Bits' Claude Code configuration into the user's `~/.claude/` directory.

## Source files

Fetch each file from GitHub using WebFetch. The base URL is:

```
https://raw.githubusercontent.com/trailofbits/claude-code-config/main/
```

Files to fetch when needed:
- `settings.json`
- `claude-md-template.md`
- `rules/python.md`, `rules/rust.md`, `rules/typescript.md`, `rules/bash.md`, `rules/github-actions.md`
- `mcp-template.json`
- `scripts/statusline.sh`
- `commands/review-pr.md`
- `commands/fix-issue.md`

Install into `$CLAUDE_CONFIG_DIR` if it is set, otherwise `~/.claude`. The paths below use `~/.claude` for brevity; substitute the configured directory when it differs. When it differs, also rewrite `~/.claude` references *inside* the installed content — the fetched `settings.json` points its `statusLine` at `~/.claude/statusline.sh`, and `claude-md-template.md` points at `~/.claude/rules/` — so the installed files track the configured directory.

## Steps

1. **Inventory what exists.** Read `~/.claude/settings.json`, `~/.claude/CLAUDE.md`, `~/.mcp.json`, `~/.claude/statusline.sh`, and check for `~/.claude/rules/`, `~/.claude/commands/review-pr.md`, and `~/.claude/commands/fix-issue.md`. Note which files exist and which don't.

2. **Ask the user what to install.** Use AskUserQuestion with a single multi-select question. List each component with a short description. Pre-label components that are missing from `~/.claude/` as recommended. Components:
   - **settings.json** — permissions, hooks, telemetry, statusline config
   - **CLAUDE.md** — global development standards and tool preferences
   - **Language rules** — path-scoped toolchain config for Python, Rust, TypeScript, Bash, and GitHub Actions
   - **MCP servers** — Context7, Exa, Granola
   - **Statusline script** — two-line status bar with context/cost tracking
   - **review-pr command** — multi-agent PR review workflow
   - **fix-issue command** — end-to-end issue fixing workflow

   If the user selects CLAUDE.md without Language rules, tell them the two are designed as a pair: the template's toolchain table points at `~/.claude/rules/` for the detailed lint and supply-chain config, so installing it alone leaves that reference dangling. Conversely, if they select Language rules but keep an existing CLAUDE.md based on the old single-file template, point out that its inline language sections now duplicate — and can contradict — the rules, and offer to trim them.

3. **Fetch selected files.** Use WebFetch to download only the files needed for the user's selections from the GitHub URLs above. Extract the raw file content from each response.

4. **For each selected component, install it:**

   - **settings.json**: If `~/.claude/settings.json` doesn't exist, write it directly. If it does exist, read both files and merge the repo's keys into the existing file — preserve any user keys that don't conflict. Show the user the merged result and ask for confirmation before writing.

   - **CLAUDE.md**: If `~/.claude/CLAUDE.md` doesn't exist, write the fetched `claude-md-template.md` content to `~/.claude/CLAUDE.md`. If it already exists, tell the user it exists and ask whether to overwrite, skip, or show a diff. Never silently overwrite CLAUDE.md — it likely has personal customizations.

   - **Language rules**: Create `~/.claude/rules/` and write each fetched rule file into it. Preserve the `paths:` frontmatter exactly — it is what scopes each rule to its language, and a rule without it loads in every session. After writing, read each installed file back and confirm it starts with a `---` frontmatter block containing a non-empty `paths:` list; WebFetch can paraphrase or strip content, and a rule that loses its frontmatter silently becomes always-loaded. Re-fetch and rewrite any file that fails the check. Any rule file the user has already customized gets the same treatment as CLAUDE.md: ask before overwriting. Tell the user to start a new session (or restart Claude Code) so the new rule files are picked up.

   - **MCP servers**: If `~/.mcp.json` doesn't exist, write the fetched template to `~/.mcp.json` and remind the user to replace `your-exa-api-key-here`. If it exists, read it, merge any missing server entries from the template, and show the result before writing.

   - **Statusline script**: Write to `~/.claude/statusline.sh` and `chmod +x` it. Safe to overwrite — it has no user customization.

   - **Commands**: Write to `~/.claude/commands/review-pr.md` and/or `~/.claude/commands/fix-issue.md`. Create the directory if needed. Safe to overwrite.

5. **Self-install.** After completing the user's selections, also install this setup command itself to `~/.claude/commands/trailofbits/config.md` so the user can run `/trailofbits:config` from any directory in the future without needing the repo cloned.

6. **Post-install.** Summarize what was installed/updated. If MCP servers were installed, remind the user about the Exa API key. If CLAUDE.md was installed, suggest they review and customize it.
