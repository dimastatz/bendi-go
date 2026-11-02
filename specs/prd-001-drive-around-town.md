# PRD-001: Drive Around Town

## Goal

Give players a car they can drive around a small Israeli-style neighborhood. Driving should feel fun on its own, because every later milestone depends on players wanting to drive.

This milestone also sets up the project, so that all later work can be built, tested, and published the same way.

## Player value

A kid opens Bendi Go, gets into the blue Bendi car, and drives around a neighborhood with streets, intersections, sidewalks, and buildings. No rules yet, just driving.

## User stories

- As a player, I spawn next to my own Bendi car and can get in right away.
- As a player, I can speed up, slow down, brake, reverse, and steer with the keyboard, a gamepad, or touch controls on a phone or tablet.
- As a player, I can drive around the whole neighborhood without getting stuck or falling off the map.
- As a player, if my car flips over or gets stuck, I can press one button to put it back on the road.

## Requirements

### Game

1. Each player gets their own Bendi car when they join. The car looks like the mascot in [docs/images/bendi-go-car.png](../docs/images/bendi-go-car.png): blue, big eyes, yellow "BENDI GO" license plate.
2. The car is controlled with:
   - Keyboard: W/S or arrow keys to drive and reverse, A/D or arrow keys to steer, Space to brake.
   - Gamepad: triggers to drive and brake, left stick to steer.
   - Touch: on-screen pedals and a steering control.
3. The car's top speed is about 70 km/h, so later speed-limit milestones (50 km/h in town) are meaningful.
4. The camera follows the car from behind and slightly above.
5. The map is one small neighborhood with:
   - At least 4 blocks and 4 four-way intersections.
   - Two-way streets with right-hand traffic, lane markings, and sidewalks.
   - Buildings, trees, and parked cars that make it look like an Israeli town.
   - Invisible walls at the map edges.
   - Space reserved (flat road, no buildings) for a roundabout, which is added in PRD-005.
6. A "Reset car" button puts the car upright on the nearest road, facing the direction of traffic.
7. Player cars do not collide with each other (separate collision group).
8. A fixed scale is chosen and written down: how many studs equal one meter. All later speeds in km/h use this scale.

### Project setup

9. Rojo project file (`default.project.json`) that maps source folders to the Roblox DataModel.
10. Pinned tool versions for Rojo, a formatter (StyLua), and a linter (Selene), installed through a toolchain manager.
11. A unit test runner that runs outside Roblox Studio and measures line coverage. The test command fails if coverage is below 95%.
12. CLAUDE.md and README.md updated with the commands to build, sync to Studio, lint, format, and run tests.

## Acceptance criteria

- [ ] Ben can join the published game on a computer and on a phone or tablet and drive with each control type.
- [ ] Ben can drive through every street and intersection without getting stuck.
- [ ] Driving at full speed into a map edge does not let the car leave the map.
- [ ] "Reset car" fixes a flipped car within 2 seconds.
- [ ] Two players in the same server can drive through each other's cars.
- [ ] Lint and format checks pass with no warnings.
- [ ] Unit tests pass with at least 95% line coverage.

## Out of scope

- Traffic lights, signs, other cars, and pedestrians.
- Stars, scoring, and saved progress.
- Car customization.
