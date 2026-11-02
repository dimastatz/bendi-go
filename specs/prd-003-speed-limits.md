# PRD-003: Speed Limits

## Goal

Teach players to notice speed limit signs and keep their speed under the limit, especially in places where people are around, like near a school.

## Player value

Players learn to read Israeli speed limit signs and learn that some places need slower driving. They earn stars for driving a whole street at a safe speed.

## User stories

- As a player, I can see how fast I'm driving.
- As a player, I see speed limit signs and know the limit on every street.
- As a player, I earn a star when I drive a whole street without going over the limit.
- As a player, if I go too fast, Bendi reminds me to slow down.

## Requirements

1. A speedometer on screen shows the car's speed in km/h, using the scale set in PRD-001.
2. The speedometer also shows the current speed limit, and turns orange when the car is over the limit.
3. The map gets speed zones:
   - Regular town streets: 50 km/h, the Israeli default in towns.
   - A residential street: 30 km/h.
   - A school zone next to a new school building: 30 km/h.
4. Each zone starts with an Israeli-style speed limit sign (red circle with the number) on the right side of the road. School zones also get a "school ahead" warning sign and painted road marking.
5. A "street segment" is the road between two intersections. If a player drives a whole segment without going over the limit by more than 3 km/h, they earn 1 star. The 3 km/h margin keeps small bumps over the limit from feeling unfair.
6. A segment can give the same player a star at most once every 60 seconds.
7. Driving more than 3 km/h over the limit for more than 2 seconds shows a tip, at most once per segment. Example: "This street is 30. Slow down, there's a school here!"
8. The first time a player enters a 30 km/h zone, Bendi explains why some streets are slower.
9. Stopping at a red light (PRD-002) does not break a segment, and waiting does not count against the player.

## Acceptance criteria

- [ ] The speedometer reading matches the car's real speed within 2 km/h.
- [ ] Every street has a visible limit sign at its start, and the HUD shows the right limit on every street.
- [ ] Driving a 50 km/h segment at 45 km/h gives 1 star; driving it at 60 km/h gives a tip and no star.
- [ ] Driving the school zone at 30 km/h or less gives 1 star.
- [ ] Tips don't repeat more than once per segment.

## Out of scope

- Intercity roads and higher speed limits.
- Speed cameras and fines.
