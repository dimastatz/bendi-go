# PRD-009: Levels and Goals

## Goal

Make every drive a small mission. Each driving session has one clear goal, shows its progress while the player drives, and ends at a finish line with a result. Passing sessions moves the player up through levels, from their first lesson to Expert driver, so there is always a next thing to aim for, even after the license.

## Player value

Players always know what they are trying to do and how close they are. Finishing a session feels like an achievement, and levels give a reason to come back after the license. A session that doesn't go well is never a failure: Bendi says what to practise, and the player tries again right away.

## User stories

- As a player, before I drive, I know exactly what my goal is.
- As a player, while I drive, I can see how close I am to my goal and to the finish line.
- As a player, when I finish, I see how well I did and what to practise next.
- As a player, when I don't reach my goal, I can try again right away and I don't lose anything.
- As a player, I move up in levels and unlock new kinds of drives: busier streets, night driving, and driving without arrows.

## Requirements

### Every session has a goal

1. A driving session is one drive from a start to a finish line: a lesson, the driving test, or a new mission. Free driving is not a session and stays open at any time.
2. Before a session starts, a goal card shows the goal in a few words (for example, "Stop at 3 red lights"), the route on the mini-map, and what passing needs. The player taps Start. A brand-new player sees the goal card of lesson 1 right away.
3. Each session has one goal, of one of these kinds:
   - Earn a number of stars (the five lessons, as in PRD-006).
   - Follow one rule a number of times: for example, stop at 3 red lights, or let 2 pedestrians cross.
   - Follow every rule on the route (the driving test, as in PRD-006).
   - Reach the finish line.

   Sessions (route, goal, and options) are plain data in core, so new sessions can be added without new code.

### Visible progress

4. While driving, a progress panel at the top of the screen shows the goal, a counter (for example, "2 of 3"), and a bar showing how much of the route is done, with a mark for each checkpoint. It changes the moment a star or checkpoint is reached. It doesn't cover the pedals, the Reset car button, or the view button.
5. Arrows on the road and the mini-map show the way, as in PRD-006, except in Expert sessions (requirement 14).

### Finishing a session

6. A session ends at the finish line. A mistake never ends it early: Bendi gives a tip as usual, and the player keeps driving.
7. At the finish, a result card shows how it went:
   - **Bronze medal:** the goal was met.
   - **Silver medal:** the goal was met, and at most one rule was missed.
   - **Gold medal:** the goal was met, and every rule was followed. A passed driving test is always gold.
   - **Not yet:** the goal wasn't met. The card says what went well and names one or two rules to practise, for example, "Almost! You stopped at 2 of 3 red lights." The game never says "failed".

   Medals are different from the stars players earn while driving, so the two are never confused.
8. The result card has Try again and Free driving buttons, plus Next when a new session has opened. Try again restarts the session from its start right away. Players can replay any open session as often as they like, and replaying can improve the session's best medal.
9. The player can stop a session at any time from the progress panel. Stopping counts as nothing, good or bad.
10. There are no time limits and nothing rewards driving fast, so the game never encourages speeding.

### Levels

11. Sessions are grouped into levels. Passing every session in a level opens the next level, with a short "Level up!" celebration and Bendi saying what's new.
12. The levels are:
    1. **Learner:** driving basics and traffic lights (lessons 1 and 2).
    2. **Road user:** speed limits and crosswalks (lessons 3 and 4).
    3. **Test day:** roundabouts and signs (lesson 5), then the driving test, which still earns the license and badge from PRD-006.
    4. **Licensed driver:** missions that mix rules on longer routes, such as a school run (the school zone and its crosswalk) and a roundabout round trip.
    5. **Busy town:** missions with more NPC cars and pedestrians on the route.
    6. **Night driver:** missions at night.
    7. **Expert:** missions without arrows on the road.

    Levels 4 to 7 have at least 2 missions each.
13. In a night mission, the player's own sky turns to night for the whole session, with the street lamps and headlights on, even when it's daytime for other players. This is the only exception to everyone sharing the same sky (PRD-007, requirement 2).
14. In an Expert mission, there are no arrows on the road and the mini-map shows only the car. A few seconds before each turn, the instructor says where to go, for example, "Turn right at the next crossing."
15. The player's level is easy to see: a level badge with a progress bar (for example, "Level 4 · 1 of 2 passed") in the Levels menu and on the result card. Other players see the level next to the car's licensed driver badge.
16. The Lessons menu becomes a Levels menu. It shows every level, its sessions, whether each one is open, locked, or passed, and each session's best medal.
17. Players never go down a level and never lose stars, medals, or their license.

### Saving

18. Passed sessions and best medals are saved with the rest of the player's progress (PRD-006). The level is worked out from the passed sessions and never saved on its own, so it can't get out of step.
19. Players who already have progress keep it. The first time they load, their passed lessons and license count toward the new levels.
20. All new text (goals, result cards, level names, and the instructor's directions) is in English and Hebrew.

## Acceptance criteria

- [ ] Every lesson, the test, and every mission starts with a goal card that says what to do and what passing needs.
- [ ] The progress panel's counter and route bar match what the player did, and update as soon as a star or checkpoint is reached.
- [ ] Making a mistake during a session shows a tip, and the session keeps going to the finish line.
- [ ] Meeting the goal shows a bronze, silver, or gold medal that matches how many rules were missed.
- [ ] Missing the goal shows "Not yet" with what to practise. Try again restarts the session at once, and nothing is lost.
- [ ] Passing every session in a level shows "Level up!" and opens the next level's sessions in the Levels menu.
- [ ] A night mission is night for that player only, and an Expert mission has no arrows but gives a direction before every turn.
- [ ] A player who had passed lessons or a license before this milestone starts on the matching level.
- [ ] Leaving and rejoining keeps the level, passed sessions, and best medals.
- [ ] There is no timer anywhere, and driving faster never gives a better result.

## Out of scope

- Leaderboards, races, and comparing with friends.
- Timers or rewards for speed.
- Rewards that can be bought.
- Losing levels, stars, or medals for any reason.
