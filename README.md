# Skyline Swinger

A 3D third-person grapple-swinging game for Godot 4.7. Swing through a procedurally
generated night city as an original hero in a teal suit with orange trim, collect
energy orbs, outrun hunter drones, and never touch the street.

Everything (hero, city, effects, sound) is generated in code. No downloaded assets.

## Controls

| Input | Action |
|---|---|
| Mouse | Look (the cursor is captured while playing) |
| Hold left mouse | Fire the grapple at the crosshair (max 60 m); release to let go |
| W A S D | Walk on rooftops; steer and pump the swing in the air |
| Space | Jump (from a rooftop) |
| Q / E | Reel the line in / out |
| Shift | Air dash toward the crosshair (1.2 s cooldown, bar at the bottom) |
| Esc | Pause menu (mouse sensitivity, volume, mute) |
| M | Mute / unmute |
| R | Restart after a run ends |

The crosshair turns orange when the grapple would hit something.

**Score** = metres travelled + 50 per orb. The best score is saved to `user://settings.cfg`:

- Linux: `~/.local/share/SkylineSwinger/settings.cfg`
- Windows: `%APPDATA%\SkylineSwinger\settings.cfg`

A run ends when you touch the street or a drone catches you. Drones get more numerous,
faster and more frequent the longer you survive.

## Run it on Linux

```sh
cd ~/Projects/skyline-swinger
godot              # opens straight into the game
godot -e           # opens the editor
./build/SkylineSwinger.x86_64   # the exported Linux build
```

## Build

Needs Godot 4.7.2 and the matching export templates in
`~/.local/share/godot/export_templates/4.7.2.stable/` (from Godot's GitHub release
`Godot_v4.7.2-stable_export_templates.tpz`). Then:

```sh
./build.sh
```

This produces:

- `build/SkylineSwinger.exe`: Windows x86_64, single file with the game data embedded
- `build/SkylineSwinger.x86_64`: Linux x86_64, single file

No Wine is needed. The Windows preset leaves `application/modify_resources` off, so the
`.exe` has Godot's default icon and version info.

## Test

```sh
godot --headless --quit-after 300   # load the title screen and quit
godot --headless -- --autotest      # scripted run: walk, grapple, swing, reel, dash, orb, drone, pause, death
```

The autotest prints `[autotest] ...` lines and ends with `[autotest] OK`. It never writes the save file.

## Layout

```
project.godot        engine config, autoloads (Settings, Sfx), Mobile renderer
export_presets.cfg   "Windows Desktop" and "Linux" presets
build.sh             headless import + both exports
scenes/              main.tscn (entry), player.tscn
scripts/
  main.gd            game flow, environment, drones, difficulty, autotest
  player.gd          movement, grapple, rope constraint, dash (tuning constants at the top)
  camera_rig.gd      follow camera, mouse look, FOV by speed, screen shake
  city.gd            chunked procedural city
  hero_model.gd      the hero built from primitives
  orb.gd, drone.gd   collectibles and enemies
  fx.gd              particle bursts
  sfx.gd             procedural sound (AudioStreamGenerator)
  settings.gd        input map, options, high score
  layers.gd          physics layer bits
shaders/             building windows and street lines
ui/                  ui.tscn + ui.gd (title, HUD, pause, game over)
```

## Tuning the swing

The swing feel lives in the constants at the top of `scripts/player.gd`:
`GRAVITY`, `SWING_ACCEL` (pumping), `ROPE_STIFFNESS`, `REEL_SPEED`, `RELEASE_BOOST`,
`DASH_SPEED`, `MAX_ROPE` and `AIR_ACCEL`.
