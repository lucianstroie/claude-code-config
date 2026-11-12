---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---

# Rust

**Runtime:** latest stable via `rustup`.

| purpose      | tool                                                       |
| ------------ | ---------------------------------------------------------- |
| build & deps | `cargo`                                                    |
| lint         | `cargo clippy --all-targets --all-features -- -D warnings` |
| format       | `cargo fmt`                                                |
| test         | `cargo test`                                               |
| supply chain | `cargo deny check` (advisories, licenses, bans)            |
| safety check | `cargo careful test` (stdlib debug assertions + UB checks)  |

## Style

- Prefer `for` loops with mutable accumulators over long iterator chains
- Shadow variables through transformations (no `raw_x`/`parsed_x` prefixes)
- Prefer patterns that break on type changes: no `_` arms, exhaustive `match` over `matches!`, explicit fields over `..`
- `let...else` for early returns; keep the happy path unindented

## Type design

- Newtypes over primitives (`UserId(u64)`, not `u64`)
- Enums for state machines, not boolean flags
- `thiserror` for libraries, `anyhow` for applications
- `tracing` for logging (`error!`/`warn!`/`info!`/`debug!`), not `println!`

## Performance

Write efficient code by default: correct algorithm, appropriate data structures, no unnecessary allocations. Profile before micro-optimizing, and measure after.

## Cargo.toml lints

Panic prevention, hygiene, and safety are enforced by config, not prose:

```toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
# Panic prevention
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"
panic_in_result_fn = "deny"
unimplemented = "deny"
# No cheating
allow_attributes = "deny"
# Code hygiene
dbg_macro = "deny"
todo = "deny"
print_stdout = "deny"
print_stderr = "deny"
# Safety
await_holding_lock = "deny"
large_futures = "deny"
exit = "deny"
mem_forget = "deny"
# Pedantic relaxations (too noisy)
module_name_repetitions = "allow"
similar_names = "allow"
```

## Tests

Use `cargo-mutants` to verify tests actually catch failures, and `proptest` for parsers, serialization, and algorithms.
