# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Bendi Go is an open-source Roblox game that teaches kids Israeli traffic rules by driving: stop at red lights, yield at roundabouts, let pedestrians cross, and keep to the speed limit. Players earn stars for every rule they follow. It is built by Ben & Dima, a father-and-son team, so keep code and explanations approachable for a young co-developer.

## Commands

Tool versions are pinned in `rokit.toml`. Install them with `rokit install`.

```bash
stylua .              # format all Luau code
stylua --check .      # check formatting (what CI runs)
selene .              # lint
scripts/test.sh       # run all specs and enforce 95% coverage on src/core
luau tests/core/Units.spec.luau   # run a single spec file
```

CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs the format check, lint, and tests on every pull request and on pushes to `main`. All three must pass.

## Code layout and testing

- `src/core/` holds pure game logic: rule checks, star awarding, light timing, speed zones, lesson progress. Modules here must not use Roblox services or instances, so they run under the plain `luau` CLI.
- Scripts that touch Roblox APIs live outside `src/core/`, stay thin, and pass data into core modules.
- `tests/` mirrors `src/core/`. Each `*.spec.luau` file uses the helpers in `tests/TestKit.luau` and ends with `TestKit.finish()`. Specs require modules by relative path, for example `require("../../src/core/Units")`.
- Coverage is measured on `src/core/` only and must stay at or above 95% line coverage. A core module that no spec requires fails the check (`scripts/coverage.py`), so every new core module needs a spec.
- Formatting follows StyLua, the way Black formats Python. Never hand-format or argue with its output.

## Specs

`specs/` holds one PRD per milestone (`prd-001-*.md` to `prd-006-*.md`), built in order. [specs/README.md](specs/README.md) lists the milestones and the rules that apply to all of them (Israeli rules done correctly, no star penalties, English and Hebrew text, kid safety, "done means published"). Read the relevant PRD before starting work on a feature.

## Not set up yet

There is no Rojo project file (`default.project.json`) yet. Once it exists, it defines how source folders map to the Roblox DataModel (for example `ReplicatedStorage` and `ServerScriptService`). Read it before adding or moving scripts, and add Rojo to `rokit.toml` and the commands above.
