# PRD-005: Roundabouts and Yielding

## Goal

Add other cars to the road, and teach players who goes first: at roundabouts, at stop signs, and at give-way signs.

## Player value

Roundabouts are everywhere in Israel, and knowing who goes first is one of the hardest things for new drivers. Players practice it safely, with other cars to watch for.

## User stories

- As a player, I see other cars driving around town and through the roundabout.
- As a player, I earn a star when I wait for cars already in the roundabout before entering.
- As a player, I earn a star when I stop fully at a stop sign.
- As a player, I earn a star when I let other cars go first at a give-way sign.

## Requirements

### Other cars

1. NPC cars drive around town on fixed routes. They follow the same rules the player learns: they stop at red lights, stop for pedestrians, keep to speed limits, and yield at the roundabout.
2. NPC cars keep a safe distance and slow down for the player's car. If a player blocks one, it waits instead of pushing.
3. About 6 to 10 NPC cars drive at once, enough that the roundabout often has cars in it.

### Roundabout

4. A single-lane roundabout is built in the space reserved in PRD-001, with 4 entrances.
5. Each entrance has an Israeli roundabout sign (blue circle with arrows) and a give-way sign (upside-down triangle), plus a painted give-way line.
6. Cars drive counterclockwise around the roundabout.
7. The game checks each player's car at each entrance:
   - **Yielded:** an NPC car was in the roundabout near the entrance, and the player waited behind the give-way line until it passed. The player earns 1 star.
   - **Entered when clear:** the roundabout was empty near the entrance, and the player entered without stopping. The player earns 1 star, since that is also correct.
   - **Didn't yield:** the player entered while an NPC car in the roundabout had to slow down for them. The player gets a tip, not a star.

### Stop and give-way signs

8. One intersection without traffic lights gets stop signs (red octagon with a stop line) on its side street. The player earns 1 star for coming to a full stop before the line. Rolling through gives a tip.
9. Another intersection gets give-way signs on its side street. The player earns 1 star for letting NPC cars on the main street pass first.
10. Each entrance or sign can give the same player a star at most once every 60 seconds.

### Tips

11. The first time a player reaches a roundabout, a stop sign, or a give-way sign, Bendi explains the rule. Example: "Cars already in the roundabout go first. Wait for them, then join!"

## Acceptance criteria

- [ ] NPC cars drive on their own for 30 minutes without getting stuck or crashing into each other.
- [ ] NPC cars obey lights, crosswalks, speed limits, and the roundabout.
- [ ] Waiting for a car in the roundabout gives 1 star; cutting one off gives a tip and no star.
- [ ] Rolling through a stop sign at walking speed gives a tip, not a star.
- [ ] The game stays smooth on a phone with all NPC cars and pedestrians active.

## Out of scope

- Multi-lane roundabouts.
- Honking, crashes, and damage.
