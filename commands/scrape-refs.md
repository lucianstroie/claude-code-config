---
description: Scrape docs site to numbered markdown files
argument-hint: <url>
allowed-tools: [WebFetch, Write, Bash, Read, Glob, Task, AskUserQuestion]
model: sonnet
---

Scrape documentation from: $ARGUMENTS

## Steps

1. Parse URL to suggest folder path:
   - Extract domain and path segments
   - Propose: `References/{Domain}/{PathSegment}`
   - Use AskUserQuestion to confirm or get custom path

2. Fetch main page with WebFetch, extract navigation:
   - Look for sidebar nav, table of contents, or sitemap
   - Build ordered list of pages with hierarchy
   - Use AskUserQuestion to show sitemap and confirm

3. Use Task agent to scrape each page:
   - Fetch page content
   - Convert to clean markdown (title, headings, content)
   - Save with numbered prefix preserving order:
     - Top-level: 1.Title.md, 2.Title.md
     - Sub-pages: 2a.Title.md, 2b.Title.md
     - Nested: 2b-i.Title.md

4. Create folder with `mkdir -p`, write files with Write tool

5. After all pages scraped, create `index.md` in the same folder:
   - **Title**: "# {Project} Documentation Index"
   - **Quick Reference**: Links to most important/commonly needed pages
   - **By Topic**: Group all files by category with brief descriptions
     - Each entry: `**filename.md** - One-line description of contents`
     - Include key params, concepts, or gotchas where relevant
   - **Common Patterns**: Cross-cutting concerns, integration points, frequently combined operations

Example index.md structure:
```markdown
# Railgun Documentation Index

## Quick Reference
- Shield/unshield: ./12b.Shielding.md
- Private transfers: ./12c.Private-Transfers.md
- Key derivation: ./10a.Encryption-Keys-New.md

## By Topic

### Getting Started
- **9.Getting-Started.md** - Setup overview
- **9a.Setting-Up-Environment-Constants.md** - Network configs, chain IDs

### Transactions
- **12b.Shielding.md** - Depositing tokens into Railgun
- **12e.Unshielding.md** - Withdrawing to public address
- **12c.Private-Transfers.md** - Private-to-private transfers

### Encryption & Wallets
- **10a.Encryption-Keys-New.md** - Viewing keys, spending keys
- **10c.RAILGUN-Wallets.md** - Wallet creation and management

## Common Patterns
- Relayer/broadcaster usage: see 13.Broadcasters.md
- Cross-contract calls (DeFi): see 12d.Cross-Contract-Calls.md
```
