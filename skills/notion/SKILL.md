# Notion

Unified skill for all Notion operations with intelligent routing and safety confirmations.

## When to Use

- User says `/notion` or `/notion <subcommand>`
- User asks to search, read, create, update, or upload to Notion
- User provides a Notion URL
- User wants to manage Notion databases

## Subcommands

```
/notion                     # Interactive - asks what to do
/notion search <query>      # Search pages/databases
/notion read <url-or-id>    # Fetch and display page content
/notion create              # Create new page
/notion update <url-or-id>  # Update existing page
/notion upload [file]       # Upload file content to Notion
/notion db create           # Create new database
/notion db update <url>     # Update database schema
```

## Pre-flight: MCP Connection Check

Before executing any Notion operation, verify MCP connectivity:

1. **Implicit check:** The first MCP tool call serves as the connection test
2. **On failure:** Immediately trigger the MCP re-authorization flow (see Error Handling)
3. **On success:** Continue with the requested workflow

If a tool call fails mid-workflow, do not continue - trigger re-auth flow and offer to retry from the beginning.

---

## Routing Logic

Evaluate in this order:

1. **Explicit subcommand** - `/notion search X` routes to SEARCH workflow
2. **Argument patterns**:
   - Notion URL or UUID -> READ workflow
   - Local file path (.md, .txt) -> UPLOAD workflow
3. **Natural language**:
   - "search/find in Notion" -> SEARCH
   - "show me/what's in" -> READ
   - "put this in/upload to Notion" -> UPLOAD
   - "create a page/new page" -> CREATE
   - "update/edit/change the" -> UPDATE
   - "delete/trash" -> UPDATE (with trash)

**Priority when patterns overlap:**
1. Explicit subcommand takes highest priority
2. URLs/IDs take priority over natural language
3. Fall through to "Ambiguous" when truly unclear

4. **Ambiguous** - Ask user:
   ```
   What would you like to do in Notion?
   1. Search for something
   2. Read a page
   3. Create a new page
   4. Update an existing page
   5. Upload a file
   ```

---

## Workflows

### SEARCH (no confirmation needed)

**Trigger:** `/notion search <query>` or "search Notion for..."

**Steps:**
1. Execute `notion-search` with query
2. Display results:

```
NOTION SEARCH: "<query>"
---
Found X results:

Pages:
  1. [Page Title] - Team/Location - modified YYYY-MM-DD
  2. [Page Title] - Team/Location - modified YYYY-MM-DD

Databases:
  3. [Database Title] - Team/Location - X entries

---
Enter number to read, or "create" to make a new page
```

---

### READ (no confirmation needed)

**Trigger:** `/notion read <url|id>` or Notion URL provided

**Steps:**
1. Parse URL/ID from input
2. Execute `notion-fetch` with ID
3. Display content:

```
NOTION PAGE: [Title]
---
Location: [Team] > [Parent Page]
Type: Page | Database entry
Last edited: YYYY-MM-DD
---

[Content - first 20-30 lines]

---
[If long: "Showing first 30 lines of ~200"]

Enter "more" to continue, "update" to modify, or "copy" to duplicate
```

---

### CREATE (confirmation required)

**Trigger:** `/notion create` or "create a page in Notion"

**Step 1 - Content:**
```
What content should the new page have?
1. I'll write it now (enter content)
2. Generate from topic (describe what you want)
3. Empty page (just title)
```

**Step 2 - Destination Discovery:**
Use `notion-search` for related pages and `notion-get-teams` for teams:
```
Where should this page be created?

[Team Name]:
  1. [Related page]
  2. [Database - add as entry]

[Another Team]:
  3. [Related page]

4. Create as standalone page
5. Other (paste URL or describe)
```

**Step 3 - Preview:**
```
NOTION CREATE PREVIEW
---
Target: [Destination] in [Team]
Title: [Page title]
Type: Page | Database entry
Length: ~X words
---
Content preview:
[First 5-10 lines]
---

Proceed? (yes/no/edit)
```

**Step 4:** On "yes", execute `notion-create-pages` and return URL.

---

### UPDATE (confirmation required)

**Trigger:** `/notion update <url|id>` or "update/edit the..."

**Step 1 - Fetch and show current state:**
```
NOTION PAGE: [Title]
---
Location: [Team] > [Parent]
Properties: [if database entry]
---
Current content:
[First 20 lines]
---

What would you like to change?
1. Update properties (title, status, etc.)
2. Replace content
3. Append content
4. Move to trash
```

**Step 2 - Preview:**
```
NOTION UPDATE PREVIEW
---
Page: [Title] in [Team]
Change type: [Properties | Content | Both | Trash]
---

CHANGES:
[For properties: old -> new]
[For content: replacement preview or diff]

---
Proceed? (yes/no/edit)
```

**Step 3:** On "yes", execute `notion-update-page` and return URL.

**For trash requests:**
```
NOTION TRASH PREVIEW
---
Page: [Title]
Location: [Team] > [Parent]
---

This will move the page to trash (recoverable in Notion for 30 days).

Proceed? (yes/no)
```

Use `notion-update-page` with properties to move to trash (soft delete only).

---

### UPLOAD (confirmation required)

**Trigger:** `/notion upload [file]` or "put this in Notion"

Preserves the existing notion-upload workflow:

**Step 1 - Identify Content:**
- If file path provided: read that file
- If no path: ask "What would you like to upload to Notion?"
- Accept: file path, "current document", or pasted content

**Step 2 - Format Selection:**
```
How would you like this uploaded?
1. Summary (3-5 bullet points)
2. Full document (preserves structure)
```

**Step 3 - Destination Discovery:**
Use `notion-search` and `notion-get-teams`:
```
Where should this go?

[Team Name]:
  1. [Related page name]
  2. [Another related page]

[Another Team]:
  3. [Related page]

4. Create new page (specify location)
5. Other (paste URL or describe)
```

**Step 4 - Preview:**
```
NOTION UPLOAD PREVIEW
---
Target: [Selected destination]
Format: [Summary | Full document]
Length: ~X words, Y sections
Sections: [heading list]
---
Preview:
[First 5-10 lines only]
---

Proceed? (yes/no/edit)
```

**Step 5:** On "yes", execute `notion-create-pages` and return URL.

---

### DATABASE CREATE (extra confirmation - type "confirm")

**Trigger:** `/notion db create` or "create a database in Notion"

**Step 1 - Gather schema:**
```
What database would you like to create?

Please describe:
1. Database name/title
2. Properties needed (columns)
   - e.g., "Status (select: To Do, In Progress, Done)"
   - e.g., "Due Date (date)"
   - e.g., "Assignee (people)"
3. Purpose (helps suggest properties)
```

**Step 2 - Destination Discovery:**
Same tree view as CREATE workflow.

**Step 3 - Preview:**
```
DATABASE CREATE PREVIEW
---
Name: [Database Title]
Location: [Team] > [Parent Page]
---

Schema:
| Property | Type | Options |
|----------|------|---------|
| Name | title | - |
| Status | select | To Do, In Progress, Done |
| Due Date | date | - |

---
Creating a database is a significant action.
Type "confirm" to proceed, or "edit" to modify.
```

**Step 4:** On "confirm", execute `notion-create-database` and return URL.

---

### DATABASE UPDATE (extra confirmation - type "confirm")

**Trigger:** `/notion db update <url|id>` or "update database schema"

**Step 1 - Fetch and show current schema:**
```
DATABASE: [Title]
---
Location: [Team] > [Parent]
Entries: X pages
---

Current schema:
| Property | Type | Options |
|----------|------|---------|
| Name | title | - |
| Status | select | To Do, In Progress, Done |
...

What would you like to change?
1. Add property
2. Rename property
3. Remove property
4. Update select/multi-select options
5. Move to trash
```

**Step 2 - Preview:**
```
DATABASE UPDATE PREVIEW
---
Database: [Title] in [Team]
Entries affected: X pages
---

CHANGES:
- ADD: "Priority" (select: High, Medium, Low)
- RENAME: "Status" -> "Project Status"
- REMOVE: "Old Field" (data will be lost!)

---
Modifying a database schema affects all X entries.
Type "confirm" to proceed, or "edit" to modify.
```

**Step 3:** On "confirm", execute `notion-update-database` and return URL.

**For trash requests:**
```
DATABASE TRASH PREVIEW
---
Database: [Title]
Location: [Team] > [Parent]
Contains: X entries
---

This will move the database and all entries to trash (recoverable for 30 days).
Type "confirm" to proceed.
```

---

## Safety Rules

### All Write Operations Require Confirmation
- Pages: Standard "Proceed? (yes/no/edit)" confirmation
- Databases: Extra confirmation - must type "confirm"

### Never Permanently Delete
- All deletions use soft delete (move to trash)
- Always mention content is recoverable in Notion for 30 days
- Never use permanent deletion

### Preview Requirements
- Never show raw markdown dumps in previews
- Max 10 lines of content preview
- Always show target location, action type, and scope
- For databases, always show affected entry count

### Destination Discovery Pattern
When creating or uploading, always:
1. Search for related pages using `notion-search`
2. Get teams using `notion-get-teams`
3. Present tree view with numbered options
4. Include "standalone" and "other" options

---

## Error Handling

### MCP Connection Failures

When any Notion MCP tool call fails with connection errors, timeout, or authorization issues:

**Detection triggers:**
- "MCP server not connected"
- "Connection refused"
- "Authorization failed"
- "Token expired"
- "MCP tool failed"
- Tool returns empty/null when it shouldn't
- Timeout errors

**Automatic re-authorization flow:**

1. **Detect and inform:**
```
NOTION CONNECTION ISSUE
---
The Notion MCP server isn't responding. This usually means:
- The OAuth token has expired
- The MCP server needs to be restarted
- Authorization was revoked

Let me help you reconnect.
```

2. **Prompt for re-authorization:**
```
To reconnect to Notion:

1. Run: /mcp
2. Find "notion" in the server list
3. Select "Restart" or "Reconnect"
4. If prompted, re-authorize in browser

Once done, say "ready" and I'll retry your request.
```

3. **Retry logic:**
- After user confirms ready, retry the original operation
- If still failing after re-auth attempt, escalate:
```
Still unable to connect. Try these steps:

1. Check MCP server status: /mcp
2. Remove and re-add the Notion integration:
   - Remove: mcp remove notion
   - Re-add: mcp add notion
3. Verify OAuth in Notion settings: https://www.notion.so/my-integrations

Let me know when you've tried these steps.
```

### Standard Errors

```
Page not found:
  "Could not find that page. It may have been deleted or you may not have access.
   Try: /notion search [keywords]"

Permission denied:
  "You don't have permission to [action] this [page|database].
   The page may be in a restricted teamspace."

Invalid URL/ID:
  "That doesn't look like a valid Notion URL or page ID.
   Expected format: https://notion.so/... or a UUID"

Search returned nothing:
  "No results found for '[query]'.
   Try broader search terms, or /notion create to make a new page"
```

---

## Guidelines

- Default to asking questions when intent is unclear
- Read operations (search, read) need no confirmation
- Write operations always need confirmation preview
- Database operations need extra confirmation (type "confirm")
- Use consistent formatting across all previews
- Always return Notion URL after successful writes
- For summaries: generate concise bullet points, not walls of text
- For full documents: preserve original headers and structure
