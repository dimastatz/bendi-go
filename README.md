<div align="center">
<h1 align="center"> Bendi Go </h1>
<h3>Learn Israeli Traffic Rules by Driving in Roblox</br></h3>
<img src="https://img.shields.io/badge/Progress-5%25-red"> <img src="https://img.shields.io/badge/Feedback-Welcome-green">
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

Open `bendi-go.rbxl` in Roblox Studio, click **Connect** in the Rojo plugin, then press **Play**. You'll be put in your Bendi car:

| Key | Action |
| :-- | :----- |
| W or Up arrow | Drive forward |
| S or Down arrow | Brake, then reverse |
| A / D or Left / Right arrows | Steer |
| Space | Brake |

Before opening a pull request, run the same checks as CI:

```bash
stylua --check .   # formatting
selene .           # lint
scripts/test.sh    # unit tests with 95% coverage
```

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
