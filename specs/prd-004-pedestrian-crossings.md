# PRD-004: Pedestrian Crossings

## Goal

Add people walking around town, and teach players to stop and let pedestrians cross at crosswalks.

## Player value

The town feels alive, and players learn one of the most important rules for keeping people safe: pedestrians at a crosswalk go first.

## User stories

- As a player, I see people walking on the sidewalks and crossing at crosswalks.
- As a player, I earn a star when I stop and let someone cross.
- As a player, if I drive through a crosswalk while someone is crossing, Bendi explains why I should have stopped.
- As a player, pedestrians never get hurt, even if I make a mistake.

## Requirements

1. The map gets at least 4 crosswalks with black-and-white zebra stripes and a crosswalk sign. At least 2 are in the middle of a block (not at a traffic light), and 1 is in the school zone from PRD-003.
2. NPC pedestrians walk along the sidewalks and cross at crosswalks. Each crosswalk has a pedestrian crossing every 20 to 40 seconds, so players meet crossings often.
3. Before crossing, a pedestrian waits at the curb for a moment and looks both ways. They do not step into the road if a car is too close to stop.
4. The game checks each player's car at each crosswalk:
   - **Let them cross:** a pedestrian was waiting or crossing, and the car stopped before the crosswalk until the pedestrian reached the other side. The player earns 1 star.
   - **Didn't stop:** the car drove onto the crosswalk while a pedestrian was on it. The player gets a tip, not a star.
5. A crosswalk can give the same player a star at most once every 60 seconds.
6. Pedestrians can never be hit. If a car gets too close, the pedestrian steps back to the curb, and the car is gently slowed. There is no injury or crash animation.
7. Pedestrians include kids, adults, and an older person walking slowly, with different looks.
8. The first time a player meets a waiting pedestrian, Bendi explains the rule. Example: "Someone wants to cross! Stop before the stripes and let them go first."

## Acceptance criteria

- [ ] Pedestrians walk and cross at every crosswalk on their own.
- [ ] Stopping for a crossing pedestrian and waiting gives exactly 1 star.
- [ ] Driving onto a crosswalk while someone is on it shows a tip and gives no star.
- [ ] No pedestrian can be knocked over or pushed by a car, from any angle or speed.
- [ ] 10 pedestrians walking at once do not make the game lag on a phone.

## Out of scope

- Pedestrian traffic lights.
- Pedestrians crossing outside crosswalks.
