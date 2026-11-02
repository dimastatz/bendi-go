# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Bendi Go is an open-source Roblox game that teaches kids Israeli traffic rules by driving: stop at red lights, yield at roundabouts, let pedestrians cross, and keep to the speed limit. Players earn stars for every rule they follow. It is built by Ben & Dima, a father-and-son team, so keep code and explanations approachable for a young co-developer.

## Status

The repository has no source code yet. It contains only the README, an MIT LICENSE, a Luau `.gitignore`, `docs/images/` (project artwork), and `specs/`. There is no Rojo project file, toolchain manifest, build, lint, or test setup yet. Update this file once they exist.

## Testing

All code must be covered by unit tests, with a minimum of 95% line coverage. A change that drops coverage below 95% is not done.

To make this reachable, keep game logic (rule checks, star awarding, light timing, speed zones, lesson progress) in pure Luau modules that don't call Roblox services directly, so they can be tested outside Roblox Studio. Scripts that touch Roblox APIs should stay thin and pass data into those modules.

## Specs

`specs/` holds one PRD per milestone (`prd-001-*.md` to `prd-006-*.md`), built in order. [specs/README.md](specs/README.md) lists the milestones and the rules that apply to all of them (Israeli rules done correctly, no star penalties, English and Hebrew text, kid safety, "done means published"). Read the relevant PRD before starting work on a feature.

## Intended stack

- **Luau** is the language for all game code.
- **StyLua** formats all Luau code, the way Black formats Python. Formatting is not up for debate: run StyLua before committing, and treat a failing `stylua --check` as a broken build.
- **Rojo** syncs the filesystem into Roblox Studio. Once a `default.project.json` exists, it defines how source folders map to the Roblox DataModel (for example `ReplicatedStorage` and `ServerScriptService`). Read it before adding or moving scripts.
