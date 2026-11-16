# PRD-008: Brake Lights

## Goal

The Bendi car's taillights light up red when the player slows down or stops, just like a real car and like the NPC cars already do.

## Player value

The car feels more real, and players learn what brake lights are for: they tell the drivers behind you that you are slowing down or stopped. Players can also see when other players' cars brake.

## User stories

- As a player, when I brake, I see my car's brake lights turn on.
- As a player, when I wait at a red light or a crosswalk, my brake lights stay on.
- As a player, I can see when another player's car brakes or stops.

## Requirements

1. Both taillights of the Bendi car light up bright red while the car slows down by braking:
   - Space, the brake pedal on a touch screen, or the gamepad's brake buttons.
   - Pressing back (S, the down arrow, or the left trigger) while the car is still rolling forward.
   - Braking while reversing.
   - The game slowing the car down by itself, for example when a pedestrian is right ahead.
2. The brake lights stay on while the car stands still with a driver in it, like a driver holding the brake pedal at a red light. This matches the NPC cars.
3. The brake lights stay off while the car speeds up, drives along, or just rolls with no pedal pressed. They go off soon after the player stops braking and drives on, and when the car starts reversing.
4. A Bendi car with no driver never has its brake lights on.
5. Every player sees every Bendi car's brake lights the same way. Each client works them out from how the car moves (`BrakeLights` in core), so there are no extra network messages. The lights don't flicker when the car's speed jumps a little as network updates arrive.

## Acceptance criteria

- [ ] Pressing Space, the brake pedal, or S while driving forward turns both taillights bright red within a moment.
- [ ] The taillights stay red while the car waits at a red light, and go dark soon after driving on.
- [ ] Letting go of the gas and rolling slowly to a stop doesn't turn the lights on until the car stops.
- [ ] Reversing doesn't turn the lights on, and braking while reversing does.
- [ ] An empty Bendi car's taillights are dark.
- [ ] A second player in the same server sees the first player's brake lights turn on and off at the same moments, with no flicker.
- [ ] NPC car brake lights work as before.
