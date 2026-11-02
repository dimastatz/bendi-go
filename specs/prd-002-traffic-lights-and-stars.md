# PRD-002: Traffic Lights and Stars

## Goal

Add the core learning loop: see a traffic rule, follow it, and earn a star. Traffic lights come first because they are the easiest rule for a kid to understand.

## Player value

Players learn how Israeli traffic lights work, including the parts that differ from other countries (the flashing green and the red-and-yellow together). They earn stars for stopping at red, and Bendi explains what to do when they get it wrong.

## How Israeli traffic lights work

The light goes through these steps, in order:

| Light | Meaning for the driver |
| :---- | :--------------------- |
| Green | Go |
| Flashing green | The light is about to change. Get ready to stop |
| Yellow | Stop, unless you are too close to stop safely |
| Red | Stop before the stop line and wait |
| Red and yellow together | The light is about to turn green. Get ready, but do not go yet |

## User stories

- As a player, I see working traffic lights at the intersections in town.
- As a player, I earn a star when I stop at a red light and wait until it turns green.
- As a player, if I drive through a red light, Bendi tells me what I should have done, and I don't lose any stars.
- As a player, I can always see how many stars I have.

## Requirements

1. At least 3 of the 4 intersections from PRD-001 get traffic lights, with a white stop line painted before each light.
2. Lights cycle through the steps in the table above. Lights facing crossing directions are coordinated so both are never green at the same time.
3. Light timing: green about 15 seconds, flashing green 3 seconds, yellow 3 seconds, red and yellow 2 seconds. Timing is set in one config file so it can be tuned after playtesting.
4. The game checks each player's car at each light:
   - **Stopped at red:** the car came to a full stop before the stop line while the light was red, and stayed stopped until green. The player earns 1 star.
   - **Ran a red:** the car crossed the stop line while the light was red. The player gets a tip, not a star.
   - Crossing on yellow is not counted as a mistake, because stopping may not have been safe.
5. A single light can give the same player a star at most once every 60 seconds, so players can't earn stars by circling one intersection.
6. A star counter is always shown on screen. Earning a star plays a short animation and sound.
7. Tips appear as a speech bubble from the Bendi mascot for about 4 seconds. Example: "Red light means stop! Wait behind the white line until it turns green."
8. The first time a player sees a flashing green or a red-and-yellow light, Bendi explains what it means.
9. All tip and HUD text is in English and Hebrew, using a Roblox localization table. The language follows the player's Roblox language setting.
10. Stars are kept for the current session only. Saving them comes in PRD-006.

## Acceptance criteria

- [ ] Each light shows all five steps in the right order, and crossing directions are never green together.
- [ ] Stopping at a red light and waiting for green gives exactly 1 star.
- [ ] Driving through a red light shows a tip and does not change the star count.
- [ ] Circling back to the same light within 60 seconds gives no extra star.
- [ ] With Roblox set to Hebrew, all text appears in Hebrew and reads correctly right-to-left.
- [ ] Ben can explain what flashing green means after playing.

## Out of scope

- Right turns on red (not allowed in Israel anyway, so no special handling).
- Saving stars between sessions.
- Leaderboards.

## Open questions

- Does Roblox render Hebrew right-to-left correctly in the HUD and speech bubbles? Test early and pick a fallback if not.
