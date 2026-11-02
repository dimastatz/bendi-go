# PRD-006: Driving Lessons and License

## Goal

Turn free driving into a journey: short guided lessons that teach one rule at a time, saved progress, and a final driving test that earns a Bendi Go driving license.

## Player value

Players always know what to do next, can come back tomorrow and keep their stars, and get a goal to work toward: their own driving license, with their name on it.

## User stories

- As a new player, Bendi guides me through my first lesson so I know how to play.
- As a player, I can pick a lesson about one rule and practice it.
- As a player, my stars and finished lessons are still there next time I play.
- As a player, after finishing all lessons, I can take a driving test and earn a license.

## Requirements

### Lessons

1. There is one lesson for each rule from earlier milestones:
   1. Driving basics (from PRD-001)
   2. Traffic lights (PRD-002)
   3. Speed limits (PRD-003)
   4. Crosswalks (PRD-004)
   5. Roundabouts, stop signs, and give-way signs (PRD-005)
2. A lesson is a short route of 2 to 4 minutes, marked with arrows on the road and a mini-map. Bendi explains the rule at the start and gives tips along the way.
3. A lesson is passed when the player earns at least 3 stars on it. Players can retry any lesson as many times as they want.
4. Lesson 1 starts automatically the first time a player joins. Each later lesson unlocks when the previous one is passed. Free driving stays available at any time.
5. A lesson menu shows every lesson, whether it's locked, passed, and the best star count.

### Driving test and license

6. After passing all 5 lessons, the driving test unlocks: one longer route that includes every rule.
7. The test is passed when the player follows every rule on the route. Tips are still shown, so a failed test teaches something.
8. Passing the test shows a celebration and a Bendi Go driving license card with the player's Roblox display name, avatar picture, and the date. The license styling is inspired by the Israeli driving license.
9. The player's car gets a "licensed driver" badge that other players can see.

### Saved progress

10. Total stars, passed lessons, best star counts, and the license are saved with Roblox DataStores and loaded when the player joins.
11. If saving or loading fails, the player can keep playing, and the game retries saving later. Progress is never reset by a failed load.

## Acceptance criteria

- [ ] A brand-new player is guided through lesson 1 without needing any help.
- [ ] Leaving and rejoining keeps stars, passed lessons, and the license.
- [ ] Locked lessons can't be started, and passing a lesson unlocks the next one.
- [ ] Passing the driving test shows the license with the correct name, avatar, and date.
- [ ] Other players in the server can see the licensed driver badge.

## Out of scope

- Leaderboards and comparing with friends.
- Rewards that can be bought.
- Lessons beyond the five rules above.
