# Changelog

Each version of Bendi Go finishes one or more milestones from [specs/](specs/README.md).

## Unreleased

- **Driving lessons and license (PRD-006):** Five guided lessons, one for each rule, with arrows on the road and a mini-map. Earning 3 stars passes a lesson and opens the next one, and a new player starts lesson 1 right away. After all five, the driving test opens; following every rule on it earns a Bendi Go driving license card with the player's name, avatar, and date, plus a "Licensed driver" badge on their car. Stars, lessons, and the license are saved between visits.
- **Realistic graphics (PRD-007):** The town now has realistic light, shadows, and distant fog, and the day slowly turns into evening and night and back again. At night, street lamps, headlights, and the windows of buildings light up. Curbs are painted the Israeli way: red and white where stopping isn't allowed, blue and white for paid parking. Buildings have windows with shutters, balconies, and roof walls, trees are fuller, gardens have hedges, and every car has tinted windows, wheels with rims, lights, and an Israeli license plate. The Bendi car keeps its big eyes and "BENDI GO" plate. Players can switch to an inside view from the driver's seat, with a speedometer, a speed limit sign, a clock, a steering wheel that turns with their hands on it, and the driving instructor sitting next to them.
- **Brake lights (PRD-008):** The Bendi car's taillights turn bright red when the player brakes and stay on while the car waits, just like the NPC cars. Every player sees every Bendi car's brake lights.

## 0.2.0

The town now has real traffic rules to learn. Players earn stars for following them, and Bendi gives a friendly tip when they make a mistake.

- **Traffic lights and stars (PRD-002):** Four crossings have Israeli traffic lights, which go red, red and yellow, green, flashing green, then yellow. Stopping at a red light earns a star, and Bendi explains flashing green and red and yellow the first time a player sees them. A star counter shows how many stars the player has.
- **Speed limits (PRD-003):** Town streets have a 50 km/h limit, and a quiet street and the school street have a 30 km/h limit, with signs and a speedometer. Driving a whole street within the limit earns a star.
- **Pedestrian crossings (PRD-004):** Zebra crosswalks have people walking across: kids, adults, and older people. Stopping to let them cross earns a star, and they step back if a car comes too close.
- **Roundabouts and yielding (PRD-005):** NPC cars drive around town. There is a roundabout where players give way to cars already in it, plus a stop sign and a give-way sign. Stopping fully at the stop sign earns a star.
- All tips and messages are in English and Hebrew.

## 0.1.0

- **Drive around town (PRD-001):** A town with streets, sidewalks, buildings, trees, and parked cars, and a car to drive around it. Players can steer with the keyboard or on-screen touch controls. A chase camera follows the car, and a reset button puts it back on the road.
