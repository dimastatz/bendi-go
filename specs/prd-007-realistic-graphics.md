# PRD-007: Realistic Graphics

## Goal

Make Bendi Go look like a real town: realistic light and shadows, a sky that changes from day to night, street lamps and headlights that light up the road in the dark, and streets, buildings, trees, and cars with more detail.

## Player value

The town feels like a real place to drive in, so the rules feel real too. Driving at dusk with the street lamps and headlights on is a new experience, and the curbs teach one more Israeli rule just by being painted the right way.

## User stories

- As a player, the town looks like a real Israeli neighborhood, not a town made of blocks.
- As a player, I see the day turn into evening and night, and the street lamps, headlights, and windows light up.
- As a player, I can still see the road clearly at night.
- As a player, I can tell from the curb color where cars may park.

## Requirements

### Light and sky

1. The game uses Roblox's Future lighting, with soft shadows, light fog in the distance, a soft glow around bright lights, and slightly warmer colors. All of this is set in `default.project.json` under `Lighting`.
2. A whole day takes 20 minutes and is worked out from the server's clock (`DayCycle`), so every player sees the same sky. Most of it is daytime: an 11-minute day, a 2-minute sunset, a 4-minute night, and a 3-minute sunrise.
3. The night is never too dark to drive: the sky has some moonlight and the picture is brightened a little.

### Night lights

4. Street lamps stand along both sides of the streets and shine on the road when it gets dark. They stand between the street trees and stay clear of corners, crosswalks, and the roundabout, where the signs are.
5. Every moving car (the Bendi car and the NPC cars) turns on headlights that light up the road at night. NPC brake lights keep working as before.
6. At night, some of the windows in every building have the lights on inside.

### Streets

7. Curbs are painted the Israeli way:
   - Red and white: no stopping or parking. Within 12 m of every crossing, the roundabout, and every crosswalk. These are the same places that have no parked cars.
   - Blue and white: paid parking, on the two busy middle streets.
   - Plain gray: free parking everywhere else.
8. Roads, sidewalks, and curbs use more realistic materials, and sign and traffic light poles are metal.

### Buildings, trees, and gardens

9. Buildings have separate windows with roller shutter boxes above them, balconies with glass railings, a stone band along the bottom, and a low wall around the roof, plus the solar water heaters from PRD-001.
10. Round trees have fuller crowns in a few shades of green, and palms have drooping fronds and dates.
11. Gardens have low hedges along the sidewalk, with gaps to walk through.

### Cars

12. All cars (the Bendi car, NPC cars, and parked cars) have a body with bumpers, tinted windows with a sloped windshield, a roof, mirrors, wheels with silver rims, headlights, taillights, and yellow Israeli license plates with a number.
13. The Bendi car still looks like the mascot from PRD-001: blue, big eyes, and a yellow "BENDI GO" license plate.
14. How cars drive and bump into things doesn't change. Each car keeps its invisible collision box, and the new parts are only for looks.

### Performance

15. The game still runs smoothly on a phone or tablet. Lights don't cast shadows, and Roblox's own graphics quality setting lowers the detail on slower devices.

## Acceptance criteria

- [ ] The town has shadows, distant fog, and glowing lights, and looks more realistic than before.
- [ ] Waiting in the game shows the sun setting, a night with street lamps, headlights, and lit windows, and the sun rising again.
- [ ] Two players in the same server see the same time of day.
- [ ] The road is easy to see and drive on at night.
- [ ] Curbs are red and white near crossings and crosswalks, blue and white on the middle streets, and parked cars only stand next to blue-white or gray curbs.
- [ ] The Bendi car still has its blue body, big eyes, and "BENDI GO" plate, and drives exactly like before.
- [ ] The game runs smoothly on a phone.

## Out of scope

- 3D models made in Blender or taken from the Creator Store. Everything is still built from Roblox parts in code. Real models can replace the car or trees later without changing how the game works, because the look is kept separate from the collision boxes.
- Weather (rain, clouds).
- A graphics setting inside the game.
