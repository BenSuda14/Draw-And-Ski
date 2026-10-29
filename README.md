# ⛷ Draw & Ski

A Roblox skiing game where you **draw your own skis** on a grid, launch down a three-zone mountain, dodge obstacles, and land tricks.

Written in **Luau**. This repo holds a selection of the game's scripts as a showcase. The full game is developed in Roblox Studio.

## How the game plays

1. **Draw**: pick a material and fill squares on a 5×12 grid to design your ski. More squares and better materials give it more health.
2. **Launch**: you're sent to the top of the mountain.
3. **Ski**: steer with A/D, jump with Space, grab with G in mid-air. Hitting obstacles damages your ski; when its health runs out, the run is over.

## The course

There are three themed zones, each about 30 seconds long, and each steeper than the last.

| Zone | Theme | Slope | Obstacles | Drops |
|---|---|---|---|---|
| 1. Pinewood Pass | Snowy pine forest, cabins, lanterns | ~11–13° | Pines, boulders, fallen logs, snowmen | Waterfalls |
| 2. Glacier Gorge | Ice canyon, glowing crystals, ice arches | ~17–19° | Ice pillars, crystals, crevasses | Glacier drops |
| 3. Ember Peak | Volcanic ash, basalt, lava | ~22–25° | Basalt columns, burning trees, lava pools | Magma falls |

The terrain and roughly 800 obstacles were generated procedurally along a curving centerline. As you enter each zone, the lighting shifts and a banner appears.

## Scripts in this repo

| Script | What it does |
|---|---|
| `StarterCharacterScripts/SkiPhysics` | The ski controller: slope acceleration, steering, jumps and hang time, ramp launches, obstacle collisions, health, tricks |
| `StarterCharacterScripts/SkiEffects` | Visual effects while skiing |
| `StarterPlayerScripts/LobbyMusic` | Lobby music with fading and ducking, plus per-zone lighting, zone banners and the finish sequence |
| `ReplicatedStorage/SkiPrompt` | Reusable animated UI banner with a snow drape, icicles, drips and falling snow |

These scripts reference objects and other systems from the full game, so they won't run on their own.

### How a few things work

- **Obstacles and ramps use CollectionService tags.** Any part tagged `SkiObstacle` damages the ski on contact. Parts tagged `SkiRamp` make the controller follow the ramp surface and add a launch boost at the lip.
- **Ground detection** is a short downward raycast from the character each frame. On the ground, velocity follows the slope; in the air, a small upward force adds hang time.
- **Jumping obstacles:** brushing a log while airborne doesn't count as a crash, so you can jump over obstacles cleanly.

File naming follows the [Rojo](https://rojo.space) convention: `.client.luau` = LocalScript, `.luau` = ModuleScript.
