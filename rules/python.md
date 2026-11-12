---
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/*.ipynb"
  - "**/pyproject.toml"
  - "**/uv.lock"
---

# Python

**Runtime:** current stable CPython (check before pinning), with `uv venv`. Run scripts via `uv run python ...`, never a bare `python3`.

| purpose       | tool                         |
| ------------- | ---------------------------- |
| deps & venv   | `uv`                         |
| lint & format | `ruff check` · `ruff format` |
| static types  | `ty check`                   |
| tests         | `pytest -q`                  |

Use `uv`, `ruff`, and `ty` over pip/poetry, black/pylint/flake8, and mypy/pyright.

## Structural limits belong in ruff config

Don't restate limits in prose — encode them so the linter enforces them. The baseline:

```toml
[tool.ruff]
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "A", "C4", "C90", "PT", "SIM", "TID", "PL", "RUF", "D"]

[tool.ruff.lint.mccabe]
max-complexity = 8

[tool.ruff.lint.pylint]
max-args = 5
max-positional-args = 5
max-statements = 50

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.lint.flake8-tidy-imports]
ban-relative-imports = "all"

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["D"]
```

Each section needs its rule family in `select` to take effect: `C90` for `max-complexity`, `PL` for `max-args` (PLR0913), `max-positional-args` (PLR0917) and `max-statements` (PLR0915), `D` for the docstring convention, `TID` for the relative-import ban (TID252). Selecting `D` makes docstrings mandatory on every public module, class, and function; the per-file-ignores block keeps tests out of that.

Two limits to know about. `max-args` caps *total* arguments, so `max-positional-args` is what actually bounds positional ones — and PLR0917 was preview-gated before ruff 0.16, so on an older ruff it silently does nothing and that limit disappears. Ruff has no direct max-lines-per-function rule either; `max-statements` is the closest proxy, so treat function length as a review concern rather than assuming lint covers it.

## Types

Configure strictness via `[tool.ty.rules]` in `pyproject.toml`. Fix every diagnostic; if one genuinely can't be fixed, add an inline ignore with a justification comment.

## Packaging

`uv_build` for pure Python, `hatchling` for projects with extension modules.

## Tests

Tests live in `tests/`, mirroring the package structure.

## Supply chain

- `pip-audit` before deploying
- Pin exact versions (`==`, not `>=`)
- Verify hashes: `uv pip install --require-hashes`
