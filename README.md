<div align="center">
<h1 align="center"> Bendi Go </h1>
<h3>Learn Israeli Traffic Rules by Driving in Roblox</br></h3>
<img src="https://img.shields.io/badge/Progress-95%25-yellow"> <img src="https://img.shields.io/badge/Feedback-Welcome-green">
</br>
</br>
<kbd>
<img src="docs/images/bendi-go-car.png" alt="Bendi Go car" width="256px">
</kbd>
</div>

## About The Project

### Bendi Go
Bendi Go is an open-source Roblox game that teaches kids Israeli traffic rules by driving. Instead of memorizing rules from a book, players get behind the wheel, drive through a city, and learn what to do at traffic lights, roundabouts, and crosswalks. Every rule followed earns a star.

### How It Works
Players drive around a city full of real-world traffic situations. When they handle a situation correctly, they earn stars:

| Situation        | What To Do                           |
| :--------------- | :----------------------------------- |
| Traffic light    | Stop at red, go on green             |
| Roundabout       | Yield to cars already in the circle  |
| Crosswalk        | Let pedestrians cross                |
| Any road         | Keep to the speed limit              |

### Who Builds It
Bendi Go is built by Ben &amp; Dima, a father-and-son team, as a way to learn game development together while making something useful for other kids.

### Tech Stack
- **[Luau](https://luau.org/)**: the gradually typed scripting language Roblox games are written in
- **[Rojo](https://rojo.space/)**: syncs code from the filesystem into Roblox Studio, so the game can be developed with regular editors and Git
- **[Roblox Studio](https://create.roblox.com/)**: builds, tests, and publishes the game

### Prerequisites

Before working on Bendi Go, install:

- **Roblox Studio**: download from [create.roblox.com](https://create.roblox.com/)
- **Rokit**: the toolchain manager that installs the pinned versions of Rojo, StyLua, Selene, and Luau. See the [Rokit installation guide](https://github.com/rojo-rbx/rokit#installation)
- **Rojo Studio plugin**: see the [Rojo installation guide](https://rojo.space/docs/v7/getting-started/installation/)

### How To Use It

```bash
# Clone the repository and install the tools
git clone https://github.com/dimastatz/bendi-go.git
cd bendi-go
rokit install

# Build the place file, then live-sync code changes into Studio
rojo build -o bendi-go.rbxl
rojo serve
```

Open `bendi-go.rbxl` in Roblox Studio, click **Connect** in the Rojo plugin, then press **Play**. You'll be put in your Bendi car in a small Israeli neighborhood:

| Control | Keyboard | Gamepad | Touch |
| :------ | :------- | :------ | :---- |
| Drive forward | W or Up arrow | Right trigger | Gas pedal |
| Brake, then reverse | S or Down arrow | Left trigger | Brake pedal |
| Steer | A / D or Left / Right arrows | Left stick | ◀ ▶ buttons |
| Brake | Space | A or B | |
| Reset car | R or the Reset car button | Y | Reset car button |

Four crossings have Israeli traffic lights (red and yellow, green, flashing green, yellow, red). Stop before the white line at a red light and wait for green to earn a star. Light timing is set in `src/core/TrafficLightConfig.luau`.

Town streets are 50 km/h, and a residential street and the school street are 30 km/h, each marked with a speed limit sign. The speedometer at the bottom of the screen shows your speed and the limit. Drive a whole street without going more than 3 km/h over the limit to earn a star.

People walk around town and cross at four zebra crosswalks. Stop before the stripes and let them cross to earn a star. Pedestrians can never be hit: they step back to the curb, and your car is gently slowed.

Other cars drive around town and follow the same rules. At the roundabout, give way to cars already going around; at the stop signs, stop completely before the line; at the give-way sign, let cars on the main road go first. Each earns a star.

The **Lessons** button opens five short lessons, one for each rule: driving basics, traffic lights, speed limits, crosswalks, and roundabouts and signs. Follow the arrows on the road and the mini-map, and earn at least 3 stars to pass and open the next lesson. A new player starts lesson 1 right away, and **Free driving** is always one tap away. After all five lessons, the driving test opens: follow every rule on a longer route to earn your own Bendi Go driving license, and a "Licensed driver" badge on your car that everyone can see.

Stars, lessons, and the license are saved with Roblox DataStores. In Studio, saving only works once the place is published and **Game Settings → Security → Enable Studio Access to API Services** is on; without it, the game still works and just doesn't save.

One stud is 0.28 m, so the car's top speed of 70 km/h is about 69 studs per second. All speeds go through `src/core/Units.luau`.

Before opening a pull request, run the same checks as CI:

```bash
stylua --check .   # formatting
selene .           # lint
scripts/test.sh    # unit tests with 95% coverage
```

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
