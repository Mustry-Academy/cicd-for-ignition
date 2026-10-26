# Validation and linters: cheat sheet

Reference reading for Part 1 (linters): which tool catches which class of bug, built
around the files this lab tracks: YAML, workflows, shell scripts and Perspective
`view.json` resources.

## The tools we install

| Tool | What it catches | Speed | Where it runs |
|---|---|---|---|
| **yamllint** | YAML syntax and style issues (`docker-compose.yml`, workflows, `.yamllint.yml`) | ms | local + CI |
| **actionlint** | GitHub Actions workflow correctness (syntax, expression typing) | ms | local + CI |
| **shellcheck** | Bash scripting bugs in `scripts/*.sh` | ms | local + CI |
| **iglint** | Ignition-native static analysis of the whole project: Perspective views, Jython scripts, expressions and the references between them | ms | local + CI |

Plus two validators that aren't really linters:

| Tool | What it catches |
|---|---|
| **`scripts/validate.sh`** | Every `*.json` under `projects/` is valid JSON, every `code.py` parses as Python 3. Exits 0 (green) or 1 (red). |
| **`docker compose config -q`** | Compose schema: "service not defined", port-string typos, malformed environment maps. |

## Three kinds of finding

**1. Syntax.** Does the file parse? `yamllint`, `docker compose config`, `actionlint` and
`scripts/validate.sh`. Cheap, fast, hard to argue with.

**2. Likely bug.** It parses, but the pattern is risky: `shellcheck` flagging an unquoted
`$VAR`, or `iglint` flagging a component reached via brittle `.getParent().getChild(...)`
traversal. It works today and breaks the moment someone renames or reorders something.

**3. Style.** Is it consistent? Some `yamllint` rules (line length) and `iglint`'s naming
conventions (PascalCase components, camelCase properties). Tune or disable rules *as long
as the team agrees*, and check the config in so the agreement is enforced.

## iglint: the Ignition-native linter

`iglint` statically analyzes an Ignition 8.3 project the way the gateway stores it on
disk, **without a running gateway**: Perspective views (components, bindings, transforms,
events), the Jython 2.7 scripts everywhere they live (also inside `view.json`),
expressions, and the references between them (views, named queries, library functions,
message types). Every finding points at an exact line and column, also inside a script
or expression embedded in JSON.

- **Package:** `iglint` on PyPI (v0.1.0, pinned)
- **Install:** `uv pip install iglint==0.1.0`
  in the Python 3.12 venv (CI installs it the same way)
- **Run (from the lab folder):** `iglint check .` (it finds `iglint.toml` from the path it
  lints, so `iglint check labs/03-github-actions` from the repo root works too)
- **Explain a rule:** `iglint rule BIND004`; list them all with `iglint rules`
- **Repo:** <https://github.com/Mustry-Solutions/iglint>
- **Docs:** <https://iglint.mustrysolutions.com/>

It's configured by the lab's `iglint.toml`, tuned so the clean `lab-project` passes with
zero findings. Every later lab uses the same rules. On top of iglint's default rule set
(syntax errors, undefined names, unknown `system.*` functions, references that resolve
nowhere, ...) it turns on two opt-in rules and tightens one:

- **NAME001 (name-pattern):** naming conventions per node type: components `PascalCase`,
  properties `camelCase`, message handlers `kebab-case`, custom methods `snake_case`. In
  this lab, component and custom-method violations are `error`; property and
  message-handler violations are `warning`.
- **BIND004 (polling-interval):** flags `now()` / `runScript()` polling faster than a
  minimum, **1000 ms** in this lab (iglint's default is 10000 ms), as an `error`.
- **VIEW018 (fragile-component-reference):** brittle traversal like `.getSibling()`,
  `.getParent()` and relative `../` paths that break when the component tree is edited.

Rules from the default set you will meet in this lab:

- **BIND005 (unresolved-property-reference):** a property reference that doesn't resolve
  to a real component or custom property (expressions and property bindings).
- **SCR001 (syntax-error)** and the other `SCR` rules: the Python inside views and in the
  script library, parsed as Jython 2.7 (the gateway's interpreter), not Python 3.
- **VIEW001 (invalid-json):** a resource that doesn't parse.

## scripts/validate.sh: the gateway-free project validator

It walks `projects/` and checks two things:

1. every `*.json` resource is valid JSON, and
2. every `code.py` parses as Python 3.

It needs nothing but `python3`, runs in about a second, and exits `0` when everything is
valid, `1` otherwise. The gateway runs Jython 2.7, so this is a Python-3 parse check, not a
Jython validator.

## Common findings and what they mean

### yamllint

- `line too long`: often a false positive for Compose env strings; this lab disables
  `line-length` in `.yamllint.yml`, with the reason in a comment.
- `trailing spaces`: strip the whitespace.
- `truthy value should be true/false`: YAML's `yes`/`no`/`on`/`off` boolean shorthand.

### shellcheck

- `SC2086: Double quote to prevent globbing and word splitting`: `$VAR` should almost
  always be `"$VAR"`.
- `SC2148: Missing shebang`: add `#!/usr/bin/env bash` at the top.
- `SC2034: VAR appears unused`.
- `SC2155: Declare and assign separately`: `local x=$(cmd)` masks `cmd`'s exit status.
  Split into two lines.

### actionlint

- `unknown action`: typo in the action name, or no version pinned.
- `expression type mismatch`: `${{ steps.foo.outputs.value }}` referenced before `foo`
  runs, or the wrong type in arithmetic.
- `the runner of "actions/checkout@v2" action is too old`: bump the action to a current
  release.

### iglint

- **Non-PascalCase component name:** `myButton` or `temp_gauge` instead of
  `TemperatureGauge`. `NAME001`, severity `error`. iglint suggests the new name and can
  rename the component and every reference to it (`iglint check --fix`, or
  `--unsafe-fixes` when it can't prove the rename is safe).
- **Sub-minimum polling interval:** a binding polling faster than 1000 ms. `BIND004`.
  Bump the interval, or use a tag change-driven binding.
- **Brittle component reference:** a binding or script reaching another component by
  relative path. `VIEW018`, plus `BIND005` when the target doesn't exist. Bind to a real
  data source, a custom property or a message handler instead.

## Further reading

- [yamllint docs](https://yamllint.readthedocs.io/): full rule reference
- [shellcheck wiki](https://www.shellcheck.net/wiki/): every error code explained
- [actionlint docs](https://github.com/rhysd/actionlint/blob/main/docs/checks.md): what it checks
- [iglint docs](https://iglint.mustrysolutions.com/): rule reference and configuration
