# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Bendi Go is an open-source Roblox game that teaches kids Israeli traffic rules by driving: stop at red lights, yield at roundabouts, let pedestrians cross, and keep to the speed limit. Players earn stars for every rule they follow. It is built by Ben & Dima, a father-and-son team, so keep code and explanations approachable for a young co-developer.

## Commands

Tool versions are pinned in `rokit.toml`. Install them with `rokit install`.

```bash
rojo serve            # live-sync into Roblox Studio (connect with the Rojo plugin)
rojo build -o bendi-go.rbxl   # build a place file
stylua .              # format all Luau code
stylua --check .      # check formatting (what CI runs)
selene .              # lint
scripts/test.sh       # run all specs and enforce 95% coverage on src/core
luau tests/core/Units.spec.luau   # run a single spec file
```

CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs the format check, lint, a Rojo build, and tests on every pull request and on pushes to `main`. All must pass. Nothing in CI runs Roblox itself, so gameplay changes must also be checked by playing in Studio.

## Code layout and testing

[default.project.json](default.project.json) maps the source folders into the game:

| Folder | Roblox location | Contents |
| :-- | :-- | :-- |
| `src/core/` | `ReplicatedStorage.Core` | Pure game logic, shared by server and client |
| `src/server/` | `ServerScriptService.Server` | Builds the map and cars, owns game state |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | Input, camera, HUD |

- `src/core/` holds pure game logic: car physics, rule checks, star awarding, light timing, speed zones, lesson progress. Modules here must not use Roblox services or instances, so they run under the plain `luau` CLI. Core modules require each other by relative string path (`require("./Units")`), which works both in the `luau` CLI and in Roblox.
- Scripts that touch Roblox APIs live in `src/server/` and `src/client/`, stay thin, and pass data into core modules. They require siblings with `require(script.Parent.X)` and core modules through `ReplicatedStorage.Core`.
- The car is driven arcade-style, not with wheel physics: an invisible `Base` part slides on the ground with no friction, and the driver's client sets its `Drive` (LinearVelocity) and `Turn` (AngularVelocity) constraints every frame from `CarPhysics.step`. The server builds the car (`CarBuilder`), seats the player, and gives the driver network ownership (`CarSpawner`).
- The town is described as plain numbers in `TownLayout` (street grid, lanes, lots, spawn and reset poses) and `TownProps` (buildings, trees, parked cars). `TownBuilder` turns them into parts. Cars drive on the right, and the lane to the right of a street's center line is `TownLayout.lanePose(street, along, direction, LANE_WIDTH / 2)`. Cars are stopped at curbs by invisible boxes over every sidewalk and block, so only roads are drivable.
- Each rule in `src/core` (`RedLightRule`, `SpeedRule`, ...) has `newState()` and `update(state, car, now, world)` and returns `RuleKit` events. `src/server/Rules.luau` runs every rule in its `RULES` list for every player. Rules that watch a way into a crossing or crosswalk use `Approach`.
- Moving things are simulated in core and drawn by the server: `Walkers` (pedestrians) and `NpcTraffic` (NPC cars, which loop on fixed routes that only turn right or use the roundabout). The server moves only each model's anchored root part; the client animates limbs (`PedestrianAnimator`). Pedestrians never collide. The server can gently slow a player's car by setting a `SpeedCap` attribute (studs per second) on it.
- Rules run on the server and award stars through `Stars` (with a per-key cooldown). `Rules.start` passes every star given and every tip to a listener in `Main.server`, which saves stars (`PlayerProgress`) and counts them for lessons (`LessonRunner`). The saved count reaches the client through the player's `Stars` attribute, and tips go through the `ReplicatedStorage.Remotes.BendiTip` remote event (declared in `default.project.json`) as `Strings` keys, with optional values to fill in. Traffic lights are worked out from `workspace:GetServerTimeNow()` with `TrafficLight.stateAt`, so the lights and the rule checks always agree.
- Lessons and the driving test are routes in `Lessons`, given as the points where they turn; `LessonRoute` turns them into checkpoints, and `LessonRun` follows one player through one. `LessonRunner` (server) runs them and talks to the client through the `BendiLesson` remote event; the client draws arrows and the mini-map (`LessonGuide`) from the same `Lessons` data, so both sides agree on the checkpoints.
- Saved progress is `Progress` (core: sanitize, merge, unlocks) stored by `PlayerProgress` (server) in a DataStore. Nothing is saved for a player whose save hasn't loaded, so a failed load never overwrites real progress. The player's `Licensed` attribute is copied to their car, where every client shows the badge (`LicenseBadges`).
- All player-facing text lives in `src/core/Strings.luau` in English and Hebrew. Clients read it through `Text.get(key)` or `Text.format(key, values)` for text with `{name}` placeholders, which load it into a Roblox LocalizationTable, never hard-coded strings.
- `tests/` mirrors `src/core/`. Each `*.spec.luau` file uses the helpers in `tests/TestKit.luau` and ends with `TestKit.finish()`. Specs require modules by relative path, for example `require("../../src/core/Units")`.
- Coverage is measured on `src/core/` only and must stay at or above 95% line coverage. A core module that no spec requires fails the check (`scripts/coverage.py`), so every new core module needs a spec.
- Formatting follows StyLua, the way Black formats Python. Never hand-format or argue with its output.

## Specs

`specs/` holds one PRD per milestone (`prd-001-*.md` to `prd-006-*.md`), built in order. [specs/README.md](specs/README.md) lists the milestones and the rules that apply to all of them (Israeli rules done correctly, no star penalties, English and Hebrew text, kid safety, "done means published"). Read the relevant PRD before starting work on a feature.
