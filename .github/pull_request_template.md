<!--
Mustry Academy — PR template
Keep it short; the goal is to make the reviewer's job easy.
-->

## What

<!-- One or two sentences describing what this change does. -->

## Why

<!-- Why are we making this change now? Link any related issue or discussion. -->

## How to test

<!-- Specific commands or steps the reviewer can run. -->

## Checklist

- [ ] Validation passes locally (`scripts/validate.sh`, run from the lab folder you changed)
- [ ] Gateway still starts cleanly (the lab's `scripts/setup.sh` or `docker compose up -d` → gateway reaches RUNNING) — for project changes
- [ ] No secrets committed (`.env` stays local)
- [ ] Changes are scoped to one logical thing (and one lab)
