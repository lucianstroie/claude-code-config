---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.mts"
  - "**/*.cts"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
  - "**/*.cjs"
  - "**/package.json"
  - "**/tsconfig.json"
---

# Node / TypeScript

**Runtime:** current Active LTS (check before pinning). ESM only (`"type": "module"`).

| purpose | tool           |
| ------- | -------------- |
| lint    | `oxlint`       |
| format  | `oxfmt`        |
| test    | `vitest`       |
| types   | `tsc --noEmit` |

Use `oxlint` and `oxfmt` over eslint/prettier. Enable the `typescript`, `import`, and `unicorn` plugins.

## tsconfig strictness

Enable all of these:

```jsonc
"strict": true,
"noUncheckedIndexedAccess": true,
"exactOptionalPropertyTypes": true,
"noImplicitOverride": true,
"noPropertyAccessFromIndexSignature": true,
"verbatimModuleSyntax": true,
"isolatedModules": true
```

## Tests

Colocated `*.test.ts` files alongside the code they cover.

## Supply chain

Use `pnpm`, not `npm` or `yarn`.

- `pnpm audit --audit-level=moderate` before installing
- Pin exact versions (no `^` or `~`)
- Enforce a 24-hour publish delay: `pnpm config set minimumReleaseAge 1440` (pnpm 10.16+; older versions ignore the setting silently)
- Block postinstall scripts: `pnpm config set ignore-scripts true`
