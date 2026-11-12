---
paths:
  - "**/*.sh"
  - "**/*.bash"
---

# Bash

Every script starts with `set -euo pipefail`.

Lint and format before committing:

```bash
shellcheck script.sh && shfmt -d script.sh
```

`shfmt -i 2 -w script.sh` writes the formatting fix in place.

Quote every expansion (`"$var"`, `"$@"`). Prefer `[[ ]]` over `[ ]`. Check that a variable is set before using it in a path — an unset variable in `rm -rf "$dir/$sub"` is how scripts delete the wrong tree, and `set -u` only catches it if you never assign a default.
