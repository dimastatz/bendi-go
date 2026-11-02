# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Bendi Go is an open-source Roblox game that teaches kids Israeli traffic rules by driving: stop at red lights, yield at roundabouts, let pedestrians cross, and keep to the speed limit. Players earn stars for every rule they follow. It is built by Ben & Dima, a father-and-son team, so keep code and explanations approachable for a young co-developer.

## Status

The repository has no source code yet. It contains only the README, an MIT LICENSE, a Luau `.gitignore`, and `docs/images/` (project artwork). There is no Rojo project file, toolchain manifest, build, lint, or test setup yet. Update this file once they exist.

## Intended stack

- **Luau** is the language for all game code.
- **Rojo** syncs the filesystem into Roblox Studio. Once a `default.project.json` exists, it defines how source folders map to the Roblox DataModel (for example `ReplicatedStorage` and `ServerScriptService`). Read it before adding or moving scripts.
